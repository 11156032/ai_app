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
  late bool isPublic;
  late bool isBookmarked;
  final List<TextEditingController> _optionCtrls = [];
  int answerIndex = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    subject = widget.initialData?['subject'] ?? widget.allSubjects.first;
    type = widget.initialData?['type'] ?? '單選題';
    difficulty = widget.initialData?['difficulty'] ?? '易';
    chapter = widget.initialData?['chapter'] ?? '未分類';
    isPublic = (widget.initialData?['is_public'] as int? ?? 0) == 1;
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
        'is_public': isPublic ? 1 : 0,
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
      appBar: AppBar(
        title: Text(widget.initialData == null ? '新增題目' : '編輯題目'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _saveQuestion,
            icon: Icon(Icons.save_rounded, color: cs.onPrimary),
            label: Text(
              '儲存',
              style: TextStyle(color: cs.onPrimary),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.initialData == null ? '建立新題目' : '編輯既有題目',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '題目、章節、答案與解析會同步保存到資料庫。',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: type,
                    decoration: _fieldDecoration(context, '題型'),
                    items: const [
                      DropdownMenuItem(value: '單選題', child: Text('單選題')),
                      DropdownMenuItem(value: '多選題', child: Text('多選題')),
                      DropdownMenuItem(value: '是非題', child: Text('是非題')),
                      DropdownMenuItem(value: '申論題', child: Text('申論題')),
                    ],
                    selectedItemBuilder: (BuildContext context) {
                      return const [
                        Text('單選題',
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                        Text('多選題',
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                        Text('是非題',
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                        Text('申論題',
                            overflow: TextOverflow.ellipsis, maxLines: 1),
                      ];
                    },
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: difficulty,
                    decoration: _fieldDecoration(context, '難度'),
                    items: const ['易', '中', '難']
                        .map((item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ))
                        .toList(),
                    selectedItemBuilder: (BuildContext context) {
                      return const ['易', '中', '難']
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
                  TextFormField(
                    controller: _questionCtrl,
                    decoration:
                        _fieldDecoration(context, '題目內容', hint: '輸入題目敘述'),
                    minLines: 3,
                    maxLines: 6,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                            ? '請輸入題目'
                            : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '選項與答案',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addOption,
                        icon: const Icon(Icons.add),
                        label: const Text('新增選項'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._optionCtrls.asMap().entries.map((entry) {
                    final index = entry.key;
                    final controller = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              decoration: _fieldDecoration(
                                context,
                                '選項 ${index + 1}',
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                      ? '請輸入選項內容，或點擊右側按鈕刪除該選項'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              Radio<int>(
                                value: index,
                                groupValue: answerIndex,
                                onChanged: (value) {
                                  setState(() => answerIndex = value ?? 0);
                                },
                              ),
                              IconButton(
                                tooltip: '刪除選項',
                                onPressed: () => _removeOption(index),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: cs.error,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Text(
                    '請至少保留兩個選項，並勾選正確答案。',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '附加資訊',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _explanationCtrl,
                    decoration:
                        _fieldDecoration(context, '解析（選填）', hint: '寫下解題說明或提示'),
                    minLines: 3,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('公開題目'),
                    subtitle: const Text('未來可擴充成分享/匯入題庫'),
                    value: isPublic,
                    onChanged: (value) => setState(() => isPublic = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('加入收藏'),
                    subtitle: const Text('方便之後快速篩選'),
                    value: isBookmarked,
                    onChanged: (value) => setState(() => isBookmarked = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveQuestion,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? '儲存中...' : '儲存題目'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
