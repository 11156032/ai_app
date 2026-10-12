import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import 'question_set_detail_page.dart';
import 'paper_builder_page.dart';
import 'wrong_questions_page.dart';
import 'subject_chapters_page.dart';
import 'question_edit_page.dart';
import 'ai_upload_paper_page.dart';
import '../services/app_locale_service.dart';

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
  bool _isLoading = true;
  List<Map<String, dynamic>> _userPapers = [];
  Map<String, int> _subjectCounts = {};
  int _customQuestionCount = 0;
  int _wrongQuestionCount = 0;
  int _favoriteQuestionCount = 0;
  int _totalQuestionCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final uid =
          (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1')
              .toString();

      // 1. Load User Papers
      final papers = await DatabaseHelper.instance.getPapersForUser(uid);

      // 2. Load Subject Counts
      final rows = await db.rawQuery('''
        SELECT subject, COUNT(id) as count
        FROM questions
        WHERE is_public = 1
        GROUP BY subject
      ''');
      final counts = <String, int>{};
      for (final row in rows) {
        final subject = row['subject']?.toString() ?? '';
        final count = int.tryParse(row['count'].toString()) ?? 0;
        if (subject.isNotEmpty) {
          counts[subject] = count;
        }
      }

      // 3. Load Custom Question Count
      final customRows = await db.rawQuery('''
        SELECT COUNT(id) as count
        FROM questions
        WHERE user_id = ? AND is_public = 0
      ''', [uid]);
      final customCount =
          int.tryParse(customRows.first['count']?.toString() ?? '0') ?? 0;

      // 4. Load Wrong Questions Count
      final wrongRows = await db.rawQuery('''
        SELECT COUNT(id) as count
        FROM wrong_questions
        WHERE user_id = ?
      ''', [uid]);
      final wrongCount =
          int.tryParse(wrongRows.first['count']?.toString() ?? '0') ?? 0;

      // 5. Load Favorite Questions Count
      final favRows = await db.rawQuery('''
        SELECT COUNT(id) as count
        FROM questions
        WHERE bookmarked = 1
      ''');
      final favCount =
          int.tryParse(favRows.first['count']?.toString() ?? '0') ?? 0;

      // 6. Load Total Questions
      final totalQRows =
          await db.rawQuery('SELECT COUNT(id) as count FROM questions');
      final totalQ =
          int.tryParse(totalQRows.first['count']?.toString() ?? '0') ?? 0;

      if (!mounted) return;
      setState(() {
        _userPapers = papers;
        _subjectCounts = counts;
        _customQuestionCount = customCount;
        _wrongQuestionCount = wrongCount;
        _favoriteQuestionCount = favCount;
        _totalQuestionCount = totalQ;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('載入題庫資料失敗: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePaper(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr('ql_delete_paper')),
        content: Text(tr('ql_delete_paper_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('btn_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('delete_account_confirm'),
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await DatabaseHelper.instance.deletePaper(id);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('ql_deleted'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, content: Text(tr('ql_delete_failed'))));
    }
  }

  Future<void> _publishPaper(int paperId, String paperName) async {
    final questionIds =
        await DatabaseHelper.instance.getQuestionIdsForPaper(paperId);
    final db = await DatabaseHelper.instance.database;

    List<Map<String, dynamic>> questionRows = [];
    if (questionIds.isNotEmpty) {
      questionRows = await db.query(
        'questions',
        where: 'id IN (${List.filled(questionIds.length, '?').join(',')})',
        whereArgs: questionIds,
      );
    }

    final userId = widget.currentUser['id'].toString();
    final myGroups = await DatabaseHelper.instance.getMyGroups(userId);

    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final cardBg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFBF9F7);
    final borderCol = isDark ? Colors.white12 : Colors.grey.shade300;

    final contentCtrl = TextEditingController(
      text: '推薦這份精選題本《$paperName》，歡迎大家一起練習！📚',
    );

    String destinationType = 'square';
    int? selectedGroupId =
        myGroups.isNotEmpty ? (myGroups.first['id'] as int) : null;
    bool isPublishing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.share_rounded,
                            color: primaryColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('ql_share_paper_title'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              tr('ql_share_paper_desc'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white60
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 題本預覽卡片
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.auto_stories_rounded,
                              color: primaryColor, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                paperName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color:
                                      isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          primaryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '共 ${questionIds.length} 題',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                  if (questionRows.isNotEmpty &&
                                      questionRows.first['subject'] !=
                                          null) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '#${questionRows.first['subject']}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 推薦心得輸入框
                  Text(
                    '推薦留言 / 心得備註',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: '說說這份題本的特色或推薦重點...',
                      filled: true,
                      fillColor:
                          isDark ? const Color(0xFF282828) : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 目的地
                  Text(
                    '分享目的地',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChoiceChip(
                        avatar: Icon(
                          Icons.public_rounded,
                          size: 16,
                          color: destinationType == 'square'
                              ? Colors.white
                              : (isDark ? Colors.white70 : primaryColor),
                        ),
                        label: const Text('公開廣場'),
                        selected: destinationType == 'square',
                        selectedColor: primaryColor,
                        labelStyle: TextStyle(
                          color: destinationType == 'square'
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: destinationType == 'square'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setModalState(() => destinationType = 'square');
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      ChoiceChip(
                        avatar: Icon(
                          Icons.groups_rounded,
                          size: 16,
                          color: destinationType == 'group'
                              ? Colors.white
                              : (isDark ? Colors.white70 : primaryColor),
                        ),
                        label: Text(myGroups.isNotEmpty
                            ? '社群群組 (${myGroups.length})'
                            : '社群群組'),
                        selected: destinationType == 'group',
                        selectedColor: primaryColor,
                        labelStyle: TextStyle(
                          color: destinationType == 'group'
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: destinationType == 'group'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setModalState(() {
                              destinationType = 'group';
                              if (selectedGroupId == null &&
                                  myGroups.isNotEmpty) {
                                selectedGroupId =
                                    myGroups.first['id'] as int;
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),

                  // 群組選擇區域（若選群組則展示）
                  if (destinationType == 'group') ...[
                    const SizedBox(height: 10),
                    if (myGroups.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : Colors.amber.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '您尚未加入任何群組，請先至社群建立或加入群組。',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      Text(
                        myGroups.length > 1
                            ? '選擇要分享的群組：'
                            : '分享至以下群組：',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white60
                              : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: myGroups.map((g) {
                          final gId = g['id'] as int;
                          final gName = (g['name'] ?? '群組').toString();
                          final isSelected = selectedGroupId == gId;
                          return ChoiceChip(
                            avatar: Icon(
                              Icons.groups_rounded,
                              size: 14,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : primaryColor),
                            ),
                            label: Text(
                              gName.length > 12
                                  ? '${gName.substring(0, 12)}...'
                                  : gName,
                            ),
                            selected: isSelected,
                            selectedColor: primaryColor,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: (val) {
                              if (val) {
                                setModalState(() => selectedGroupId = gId);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                  const SizedBox(height: 18),

                  // 發布按鈕
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: (isPublishing ||
                              (destinationType == 'group' && myGroups.isEmpty))
                          ? null
                          : () async {
                              setModalState(() => isPublishing = true);
                              try {
                                final questionsData = questionRows
                                    .map((q) => {
                                          'id': q['id'],
                                          'text': q['text'],
                                          'options': q['options'],
                                          'answer': q['answer'],
                                          'explanation': q['explanation'],
                                          'subject': q['subject'],
                                          'difficulty': q['difficulty'],
                                          'type': q['type'],
                                        })
                                    .toList();

                                final attachedData = {
                                  'shared_type': 'paper',
                                  'paper_id': paperId,
                                  'paper_name': paperName,
                                  'question_count': questionIds.length,
                                  'question_ids': questionIds,
                                  'questions_data': questionsData,
                                  'creator_name':
                                      widget.currentUser['display_name'] ??
                                          '同學',
                                  'created_at':
                                      DateTime.now().toIso8601String(),
                                };

                                final textContent =
                                    contentCtrl.text.trim().isEmpty
                                        ? '推薦這份精選題本《$paperName》，歡迎大家一起練習！📚'
                                        : contentCtrl.text.trim();

                                final targetGroupId =
                                    destinationType == 'group'
                                        ? selectedGroupId
                                        : null;

                                await db.insert('posts', {
                                  'user_id': userId,
                                  'group_id': targetGroupId,
                                  'content': textContent,
                                  'type': 'paper',
                                  'attached_data': jsonEncode(attachedData),
                                  'created_at':
                                      DateTime.now().toIso8601String(),
                                });

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  final selectedG = myGroups.firstWhere(
                                    (g) => g['id'] == selectedGroupId,
                                    orElse: () => <String, dynamic>{},
                                  );
                                  final gName =
                                      selectedG['name']?.toString() ?? '群組';
                                  final msg = destinationType == 'group'
                                      ? '已成功分享至「$gName」群組！'
                                      : tr('ql_share_success');

                                  ScaffoldMessenger.of(context)
                                    ..clearSnackBars()
                                    ..showSnackBar(
                                      SnackBar(
                                        content: Text(msg),
                                        backgroundColor: primaryColor,
                                        behavior: SnackBarBehavior.floating,
                                        duration:
                                            const Duration(milliseconds: 1200),
                                      ),
                                    );
                                }
                              } catch (e) {
                                setModalState(() => isPublishing = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('分享失敗: $e')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: isPublishing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Icon(
                              destinationType == 'group'
                                  ? Icons.groups_rounded
                                  : Icons.send_rounded,
                              size: 18),
                      label: Text(
                        isPublishing
                            ? '發布中...'
                            : (destinationType == 'group'
                                ? (myGroups.isEmpty
                                    ? '尚未加入群組'
                                    : '分享至群組')
                                : tr('ql_share_to_square')),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 多元分享按鈕列
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final code = 'PAPER#$paperId#$paperName';
                            await Clipboard.setData(
                                ClipboardData(text: code));
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                ..clearSnackBars()
                                ..showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        tr('ql_share_code_copied', [code])),
                                    behavior: SnackBarBehavior.floating,
                                    duration:
                                        const Duration(milliseconds: 1200),
                                  ),
                                );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: Text(tr('ql_share_copy_code'),
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final buffer = StringBuffer();
                            buffer.writeln(
                                '【精選題本】$paperName (共 ${questionRows.length} 題)');
                            buffer.writeln('--------------------------------');
                            for (int i = 0; i < questionRows.length; i++) {
                              final q = questionRows[i];
                              buffer.writeln('${i + 1}. ${q['text']}');
                              final rawOpts = q['options'];
                              List<dynamic> opts = [];
                              if (rawOpts is String) {
                                try {
                                  opts = jsonDecode(rawOpts) as List;
                                } catch (_) {}
                              } else if (rawOpts is List) {
                                opts = rawOpts;
                              }
                              for (int oi = 0; oi < opts.length; oi++) {
                                buffer.writeln(
                                    '   ${String.fromCharCode(65 + oi)}. ${opts[oi]}');
                              }
                              buffer.writeln('');
                            }
                            await Clipboard.setData(
                                ClipboardData(text: buffer.toString()));
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                ..clearSnackBars()
                                ..showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(tr('ql_share_text_copied')),
                                    behavior: SnackBarBehavior.floating,
                                    duration:
                                        const Duration(milliseconds: 1200),
                                  ),
                                );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.text_snippet_rounded,
                              size: 16),
                          label: Text(tr('ql_share_copy_text'),
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openSetDetail({String? subject, int? paperId, required String title}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionSetDetailPage(
          currentUser: widget.currentUser,
          title: title,
          subject: subject,
          paperId: paperId,
          allSubjects: widget.allSubjects,
          subjectChapters: widget.subjectChapters,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _showCreateOptionsBottomSheet(BuildContext context, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: cs.surface,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('ql_create_new'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.purple, size: 24),
                  ),
                  title: Text(tr('ql_ai_import'),
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(tr('ql_ai_import_sub')),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AiUploadPaperPage(
                          currentUser: widget.currentUser,
                          allSubjects: widget.allSubjects,
                          subjectChapters: widget.subjectChapters,
                        ),
                      ),
                    );
                    if (result == true) {
                      _loadData();
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.edit_note_rounded,
                        color: cs.primary, size: 24),
                  ),
                  title: Text(tr('ql_manual_add'),
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(tr('ql_manual_add_sub')),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuestionEditPage(
                          currentUser: widget.currentUser,
                          allSubjects: widget.allSubjects,
                          subjectChapters: widget.subjectChapters,
                        ),
                      ),
                    );
                    if (result == true) {
                      _loadData();
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.library_add_rounded,
                        color: Colors.orange, size: 24),
                  ),
                  title: Text(tr('ql_from_bank'),
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(tr('ql_from_bank_sub')),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaperBuilderPage(
                          currentUser: widget.currentUser,
                        ),
                      ),
                    );
                    if (result == true) {
                      _loadData();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  // Subject Theme Helper
  Map<String, dynamic> _getSubjectStyle(String subject) {
    switch (subject) {
      case '數學':
        return {
          'icon': Icons.calculate_rounded,
          'color': const Color(0xFF4F46E5),
          'bg': const Color(0xFFEEF2FF),
        };
      case '英文':
        return {
          'icon': Icons.translate_rounded,
          'color': const Color(0xFF059669),
          'bg': const Color(0xFFECFDF5),
        };
      case '理化':
      case '自然':
        return {
          'icon': Icons.science_rounded,
          'color': const Color(0xFF0891B2),
          'bg': const Color(0xFFECFEFF),
        };
      case '歷史':
      case '社會':
        return {
          'icon': Icons.auto_stories_rounded,
          'color': const Color(0xFFD97706),
          'bg': const Color(0xFFFFFBEB),
        };
      case '地理':
        return {
          'icon': Icons.public_rounded,
          'color': const Color(0xFF2563EB),
          'bg': const Color(0xFFEFF6FF),
        };
      case '國文':
        return {
          'icon': Icons.history_edu_rounded,
          'color': const Color(0xFFDB2777),
          'bg': const Color(0xFFFDF2F8),
        };
      default:
        return {
          'icon': Icons.menu_book_rounded,
          'color': const Color(0xFF7C3AED),
          'bg': const Color(0xFFF5F3FF),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subjects =
        widget.allSubjects.where((s) => _subjectCounts.containsKey(s)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
                children: [
                  // 1. Header & AI Quick Action
                  _buildHeader(cs),
                  const SizedBox(height: 20),

                  // 2. Section: 快速複習 (錯題複習 & 精選收藏 雙卡)
                  _buildQuickReviewSection(cs),
                  const SizedBox(height: 24),

                  // 3. Section: 我的題本 (Grouped List Style)
                  _buildMyPapersGroupSection(cs),
                  const SizedBox(height: 24),

                  // 4. Section: 學科分類 (Grouped List Style)
                  _buildSubjectsGroupSection(subjects, cs),
                ],
              ),
            ),
    );
  }

  // --- 1. Header ---
  Widget _buildHeader(ColorScheme cs) {
    final displayName = widget.currentUser['display_name'] ??
        widget.currentUser['username'] ??
        tr('profile_learner');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('ql_hello', [displayName.toString()]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tr('ql_total_n', [_totalQuestionCount.toString()]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // AI Scan Quick Button
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => AiUploadPaperPage(
                    currentUser: widget.currentUser,
                    allSubjects: widget.allSubjects,
                    subjectChapters: widget.subjectChapters,
                  ),
                ),
              );
              if (result == true) {
                _loadData();
              }
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 15),
            label: Text(tr('pb_ai_snap'),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. Section: 快速複習 (雙卡片) ---
  Widget _buildQuickReviewSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('ql_quick_review'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // 錯題複習
            Expanded(
              child: _buildReviewCard(
                title: tr('ql_wrong_review'),
                count: tr('ql_n', [_wrongQuestionCount.toString()]),
                icon: Icons.flash_on_rounded,
                iconColor: cs.primary,
                iconBgColor: Colors.white,
                badgeColor: cs.primary,
                cardBgColor: cs.primary.withValues(alpha: 0.08),
                borderColor: cs.primary.withValues(alpha: 0.2),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(tr('ql_wrong_book_review'))),
                        body: WrongQuestionsPage(
                          currentUser: widget.currentUser,
                          embed: true,
                          mode: 0,
                        ),
                      ),
                    ),
                  ).then((_) => _loadData());
                },
              ),
            ),
            const SizedBox(width: 12),
            // 精選收藏
            Expanded(
              child: _buildReviewCard(
                title: tr('ql_fav'),
                count: tr('ql_fav_n', [_favoriteQuestionCount.toString()]),
                icon: Icons.star_rounded,
                iconColor: cs.primary,
                iconBgColor: Colors.white,
                badgeColor: cs.primary,
                cardBgColor: cs.primary.withValues(alpha: 0.08),
                borderColor: cs.primary.withValues(alpha: 0.2),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: Text(tr('ql_fav_title'))),
                        body: WrongQuestionsPage(
                          currentUser: widget.currentUser,
                          embed: true,
                          mode: 1,
                        ),
                      ),
                    ),
                  ).then((_) => _loadData());
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewCard({
    required String title,
    required String count,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required Color badgeColor,
    Color? cardBgColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        count,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: Colors.grey.shade400, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 3. Section: 我的題本 (Grouped List Style) ---
  Widget _buildMyPapersGroupSection(ColorScheme cs) {
    final totalPapers = _userPapers.length + (_customQuestionCount > 0 ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    tr('ql_my_papers'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$totalPapers',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _showCreateOptionsBottomSheet(context, cs),
              icon: Icon(Icons.add_rounded, size: 15, color: cs.primary),
              label: Text(tr('ql_new_paper'),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: cs.primary)),
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_userPapers.isEmpty && _customQuestionCount == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.assignment_outlined,
                    size: 36, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text(
                  tr('ql_no_papers'),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF374151)),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('ql_no_papers_sub'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else
          Container(
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalPapers,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 1,
                  indent: 56,
                  color: Colors.grey.shade100,
                ),
                itemBuilder: (context, index) {
                  if (_customQuestionCount > 0 && index == 0) {
                    // Custom Questions Total Deck Row
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.app_registration_rounded,
                            color: cs.primary, size: 20),
                      ),
                      title: Text(
                        tr('ql_custom_bank'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: Color(0xFF111827)),
                      ),
                      subtitle: Text(
                        tr('ql_custom_bank_sub'),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tr('ql_custom_n', [_customQuestionCount.toString()]),
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded,
                              color: Colors.grey.shade400, size: 18),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuestionSetDetailPage(
                              currentUser: widget.currentUser,
                              title: tr('ql_custom_bank'),
                              isCustomOnly: true,
                              allSubjects: widget.allSubjects,
                              subjectChapters: widget.subjectChapters,
                            ),
                          ),
                        ).then((_) => _loadData());
                      },
                    );
                  }

                  final pIndex = _customQuestionCount > 0 ? index - 1 : index;
                  final paper = _userPapers[pIndex];
                  final pid = int.tryParse(paper['id'].toString()) ?? 0;
                  final name = paper['name'] ?? tr('wq_paper_unnamed');
                  final dateStr =
                      (paper['created_at'] ?? '').toString().split(' ')[0];

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_rounded,
                          color: Colors.orange, size: 20),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: Color(0xFF111827)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      dateStr.isNotEmpty ? tr('ql_created_at', [dateStr.toString()]) : tr('ql_exclusive'),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert,
                              color: Colors.grey.shade400, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (val) {
                            if (val == 'edit') {
                              Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaperBuilderPage(
                                    currentUser: widget.currentUser,
                                    paperId: pid,
                                  ),
                                ),
                              ).then((res) {
                                if (res == true) _loadData();
                              });
                            } else if (val == 'publish') {
                              _publishPaper(pid, name);
                            } else if (val == 'delete') {
                              _deletePaper(pid);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                                value: 'edit', child: Text(tr('ql_edit_paper'))),
                            PopupMenuItem(
                                value: 'publish', child: Text(tr('ql_share_social'))),
                            PopupMenuItem(
                                value: 'delete',
                                child: Text(tr('ql_delete_paper'),
                                    style: TextStyle(color: Colors.redAccent))),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.grey.shade400, size: 18),
                      ],
                    ),
                    onTap: () => _openSetDetail(paperId: pid, title: name),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  // --- 4. Section: 學科分類 (Grouped List Style) ---
  Widget _buildSubjectsGroupSection(List<String> subjects, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('ql_subjects'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 10),
        if (subjects.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(child: Text(tr('ql_no_subjects'))),
          )
        else
          Container(
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subjects.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 1,
                  indent: 56,
                  color: Colors.grey.shade100,
                ),
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  final count = _subjectCounts[subject] ?? 0;
                  final style = _getSubjectStyle(subject);
                  final Color color = style['color'];
                  final Color bg = style['bg'];
                  final IconData icon = style['icon'];

                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Text(
                      trv(subject),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    subtitle: Text(
                      tr('ql_by_unit'),
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tr('ql_count_n', [count.toString()]),
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.grey.shade400, size: 18),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SubjectChaptersPage(
                            currentUser: widget.currentUser,
                            subject: subject,
                            allSubjects: widget.allSubjects,
                            subjectChapters: widget.subjectChapters,
                          ),
                        ),
                      ).then((_) => _loadData());
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
