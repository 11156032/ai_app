import 'dart:convert';
import 'package:flutter/material.dart';
import '../screens/notes_screen.dart';
import 'app_locale_service.dart';

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
        title: Text(tr('nb_wip_title'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: Text(
          tr('nb_wip_msg'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, color: Colors.black54, height: 1.6),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(tr('confirm')),
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
    final String userId =
        (currentUser['id'] ?? currentUser['user_id'] ?? 'u1').toString();

    // Check for guest account restriction (u4)
    if (userId == 'u4') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3E0),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline_rounded,
                color: Color(0xFFFF9800), size: 32),
          ),
          title: Text(tr('nb_guest_title'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          content: Text(
            tr('nb_guest_msg'),
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13.5, color: Colors.black54, height: 1.6),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(tr('confirm')),
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
    final categories =
        NotesDatabase.categories.where((cat) => cat != '全部').toList();
    if (categories.isEmpty) {
      categories.add('未分類');
    }

    String selectedCategory =
        categories.contains('學習') ? '學習' : categories.first;

    final String subject = (question['subject'] ?? '一般').toString();
    final String qText =
        (question['question'] ?? question['text'] ?? '').toString();
    final List<String> options = parseOptions(question['options']);

    // Get correct answer index
    final rawAns = question['answerIndex'] ?? question['answer'] ?? 0;
    final int ansIdx = int.tryParse(rawAns.toString()) ?? 0;

    final String explanation = (question['explanation'] ?? '').toString();

    // Default note title
    final titleController = TextEditingController(text: tr('nb_note_title_default', [subject.toString()]));
    final commentController = TextEditingController();

    if (!context.mounted) return;

    final cs = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.edit_note_rounded, color: cs.primary, size: 28),
                  const SizedBox(width: 8),
                  Text(tr('nb_add_to_notebook'),
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category dropdown
                    Text(tr('nb_pick_cat'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.grey)),
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
                    Text(tr('nb_note_title'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.grey)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: tr('vn_title_hint'),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Custom comment
                    Text(tr('nb_my_note'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.grey)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: commentController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: tr('nb_my_note_hint'),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final String titleText = titleController.text.trim();
                    final String finalTitle =
                        titleText.isEmpty ? tr('nb_note_title_default', [subject.toString()]) : titleText;
                    final String userComment = commentController.text.trim();

                    // Generate beautiful markdown content
                    final buffer = StringBuffer();
                    buffer.writeln(tr('nb_h_title', [subject.toString()]));
                    buffer.writeln();
                    buffer.writeln(tr('nb_h_question'));
                    buffer.writeln(qText);
                    buffer.writeln();

                    if (options.isNotEmpty) {
                      buffer.writeln(tr('nb_h_options'));
                      for (int i = 0; i < options.length; i++) {
                        final char = String.fromCharCode(65 + i);
                        buffer.writeln('- **$char.** ${options[i]}');
                      }
                      buffer.writeln();
                    }

                    final String correctChar =
                        (ansIdx >= 0 && ansIdx < options.length)
                            ? String.fromCharCode(65 + ansIdx)
                            : 'A';
                    buffer.writeln(tr('nb_h_answer'));
                    buffer.writeln(tr('nb_answer_is', [correctChar.toString()]));
                    buffer.writeln();

                    if (explanation.isNotEmpty) {
                      buffer.writeln(tr('nb_h_explanation'));
                      buffer.writeln(explanation);
                      buffer.writeln();
                    }

                    if (userComment.isNotEmpty) {
                      buffer.writeln('---');
                      buffer.writeln(tr('nb_h_mynote'));
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

                    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
                      SnackBar(duration: const Duration(milliseconds: 1500), 
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: Colors.white),
                            const SizedBox(width: 8),
                            Text(tr('nb_added', [selectedCategory.toString()])),
                          ],
                        ),
                        backgroundColor: Theme.of(context).primaryColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                  child: Text(tr('nb_confirm_add')),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
