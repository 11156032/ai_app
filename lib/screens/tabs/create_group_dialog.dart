import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

// ─── 分類標籤選項 ───────────────────────────────────────────────────────────────
const List<String> kGroupTags = ['數學', '英文', '程式', '自然', '歷史', '升學', '考試', '讀書會', '其他'];

// ─── Emoji 選項 ─────────────────────────────────────────────────────────────────
const List<String> kGroupEmojis = [
  '📚', '📖', '✏️', '🔬', '🧮', '🌏', '💡', '🎯', '🏆', '🎓',
  '💻', '🎵', '🎨', '📐', '🧪', '🔭', '📝', '🤝', '🚀', '⭐',
];

class CreateGroupDialog extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final VoidCallback onCreated;

  const CreateGroupDialog({
    super.key,
    required this.currentUser,
    required this.onCreated,
  });

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedEmoji = '📚';
  String _selectedType = 'public'; // 'public' | 'private'
  bool _joinRequiresApproval = false;
  final Set<String> _selectedTags = {};
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入群組名稱')),
      );
      return;
    }
    setState(() => _isCreating = true);
    try {
      await DatabaseHelper.instance.createGroup(
        name: name,
        description: _descController.text.trim(),
        iconEmoji: _selectedEmoji,
        type: _selectedType,
        ownerId: widget.currentUser['id'].toString(),
        joinRequiresApproval: _joinRequiresApproval,
        tags: _selectedTags.toList(),
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 群組「$name」已建立！'),
            backgroundColor: const Color(0xFF8D6E63),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('建立失敗：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final inputBg = isDark ? Colors.white10 : Colors.grey.shade50;
    final borderCol = isDark ? Colors.white12 : Colors.grey.shade200;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 標題列 ──
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D6E63).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.group_add_rounded,
                      color: Color(0xFF8D6E63), size: 22),
                ),
                const SizedBox(width: 12),
                const Text('建立新群組',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037))),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Emoji 選擇 ──
            Text('群組圖示',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: kGroupEmojis.length,
                itemBuilder: (context, idx) {
                  final emoji = kGroupEmojis[idx];
                  final isSelected = emoji == _selectedEmoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF8D6E63)
                            : inputBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isSelected
                                ? const Color(0xFF8D6E63)
                                : borderCol,
                            width: isSelected ? 2 : 1),
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // ── 群組名稱 ──
            Text('群組名稱 *',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              maxLength: 30,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: '例：高中數學研討群',
                hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey.shade400),
                filled: true,
                fillColor: inputBg,
                counterText: '',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),

            // ── 群組簡介 ──
            Text('群組簡介',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 2,
              maxLength: 80,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: '簡單介紹這個群組的用途',
                hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey.shade400),
                filled: true,
                fillColor: inputBg,
                counterText: '',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // ── 類型選擇（最重要的部分）──
            Text('群組類型',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 8),
            _buildTypeOption(
              isDark: isDark,
              type: 'public',
              icon: Icons.public_rounded,
              iconColor: const Color(0xFF2196F3),
              title: '公開群組 🌐',
              subtitle: '任何人可瀏覽、加入和閱讀貼文',
            ),
            const SizedBox(height: 8),
            _buildTypeOption(
              isDark: isDark,
              type: 'private',
              icon: Icons.lock_rounded,
              iconColor: const Color(0xFFFF9800),
              title: '私人群組 🔒',
              subtitle: '未公開，非成員無法閱讀貼文',
            ),
            const SizedBox(height: 8),
            // 加入設定
            SwitchListTile(
              title: Text('加入群組需審核',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87)),
              subtitle: Text(
                _joinRequiresApproval ? '使用者點擊連結後需由管理員審核' : '知道連結的人可直接加入群組',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey.shade600),
              ),
              value: _joinRequiresApproval,
              onChanged: (val) => setState(() => _joinRequiresApproval = val),
              activeTrackColor: const Color(0xFF8D6E63),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // ── 分類標籤 ──
            Text('分類標籤',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: kGroupTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8D6E63)
                          : inputBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isSelected
                              ? const Color(0xFF8D6E63)
                              : borderCol),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black54),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── 建立按鈕 ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D6E63),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('$_selectedEmoji 建立群組',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption({
    required bool isDark,
    required String type,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedType == type;
    final bg = isDark ? Colors.white10 : Colors.grey.shade50;
    final selectedBg = isDark
        ? iconColor.withValues(alpha: 0.12)
        : iconColor.withValues(alpha: 0.06);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          if (type == 'private') {
            _joinRequiresApproval = true; // 預設私人群組開啟審核
          } else {
            _joinRequiresApproval = false; // 預設公開群組關閉審核
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? iconColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: isDark ? Colors.white : Colors.black87)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                          height: 1.3)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected ? iconColor : Colors.grey.shade400,
                    width: 2),
                color: isSelected ? iconColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
