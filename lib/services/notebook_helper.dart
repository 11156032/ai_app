import 'dart:convert';
import 'package:flutter/material.dart';
import '../screens/notes_screen.dart';

class NotebookHelper {
  /// Parses options safely from the question map
  static List<String> parseOptions(dynamic raw) {
    try {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String && raw.trim().isNotEmpty) {
        final d = jsonDecode(raw);
        if (d is List) return d.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    if (raw is String) {
      return raw
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Show dialog to add a question to the user's notebook
  static Future<void> showAddToNotebookDialog(
    BuildContext context,
    Map<String, dynamic> currentUser,
    Map<String, dynamic> question,
  ) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF3E0),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.construction_rounded,
              color: Color(0xFFFF9800), size: 32),
        ),
        title: const Text('功能開發中',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: const Text(
          '題目與筆記本的同步整合功能目前正於系統後端開發中，敬請期待！',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: Colors.black54, height: 1.6),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8D6E63),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('確定'),
            ),
          )
        ],
      ),
    );
  }

  /// Real implementation (Preserved for future use)
  static Future<void> showAddToNotebookDialogReal(
    BuildContext context,
    Map<String, dynamic> currentUser,
    Map<String, dynamic> question,
  ) async {
    final String userId = (currentUser['id'] ?? currentUser['user_id'] ?? 'u1').toString();
    
    // Check for guest account restriction (u4)
    if (userId == 'u4') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3E0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline_rounded,
                color: Color(0xFFFF9800), size: 32),
          ),
          title: const Text('訪客限制',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          content: const Text(
            '訪客帳戶無法使用筆記本功能，請先登入！',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Colors.black54, height: 1.6),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D6E63),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('確定'),
              ),
            )
          ],
        ),
      );
      return;
    }

    // Ensure user's notes are initialized
    NotesDatabase.initializeForUser(userId);

    // Filter out '全部' category for creation
    final categories = NotesDatabase.categories.where((cat) => cat != '全部').toList();
    if (categories.isEmpty) {
      categories.add('未分類');
    }

    String selectedCategory = categories.contains('學習') ? '學習' : categories.first;
    
    final String subject = (question['subject'] ?? '一般').toString();
    final String qText = (question['question'] ?? question['text'] ?? '').toString();
    final List<String> options = parseOptions(question['options']);
    
    // Get correct answer index
    final rawAns = question['answerIndex'] ?? question['answer'] ?? 0;
    final int ansIdx = int.tryParse(rawAns.toString()) ?? 0;
    
    final String explanation = (question['explanation'] ?? '').toString();

    // Default note title
    final titleController = TextEditingController(text: '題目筆記 - $subject');
    final commentController = TextEditingController();

    if (!context.mounted) return;

    final cs = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: cs.primary, size: 28),
                  const SizedBox(width: 8),
                  const Text('加入我的筆記本', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category dropdown
                    const Text('選擇分類', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCategory,
                          isExpanded: true,
                          items: categories.map((cat) {
                            return DropdownMenuItem<String>(
                              value: cat,
                              child: Text(cat),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedCategory = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Note Title
                    const Text('筆記標題', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: '輸入筆記標題...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Custom comment
                    const Text('我的心得與筆記 (選填)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: commentController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: '在此寫下關於這題的想法、重點或錯誤原因...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8D6E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final String titleText = titleController.text.trim();
                    final String finalTitle = titleText.isEmpty ? '題目筆記 - $subject' : titleText;
                    final String userComment = commentController.text.trim();

                    // Generate beautiful markdown content
                    final buffer = StringBuffer();
                    buffer.writeln('# 題目筆記：$subject');
                    buffer.writeln();
                    buffer.writeln('### 📝 題目問題');
                    buffer.writeln(qText);
                    buffer.writeln();

                    if (options.isNotEmpty) {
                      buffer.writeln('### 🔍 選擇選項');
                      for (int i = 0; i < options.length; i++) {
                        final char = String.fromCharCode(65 + i);
                        buffer.writeln('- **$char.** ${options[i]}');
                      }
                      buffer.writeln();
                    }

                    final String correctChar = (ansIdx >= 0 && ansIdx < options.length) 
                        ? String.fromCharCode(65 + ansIdx) 
                        : 'A';
                    buffer.writeln('### 💡 正確答案');
                    buffer.writeln('**正確解答為：[$correctChar]**');
                    buffer.writeln();

                    if (explanation.isNotEmpty) {
                      buffer.writeln('### 📖 題目解析');
                      buffer.writeln(explanation);
                      buffer.writeln();
                    }

                    if (userComment.isNotEmpty) {
                      buffer.writeln('---');
                      buffer.writeln('### ✍️ 我的筆記與心得');
                      buffer.writeln(userComment);
                    }

                    // Insert to memory database
                    final newNote = Note(
                      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
                      userId: userId,
                      title: finalTitle,
                      content: buffer.toString(),
                      category: selectedCategory,
                      strokes: [],
                      updatedAt: DateTime.now(),
                    );
                    
                    NotesDatabase.notes.insert(0, newNote);

                    Navigator.pop(ctx);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('已將題目成功加入筆記本「$selectedCategory」！'),
                          ],
                        ),
                        backgroundColor: const Color(0xFF8D6E63),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  child: const Text('確定加入'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
