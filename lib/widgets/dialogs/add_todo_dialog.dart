import 'package:flutter/material.dart';

void showAddTodoDialog({
  required BuildContext context,
  required bool isDark,
  required Color primaryColor,
  required void Function(String title) onSubmit,
}) {
  final titleController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.check_circle_outline_rounded,
                color: primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          const Text(
            '手動新增待辦',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: TextField(
        controller: titleController,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        autofocus: true,
        decoration: InputDecoration(
          labelText: '待辦內容',
          hintText: '輸入待辦項目（例：背誦單字 Unit 3）...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          filled: true,
          fillColor: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
          prefixIcon: Icon(Icons.format_list_bulleted_rounded,
              color: primaryColor, size: 20),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () {
            if (titleController.text.trim().isNotEmpty) {
              onSubmit(titleController.text.trim());
            }
            Navigator.pop(ctx);
          },
          child: const Text('確認加入',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
