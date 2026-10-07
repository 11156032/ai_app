import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/database_helper.dart';
import '../../widgets/group_qr_code_widget.dart';
import '../../services/app_locale_service.dart';

/// 群組邀請管理頁（4 碼數字加入碼 + QR Code + 邀請連結）
class GroupInvitePage extends StatefulWidget {
  final Map<String, dynamic> group;
  final String currentUserId;
  final bool isOwnerOrAdmin;

  const GroupInvitePage({
    super.key,
    required this.group,
    required this.currentUserId,
    required this.isOwnerOrAdmin,
  });

  @override
  State<GroupInvitePage> createState() => _GroupInvitePageState();
}

class _GroupInvitePageState extends State<GroupInvitePage> {
  late Map<String, dynamic> _group;
  bool _isLoading = false;
  String? _expiryLabel; // 顯示用的過期標籤
  late String _linkType;

  @override
  void initState() {
    super.initState();
    _group = Map<String, dynamic>.from(widget.group);

    if (_group['type'] != 'private') {
      _linkType = 'auto'; // 公開群組預設直接加入
    } else if (widget.isOwnerOrAdmin) {
      _linkType = 'auto'; // 私人群組管理員預設直接加入
    } else {
      _linkType = 'approval'; // 私人群組成員預設需要審核
    }

    _refreshGroupData();
  }

  Future<void> _refreshGroupData() async {
    final groupId = _group['id'] as int?;
    if (groupId != null) {
      final updated = await DatabaseHelper.instance.getGroupById(groupId);
      if (updated != null && mounted) {
        setState(() {
          _group = updated;
          _updateExpiryLabel();
        });
        return;
      }
    }
    _updateExpiryLabel();
  }

  void _updateExpiryLabel() {
    final exp = _group['token_expires_at'] as String?;
    if (exp == null || exp.isEmpty) {
      _expiryLabel = tr('gi_forever');
    } else {
      final expDate = DateTime.tryParse(exp);
      if (expDate == null) {
        _expiryLabel = tr('gi_forever');
      } else if (expDate.isBefore(DateTime.now())) {
        _expiryLabel = tr('gi_expired');
      } else {
        final diff = expDate.difference(DateTime.now()).inDays;
        _expiryLabel = diff == 0 ? tr('gi_today') : tr('gi_days_left', [diff.toString()]);
      }
    }
  }

  String get _inviteCode => (_group['invite_code'] as String?) ?? '1000';

  String get _inviteToken => (_group['invite_token'] as String?) ?? '';

  String get _inviteUrl {
    return 'app://join?code=$_inviteCode&token=$_inviteToken&ref=${widget.currentUserId}&type=$_linkType';
  }

  bool get _linkActive => (_group['invite_link_active'] as int? ?? 1) == 1;

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _inviteCode));
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(tr('gi_code_copied', [_inviteCode.toString()])),
            backgroundColor: Theme.of(context).primaryColor,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _copyFullShareText() async {
    final groupName = _group['name'] as String? ?? tr('gi_default_name');
    final emoji = _group['icon_emoji'] as String? ?? '📚';
    final isPrivate = _group['type'] == 'private';
    final shareText = '''
$emoji 邀請你加入【$groupName】${isPrivate ? '(私人群組)' : ''}
🔑 4 碼快速加入碼：$_inviteCode
📲 開啟 App 至「社群 > 加入群組」輸入 4 碼即可加入！
🔗 邀請連結：$_inviteUrl
'''.trim();

    await Clipboard.setData(ClipboardData(text: shareText));
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(tr('gi_card_copied')),
            backgroundColor: Theme.of(context).primaryColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _inviteUrl));
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(tr('gi_link_copied')),
            backgroundColor: Theme.of(context).primaryColor,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _regenerateCodeAndToken() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.refresh_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(tr('gi_regen_q'), style: TextStyle(fontSize: 17)),
          ],
        ),
        content: Text(tr('gi_regen_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('btn_cancel'), style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('gi_regen_confirm')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final res = await DatabaseHelper.instance
          .regenerateInviteTokenAndCode(_group['id'] as int);
      final updated =
          await DatabaseHelper.instance.getGroupById(_group['id'] as int);
      if (mounted) {
        setState(() {
          _group = updated ?? _group;
          _group['invite_token'] = res['token'];
          _group['invite_code'] = res['code'];
          _isLoading = false;
          _updateExpiryLabel();
        });
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(tr('gi_regenerated', [(res['code']).toString()])),
              duration: const Duration(seconds: 2),
              backgroundColor: Theme.of(context).primaryColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLinkActive() async {
    final newActive = !_linkActive;
    await DatabaseHelper.instance
        .setInviteLinkActive(_group['id'] as int, newActive);
    final updated =
        await DatabaseHelper.instance.getGroupById(_group['id'] as int);
    if (mounted) {
      setState(() {
        _group = updated ?? _group;
        _updateExpiryLabel();
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(newActive ? tr('gi_on') : tr('gi_off')),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _setExpiry(String label, DateTime? expiresAt) async {
    await DatabaseHelper.instance
        .setTokenExpiry(_group['id'] as int, expiresAt);
    final updated =
        await DatabaseHelper.instance.getGroupById(_group['id'] as int);
    if (mounted) {
      setState(() {
        _group = updated ?? _group;
        _updateExpiryLabel();
      });
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(tr('gi_expiry_set', [label.toString()])),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  void _showExpirySheet() {
    final options = [
      {'label': tr('gi_forever'), 'days': null},
      {'label': tr('gi_1d'), 'days': 1},
      {'label': tr('gi_7d'), 'days': 7},
      {'label': tr('gi_30d'), 'days': 30},
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(tr('gi_expiry_title'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const Divider(height: 1),
            ...options.map((opt) => ListTile(
                  title: Text(opt['label'] as String),
                  trailing: (_expiryLabel == opt['label'])
                      ? Icon(Icons.check_circle,
                          color: Theme.of(context).primaryColor)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    final days = opt['days'] as int?;
                    final expiry = days != null
                        ? DateTime.now().add(Duration(days: days))
                        : null;
                    _setExpiry(opt['label'] as String, expiry);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderCol = isDark ? Colors.white12 : Colors.grey.shade200;
    final groupName = _group['name'] as String? ?? tr('group_default_name');
    final iconEmoji = _group['icon_emoji'] as String? ?? '📚';
    final memberCount = _group['member_count'] as int? ?? 1;

    final codeStr = _inviteCode.padLeft(4, '0');
    final digits = codeStr.split('');

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF7F5F3),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : const Color(0xFF1E293B),
        ),
        elevation: 0.5,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 18,
              color: isDark ? Colors.white : const Color(0xFF1E293B)),
          tooltip: tr('btn_cancel'),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tr('gi_title'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. 群組基本資訊卡 ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(iconEmoji,
                                style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(groupName,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _group['type'] == 'private'
                                          ? Colors.orange.withValues(alpha: 0.12)
                                          : Colors.blue.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _group['type'] == 'private'
                                          ? tr('gi_private')
                                          : tr('gi_public'),
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: _group['type'] == 'private'
                                              ? Colors.orange.shade700
                                              : Colors.blue.shade700),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(tr('group_members_n', [memberCount.toString()]),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey.shade600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 2. 4 碼數字加入碼專屬卡片 (最便利的加入方式) ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF25201C), const Color(0xFF1E1E1E)]
                            : [const Color(0xFFFFF9F5), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.pin_outlined,
                                  color: primaryColor, size: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tr('gi_code_title'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF3E2723),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _linkActive
                              ? tr('gi_code_hint')
                              : tr('gi_paused'),
                          style: TextStyle(
                            fontSize: 12,
                            color: _linkActive
                                ? (isDark ? Colors.white60 : Colors.black54)
                                : Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 4 個大號數字方塊
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            final digit = index < digits.length ? digits[index] : '-';
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 54,
                              height: 62,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.3)
                                    : primaryColor.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.4),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  digit,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: primaryColor,
                                    fontFamily: 'monospace',
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 20),

                        // 按鈕列 (複製 4 碼 / 複製完整邀請卡)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _linkActive ? _copyCode : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: Text(tr('gi_copy_code'),
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _linkActive ? _copyFullShareText : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryColor,
                                  side: BorderSide(color: primaryColor),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.share_outlined, size: 16),
                                label: Text(tr('gi_share_card'),
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 3. QR Code 卡片 ──
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2_rounded,
                                color: primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              tr('gi_qr_title'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // QR Code 視覺呈現
                        GroupQrCodeWidget(
                          data: _inviteUrl,
                          centerEmoji: iconEmoji,
                          size: 190,
                          foregroundColor: isDark ? Colors.white : const Color(0xFF3E2723),
                          backgroundColor: isDark ? const Color(0xFF282828) : Colors.white,
                          showFrame: true,
                        ),
                        const SizedBox(height: 14),

                        Text(
                          tr('gi_expiry_line', [_expiryLabel.toString(), (_linkActive ? tr('gi_scan_or_code') : tr('gi_closed')).toString()]),
                          style: TextStyle(
                            fontSize: 12,
                            color: _linkActive
                                ? (isDark ? Colors.white60 : Colors.grey.shade600)
                                : Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 複製連結按鈕
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: _linkActive ? _copyLink : null,
                            style: TextButton.styleFrom(
                              foregroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.link_rounded, size: 18),
                            label: Text(tr('gi_copy_link'),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 4. 邀請設定 (Owner / Admin) ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 開關
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _linkActive
                                    ? primaryColor.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.toggle_on_rounded,
                                color: _linkActive ? primaryColor : Colors.grey,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tr('gi_status'),
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87)),
                                  Text(
                                    _linkActive
                                        ? tr('gi_status_on')
                                        : tr('gi_status_off'),
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: _linkActive
                                            ? primaryColor
                                            : Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _linkActive,
                              onChanged: (_) => _toggleLinkActive(),
                              activeTrackColor: primaryColor.withValues(alpha: 0.5),
                              activeThumbColor: primaryColor,
                            ),
                          ],
                        ),

                        if (_linkActive) ...[
                          const SizedBox(height: 14),
                          const Divider(height: 1),
                          const SizedBox(height: 14),

                          // 設定有效期 & 重新生成按鈕
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _showExpirySheet,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: isDark
                                        ? Colors.white70
                                        : Colors.grey.shade800,
                                    side: BorderSide(color: borderCol),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                  icon: const Icon(Icons.timer_outlined, size: 16),
                                  label: Text(tr('gi_expiry_n', [_expiryLabel.toString()]),
                                      style: const TextStyle(fontSize: 12.5)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _regenerateCodeAndToken,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: BorderSide(
                                        color:
                                            Colors.redAccent.withValues(alpha: 0.4)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: Text(tr('common_regenerate'),
                                      style: TextStyle(fontSize: 12.5)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 5. 說明卡片 ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.orange.withValues(alpha: 0.08)
                          : const Color(0xFFFFF8F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💡 ', style: TextStyle(fontSize: 15)),
                        Expanded(
                          child: Text(
                            tr('gi_footer'),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.orange.shade200 : const Color(0xFF8D4200),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
