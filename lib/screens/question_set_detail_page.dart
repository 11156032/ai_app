import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../services/add_to_paper_service.dart';
import '../services/notebook_helper.dart';
import '../utils/question_utils.dart';
import 'question_edit_page.dart';
import 'question_practice_page.dart';
import 'main_screen.dart';
import '../services/app_locale_service.dart';

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
  final List<Map<String, dynamic>>? initialQuestions;

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
    this.initialQuestions,
  });

  @override
  State<QuestionSetDetailPage> createState() => _QuestionSetDetailPageState();
}

class _QuestionSetDetailPageState extends State<QuestionSetDetailPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _questions = [];
  bool _showAnswers = false;
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _itemKeys = [];
  final Set<int> _expandedIndices = {};
  bool _onlyFavorites = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

      if (widget.initialQuestions != null && widget.initialQuestions!.isNotEmpty) {
        rows = widget.initialQuestions!
            .map((q) => Map<String, Object?>.from(q))
            .toList();
      } else if (widget.isFavoriteOnly) {
        rows = await db.query('questions',
            where: 'bookmarked = 1', orderBy: 'created_at DESC');
      } else if (widget.isCustomOnly) {
        final uid =
            widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
        rows = await db.rawQuery('''
          SELECT q.*, u.display_name as author
          FROM questions q
          LEFT JOIN users u ON q.user_id = u.id
          WHERE q.user_id = ? AND q.is_public = 0
          ORDER BY q.created_at DESC
        ''', [uid.toString()]);
      } else if (widget.paperId != null) {
        final ids = await DatabaseHelper.instance
            .getQuestionIdsForPaper(widget.paperId!);
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
        if (_showAnswers) {
          _expandedIndices.addAll(List.generate(mapped.length, (i) => i));
        } else {
          _expandedIndices.clear();
        }
        _itemKeys = List.generate(mapped.length, (_) => GlobalKey());
      });
    } catch (e) {
      debugPrint('載入題目失敗: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _openDiscussion(Map<String, dynamic> question) {
    if (widget.paperId != null || widget.isCustomOnly) return;
    QuestionDiscussionPage.showAsBottomSheet(
      context,
      questionData: question,
      currentUser: widget.currentUser,
    );
  }

  void _openPractice(int initialIndex,
      {bool saveResult = true, bool isPaperMode = false}) {
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
          saveResult: true,
          subject: widget.subject ?? widget.title,
          paperId: widget.paperId,
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
        title: Text(tr('qs_delete_q')),
        content: Text(tr('qs_delete_q_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('btn_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('common_delete'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final db = await DatabaseHelper.instance.database;
      if (widget.paperId != null) {
        // Remove from paper
        final ids = await DatabaseHelper.instance
            .getQuestionIdsForPaper(widget.paperId!);
        ids.remove(question['id']);
        await DatabaseHelper.instance
            .updatePaper(widget.paperId!, widget.title, ids);
      } else {
        // Delete completely
        await db.delete(
          'questions',
          where: 'id = ?',
          whereArgs: [question['id']],
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('qs_removed'))),
      );
      await _loadQuestions();
    } catch (e) {
      debugPrint('刪除題目失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('qs_remove_failed'))),
      );
    }
  }

  Future<void> _addQuestionToPaper(Map<String, dynamic> question) async {
    final uid =
        widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
    final questionId = int.tryParse(question['id'].toString()) ?? 0;
    if (questionId <= 0) return;

    await AddToPaperService.show(
      context: context,
      userId: uid.toString(),
      questionIds: [questionId],
    );
  }

  Future<Map<String, dynamic>?> _importAllQuestionsToPaper() async {
    if (_questions.isEmpty) return null;

    final uid =
        widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
    final allIds = _questions
        .map((q) => int.tryParse(q['id'].toString()) ?? 0)
        .where((id) => id > 0)
        .toList();

    return AddToPaperService.show(
      context: context,
      userId: uid.toString(),
      questionIds: allIds,
      defaultNewName: tr('qs_copy_name', [widget.title.toString()]),
    );
  }


  Widget _buildQuestionNumberBadge(int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Text(
        '${index + 1}',
        style: const TextStyle(
          color: Color(0xFF4338CA),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, Map<String, dynamic> question,
      int index, ColorScheme cs, bool isExpanded) {
    final options = QuestionUtils.parseOptions(question['options']);
    final answerIndex = QuestionUtils.getCorrectAnswerIndex(question);
    final correctAnswerText = (answerIndex >= 0 && answerIndex < options.length)
        ? options[answerIndex]
        : tr('common_unknown');
    final explanation = question['explanation']?.toString() ?? '';
    final snippet = question['question']?.toString() ?? '';
    final currentUserId = (widget.currentUser['id'] ??
            widget.currentUser['user_id'] ??
            'u1')
        .toString();
    final isOwner = question['user_id']?.toString() == currentUserId;
    final canRemoveOrDelete = isOwner || widget.paperId != null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedIndices.remove(index);
            } else {
              _expandedIndices.add(index);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuestionNumberBadge(index),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snippet,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                            height: 1.45,
                          ),
                          maxLines: isExpanded ? null : 2,
                          overflow: isExpanded ? null : TextOverflow.ellipsis,
                        ),
                        if (!isExpanded) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if ((question['difficulty'] ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                _buildMiniTag(question['difficulty'].toString(),
                                    const Color(0xFF0D9488), cs),
                                const SizedBox(width: 6),
                              ],
                              _buildMiniTag(
                                  question['type'] ?? '單選題',
                                  const Color(0xFF6366F1),
                                  cs),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      question['isFavorite'] == true
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: question['isFavorite'] == true
                          ? Colors.amber
                          : const Color(0xFF94A3B8),
                      size: 22,
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final db = await DatabaseHelper.instance.database;
                        final nextVal = question['isFavorite'] == true ? 0 : 1;
                        await db.update(
                            'questions', <String, Object?>{'bookmarked': nextVal},
                            where: 'id = ?', whereArgs: [question['id']]);
                        setState(() {
                          question['isFavorite'] = nextVal == 1;
                        });
                        messenger..hideCurrentSnackBar()..showSnackBar(
                          SnackBar(
                            duration: const Duration(milliseconds: 1500),
                            behavior: SnackBarBehavior.floating,
                            content: Text(nextVal == 1
                                ? tr('wq_faved')
                                : tr('post_unbookmarked')),
                          ),
                        );
                      } catch (e) {
                        debugPrint('切換收藏失敗: $e');
                      }
                    },
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: isExpanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 14),
                          ...options.asMap().entries.map((opt) {
                            final isCorrect = opt.key == answerIndex;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isCorrect
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : cs.surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCorrect
                                      ? Colors.green.withValues(alpha: 0.5)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${String.fromCharCode(65 + opt.key)}.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCorrect
                                          ? Colors.green.shade700
                                          : cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      opt.value,
                                      style: TextStyle(
                                        color: isCorrect
                                            ? Colors.green.shade800
                                            : cs.onSurface,
                                      ),
                                    ),
                                  ),
                                  if (isCorrect)
                                    const Icon(Icons.check_circle,
                                        color: Colors.green, size: 20),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.lightbulb_outline,
                                        size: 18, color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        tr('qs_correct_answer',
                                            [correctAnswerText.toString()]),
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
                                    tr('qs_explanation',
                                        [explanation.toString()]),
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      height: 1.5,
                                    ),
                                  ),
                                ]
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _openDiscussion(question),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFC7D2FE)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.forum_outlined,
                                      size: 16, color: Color(0xFF4F46E5)),
                                  const SizedBox(width: 6),
                                  Text(
                                    tr('qs_go_discussion'),
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (isOwner) ...[
                                  TextButton.icon(
                                    onPressed: () => _openEditPage(question),
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    label: Text(tr('qs_edit_q'),
                                        style: const TextStyle(fontSize: 12)),
                                    style: TextButton.styleFrom(
                                      foregroundColor: cs.onSurfaceVariant,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                TextButton.icon(
                                  onPressed: () => _addQuestionToPaper(question),
                                  icon: const Icon(Icons.post_add_rounded, size: 16),
                                  label: Text(tr('qs_add_to_paper'),
                                      style: const TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: cs.onSurfaceVariant,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                TextButton.icon(
                                  onPressed: () =>
                                      NotebookHelper.showAddToNotebookDialog(
                                          context,
                                          widget.currentUser,
                                          question),
                                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                                  label: Text(tr('wq_add_notebook'),
                                      style: const TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    foregroundColor: cs.onSurfaceVariant,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                if (canRemoveOrDelete) ...[
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    onPressed: () => _deleteQuestion(question),
                                    icon: Icon(Icons.delete_outline_rounded,
                                        size: 16, color: Colors.red.shade400),
                                    label: Text(
                                      widget.paperId != null
                                          ? tr('qs_remove_q')
                                          : tr('qs_delete_q'),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red.shade400),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red.shade400,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBar(ColorScheme cs) {
    final subText = widget.isCustomOnly
        ? tr('qs_custom_personal')
        : (widget.paperId != null
            ? tr('qs_custom_paper')
            : (widget.subject != null ? trv(widget.subject!) : tr('qs_public_bank')));
    final chapterText = widget.chapter ?? tr('qs_all_chapters');
    final favCount = _questions.where((q) => q['isFavorite'] == true).length;
    if (favCount == 0 && _onlyFavorites) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _onlyFavorites = false);
      });
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.paperId != null
                  ? Icons.menu_book_rounded
                  : Icons.folder_open_rounded,
              color: cs.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.paperId != null ? subText : '$subText • $chapterText',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              if (_onlyFavorites) {
                setState(() => _onlyFavorites = false);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: !_onlyFavorites
                    ? cs.primary.withValues(alpha: 0.12)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: !_onlyFavorites
                      ? cs.primary.withValues(alpha: 0.25)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.quiz_outlined,
                      size: 13,
                      color: !_onlyFavorites ? cs.primary : const Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    tr('qs_n', [_questions.length.toString()]),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: !_onlyFavorites ? cs.primary : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (favCount > 0) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                setState(() => _onlyFavorites = !_onlyFavorites);
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _onlyFavorites
                      ? const Color(0xFFD97706)
                      : Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _onlyFavorites
                        ? const Color(0xFFB45309)
                        : Colors.amber.withValues(alpha: 0.35),
                  ),
                  boxShadow: _onlyFavorites
                      ? [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: _onlyFavorites ? Colors.white : Colors.amber.shade800,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$favCount',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: _onlyFavorites ? Colors.white : Colors.amber.shade800,
                      ),
                    ),
                    if (_onlyFavorites) ...[
                      const SizedBox(width: 3),
                      const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionBar(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          // 開始測驗 (主要行動按鈕，一律儲存成績)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _questions.isEmpty
                    ? null
                    : () => _openPractice(0,
                        saveResult: true,
                        isPaperMode: widget.paperId != null),
                icon: const Icon(Icons.play_arrow_rounded, size: 22, color: Colors.white),
                label: const Text(
                  '開始測驗',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMiniTag(String text, Color baseColor, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: baseColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: baseColor,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showQuestionJumpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '題目快速跳轉',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '共 ${_questions.length} 題',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.45,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _questions.length,
                    itemBuilder: (context, idx) {
                      final isFav = _questions[idx]['isFavorite'] == true;
                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            if (_onlyFavorites &&
                                _questions[idx]['isFavorite'] != true) {
                              _onlyFavorites = false;
                            }
                            if (!_showAnswers) {
                              _expandedIndices.add(idx);
                            }
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            final targetCtx = _itemKeys[idx].currentContext;
                            if (targetCtx != null) {
                              Scrollable.ensureVisible(
                                targetCtx,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeInOut,
                              );
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isFav
                                  ? Colors.amber.shade600
                                  : const Color(0xFFCBD5E1),
                              width: isFav ? 1.5 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isFav ? Colors.amber.shade900 : const Color(0xFF1E293B),
                                ),
                              ),
                              if (isFav)
                                const Positioned(
                                  top: 3,
                                  right: 3,
                                  child: Icon(Icons.star_rounded,
                                      size: 11, color: Colors.amber),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        elevation: 0,
        actions: [
          Builder(builder: (context) {
            final allExpanded = _questions.isNotEmpty &&
                _expandedIndices.length >= _questions.length;
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: Icon(
                  allExpanded
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                tooltip: allExpanded ? '收合全部' : '展開全部',
                onPressed: () {
                  setState(() {
                    if (allExpanded) {
                      _expandedIndices.clear();
                      _showAnswers = false;
                    } else {
                      _expandedIndices.addAll(
                          List.generate(_questions.length, (i) => i));
                      _showAnswers = true;
                    }
                  });
                },
              ),
            );
          }),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.format_list_numbered_rounded,
                  color: Colors.white, size: 20),
              tooltip: '題號導覽',
              onPressed: () => _showQuestionJumpSheet(context),
            ),
          ),
          if (widget.paperId == null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.post_add_rounded,
                    color: Colors.white, size: 20),
                tooltip: tr('qs_collect'),
                onPressed: _importAllQuestionsToPaper,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open,
                          size: 64, color: cs.primary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(tr('qs_folder_empty'),
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 16)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(16, 16, 16,
                      80 + MediaQuery.of(context).padding.bottom),
                  child: Column(
                    children: [
                      _buildInfoBar(cs),
                      _buildActionBar(cs),
                      ...List.generate(_questions.length, (qIdx) {
                        final question = _questions[qIdx];
                        if (_onlyFavorites && question['isFavorite'] != true) {
                          return const SizedBox.shrink();
                        }
                        final isExpanded = _expandedIndices.contains(qIdx);
                        return Container(
                          key: _itemKeys[qIdx],
                          child: _buildQuestionCard(
                              context, question, qIdx, cs, isExpanded),
                        );
                      }),
                      if (_onlyFavorites &&
                          !_questions.any((q) => q['isFavorite'] == true))
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.star_outline_rounded,
                                  size: 44,
                                  color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                              const SizedBox(height: 8),
                              Text(
                                '目前無收藏題目',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
      floatingActionButton: widget.isCustomOnly
          ? FloatingActionButton(
              heroTag: 'add_question_fab',
              onPressed: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuestionEditPage(
                      initialData: widget.subject != null
                          ? {'subject': widget.subject}
                          : null,
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
