import 'package:flutter/material.dart';

void showEditDeleteTodoDialog({
  required BuildContext context,
  required Map<String, dynamic> item,
  required void Function(String id, String newText) onEdit,
  required void Function(String id) onDelete,
}) {
  final editController = TextEditingController(text: item['title']);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('管理待辦事項'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: editController,
            decoration: const InputDecoration(labelText: '內容'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            showDialog(
              context: context,
              builder: (confirmCtx) => AlertDialog(
                title: const Text('刪除待辦事項'),
                content: Text('確定要刪除「${item['title']}」嗎？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(confirmCtx),
                    child: const Text('取消'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white),
                    onPressed: () {
                      Navigator.pop(confirmCtx);
                      onDelete(item['id']);
                    },
                    child: const Text('確定刪除'),
                  ),
                ],
              ),
            );
          },
          child: const Text('刪除', style: TextStyle(color: Colors.redAccent)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (editController.text.trim().isNotEmpty) {
              onEdit(item['id'], editController.text.trim());
            }
            Navigator.pop(ctx);
          },
          child: const Text('儲存'),
        ),
      ],
    ),
  );
}
