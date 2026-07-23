import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../database/database_helper.dart';

/// 群組邀請連結管理頁（Owner / Admin 才可進入）
class GroupInvitePage extends StatefulWidget {
  final Map<String, dynamic> group;
  final String currentUserId;

  const GroupInvitePage({
    super.key,
    required this.group,
    required this.currentUserId,
  });

  @override
  State<GroupInvitePage> createState() => _GroupInvitePageState();
}

class _GroupInvitePageState extends State<GroupInvitePage> {
  late Map<String, dynamic> _group;
  bool _isLoading = false;
  String? _expiryLabel; // 顯示用的過期標籤

  @override
  void initState() {
    super.initState();
    _group = Map<String, dynamic>.from(widget.group);
    _updateExpiryLabel();
  }

  void _updateExpiryLabel() {
    final exp = _group['token_expires_at'] as String?;
    if (exp == null || exp.isEmpty) {
      _expiryLabel = '永久有效';
    } else {
      final expDate = DateTime.tryParse(exp);
      if (expDate == null) {
        _expiryLabel = '永久有效';
      } else if (expDate.isBefore(DateTime.now())) {
        _expiryLabel = '已過期';
      } else {
        final diff = expDate.difference(DateTime.now()).inDays;
        _expiryLabel = '$diff 天後到期';
      }
    }
  }

  String get _inviteUrl {
    final token = _group['invite_token'] ?? '';
    return 'app://join?token=$token';
  }

  bool get _linkActive => (_group['invite_link_active'] as int? ?? 1) == 1;

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _inviteUrl));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 邀請連結已複製到剪貼板！'),
          backgroundColor: Color(0xFF8D6E63),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _regenerateToken() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('重新生成邀請連結？'),
        content: const Text('重新生成後，舊的邀請連結將立即失效，無法再用於加入群組。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('重新生成'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final newToken = await DatabaseHelper.instance
          .regenerateInviteToken(_group['id'] as int);
      final updated = await DatabaseHelper.instance
          .getGroupById(_group['id'] as int);
      if (mounted) {
        setState(() {
          _group = updated ?? _group;
          _group['invite_token'] = newToken;
          _isLoading = false;
          _updateExpiryLabel();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('邀請連結已重新生成')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已設定為：$label')),
      );
    }
  }

  void _showExpirySheet() {
    final options = [
      {'label': '永久有效', 'days': null},
      {'label': '1 天後到期', 'days': 1},
      {'label': '7 天後到期', 'days': 7},
      {'label': '30 天後到期', 'days': 30},
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
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('設定連結有效期',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const Divider(height: 1),
            ...options.map((opt) => ListTile(
                  title: Text(opt['label'] as String),
                  trailing: (_expiryLabel == opt['label'])
                      ? const Icon(Icons.check_circle,
                          color: Color(0xFF8D6E63))
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
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final secondaryBg = isDark ? Colors.white10 : Colors.grey.shade50;
    final borderCol = isDark ? Colors.white12 : Colors.grey.shade200;
    final groupName = _group['name'] as String? ?? '群組';
    final iconEmoji = _group['icon_emoji'] as String? ?? '📚';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F0EE),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('邀請連結管理',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 群組標頭 ──
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
                            color: const Color(0xFF8D6E63).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(iconEmoji,
                                style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(groupName,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87)),
                            Text(
                                _group['type'] == 'private'
                                    ? '🔒 私人群組'
                                    : '🌐 公開群組',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF8D6E63))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 邀請連結區 ──
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
                        // 標題 + 開關
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _linkActive
                                    ? const Color(0xFF8D6E63).withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.link_rounded,
                                color: _linkActive
                                    ? const Color(0xFF8D6E63)
                                    : Colors.grey,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('邀請連結',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87)),
                                  Text(
                                    _linkActive
                                        ? '連結有效 · $_expiryLabel'
                                        : '連結已關閉',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: _linkActive
                                            ? const Color(0xFF8D6E63)
                                            : Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _linkActive,
                              onChanged: (_) => _toggleLinkActive(),
                              activeThumbColor: const Color(0xFF8D6E63),
                            ),
                          ],
                        ),

                        if (_linkActive) ...[
                          const SizedBox(height: 12),
                          // 連結顯示框
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: secondaryBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderCol),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _inviteUrl,
                                    style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black54),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _copyLink,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8D6E63),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.copy_rounded,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 按鈕列
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _copyLink,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF8D6E63),
                                    side: const BorderSide(
                                        color: Color(0xFF8D6E63)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                  icon: const Icon(Icons.share_rounded,
                                      size: 16),
                                  label: const Text('複製連結',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _showExpirySheet,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                    side: BorderSide(
                                        color: borderCol),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                  icon: const Icon(Icons.timer_outlined,
                                      size: 16),
                                  label: const Text('設定期限',
                                      style: TextStyle(fontSize: 13)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: _regenerateToken,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('重新生成連結（舊連結將失效）',
                                  style: TextStyle(fontSize: 12.5)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── 說明文字 ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F5),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFFFFCC80), width: 1),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('💡 ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            '複製邀請連結後，透過 LINE、訊息或其他管道分享給對方。'
                            '對方在 App 的「群組」→「探索群組」頁面貼上連結，即可加入群組。',
                            style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF8D4200),
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
