import 'dart:convert';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'question_edit_page.dart';
import 'question_practice_page.dart';

class QuestionSetDetailPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final String title;
  final String? subject;
  final String? chapter; // 新增章節參數
  final int? paperId;
  final List<String> allSubjects;
  final Map<String, List<String>> subjectChapters;

  const QuestionSetDetailPage({
    super.key,
    required this.currentUser,
    required this.title,
    this.subject,
    this.chapter,
    this.paperId,
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
  bool _isGridExpanded = true;
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _itemKeys = [];
  final Set<int> _expandedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;
      List<Map<String, Object?>> rows = [];
      
      if (widget.paperId != null) {
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
            WHERE q.subject = ? AND t.name = ?
            ORDER BY q.created_at DESC
          ''', [widget.subject, widget.chapter]);
        } else {
          rows = await db.rawQuery('''
            SELECT q.*, u.display_name as author
            FROM questions q
            LEFT JOIN users u ON q.user_id = u.id
            WHERE q.subject = ?
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
        _isGridExpanded = mapped.isNotEmpty;
        _itemKeys = List.generate(mapped.length, (_) => GlobalKey());
      });
    } catch (e) {
      debugPrint('載入題目失敗: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _openPractice(int initialIndex) {
    if (_questions.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionPracticePage(
          questions: _questions,
          initialIndex: initialIndex,
          title: widget.title,
          currentUser: widget.currentUser,
        ),
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
      final questionId = question['id'] as int;
      
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
                  subtitle: Text('建立於 ${p['created_at']?.toString().split(' ')[0] ?? ""}'),
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

  Future<void> _importAllQuestionsToPaper() async {
    if (_questions.isEmpty) return;
    try {
      final uid = widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
      final papers = await DatabaseHelper.instance.getPapersForUser(uid.toString());
      final allIds = _questions.map((q) => q['id'] as int).toList();

      if (!mounted) return;

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
                  subtitle: Text('建立於 ${p['created_at']?.toString().split(' ')[0] ?? ""}'),
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

        if (newPaperName == null) return;

        await DatabaseHelper.instance.createPaper(
          uid.toString(),
          newPaperName,
          allIds,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已建立並成功匯入 ${allIds.length} 題至「$newPaperName」')),
        );
        return;
      }

      final paperId = int.tryParse(selectedPaper['id'].toString()) ?? 0;
      final paperName = selectedPaper['name'] ?? '未命名題本';

      final ids = await DatabaseHelper.instance.getQuestionIdsForPaper(paperId);
      final int originalCount = ids.length;
      final Set<int> mergedSet = {...ids, ...allIds};
      final int addedCount = mergedSet.length - originalCount;

      await DatabaseHelper.instance.updatePaper(paperId, paperName, mergedSet.toList());
      
      if (!mounted) return;
      if (addedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('所有題目均已存在於「$paperName」中')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已成功匯入 $addedCount 題至「$paperName」！')),
        );
      }
    } catch (e) {
      debugPrint('整套匯入失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('匯入失敗，請稍後再試')),
      );
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
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                onSelected: (value) {
                  if (value == 'practice') _openPractice(index);
                  if (value == 'edit') _openEditPage(question);
                  if (value == 'delete') _deleteQuestion(question);
                  if (value == 'add_to_paper') _addQuestionToPaper(question);
                },
                itemBuilder: (context) => widget.paperId != null
                    ? [
                        const PopupMenuItem(value: 'practice', child: Text('單題練習')),
                        const PopupMenuItem(value: 'edit', child: Text('編輯題目')),
                        const PopupMenuItem(value: 'delete', child: Text('移除題目', style: TextStyle(color: Colors.red))),
                      ]
                    : [
                        const PopupMenuItem(value: 'practice', child: Text('單題練習')),
                        const PopupMenuItem(value: 'add_to_paper', child: Text('加到自訂題本')),
                      ],
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
      margin: const EdgeInsets.only(bottom: 20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      widget.paperId != null ? '自訂題本' : '${widget.subject ?? "公共題庫"} • ${widget.chapter ?? "全部章節"}',
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
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.paperId == null) ...[
                    IconButton(
                      icon: const Icon(Icons.copy_all_rounded),
                      tooltip: '整套匯入自訂題本',
                      style: IconButton.styleFrom(
                        backgroundColor: cs.onPrimary.withValues(alpha: 0.15),
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _importAllQuestionsToPaper,
                    ),
                    const SizedBox(width: 8),
                  ],
                  ElevatedButton.icon(
                    onPressed: () => _openPractice(0),
                    icon: const Icon(Icons.play_arrow_rounded, size: 24),
                    label: const Text('開始測驗', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.onPrimary,
                      foregroundColor: cs.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
                        if ((question['type'] ?? '').toString().isNotEmpty)
                          _buildMiniTag(question['type'].toString(), cs.primary, cs),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (value) {
                  if (value == 'practice') _openPractice(index);
                  if (value == 'edit') _openEditPage(question);
                  if (value == 'delete') _deleteQuestion(question);
                  if (value == 'add_to_paper') _addQuestionToPaper(question);
                },
                itemBuilder: (context) => widget.paperId != null
                    ? [
                        const PopupMenuItem(value: 'practice', child: Text('單題練習')),
                        const PopupMenuItem(value: 'edit', child: Text('編輯題目')),
                        const PopupMenuItem(value: 'delete', child: Text('移除題目', style: TextStyle(color: Colors.red))),
                      ]
                    : [
                        const PopupMenuItem(value: 'practice', child: Text('單題練習')),
                        const PopupMenuItem(value: 'add_to_paper', child: Text('加到自訂題本')),
                      ],
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

  Widget _buildCollapsibleNavigationGrid(ColorScheme cs) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Icon(Icons.grid_view_rounded, color: cs.primary),
            title: Text(
              '題號快速跳轉 (${_questions.length} 題)',
              style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            trailing: Icon(_isGridExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            onTap: () {
              setState(() {
                _isGridExpanded = !_isGridExpanded;
              });
            },
          ),
          if (_isGridExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      if (!_showAnswers) {
                        setState(() {
                          _expandedIndices.add(index);
                        });
                      }
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
                },
              ),
            ),
          ],
        ],
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
        actions: [
          if (_questions.isNotEmpty) ...[
            IconButton(
              icon: Icon(_showAnswers ? Icons.visibility_rounded : Icons.visibility_off_rounded),
              tooltip: _showAnswers ? '隱藏答案與解析' : '顯示答案與解析',
              onPressed: () {
                setState(() {
                  _showAnswers = !_showAnswers;
                });
              },
            ),
          ],
        ],
      ),
      body: _isLoading
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
              : Column(
                  children: [
                    _buildCollapsibleNavigationGrid(cs),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildHeroHeader(cs),
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
    );
  }
}
