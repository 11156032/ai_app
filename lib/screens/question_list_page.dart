import 'dart:convert';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import 'question_edit_page.dart';
import 'question_practice_page.dart';
import 'paper_builder_page.dart';
import 'wrong_questions_page.dart';

class QuestionListPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final List<String> allSubjects;
  final Map<String, List<String>> subjectChapters;

  const QuestionListPage({
    super.key,
    required this.currentUser,
    required this.allSubjects,
    required this.subjectChapters,
  });

  @override
  State<QuestionListPage> createState() => _QuestionListPageState();
}

class _QuestionListPageState extends State<QuestionListPage> {
  String selectedSubject = '全部';
  String selectedChapter = '全部';
  String selectedDifficulty = '全部';
  String searchQuery = '';
  bool favoritesOnly = false;
  bool _isLoading = true;
  bool _isLoadingPapers = true;
  List<Map<String, dynamic>> _userPapers = [];

  List<Map<String, dynamic>> _questions = [];
  Map<String, int> _stats = {
    'total': 0,
    'favorites': 0,
    'public': 0,
    'subjects': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _loadUserPapers();
  }

  Future<void> _loadUserPapers() async {
    try {
      final uid = widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
      final papers = await DatabaseHelper.instance.getPapersForUser(uid.toString());
      if (!mounted) return;
      setState(() {
        _userPapers = papers;
        _isLoadingPapers = false;
      });
    } catch (e) {
      debugPrint('載入考卷失敗: $e');
      if (!mounted) return;
      setState(() => _isLoadingPapers = false);
    }
  }

  Future<void> _deletePaper(int id) async {
    try {
      await DatabaseHelper.instance.deletePaper(id);
      await _loadUserPapers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除考卷')));
    } catch (e) {
      debugPrint('刪除考卷失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('刪除失敗')));
    }
  }

  Future<void> _startPaperPractice(int paperId) async {
    try {
      final ids = await DatabaseHelper.instance.getQuestionIdsForPaper(paperId);
      if (ids.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('此考卷尚無題目')));
        return;
      }
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('questions', where: 'id IN (${List.filled(ids.length, '?').join(',')})', whereArgs: ids, orderBy: 'created_at DESC');
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

      final mapped = rows.map((row) {
        final id = int.tryParse(row['id'].toString()) ?? -1;
        final rawOptions = row['options'];
        final decodedOptions = rawOptions is String
            ? jsonDecode(rawOptions) as List<dynamic>
            : (rawOptions as List<dynamic>? ?? []);
        final chapter = chapterMap[id] ?? '';

        return {
          'id': id,
          'subject': row['subject'] ?? '',
          'chapter': chapter,
          'difficulty': row['difficulty'] ?? '',
          'type': row['type'] ?? '單選題',
          'question': row['text'] ?? '',
          'options': decodedOptions,
          'answerIndex': int.tryParse((row['answer'] ?? '0').toString()) ?? 0,
          'explanation': row['explanation'] ?? '',
          'isFavorite': (row['bookmarked'] as int? ?? 0) == 1,
          'isPublic': (row['is_public'] as int? ?? 0) == 1,
          'author': row['user_id'] ?? '',
          'user_id': row['user_id'] ?? '',
          'created_at': row['created_at'],
        };
      }).toList();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuestionPracticePage(
            questions: mapped,
            initialIndex: 0,
            title: '自訂考卷練習',
          ),
        ),
      );
    } catch (e) {
      debugPrint('啟動考卷練習失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('無法啟動考卷')));
    }
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

      final mapped = rows.map((row) {
        final id = int.tryParse(row['id'].toString()) ?? -1;
        final rawOptions = row['options'];
        final decodedOptions = rawOptions is String
            ? jsonDecode(rawOptions) as List<dynamic>
            : (rawOptions as List<dynamic>? ?? []);
        final chapter = chapterMap[id] ?? '';

        return {
          'id': id,
          'subject': row['subject'] ?? '',
          'chapter': chapter,
          'difficulty': row['difficulty'] ?? '',
          'type': row['type'] ?? '單選題',
          'question': row['text'] ?? '',
          'options': decodedOptions,
          'answerIndex': int.tryParse((row['answer'] ?? '0').toString()) ?? 0,
          'explanation': row['explanation'] ?? '',
          'isFavorite': (row['bookmarked'] as int? ?? 0) == 1,
          'isPublic': (row['is_public'] as int? ?? 0) == 1,
          'author': row['author'] ?? '',
          'user_id': row['user_id'] ?? '',
          'created_at': row['created_at'],
        };
      }).toList();

      final subjects = mapped
          .map((question) => question['subject'].toString())
          .where((value) => value.isNotEmpty)
          .toSet();

      if (!mounted) return;
      setState(() {
        _questions = mapped;
        _stats = {
          'total': mapped.length,
          'favorites': mapped.where((q) => q['isFavorite'] == true).length,
          'public': mapped.where((q) => q['isPublic'] == true).length,
          'subjects': subjects.length,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('載入題庫失敗: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editPaper(int paperId) async {
    try {
      final ids = await DatabaseHelper.instance.getQuestionIdsForPaper(paperId);
      final db = await DatabaseHelper.instance.database;
      List<Map<String, dynamic>> initial = [];
      if (ids.isNotEmpty) {
        final rows = await db.query('questions', where: 'id IN (${List.filled(ids.length, '?').join(',')})', whereArgs: ids);
        initial = rows.map((r) {
          final id = int.tryParse(r['id'].toString()) ?? 0;
          return {'id': id, 'question': r['text'] ?? ''};
        }).toList();
      }

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaperBuilderPage(
            currentUser: widget.currentUser,
            initialQuestions: initial,
            paperId: paperId,
          ),
        ),
      );
      if (result == true) await _loadUserPapers();
    } catch (e) {
      debugPrint('編輯考卷失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('無法編輯考卷')));
    }
  }

  List<Map<String, dynamic>> get filteredQuestions {
    return _questions.where((question) {
      if (selectedSubject != '全部' && question['subject'] != selectedSubject) {
        return false;
      }
      if (selectedChapter != '全部' && question['chapter'] != selectedChapter) {
        return false;
      }
      if (selectedDifficulty != '全部' &&
          question['difficulty'] != selectedDifficulty) {
        return false;
      }
      if (favoritesOnly && question['isFavorite'] != true) {
        return false;
      }
      if (searchQuery.trim().isNotEmpty) {
        final needle = searchQuery.trim().toLowerCase();
        final text = [
          question['question'],
          question['author'],
          question['subject'],
          question['chapter'],
          question['type'],
        ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
        if (!text.contains(needle)) return false;
      }
      return true;
    }).toList();
  }

  List<String> get chaptersForSelectedSubject {
    if (selectedSubject == '全部') {
      final all = <String>{};
      for (final chapters in widget.subjectChapters.values) {
        all.addAll(chapters);
      }
      return ['全部', ...all];
    }
    final list = <String>['全部'];
    final extras = widget.subjectChapters[selectedSubject];
    if (extras != null) list.addAll(extras);
    return list;
  }

  Future<void> _toggleFavorite(Map<String, dynamic> question) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final nextValue = question['isFavorite'] == true ? 0 : 1;
      await db.update(
        'questions',
        {'bookmarked': nextValue},
        where: 'id = ?',
        whereArgs: [question['id']],
      );
      await _loadQuestions();
    } catch (e) {
      debugPrint('更新收藏失敗: $e');
    }
  }

  Future<void> _deleteQuestion(Map<String, dynamic> question) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除題目'),
        content: const Text('確定要刪掉這題嗎？這個動作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'questions',
        where: 'id = ?',
        whereArgs: [question['id']],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('題目已刪除')),
      );
      await _loadQuestions();
    } catch (e) {
      debugPrint('刪除題目失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('刪除失敗，請稍後再試')),
      );
    }
  }

  Future<void> _openEditPage({Map<String, dynamic>? initialData}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditPage(
          initialData: initialData,
          currentUser: widget.currentUser,
          allSubjects: widget.allSubjects,
          subjectChapters: widget.subjectChapters,
        ),
      ),
    );
    if (result == true) {
      await _loadQuestions();
    }
  }

  void _openPractice([List<Map<String, dynamic>>? questions, int initialIndex = 0]) {
    final target = questions ?? filteredQuestions;
    if (target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目前沒有可練習的題目')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionPracticePage(
          questions: target,
          initialIndex: initialIndex.clamp(0, target.length - 1),
          title: '題庫練習',
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      selectedSubject = '全部';
      selectedChapter = '全部';
      selectedDifficulty = '全部';
      searchQuery = '';
      favoritesOnly = false;
    });
  }

  InputDecoration _fieldDecoration(BuildContext context, String label,
      {Widget? prefixIcon}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: cs.surface,
      prefixIcon: prefixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outline.withOpacity(0.18)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outline.withOpacity(0.18)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
    );
  }

  Widget _summaryCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '題庫中心',
            style: TextStyle(
              color: cs.onPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '搜尋、收藏、練習、編輯與刪除都集中在這裡。',
            style: TextStyle(
              color: cs.onPrimary.withOpacity(0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStatCard(
                  label: '總題數',
                  value: '${_stats['total'] ?? 0}',
                  foreground: cs.onPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatCard(
                  label: '收藏',
                  value: '${_stats['favorites'] ?? 0}',
                  foreground: cs.onPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStatCard(
                  label: '科目',
                  value: '${_stats['subjects'] ?? 0}',
                  foreground: cs.onPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _questionCard(BuildContext context, Map<String, dynamic> question,
      int index, ColorScheme cs) {
    final options = question['options'] is List
        ? (question['options'] as List).map((item) => item.toString()).toList()
        : <String>[];

    final snippet = (question['question'] ?? '').toString();
    final displayText = snippet.length > 90 ? '${snippet.substring(0, 90)}...' : snippet;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openPractice(filteredQuestions, index),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TagPill(label: question['subject']?.toString().isEmpty == true ? '未分類' : question['subject'].toString(), color: cs.primary),
                        _TagPill(label: question['chapter']?.toString().isEmpty == true ? '未分類' : question['chapter'].toString(), color: cs.secondary),
                        _TagPill(label: question['difficulty']?.toString().isEmpty == true ? '中' : question['difficulty'].toString(), color: cs.tertiary),
                        if (question['isFavorite'] == true)
                          _TagPill(label: '收藏', color: Colors.amber.shade700),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: question['isFavorite'] == true ? '取消收藏' : '加入收藏',
                    onPressed: () => _toggleFavorite(question),
                    icon: Icon(
                      question['isFavorite'] == true
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: question['isFavorite'] == true ? Colors.amber.shade700 : cs.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                displayText.isEmpty ? '題目內容遺失' : displayText,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${question['type'] ?? '單選題'} · ${options.length} 選項 · ${question['author']?.toString().isEmpty == true ? '未知作者' : question['author']}',
                style: TextStyle(
                  color: cs.onSurface.withOpacity(0.65),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openPractice(filteredQuestions, index),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('練習'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openEditPage(initialData: question),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('編輯'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: '刪除',
                    onPressed: () => _deleteQuestion(question),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = filteredQuestions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('題庫'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          IconButton(
            tooltip: '練習目前篩選',
            onPressed: () => _openPractice(filtered),
            icon: const Icon(Icons.play_circle_outline_rounded),
          ),
          IconButton(
            tooltip: '錯題本',
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => WrongQuestionsPage(currentUser: widget.currentUser)),
              );
              if (result == true) await _loadQuestions();
            },
            icon: const Icon(Icons.error_outline_rounded),
          ),
          // 新增題目按鈕已暫時隱藏以簡化介面
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadQuestions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // _summaryCard(context), 移除「題庫中心」大標與裝飾以保持簡潔
            const SizedBox(height: 12),
            // 我的考卷區塊
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('我的考卷', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaperBuilderPage(
                                currentUser: widget.currentUser,
                                initialQuestions: filtered,
                              ),
                            ),
                          );
                          if (result == true) await _loadUserPapers();
                        },
                        icon: const Icon(Icons.playlist_add_rounded),
                        label: const Text('新增考卷'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingPapers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator(color: cs.primary)),
                    )
                  else if (_userPapers.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('尚無已儲存的考卷', style: TextStyle(color: cs.onSurface.withOpacity(0.7))),
                    )
                  else
                    Column(
                      children: _userPapers.map((p) {
                        final pid = int.tryParse(p['id'].toString()) ?? 0;
                        final name = p['name'] ?? '';
                        return ListTile(
                          title: Text(name, style: TextStyle(color: cs.onSurface)),
                          subtitle: Text('建立於 ${p['created_at']}', style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              tooltip: '開始作答',
                              onPressed: () => _startPaperPractice(pid),
                              icon: const Icon(Icons.play_arrow_rounded),
                            ),
                                        IconButton(
                                          tooltip: '編輯考卷',
                                          onPressed: () => _editPaper(pid),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          tooltip: '刪除考卷',
                                          onPressed: () => _deletePaper(pid),
                                          icon: const Icon(Icons.delete_outline_rounded),
                                        ),
                          ]),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cs.outline.withOpacity(0.12)),
              ),
              child: Column(
                children: [
                  TextField(
                    decoration: _fieldDecoration(
                      context,
                      '搜尋題目、章節、科目、作者',
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: (value) => setState(() => searchQuery = value),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedSubject,
                          decoration: _fieldDecoration(context, '科目'),
                          items: ['全部', ...widget.allSubjects]
                              .map((subject) => DropdownMenuItem(
                                    value: subject,
                                    child: Text(subject),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              selectedSubject = value;
                              selectedChapter = '全部';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedChapter,
                          decoration: _fieldDecoration(context, '章節'),
                          items: chaptersForSelectedSubject
                              .map((chapter) => DropdownMenuItem(
                                    value: chapter,
                                    child: Text(chapter),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => selectedChapter = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedDifficulty,
                          decoration: _fieldDecoration(context, '難度'),
                          items: ['全部', '易', '中', '難']
                              .map((difficulty) => DropdownMenuItem(
                                    value: difficulty,
                                    child: Text(difficulty),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => selectedDifficulty = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilterChip(
                          selected: favoritesOnly,
                          label: const Text('只看收藏'),
                          onSelected: (value) => setState(() => favoritesOnly = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('清除篩選'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: filtered.isEmpty ? null : () => _openPractice(filtered),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('開始練習'),
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
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  '共 ${filtered.length} 題符合條件',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Row(children: [
                  TextButton.icon(
                    onPressed: () => _openEditPage(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('新增題目'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaperBuilderPage(
                            currentUser: widget.currentUser,
                            initialQuestions: filtered,
                          ),
                        ),
                      );
                      if (result == true) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('考卷已儲存')));
                      }
                    },
                    icon: const Icon(Icons.playlist_add_check_rounded),
                    label: const Text('建立考卷'),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: cs.primary),
                ),
              )
            else if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.outline.withOpacity(0.12)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 44,
                      color: cs.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '找不到符合的題目',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '試著放寬條件。',
                      style: TextStyle(
                        color: cs.onSurface.withOpacity(0.65),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...filtered.asMap().entries.map(
                    (entry) => _questionCard(context, entry.value, entry.key, cs),
                  ),
          ],
        ),
      ),
      // Floating action for adding questions removed to simplify UI
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color foreground;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: foreground,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: foreground.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  final Color color;

  const _TagPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
