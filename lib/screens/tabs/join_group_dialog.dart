import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/database_helper.dart';
import 'group_detail_page.dart';
import '../../services/app_locale_service.dart';

/// 加入群組彈窗（支援 4 碼數字即時比對、QR Code 掃描模擬、邀請連結）
class JoinGroupDialog extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final VoidCallback onJoined;

  const JoinGroupDialog({
    super.key,
    required this.currentUser,
    required this.onJoined,
  });

  @override
  State<JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<JoinGroupDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 4 碼輸入控制器與焦點
  final List<TextEditingController> _codeControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  final TextEditingController _linkController = TextEditingController();
  bool _showLinkInput = false;

  bool _isSearching = false;
  Map<String, dynamic>? _foundGroup;
  bool _isMemberOfFoundGroup = false;
  bool _isPendingApproval = false;
  String? _searchError;

  bool _isJoining = false;

  String get _currentUserId => widget.currentUser['id'].toString();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var c in _codeControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    _linkController.dispose();
    super.dispose();
  }

  String get _currentEnteredCode {
    return _codeControllers.map((c) => c.text.trim()).join();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // 若貼上多個字元
      _handlePastedText(value);
      return;
    }

    if (value.isNotEmpty) {
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    final code = _currentEnteredCode;
    if (code.length == 4) {
      _lookupGroup(code);
    } else {
      setState(() {
        _foundGroup = null;
        _searchError = null;
      });
    }
  }

  void _handlePastedText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return;

    // 若包含 URL 或 query
    String code = text;
    try {
      final uri = Uri.tryParse(text);
      if (uri != null && uri.hasQuery) {
        code = uri.queryParameters['code'] ??
            uri.queryParameters['token'] ??
            text;
      }
    } catch (_) {}

    // 若是純 4 碼數字
    final numericOnly = code.replaceAll(RegExp(r'[^0-9]'), '');
    if (numericOnly.length >= 4) {
      final fourDigits = numericOnly.substring(0, 4);
      for (int i = 0; i < 4; i++) {
        _codeControllers[i].text = fourDigits[i];
      }
      _focusNodes[3].unfocus();
      _lookupGroup(fourDigits);
      return;
    }

    // 若為非 4 碼之 token 或連結，自動切換至文字欄位查詢
    setState(() {
      _showLinkInput = true;
      _linkController.text = text;
    });
    _lookupGroup(text);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _handlePastedText(data.text!.trim());
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(tr('jg_clip_empty')),
              duration: Duration(milliseconds: 1000),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  Future<void> _lookupGroup(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    setState(() {
      _isSearching = true;
      _foundGroup = null;
      _searchError = null;
    });

    try {
      final group = await DatabaseHelper.instance.getGroupByInviteCode(q);
      if (!mounted) return;

      if (group == null) {
        setState(() {
          _isSearching = false;
          _searchError = tr('jg_not_found');
        });
        return;
      }

      // 檢查是否已是成員
      final groupId = group['id'] as int;
      final membership = await DatabaseHelper.instance
          .getGroupMembership(groupId, _currentUserId);

      final isOwner = group['owner_id'].toString() == _currentUserId;
      final isMember = isOwner ||
          (membership != null && membership['status'] == 'active');
      final isPending =
          membership != null && membership['status'] == 'pending';

      setState(() {
        _isSearching = false;
        _foundGroup = group;
        _isMemberOfFoundGroup = isMember;
        _isPendingApproval = isPending;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchError = tr('jg_search_failed', [e.toString()]);
        });
      }
    }
  }

  Future<void> _executeJoin() async {
    if (_foundGroup == null) return;
    if (_isMemberOfFoundGroup) {
      // 已經是成員，直接開啟群組頁面
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupDetailPage(
            group: _foundGroup!,
            currentUser: widget.currentUser,
          ),
        ),
      );
      return;
    }

    setState(() => _isJoining = true);
    try {
      final groupId = _foundGroup!['id'] as int;
      final isPrivate = _foundGroup!['type'] == 'private';
      final requiresApproval =
          (_foundGroup!['join_requires_approval'] as int? ?? (isPrivate ? 1 : 0)) == 1;

      await DatabaseHelper.instance.joinGroup(
        groupId,
        _currentUserId,
        isPending: requiresApproval,
      );

      widget.onJoined();

      if (mounted) {
        Navigator.pop(context);
        if (requiresApproval) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(
                    tr('jg_requested', [(_foundGroup!['name']).toString()])),
                backgroundColor: Colors.orange.shade800,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
        } else {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(tr('jg_joined', [(_foundGroup!['name']).toString()])),
                backgroundColor: Theme.of(context).primaryColor,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupDetailPage(
                group: _foundGroup!,
                currentUser: widget.currentUser,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(tr('group_join_failed', [e.toString()])),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final bg = isDark ? const Color(0xFF222222) : Colors.white;
    final borderCol = isDark ? Colors.white12 : Colors.grey.shade200;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 標題與關閉按鈕 ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.group_add_rounded,
                        color: primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('jg_title'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF3E2723),
                          ),
                        ),
                        Text(
                          tr('jg_sub'),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Tab 切換（4 碼輸入 / QR 碼掃描）──
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      isDark ? Colors.white60 : Colors.grey.shade700,
                  labelStyle:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(
                      icon: Icon(Icons.pin_outlined, size: 16),
                      text: tr('jg_tab_code'),
                    ),
                    Tab(
                      icon: Icon(Icons.qr_code_scanner_rounded, size: 16),
                      text: tr('jg_tab_qr'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── Tab 內容 ──
              SizedBox(
                height: _tabController.index == 0 ? 175 : 175,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 0: 4 碼輸入
                    _buildPinInputTab(isDark, primaryColor, borderCol),
                    // Tab 1: QR 碼掃描
                    _buildQrScanTab(isDark, primaryColor),
                  ],
                ),
              ),

              // ── 查詢中狀態 ──
              if (_isSearching)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: primaryColor),
                      ),
                      const SizedBox(width: 10),
                      Text(tr('jg_searching'),
                          style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white70 : Colors.grey.shade600)),
                    ],
                  ),
                ),

              // ── 錯誤提示 ──
              if (_searchError != null)
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _searchError!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── 即時群組預覽卡片 ──
              if (_foundGroup != null) ...[
                const SizedBox(height: 12),
                _buildGroupPreviewCard(isDark, primaryColor, borderCol),
                const SizedBox(height: 16),

                // 加入 / 前往按鈕
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isJoining ? null : _executeJoin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isMemberOfFoundGroup
                          ? Colors.teal
                          : (_foundGroup!['type'] == 'private' &&
                                  (_foundGroup!['join_requires_approval'] == 1 ||
                                      _foundGroup!['join_requires_approval'] == null))
                              ? Colors.orange.shade800
                              : primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 1,
                    ),
                    child: _isJoining
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isMemberOfFoundGroup
                                    ? Icons.arrow_forward_rounded
                                    : (_foundGroup!['type'] == 'private'
                                        ? Icons.lock_open_rounded
                                        : Icons.check_circle_rounded),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isMemberOfFoundGroup
                                    ? tr('jg_go_group')
                                    : (_isPendingApproval
                                        ? tr('jg_pending_again')
                                        : (_foundGroup!['type'] == 'private'
                                            ? tr('jg_request')
                                            : tr('jg_join_now'))),
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── 4 碼輸入 Tab ──
  Widget _buildPinInputTab(
      bool isDark, Color primaryColor, Color borderCol) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_showLinkInput) ...[
          // 4 個方塊
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 48,
                height: 56,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _focusNodes[index].hasFocus
                        ? primaryColor
                        : (_codeControllers[index].text.isNotEmpty
                            ? primaryColor.withValues(alpha: 0.5)
                            : borderCol),
                    width: _focusNodes[index].hasFocus ? 2 : 1.2,
                  ),
                ),
                child: Center(
                  child: TextField(
                    controller: _codeControllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) => _onDigitChanged(index, val),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // 貼上按鈕 & 切換連結輸入
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.paste_rounded, size: 15),
                label: Text(tr('common_paste'), style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              Text('·', style: TextStyle(color: Colors.grey.shade400)),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _showLinkInput = true),
                style: TextButton.styleFrom(
                  foregroundColor:
                      isDark ? Colors.white60 : Colors.grey.shade700,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(tr('jg_use_link'),
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ] else ...[
          // 完整連結/Token 輸入框
          TextField(
            controller: _linkController,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: tr('jg_paste_hint'),
              hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                  fontSize: 12),
              filled: true,
              fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderCol),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search_rounded, size: 20),
                color: primaryColor,
                onPressed: () => _lookupGroup(_linkController.text),
              ),
            ),
            onSubmitted: _lookupGroup,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(Icons.paste_rounded, size: 14),
                label: Text(tr('jg_paste_clip'), style: TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _showLinkInput = false),
                style: TextButton.styleFrom(
                  foregroundColor:
                      isDark ? Colors.white60 : Colors.grey.shade700,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(tr('jg_back_code'),
                    style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── QR Code 掃描 Tab ──
  Widget _buildQrScanTab(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.25)
            : const Color(0xFFF9F7F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_scanner_rounded, size: 36, color: primaryColor),
          const SizedBox(height: 8),
          Text(
            tr('jg_aim_qr'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _pasteFromClipboard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.center_focus_strong_rounded, size: 15),
                label: Text(tr('jg_read_qr'),
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 即時群組預覽卡片 ──
  Widget _buildGroupPreviewCard(
      bool isDark, Color primaryColor, Color borderCol) {
    final g = _foundGroup!;
    final name = g['name'] as String? ?? tr('group_default_name');
    final iconEmoji = g['icon_emoji'] as String? ?? '📚';
    final desc = g['description'] as String? ?? '';
    final memberCount = g['member_count'] as int? ?? 1;
    final isPrivate = g['type'] == 'private';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFBF9F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isMemberOfFoundGroup
              ? Colors.teal.withValues(alpha: 0.5)
              : primaryColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(iconEmoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPrivate
                            ? Colors.orange.withValues(alpha: 0.15)
                            : Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPrivate ? tr('group_private') : tr('group_public'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPrivate
                              ? Colors.orange.shade700
                              : Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.people_outline,
                        size: 13,
                        color: isDark ? Colors.white38 : Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      tr('group_members_n', [memberCount.toString()]),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    if (_isMemberOfFoundGroup)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tr('jg_already_in'),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else if (_isPendingApproval)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tr('jg_pending'),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
