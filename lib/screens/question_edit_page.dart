// ignore_for_file: deprecated_member_use
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/database_helper.dart';

class QuestionEditPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic> currentUser;
  final List<String> allSubjects;
  final Map<String, List<String>> subjectChapters;

  const QuestionEditPage({
    super.key,
    this.initialData,
    required this.currentUser,
    required this.allSubjects,
    required this.subjectChapters,
  });

  @override
  State<QuestionEditPage> createState() => _QuestionEditPageState();
}

class _QuestionEditPageState extends State<QuestionEditPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _questionCtrl = TextEditingController();
  final TextEditingController _explanationCtrl = TextEditingController();

  late String subject;
  late String chapter;
  late String type;
  late String difficulty;
  late bool isBookmarked;
  final List<TextEditingController> _optionCtrls = [];
  int answerIndex = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    subject = widget.initialData?['subject'] ?? widget.allSubjects.first;
    type = widget.initialData?['type'] ?? '單選題';
    final rawDiff = widget.initialData?['difficulty'];
    difficulty = (rawDiff == 'easy' || rawDiff == null) ? '無' : rawDiff.toString();
    chapter = widget.initialData?['chapter'] ?? '未分類';
    isBookmarked = (widget.initialData?['bookmarked'] as int? ?? 0) == 1;

    _questionCtrl.text = widget.initialData?['question'] ?? '';
    _explanationCtrl.text = widget.initialData?['explanation'] ?? '';

    final options = widget.initialData?['options'];
    if (options is List) {
      for (final option in options) {
        _optionCtrls.add(TextEditingController(text: option.toString()));
      }
    }
    while (_optionCtrls.length < 4) {
      _optionCtrls.add(TextEditingController());
    }

    final rawAnswer = widget.initialData?['answerIndex'] ??
        widget.initialData?['answer'] ??
        0;
    answerIndex = int.tryParse(rawAnswer.toString()) ?? 0;
    if (answerIndex < 0) answerIndex = 0;
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _explanationCtrl.dispose();
    for (final ctrl in _optionCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  List<String> _chaptersForSubject(String subjectName) {
    final chapters = <String>['未分類'];
    final extras = widget.subjectChapters[subjectName];
    if (extras != null) {
      chapters.addAll(extras);
    }
    return chapters;
  }

  Future<int?> _ensureTagId(DatabaseHelper dbHelper, String tagName) async {
    final db = await dbHelper.database;
    final existing = await db.query(
      'tags',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [tagName],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return int.tryParse(existing.first['id'].toString());
    }
    return db.insert('tags', {'name': tagName});
  }

  Future<void> _syncChapterTag(dynamic db, int questionId) async {
    await db.delete('question_tag_map',
        where: 'question_id = ?', whereArgs: [questionId]);
    if (chapter == '未分類' || chapter.trim().isEmpty) return;

    final tagId = await _ensureTagId(DatabaseHelper.instance, chapter);
    if (tagId == null) return;
    await db.insert('question_tag_map', {
      'question_id': questionId,
      'tag_id': tagId,
    });
  }

  Future<void> _saveQuestion() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final options = _optionCtrls
        .map((c) => c.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少需要兩個選項')),
      );
      return;
    }

    if (answerIndex < 0 || answerIndex >= options.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請選擇正確答案')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final values = <String, dynamic>{
        'user_id': widget.initialData?['user_id'] ?? widget.currentUser['id'],
        'text': _questionCtrl.text.trim(),
        'options': jsonEncode(options),
        'answer': answerIndex.toString(),
        'explanation': _explanationCtrl.text.trim(),
        'subject': subject,
        'type': type,
        'difficulty': difficulty,
        'is_public': 0,
        'bookmarked': isBookmarked ? 1 : 0,
      };

      int questionId;
      if (widget.initialData?['id'] != null) {
        questionId = int.tryParse(widget.initialData!['id'].toString()) ?? 0;
        await db.update(
          'questions',
          values,
          where: 'id = ?',
          whereArgs: [questionId],
        );
      } else {
        questionId = await db.insert('questions', values);
      }

      if (questionId > 0) {
        await _syncChapterTag(db, questionId);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('儲存題目失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('儲存失敗，請稍後再試')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _addOption() {
    setState(() {
      _optionCtrls.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionCtrls.length <= 2) return;
    setState(() {
      _optionCtrls[index].dispose();
      _optionCtrls.removeAt(index);
      if (answerIndex >= _optionCtrls.length) {
        answerIndex = 0;
      }
    });
  }

  InputDecoration _fieldDecoration(BuildContext context, String label,
      {String? hint, Widget? suffixIcon}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: cs.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chapterItems = _chaptersForSubject(subject);
    if (!chapterItems.contains(chapter)) {
      chapter = chapterItems.first;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F6), // soft warm coffee background
      appBar: AppBar(
        title: Text(
          widget.initialData == null ? '新增題目' : '編輯題目',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              onPressed: _saving ? null : _saveQuestion,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.check_circle_outline_rounded, color: cs.onPrimary, size: 20),
              label: Text(
                _saving ? '儲存中' : '儲存',
                style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // ── Card 1: 題目基本設定 ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.initialData == null ? '建立新題目' : '編輯既有題目',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 科目與章節 (並排在一行)
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: subject,
                          decoration: _fieldDecoration(context, '科目'),
                          items: widget.allSubjects
                              .map((item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item),
                                  ))
                              .toList(),
                          selectedItemBuilder: (BuildContext context) {
                            return widget.allSubjects
                                .map((item) => Text(
                                      item,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ))
                                .toList();
                          },
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              subject = value;
                              final options = _chaptersForSubject(subject);
                              if (!options.contains(chapter)) {
                                chapter = options.first;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: chapter,
                          decoration: _fieldDecoration(context, '章節'),
                          items: chapterItems
                              .map((item) => DropdownMenuItem(
                                    value: item,
                                    child: Text(item),
                                  ))
                              .toList(),
                          selectedItemBuilder: (BuildContext context) {
                            return chapterItems
                                .map((item) => Text(
                                      item,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ))
                                .toList();
                          },
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => chapter = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // 難度
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: difficulty,
                    decoration: _fieldDecoration(context, '難度'),
                    items: const ['無', '易', '中', '難']
                        .map((item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ))
                        .toList(),
                    selectedItemBuilder: (BuildContext context) {
                      return const ['無', '易', '中', '難']
                          .map((item) => Text(
                                item,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ))
                          .toList();
                    },
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => difficulty = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // 題目內容
                  TextFormField(
                    controller: _questionCtrl,
                    decoration: _fieldDecoration(context, '題目內容', hint: '請輸入題目敘述...'),
                    minLines: 3,
                    maxLines: 6,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? '請輸入題目' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // ── Card 2: 選項與正確答案 ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '選項與正確答案',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addOption,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('新增選項', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          foregroundColor: cs.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '勾選左側的綠圈，代表該選項為正確答案。',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  ..._optionCtrls.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controller = entry.value;
                    final isCorrect = answerIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          // Custom premium Radio button (Green Check Circle)
                          GestureDetector(
                            onTap: () {
                              setState(() => answerIndex = index);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCorrect ? Colors.green.shade50 : Colors.grey.shade50,
                                border: Border.all(
                                  color: isCorrect ? Colors.green.shade600 : Colors.grey.shade300,
                                  width: 2.0,
                                ),
                              ),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                                color: isCorrect ? Colors.green.shade600 : Colors.transparent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // TextFormField for option
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              decoration: _fieldDecoration(
                                context,
                                '選項 ${String.fromCharCode(65 + index)}',
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                      ? '請輸入選項內容'
                                      : null,
                            ),
                          ),
                          
                          // Delete option button
                          if (_optionCtrls.length > 2) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: '刪除此選項',
                              onPressed: () => _removeOption(index),
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: cs.error.withValues(alpha: 0.8),
                                size: 22,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // ── Card 3: 附加資訊與發佈設定 ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '附加與發佈設定',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // 解析說明
                  TextFormField(
                    controller: _explanationCtrl,
                    decoration: _fieldDecoration(context, '解析說明（選填）', hint: '寫下這題的詳細解說或提示...'),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  
                  // 僅剩加入我的收藏 Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('加入我的收藏', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('將這題加入我的收藏，方便之後快速複習', style: TextStyle(fontSize: 11.5)),
                    activeColor: Colors.amber.shade700,
                    value: isBookmarked,
                    onChanged: (value) => setState(() => isBookmarked = value),
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
