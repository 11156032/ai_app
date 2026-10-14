import 'package:flutter/material.dart';

/// 顯示編輯個人簡介彈窗
void showEditBioDialog({
  required BuildContext context,
  required String? initialBio,
  required bool isDarkMode,
  required Color primaryColor,
  required Future<void> Function(String newBio) onSave,
}) {
  showDialog(
    context: context,
    builder: (ctx) => EditBioDialog(
      initialBio: initialBio,
      isDarkMode: isDarkMode,
      primaryColor: primaryColor,
      onSave: onSave,
    ),
  );
}

/// 編輯個人簡介 Dialog
class EditBioDialog extends StatefulWidget {
  final String? initialBio;
  final bool isDarkMode;
  final Color primaryColor;
  final Future<void> Function(String newBio) onSave;

  const EditBioDialog({
    super.key,
    required this.initialBio,
    required this.isDarkMode,
    required this.primaryColor,
    required this.onSave,
  });

  @override
  State<EditBioDialog> createState() => _EditBioDialogState();
}

class _EditBioDialogState extends State<EditBioDialog> {
  late final TextEditingController _controller;
  static const int _maxBioLength = 150;

  static const List<String> _bioPresets = [
    '🎯 專注備考衝刺中，全力以赴！',
    '📚 每天進步一點點，堅持就是勝利',
    '💻 熱愛科技與程式設計，持續探索',
    '🔥 自律帶來自由，每日學習打卡',
    '✨ 保持好奇心，享受解題與成長',
    '🌟 踏實走好每一步，追求卓越',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialBio ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final primary = widget.primaryColor;
    final currentLen = _controller.text.length;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF222226) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 標題與圖示 ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary, primary.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.edit_note_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '編輯個人簡介',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '展現你的學習態度與個人特色',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white60
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: isDark ? Colors.white54 : Colors.grey,
                        size: 20),
                    onPressed: () => Navigator.pop(context),
                    tooltip: '關閉',
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── 輸入區塊 ──
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF18181B)
                      : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _controller,
                      maxLines: 4,
                      maxLength: _maxBioLength,
                      buildCounter: (_,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          const SizedBox.shrink(),
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: '介紹一下自己吧！寫下你的學習目標、座右銘或興趣領域...',
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          color: isDark
                              ? Colors.white38
                              : Colors.grey.shade400,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_controller.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _controller.clear();
                              setState(() {});
                            },
                            child: Row(
                              children: [
                                Icon(Icons.clear,
                                    size: 14,
                                    color: Colors.grey.shade500),
                                const SizedBox(width: 2),
                                Text(
                                  '清空',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        Text(
                          '$currentLen / $_maxBioLength',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: currentLen >= _maxBioLength
                                ? Colors.redAccent
                                : (isDark
                                    ? Colors.white54
                                    : Colors.grey.shade500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 靈感標籤 ──
              Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 15, color: primary),
                  const SizedBox(width: 6),
                  Text(
                    '靈感推薦 (點擊快速填入)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bioPresets.map((preset) {
                  return InkWell(
                    onTap: () {
                      _controller.text = preset;
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? primary.withValues(alpha: 0.12)
                            : primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        preset,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white70 : primary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              // ── 操作按鈕 ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white24
                              : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.white70
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        final newBio = _controller.text.trim();
                        Navigator.pop(context);
                        await widget.onSave(newBio);
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded,
                              size: 18, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            '儲存簡介',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
