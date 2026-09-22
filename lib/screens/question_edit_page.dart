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

  final List<String> _difficulties = ['無', '易', '中', '難'];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    subject = widget.initialData?['subject'] ??
        (widget.allSubjects.isNotEmpty ? widget.allSubjects.first : '數學');
    type = widget.initialData?['type'] ?? '單選題';
    final rawDiff = widget.initialData?['difficulty'];
    difficulty = (rawDiff == 'easy' || rawDiff == null) ? '無' : rawDiff.toString();
    if (!_difficulties.contains(difficulty)) {
      difficulty = '無';
    }
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
    return db.insert('tags', <String, Object?>{'name': tagName});
  }

  Future<void> _syncChapterTag(dynamic db, int questionId) async {
    await db.delete('question_tag_map',
        where: 'question_id = ?', whereArgs: [questionId]);
    if (chapter == '未分類' || chapter.trim().isEmpty) return;

    final tagId = await _ensureTagId(DatabaseHelper.instance, chapter);
    if (tagId == null) return;
    await db.insert('question_tag_map', <String, Object?>{
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
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text('至少需要填寫兩個選項')),
      );
      return;
    }

    if (answerIndex < 0 || answerIndex >= options.length) {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text('請指定一個有效的正確答案')),
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
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, 
          content: Text(widget.initialData == null ? '題目已成功新增！' : '題目已成功儲存！'),
          backgroundColor: Colors.green.shade600,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('儲存題目失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text('儲存失敗，請稍後再試')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _addOption() {
    if (_optionCtrls.length >= 6) {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text('最多支援 6 個選項')),
      );
      return;
    }
    setState(() {
      _optionCtrls.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionCtrls.length <= 2) {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text('題目至少需要 2 個選項')),
      );
      return;
    }
    setState(() {
      _optionCtrls[index].dispose();
      _optionCtrls.removeAt(index);
      if (answerIndex >= _optionCtrls.length) {
        answerIndex = _optionCtrls.length - 1;
      }
    });
  }

  void _onTypeChanged(String newType) {
    setState(() {
      type = newType;
      if (newType == '是非題') {
        while (_optionCtrls.length > 2) {
          _optionCtrls.removeLast().dispose();
        }
        while (_optionCtrls.length < 2) {
          _optionCtrls.add(TextEditingController());
        }
        if (_optionCtrls[0].text.trim().isEmpty) {
          _optionCtrls[0].text = '正確 (O)';
        }
        if (_optionCtrls[1].text.trim().isEmpty) {
          _optionCtrls[1].text = '錯誤 (X)';
        }
        if (answerIndex >= 2) answerIndex = 0;
      } else {
        while (_optionCtrls.length < 4) {
          _optionCtrls.add(TextEditingController());
        }
      }
    });
  }

  Color _getDifficultyColor(String diff) {
    switch (diff) {
      case '易':
        return const Color(0xFF10B981);
      case '中':
        return const Color(0xFFF59E0B);
      case '難':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapterItems = _chaptersForSubject(subject);
    if (!chapterItems.contains(chapter)) {
      chapter = chapterItems.first;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.initialData == null ? '手動新增題目' : '編輯題目',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF334155)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                children: [
                  // ── 1. 基本資訊卡片（科目、章節、難度） ──
                  _buildSectionCard(
                    title: '分類與難度',
                    icon: Icons.category_rounded,
                    iconColor: const Color(0xFF4F46E5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 科目與章節並排
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '學科領域',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: subject,
                                    decoration: _dropdownDecoration(Icons.school_rounded),
                                    items: widget.allSubjects
                                        .map((s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(s, style: const TextStyle(fontSize: 14)),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setState(() {
                                        subject = val;
                                        final options = _chaptersForSubject(subject);
                                        if (!options.contains(chapter)) {
                                          chapter = options.first;
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '所屬章節',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: chapter,
                                    decoration: _dropdownDecoration(Icons.bookmark_outline_rounded),
                                    items: chapterItems
                                        .map((c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(c,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 14)),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setState(() => chapter = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 難度選擇 ChoiceChips
                        const Text(
                          '試題難度',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _difficulties.map((d) {
                            final isSel = difficulty == d;
                            final chipColor = _getDifficultyColor(d);

                            return ChoiceChip(
                              label: Text(d),
                              selected: isSel,
                              selectedColor: chipColor.withValues(alpha: 0.15),
                              backgroundColor: const Color(0xFFF8FAFC),
                              labelStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                color: isSel ? chipColor : const Color(0xFF64748B),
                              ),
                              side: BorderSide(
                                color: isSel ? chipColor : Colors.grey.shade300,
                                width: isSel ? 1.5 : 1.0,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              onSelected: (_) => setState(() => difficulty = d),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 2. 題目與題型卡片 ──
                  _buildSectionCard(
                    title: '題目內容',
                    icon: Icons.edit_note_rounded,
                    iconColor: const Color(0xFF0EA5E9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 題型切換
                        const Text(
                          '試題題型',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: ['單選題', '是非題'].map((t) {
                            final isSel = type == t;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(t),
                                selected: isSel,
                                selectedColor: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                                backgroundColor: const Color(0xFFF8FAFC),
                                labelStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                  color: isSel ? const Color(0xFF0EA5E9) : const Color(0xFF64748B),
                                ),
                                side: BorderSide(
                                  color: isSel ? const Color(0xFF0EA5E9) : Colors.grey.shade300,
                                  width: isSel ? 1.5 : 1.0,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                onSelected: (_) => _onTypeChanged(t),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // 題目文字輸入
                        TextFormField(
                          controller: _questionCtrl,
                          decoration: InputDecoration(
                            labelText: '題目敘述 *',
                            hintText: '請輸入題目完整敘述...',
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
                            ),
                          ),
                          minLines: 3,
                          maxLines: 6,
                          validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入題目' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 3. 選項設定與正確答案 ──
                  _buildSectionCard(
                    title: '選項與正確答案',
                    icon: Icons.checklist_rounded,
                    iconColor: const Color(0xFF10B981),
                    trailing: type == '單選題' && _optionCtrls.length < 6
                        ? TextButton.icon(
                            onPressed: _addOption,
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                            label: const Text('新增選項', style: TextStyle(fontSize: 12.5)),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '請點擊前方圓鈕標記「正確答案」：',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 10),
                        ...List.generate(_optionCtrls.length, (index) {
                          final label = String.fromCharCode(65 + index);
                          final isAnswer = answerIndex == index;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isAnswer ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAnswer ? const Color(0xFF10B981) : Colors.grey.shade200,
                                width: isAnswer ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                // 選取正確答案 Radio
                                InkWell(
                                  onTap: () => setState(() => answerIndex = index),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isAnswer ? const Color(0xFF10B981) : Colors.white,
                                      border: Border.all(
                                        color: isAnswer ? const Color(0xFF10B981) : Colors.grey.shade400,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isAnswer ? Colors.white : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // 選項文字輸入框
                                Expanded(
                                  child: TextFormField(
                                    controller: _optionCtrls[index],
                                    decoration: InputDecoration(
                                      hintText: '輸入選項 $label 內容...',
                                      isDense: true,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return '請填寫選項 $label';
                                      }
                                      return null;
                                    },
                                  ),
                                ),

                                // 刪除選項按鈕（單選題 > 2 個選項時可刪除）
                                if (type == '單選題' && _optionCtrls.length > 2)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                                    color: Colors.grey.shade400,
                                    tooltip: '移除選項',
                                    onPressed: () => _removeOption(index),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 4. 解析與其他設定 ──
                  _buildSectionCard(
                    title: '解析與備註',
                    icon: Icons.lightbulb_outline_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _explanationCtrl,
                          decoration: InputDecoration(
                            labelText: '詳細解析（選填）',
                            hintText: '記錄解題思路、相關觀念或提醒...',
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                            ),
                          ),
                          minLines: 2,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 12),

                        // 加入我的收藏 Switch
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            '加入我的收藏',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                          subtitle: const Text(
                            '標記為星號收藏，方便在首頁或題庫快速檢視',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                          // ignore: deprecated_member_use
                          activeColor: const Color(0xFFF59E0B),
                          value: isBookmarked,
                          onChanged: (val) => setState(() => isBookmarked = val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── 底部固定操作列 ──
            Container(
              padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveQuestion,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(
                    _saving ? '儲存中...' : (widget.initialData == null ? '確認新增題目' : '更新題目內容'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
    );
  }
}
