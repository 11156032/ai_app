import 'package:flutter/material.dart';
import 'dart:convert';

import '../database/database_helper.dart';
import 'question_practice_page.dart';
import 'question_edit_page.dart';

class QuestionListPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final List<String> allSubjects;
  final Map<String, List<String>> subjectChapters;

  const QuestionListPage(
      {super.key,
      required this.currentUser,
      required this.allSubjects,
      required this.subjectChapters});

  @override
  State<QuestionListPage> createState() => _QuestionListPageState();
}

class _QuestionListPageState extends State<QuestionListPage> {
  String selectedSubject = '全部';
  String selectedChapter = '全部';
  String selectedDifficulty = '全部';
  String searchQuery = '';

  List<Map<String, dynamic>> _questions = [];

  List<Map<String, dynamic>> get filteredQuestions {
    return _questions.where((q) {
      if (selectedSubject != '全部' && q['subject'] != selectedSubject) {
        return false;
      }
      if (selectedChapter != '全部') {
        // chapter stored in q['chapter'] when loaded
        final chap = (q['chapter'] ?? '');
        if (chap != selectedChapter) return false;
      }
      if (selectedDifficulty != '全部' && q['difficulty'] != selectedDifficulty) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final sq = searchQuery.toLowerCase();
        if (!(q['question'] as String).toLowerCase().contains(sq) &&
            !(q['author'] as String).toLowerCase().contains(sq)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<String> get chaptersForSelectedSubject {
    if (selectedSubject == '全部') {
      return ['全部'];
    }
    final list = <String>['全部'];
    final extras = widget.subjectChapters[selectedSubject];
    if (extras != null) list.addAll(extras);
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('題目列表'),
        backgroundColor: const Color(0xFF8D6E63),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF8D6E63),
        child: const Icon(Icons.add),
        onPressed: () async {
          final res = await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => QuestionEditPage(
                        currentUser: widget.currentUser,
                        allSubjects: widget.allSubjects,
                        subjectChapters: widget.subjectChapters,
                      )));
          if (res == true) {
            await _loadQuestions();
          }
        },
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedSubject == '全部' ? '全部' : selectedSubject,
                  items: ['全部', ...widget.allSubjects]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    selectedSubject = v!;
                    selectedChapter = '全部';
                  }),
                  decoration: const InputDecoration(labelText: '科目'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedChapter,
                  items: chaptersForSelectedSubject
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedChapter = v!),
                  decoration: const InputDecoration(labelText: '章節'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedDifficulty,
                  items: ['全部', '易', '中', '難']
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setState(() => selectedDifficulty = v!),
                  decoration: const InputDecoration(labelText: '難度'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: '搜尋題目或作者',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => searchQuery = v),
                ),
              ),
            ])
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: filteredQuestions.isEmpty
                ? const Center(child: Text('找不到符合的題目'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredQuestions.length,
                    itemBuilder: (ctx, i) {
                      final q = filteredQuestions[i];
                      final options = q['options'] is String
                          ? (jsonDecode(q['options'] as String) as List<dynamic>)
                          : (q['options'] as List<dynamic>? ?? []);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(q['question'] ?? ''),
                                subtitle: Text(
                                    '${q['subject'] ?? ''} · ${q['chapter'] ?? '未分類'} · ${q['difficulty'] ?? ''} · ${options.length} 選項'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () async {
                                        final res = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => QuestionEditPage(
                                              initialData: q,
                                              currentUser: widget.currentUser,
                                              allSubjects: widget.allSubjects,
                                              subjectChapters: widget.subjectChapters,
                                            ),
                                          ),
                                        );
                                        if (res == true) {
                                          await _loadQuestions();
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => QuestionPracticePage(
                                                    questionData: q,
                                                  ))),
                                    ),
                                  ],
                          ),
                        ),
                      );
                    })),
      ]),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT q.*, u.display_name as author
        FROM questions q
        LEFT JOIN users u ON q.user_id = u.id
        ORDER BY q.created_at DESC
      ''');
      final chapterRows = await db.rawQuery('''
        SELECT qm.question_id, t.name AS chapter
        FROM question_tag_map qm
        JOIN tags t ON t.id = qm.tag_id
      ''');
      final chapterMap = <int, String>{};
      for (final row in chapterRows) {
        final qid = int.tryParse(row['question_id'].toString()) ?? -1;
        chapterMap.putIfAbsent(qid, () => row['chapter']?.toString() ?? '');
      }
      setState(() {
        _questions = rows.map((r) {
          // normalize keys used elsewhere
          final id = int.tryParse(r['id'].toString()) ?? -1;
          final rawOptions = r['options'];
          final decodedOptions = rawOptions is String
              ? jsonDecode(rawOptions) as List<dynamic>
              : (rawOptions as List<dynamic>? ?? []);
          return {
            'id': id,
            'subject': r['subject'] ?? '',
            'chapter': chapterMap[id] ?? '',
            'difficulty': r['difficulty'] ?? '',
            'question': r['text'] ?? '',
            'options': decodedOptions,
            'answerIndex': int.tryParse((r['answer'] ?? '0').toString()) ?? 0,
            'explanation': r['explanation'] ?? '',
            'isFavorite': (r['bookmarked'] as int? ?? 0) == 1,
            'author': r['author'] ?? '',
            'type': r['type'] ?? '單選題',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('載入題目失敗: $e');
    }
  }
}
