import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../services/notebook_helper.dart';
import 'question_edit_page.dart';
import 'question_practice_page.dart';

class QuestionSetDetailPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final String title;
  final String? subject;
  final String? chapter; // 新增章節參數
  final int? paperId;
  final bool isFavoriteOnly; // 新增收藏篩選參數
  final bool isCustomOnly; // 新增自訂題目篩選參數
  final List<String> allSubjects;
  final Map<String, List<String>> subjectChapters;

  const QuestionSetDetailPage({
    super.key,
    required this.currentUser,
    required this.title,
    this.subject,
    this.chapter,
    this.paperId,
    this.isFavoriteOnly = false,
    this.isCustomOnly = false,
    required this.allSubjects,
    required this.subjectChapters,
  });

  @override
  State<QuestionSetDetailPage> createState() => _QuestionSetDetailPageState();
}

class _QuestionSetDetailPageState extends State<QuestionSetDetailPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _questions = [];
  bool _showAnswers = false;
  bool _isFloatingNavExpanded = false;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  List<GlobalKey> _itemKeys = [];
  final Set<int> _expandedIndices = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _loadQuestions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      List<Map<String, Object?>> rows = [];
      
      if (widget.isFavoriteOnly) {
        rows = await db.query('questions',
            where: 'bookmarked = 1',
            orderBy: 'created_at DESC');
      } else if (widget.isCustomOnly) {
        final uid = widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
        rows = await db.rawQuery('''
          SELECT q.*, u.display_name as author
          FROM questions q
          LEFT JOIN users u ON q.user_id = u.id
          WHERE q.user_id = ? AND q.is_public = 0
          ORDER BY q.created_at DESC
        ''', [uid.toString()]);
      } else if (widget.paperId != null) {
        final ids = await DatabaseHelper.instance.getQuestionIdsForPaper(widget.paperId!);
        if (ids.isNotEmpty) {
          rows = await db.query('questions',
              where: 'id IN (${List.filled(ids.length, '?').join(',')})',
              whereArgs: ids,
              orderBy: 'created_at DESC');
        }
      } else if (widget.subject != null) {
        if (widget.chapter != null) {
          rows = await db.rawQuery('''
            SELECT q.*, u.display_name as author
            FROM questions q
            LEFT JOIN users u ON q.user_id = u.id
            JOIN question_tag_map qm ON q.id = qm.question_id
            JOIN tags t ON t.id = qm.tag_id
            WHERE q.subject = ? AND t.name = ? AND q.is_public = 1
            ORDER BY q.created_at DESC
          ''', [widget.subject, widget.chapter]);
        } else {
          rows = await db.rawQuery('''
            SELECT q.*, u.display_name as author
            FROM questions q
            LEFT JOIN users u ON q.user_id = u.id
            WHERE q.subject = ? AND q.is_public = 1
            ORDER BY q.created_at DESC
          ''', [widget.subject]);
        }
      }

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
          'author': row['author'] ?? row['user_id'] ?? '',
          'user_id': row['user_id'] ?? '',
          'created_at': row['created_at'],
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _questions = mapped;
        _isLoading = false;
        _showAnswers = widget.paperId == null;
        _isFloatingNavExpanded = false;
        _itemKeys = List.generate(mapped.length, (_) => GlobalKey());
      });
    } catch (e) {
      debugPrint('載入題目失敗: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _openPractice(int initialIndex, {bool saveResult = false, bool isPaperMode = false}) {
    if (_questions.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionPracticePage(
          questions: _questions,
          initialIndex: initialIndex,
          title: widget.title,
          currentUser: widget.currentUser,
          isPaper: isPaperMode,
          saveResult: saveResult,
          subject: widget.subject ?? widget.title,
          paperId: widget.paperId,
        ),
      ),
    );
  }

  Future<void> _showPracticeModeSelectionDialog() async {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.psychology_rounded, color: cs.primary, size: 28),
            const SizedBox(width: 12),
            const Text(
              '請選擇作答模式',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '此設定會影響測驗結束後，系統是否為您儲存分數與錯題紀錄。',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            // Card 1: 一般練習 (不記錄成績)
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _openPractice(0, saveResult: false, isPaperMode: widget.paperId != null);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
                  color: cs.surfaceContainerLowest,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Colors.blue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '一般練習 (不記錄成績)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '直接作答，作答結果不存入個人學習歷程。',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Card 2: 模擬測驗 (記錄成績)
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                if (widget.paperId != null) {
                  _openPractice(0, saveResult: true, isPaperMode: true);
                } else {
                  // 不需要強制匯入自訂題本，直接開始作答並記錄成績
                  _openPractice(0, saveResult: true, isPaperMode: false);
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
                  color: cs.surfaceContainerLowest,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.assignment_turned_in_rounded, color: Colors.orange),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '模擬測驗 (儲存測驗紀錄)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.paperId != null
                                ? '交卷後自動儲存測驗分數與歷史。'
                                : '交卷後將自動儲存測驗分數，並將錯題加入錯題本。',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditPage(Map<String, dynamic> question) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionEditPage(
          initialData: question,
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

  Future<void> _deleteQuestion(Map<String, dynamic> question) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除題目'),
        content: const Text('確定要刪除這題嗎？這個動作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final db = await DatabaseHelper.instance.database;
      if (widget.paperId != null) {
        // Remove from paper
        final ids = await DatabaseHelper.instance.getQuestionIdsForPaper(widget.paperId!);
        ids.remove(question['id']);
        await DatabaseHelper.instance.updatePaper(widget.paperId!, widget.title, ids);
      } else {
        // Delete completely
        await db.delete(
          'questions',
          where: 'id = ?',
          whereArgs: [question['id']],
        );
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('題目已移除')),
      );
      await _loadQuestions();
    } catch (e) {
      debugPrint('刪除題目失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('移除失敗')),
      );
    }
  }

  Future<void> _addQuestionToPaper(Map<String, dynamic> question) async {
    try {
      final uid = widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
      final papers = await DatabaseHelper.instance.getPapersForUser(uid.toString());
      final questionId = int.tryParse(question['id'].toString()) ?? 0;
      
      if (!mounted) return;

      final selectedPaper = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('選擇要加入的自訂題本'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: papers.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const Icon(Icons.add, color: Colors.blue),
                    title: const Text('建立新題本並加入', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    onTap: () => Navigator.pop(ctx, {'action': 'create_new'}),
                  );
                }
                final p = papers[index - 1];
                return ListTile(
                  leading: const Icon(Icons.assignment_rounded, color: Colors.orange),
                  title: Text(p['name'] ?? '未命名題本'),
                  onTap: () => Navigator.pop(ctx, p),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        ),
      );

      if (selectedPaper == null) return;

      if (selectedPaper['action'] == 'create_new') {
        if (!mounted) return;
        final newNameController = TextEditingController();
        final defaultName = '題本 ${papers.length + 1}';
        
        final newPaperName = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('建立新題本'),
            content: TextField(
              controller: newNameController,
              decoration: InputDecoration(
                labelText: '題本名稱',
                hintText: defaultName,
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = newNameController.text.trim();
                  Navigator.pop(ctx, text.isEmpty ? defaultName : text);
                },
                child: const Text('確定'),
              ),
            ],
          ),
        );

        if (newPaperName == null) return;

        await DatabaseHelper.instance.createPaper(
          uid.toString(),
          newPaperName,
          [questionId],
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已建立並成功加入「$newPaperName」')),
        );
        return;
      }

      final paperId = int.tryParse(selectedPaper['id'].toString()) ?? 0;
      final paperName = selectedPaper['name'] ?? '未命名題本';

      final ids = await DatabaseHelper.instance.getQuestionIdsForPaper(paperId);
      if (ids.contains(questionId)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('此題目已存在於該自訂題本中')),
        );
      } else {
        ids.add(questionId);
        await DatabaseHelper.instance.updatePaper(paperId, paperName, ids);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已將題目成功加入「$paperName」')),
        );
      }
    } catch (e) {
      debugPrint('加到題本失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加入失敗，請稍後再試')),
      );
    }
  }

  Future<Map<String, dynamic>?> _importAllQuestionsToPaper() async {
    if (_questions.isEmpty) return null;
    try {
      final uid = widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
      final papers = await DatabaseHelper.instance.getPapersForUser(uid.toString());
      final allIds = _questions.map((q) => int.tryParse(q['id'].toString()) ?? 0).where((id) => id > 0).toList();

      if (!mounted) return null;

      final selectedPaper = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('選擇要匯入的自訂題本'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: papers.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const Icon(Icons.add, color: Colors.blue),
                    title: const Text('建立新題本並匯入', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    onTap: () => Navigator.pop(ctx, {'action': 'create_new'}),
                  );
                }
                final p = papers[index - 1];
                return ListTile(
                  leading: const Icon(Icons.assignment_rounded, color: Colors.orange),
                  title: Text(p['name'] ?? '未命名題本'),
                  onTap: () => Navigator.pop(ctx, p),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
          ],
        ),
      );

      if (selectedPaper == null) return null;

      int finalPaperId = 0;
      String finalPaperName = '';

      if (selectedPaper['action'] == 'create_new') {
        if (!mounted) return null;
        final newNameController = TextEditingController();
        final defaultName = '${widget.title} (複製)';

        final newPaperName = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('建立新題本'),
            content: TextField(
              controller: newNameController,
              decoration: InputDecoration(
                labelText: '題本名稱',
                hintText: defaultName,
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  final text = newNameController.text.trim();
                  Navigator.pop(ctx, text.isEmpty ? defaultName : text);
                },
                child: const Text('確定'),
              ),
            ],
          ),
        );

        if (newPaperName == null) return null;

        finalPaperId = await DatabaseHelper.instance.createPaper(
          uid.toString(),
          newPaperName,
          allIds,
        );
        finalPaperName = newPaperName;

        if (!mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已建立並成功匯入 ${allIds.length} 題至「$newPaperName」')),
        );
      } else {
        finalPaperId = int.tryParse(selectedPaper['id'].toString()) ?? 0;
        finalPaperName = selectedPaper['name'] ?? '未命名題本';

        final ids = await DatabaseHelper.instance.getQuestionIdsForPaper(finalPaperId);
        final int originalCount = ids.length;
        final Set<int> mergedSet = {...ids, ...allIds};
        final int addedCount = mergedSet.length - originalCount;

        await DatabaseHelper.instance.updatePaper(finalPaperId, finalPaperName, mergedSet.toList());
        
        if (!mounted) return null;
        if (addedCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('所有題目均已存在於「$finalPaperName」中')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已成功匯入 $addedCount 題至「$finalPaperName」！')),
          );
        }
      }
      return {'id': finalPaperId, 'name': finalPaperName};
    } catch (e) {
      debugPrint('整套匯入失敗: $e');
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('匯入失敗，請稍後再試')),
      );
      return null;
    }
  }

  Widget _buildQuestionItem(BuildContext context, Map<String, dynamic> question, int index, ColorScheme cs) {
    final options = question['options'] is List
        ? (question['options'] as List).map((item) => item.toString()).toList()
        : <String>[];
    
    final answerIndex = question['answerIndex'] as int;
    final correctAnswerText = (answerIndex >= 0 && answerIndex < options.length) 
        ? options[answerIndex] 
        : '未知';
        
    final explanation = question['explanation']?.toString() ?? '';

    final cardContent = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question['question']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    height: 1.5,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(
                  question['isFavorite'] == true ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: question['isFavorite'] == true ? Colors.amber : cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final db = await DatabaseHelper.instance.database;
                    final nextVal = question['isFavorite'] == true ? 0 : 1;
                    await db.update('questions', <String, Object?>{'bookmarked': nextVal}, where: 'id = ?', whereArgs: [question['id']]);
                    setState(() {
                      question['isFavorite'] = nextVal == 1;
                    });
                    messenger.showSnackBar(
                      SnackBar(content: Text(nextVal == 1 ? '已加入收藏' : '已取消收藏')),
                    );
                  } catch (e) {
                    debugPrint('切換收藏失敗: $e');
                  }
                },
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                onSelected: (value) {
                  if (value == 'edit') _openEditPage(question);
                  if (value == 'delete') _deleteQuestion(question);
                  if (value == 'add_to_paper') _addQuestionToPaper(question);
                  if (value == 'add_to_notebook') {
                    NotebookHelper.showAddToNotebookDialog(context, widget.currentUser, question);
                  }
                },
                itemBuilder: (context) {
                  final currentUserId = (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1').toString();
                  final isOwner = question['user_id']?.toString() == currentUserId;
                  
                  final items = <PopupMenuEntry<String>>[];
                  if (isOwner) {
                    items.add(const PopupMenuItem(value: 'edit', child: Text('編輯題目')));
                  }
                  if (widget.paperId != null) {
                    items.add(const PopupMenuItem(value: 'add_to_notebook', child: Text('加入筆記本')));
                    items.add(const PopupMenuItem(value: 'delete', child: Text('移除題目', style: TextStyle(color: Colors.red))));
                  } else {
                    items.add(const PopupMenuItem(value: 'add_to_paper', child: Text('加到自訂題本')));
                    items.add(const PopupMenuItem(value: 'add_to_notebook', child: Text('加入筆記本')));
                    if (isOwner) {
                      items.add(const PopupMenuItem(value: 'delete', child: Text('刪除題目', style: TextStyle(color: Colors.red))));
                    }
                  }
                  return items;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...options.asMap().entries.map((opt) {
            final isCorrect = opt.key == answerIndex;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isCorrect ? Colors.green.withValues(alpha: 0.1) : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect ? Colors.green.withValues(alpha: 0.5) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${String.fromCharCode(65 + opt.key)}.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCorrect ? Colors.green.shade700 : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      opt.value,
                      style: TextStyle(
                        color: isCorrect ? Colors.green.shade800 : cs.onSurface,
                      ),
                    ),
                  ),
                  if (isCorrect)
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '正確答案：$correctAnswerText',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                if (explanation.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
                  ),
                  Text(
                    '解析：\n$explanation',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: !_showAnswers
          ? InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _expandedIndices.remove(index);
                });
              },
              child: cardContent,
            )
          : cardContent,
    );
  }

  Widget _buildHeroHeader(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary,
            cs.primary.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.onPrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.paperId != null ? Icons.assignment_rounded : Icons.folder_open_rounded,
                    color: cs.onPrimary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.isCustomOnly ? '個人自訂' : (widget.paperId != null ? '自訂題本' : '${widget.subject ?? "公共題庫"} • ${widget.chapter ?? "全部章節"}'),
                        style: TextStyle(
                          color: cs.onPrimary.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '題目總數',
                style: TextStyle(
                  color: cs.onPrimary.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_questions.length} 題',
                style: TextStyle(
                  color: cs.onPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: ElevatedButton.icon(
              onPressed: _showPracticeModeSelectionDialog,
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('開始作答', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _showAnswers = !_showAnswers;
                  // 切換解析顯示時同步清空個別展開記錄，確保狀態一致
                  _expandedIndices.clear();
                });
              },
              icon: Icon(
                _showAnswers ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 20,
              ),
              label: Text(_showAnswers ? '隱藏解析' : '顯示解析', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.primary,
                side: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (widget.paperId == null) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: OutlinedButton.icon(
                onPressed: _importAllQuestionsToPaper,
                icon: const Icon(Icons.copy_all_rounded, size: 20),
                label: const Text('收錄題本', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.secondary,
                  side: BorderSide(color: cs.secondary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactQuestionItem(BuildContext context, Map<String, dynamic> question, int index, ColorScheme cs) {
    final snippet = question['question']?.toString() ?? '';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.08)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _expandedIndices.add(index);
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: cs.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snippet,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if ((question['difficulty'] ?? '').toString().isNotEmpty)
                          _buildMiniTag(question['difficulty'].toString(), cs.tertiary, cs),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                icon: Icon(
                  question['isFavorite'] == true ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: question['isFavorite'] == true ? Colors.amber : cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final db = await DatabaseHelper.instance.database;
                    final nextVal = question['isFavorite'] == true ? 0 : 1;
                    await db.update('questions', <String, Object?>{'bookmarked': nextVal}, where: 'id = ?', whereArgs: [question['id']]);
                    setState(() {
                      question['isFavorite'] = nextVal == 1;
                    });
                    messenger.showSnackBar(
                      SnackBar(content: Text(nextVal == 1 ? '已加入收藏' : '已取消收藏')),
                    );
                  } catch (e) {
                    debugPrint('切換收藏失敗: $e');
                  }
                },
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (value) {
                  if (value == 'edit') _openEditPage(question);
                  if (value == 'delete') _deleteQuestion(question);
                  if (value == 'add_to_paper') _addQuestionToPaper(question);
                  if (value == 'add_to_notebook') {
                    NotebookHelper.showAddToNotebookDialog(context, widget.currentUser, question);
                  }
                },
                itemBuilder: (context) {
                  final currentUserId = (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1').toString();
                  final isOwner = question['user_id']?.toString() == currentUserId;
                  
                  final items = <PopupMenuEntry<String>>[];
                  if (isOwner) {
                    items.add(const PopupMenuItem(value: 'edit', child: Text('編輯題目')));
                  }
                  if (widget.paperId != null) {
                    items.add(const PopupMenuItem(value: 'add_to_notebook', child: Text('加入筆記本')));
                    items.add(const PopupMenuItem(value: 'delete', child: Text('移除題目', style: TextStyle(color: Colors.red))));
                  } else {
                    items.add(const PopupMenuItem(value: 'add_to_paper', child: Text('加到自訂題本')));
                    items.add(const PopupMenuItem(value: 'add_to_notebook', child: Text('加入筆記本')));
                    if (isOwner) {
                      items.add(const PopupMenuItem(value: 'delete', child: Text('刪除題目', style: TextStyle(color: Colors.red))));
                    }
                  }
                  return items;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniTag(String text, Color baseColor, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: baseColor.withValues(alpha: 0.15)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: baseColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNavigationItem(ColorScheme cs, int index) {
    return InkWell(
      onTap: () {
        if (!_showAnswers) {
          setState(() {
            _expandedIndices.add(index);
          });
        }
        setState(() {
          _isFloatingNavExpanded = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final targetCtx = _itemKeys[index].currentContext;
          if (targetCtx != null) {
            Scrollable.ensureVisible(
              targetCtx,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: cs.onSecondaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNavigator(ColorScheme cs) {
    final double maxExpandedHeight = (_questions.length * 48.0 + 56.0).clamp(100.0, 320.0);
    final double targetHeight = _isFloatingNavExpanded ? maxExpandedHeight : 56.0;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: 16 + bottomPadding,
      right: 16,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 56.0,
        height: targetHeight,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isFloatingNavExpanded
                  ? null
                  : () {
                      setState(() {
                        _isFloatingNavExpanded = true;
                      });
                    },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 收合狀態：題單圖示
                  AnimatedOpacity(
                    opacity: _isFloatingNavExpanded ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: _isFloatingNavExpanded
                        ? const SizedBox.shrink()
                        : Icon(
                            Icons.format_list_numbered_rounded,
                            color: cs.primary,
                            size: 24,
                          ),
                  ),
                  // 展開狀態：滑動題號面板 (直式)
                  AnimatedOpacity(
                    opacity: _isFloatingNavExpanded ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: !_isFloatingNavExpanded
                        ? const SizedBox.shrink()
                        : Column(
                            children: [
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.builder(
                                  controller: _horizontalScrollController,
                                  scrollDirection: Axis.vertical,
                                  itemCount: _questions.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: _buildNavigationItem(cs, index),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const Divider(height: 1, indent: 8, endIndent: 8),
                              IconButton(
                                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                onPressed: () {
                                  setState(() {
                                    _isFloatingNavExpanded = false;
                                  });
                                },
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: GestureDetector(
        onTap: () {
          if (_isFloatingNavExpanded) {
            setState(() {
              _isFloatingNavExpanded = false;
            });
          }
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _questions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 64, color: cs.primary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text('這個資料夾目前沒有題目', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              padding: EdgeInsets.fromLTRB(16, 16, 16, 100 + MediaQuery.of(context).padding.bottom),
                              child: Column(
                                children: [
                                  _buildHeroHeader(cs),
                                  _buildActionBar(cs),
                                  ...List.generate(_questions.length, (qIdx) {
                                    final question = _questions[qIdx];
                                    final isExpanded = _showAnswers || _expandedIndices.contains(qIdx);
                                    return Container(
                                      key: _itemKeys[qIdx],
                                      child: isExpanded
                                          ? _buildQuestionItem(context, question, qIdx, cs)
                                          : _buildCompactQuestionItem(context, question, qIdx, cs),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      _buildFloatingNavigator(cs),
                    ],
                  ),
      ),
      floatingActionButton: widget.paperId == null
          ? FloatingActionButton(
              heroTag: 'add_question_fab',
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuestionEditPage(
                      initialData: widget.subject != null ? {'subject': widget.subject} : null,
                      currentUser: widget.currentUser,
                      allSubjects: widget.allSubjects,
                      subjectChapters: widget.subjectChapters,
                    ),
                  ),
                );
                if (result == true) {
                  _loadQuestions();
                }
              },
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
