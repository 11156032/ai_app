import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import 'question_set_detail_page.dart';
import 'paper_builder_page.dart';
import 'question_practice_page.dart';
import 'ai_upload_paper_page.dart';
import 'main_screen.dart';
import '../services/app_locale_service.dart';

class SubjectChaptersPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final String subject;
  final List<String> allSubjects;
  final Map<String, List<String>> subjectChapters;

  const SubjectChaptersPage({
    super.key,
    required this.currentUser,
    required this.subject,
    required this.allSubjects,
    required this.subjectChapters,
  });

  @override
  State<SubjectChaptersPage> createState() => _SubjectChaptersPageState();
}

class _SubjectChaptersPageState extends State<SubjectChaptersPage> {
  bool _isLoading = true;
  Map<String, int> _chapterQuestionCounts = {};
  int _totalSubjectQuestions = 0;
  List<Map<String, dynamic>> _relatedPapers = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. 章節題目數
      final chapterCounts = <String, int>{};
      final rows = await db.rawQuery('''
        SELECT t.name AS chapter, COUNT(q.id) AS count
        FROM questions q
        JOIN question_tag_map qm ON q.id = qm.question_id
        JOIN tags t ON t.id = qm.tag_id
        WHERE q.subject = ? AND q.is_public = 1
        GROUP BY t.name
      ''', [widget.subject]);

      for (final r in rows) {
        final ch = r['chapter']?.toString() ?? '';
        final cnt = int.tryParse(r['count']?.toString() ?? '0') ?? 0;
        chapterCounts[ch] = cnt;
      }

      // 2. 本學科總題目數
      final totalRows = await db.rawQuery('''
        SELECT COUNT(id) as count FROM questions
        WHERE subject = ? AND is_public = 1
      ''', [widget.subject]);
      final totalQ =
          int.tryParse(totalRows.first['count']?.toString() ?? '0') ?? 0;

      // 3. 本學科相關自訂試卷
      final uid = (widget.currentUser['id'] ??
              widget.currentUser['user_id'] ??
              'u1')
          .toString();
      final allUserPapers = await DatabaseHelper.instance.getPapersForUser(uid);
      final related = <Map<String, dynamic>>[];
      for (final p in allUserPapers) {
        final pName = p['name']?.toString() ?? '';
        if (pName.contains(widget.subject) ||
            pName.contains(trv(widget.subject))) {
          related.add(p);
        }
      }

      if (!mounted) return;
      setState(() {
        _chapterQuestionCounts = chapterCounts;
        _totalSubjectQuestions = totalQ;
        _relatedPapers = related;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('載入學科題庫資料失敗: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  IconData _getSubjectIcon(String subject) {
    switch (subject) {
      case '數學':
        return Icons.calculate_rounded;
      case '英文':
        return Icons.translate_rounded;
      case '理化':
      case '自然':
        return Icons.science_rounded;
      case '歷史':
      case '社會':
        return Icons.auto_stories_rounded;
      case '地理':
        return Icons.public_rounded;
      case '國文':
        return Icons.history_edu_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  // 啟動全科隨機混合練習
  Future<void> _startRandomPractice({
    int count = 20,
    String difficulty = 'all',
    String? customTitle,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      String whereClause = 'subject = ? AND is_public = 1';
      List<dynamic> whereArgs = [widget.subject];

      if (difficulty == 'easy_medium') {
        whereClause += " AND difficulty IN ('易', '中', '簡單', '一般')";
      } else if (difficulty == 'hard') {
        whereClause += " AND difficulty IN ('難', '進階', '困難')";
      }

      final rows = await db.rawQuery('''
        SELECT q.*, u.display_name as author
        FROM questions q
        LEFT JOIN users u ON q.user_id = u.id
        WHERE $whereClause
        ORDER BY RANDOM()
        LIMIT ?
      ''', [...whereArgs, count]);

      if (rows.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${trv(widget.subject)} 題庫目前題目不足，請先透過 AI 拍照匯入或新增題目！'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final mapped = rows.map((row) {
        final id = int.tryParse(row['id'].toString()) ?? -1;
        final rawOptions = row['options'];
        final decodedOptions = rawOptions is String
            ? jsonDecode(rawOptions) as List<dynamic>
            : (rawOptions as List<dynamic>? ?? []);

        return {
          'id': id,
          'subject': row['subject'] ?? widget.subject,
          'chapter': '全科混合',
          'difficulty': row['difficulty'] ?? '中',
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
      final title = customTitle ?? '${trv(widget.subject)} 隨機混合特訓 (${mapped.length}題)';
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuestionPracticePage(
            questions: mapped,
            title: title,
            currentUser: widget.currentUser,
            isPaper: true,
            saveResult: true,
            subject: widget.subject,
          ),
        ),
      );
    } catch (e) {
      debugPrint('啟動隨機測驗失敗: $e');
    }
  }

  // 選擇題數的彈窗（統一使用全站主色 cs.primary，維持風格連貫）
  void _showRandomQuizDialog(BuildContext context, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.bolt_rounded, color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${trv(widget.subject)} 全科混合練習',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '跨章節隨機抽取，擺脫單元思維，模擬真實大考',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildQuizModeTile(
                ctx,
                icon: Icons.flash_on_rounded,
                cs: cs,
                title: '10 題 快速手感練習',
                subtitle: '約 10 分鐘 • 適合零碎時間隨時練手',
                onTap: () {
                  Navigator.pop(ctx);
                  _startRandomPractice(
                    count: 10,
                    customTitle: '${trv(widget.subject)} 10題快速練',
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildQuizModeTile(
                ctx,
                icon: Icons.assignment_turned_in_rounded,
                cs: cs,
                title: '20 題 標準模擬考',
                subtitle: '約 25 分鐘 • 完整綜合診斷與考點覆蓋',
                badgeText: '推薦',
                onTap: () {
                  Navigator.pop(ctx);
                  _startRandomPractice(
                    count: 20,
                    customTitle: '${trv(widget.subject)} 20題標準模擬考',
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildQuizModeTile(
                ctx,
                icon: Icons.all_inclusive_rounded,
                cs: cs,
                title: '全科全量題庫挑戰',
                subtitle: '包含本學科全部題目 • 考前極限衝刺',
                onTap: () {
                  Navigator.pop(ctx);
                  _openAllSubjectQuestions(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizModeTile(
    BuildContext context, {
    required IconData icon,
    required ColorScheme cs,
    required String title,
    required String subtitle,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: cs.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  void _openAllSubjectQuestions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionSetDetailPage(
          currentUser: widget.currentUser,
          title: '${trv(widget.subject)} 全科題庫總覽',
          subject: widget.subject,
          allSubjects: widget.allSubjects,
          subjectChapters: widget.subjectChapters,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _openChapter(BuildContext context, String chapter) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionSetDetailPage(
          currentUser: widget.currentUser,
          title: chapter,
          subject: widget.subject,
          chapter: chapter,
          allSubjects: widget.allSubjects,
          subjectChapters: widget.subjectChapters,
        ),
      ),
    ).then((_) => _loadData());
  }

  void _openPaper(BuildContext context, int paperId, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionSetDetailPage(
          currentUser: widget.currentUser,
          title: title,
          paperId: paperId,
          allSubjects: widget.allSubjects,
          subjectChapters: widget.subjectChapters,
        ),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chapters = widget.subjectChapters[widget.subject] ?? [];
    final IconData subjectIcon = _getSubjectIcon(widget.subject);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(subjectIcon, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              '${trv(widget.subject)} 題庫中心',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.home_rounded, size: 20, color: Colors.white),
              tooltip: tr('qs_back_to_bank'),
              onPressed: () {
                MainScreen.tabSwitchNotifier.value = 1;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 60),
                children: [
                  // 1. 頂部 Hero 橫幅（隨機特訓一鍵直達，風格與考卷一致）
                  _buildSubjectHeroBanner(
                    context,
                    cs,
                    subjectIcon,
                  ),
                  const SizedBox(height: 22),

                  // 2. 精選主題考卷（以全站統一風格呈現）
                  _buildSectionHeader(
                    title: '學科精選試卷',
                    subtitle: '高品質綜合題本，全真模擬大考節奏',
                    badgeText: '推薦',
                    icon: Icons.assignment_rounded,
                    cs: cs,
                  ),
                  const SizedBox(height: 12),
                  _buildCuratedPapers(context, cs),

                  const SizedBox(height: 24),

                  // 3. 我的自訂試卷與拍題（個人私有考卷）
                  _buildSectionHeader(
                    title: '我的自訂試卷',
                    subtitle: '自己拍照匯入或組裝的考卷',
                    badgeText: '${_relatedPapers.length}',
                    icon: Icons.folder_special_rounded,
                    cs: cs,
                    action: ElevatedButton.icon(
                      onPressed: () async {
                        final res = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaperBuilderPage(
                              currentUser: widget.currentUser,
                            ),
                          ),
                        );
                        if (res == true) _loadData();
                      },
                      icon: const Icon(Icons.add_rounded, size: 15, color: Colors.white),
                      label: const Text('組新卷', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_relatedPapers.isEmpty)
                    _buildEmptyUserPapersCard(context, cs)
                  else
                    _buildUserPapersList(context, cs),

                  const SizedBox(height: 24),

                  // 4. 章節專項補強（折疊收納，不搶版面）
                  _buildChaptersAccordion(
                    context,
                    chapters,
                    cs,
                  ),
                ],
              ),
            ),
    );
  }

  // 1. 頂部學科 Hero 橫幅
  Widget _buildSubjectHeroBanner(
    BuildContext context,
    ColorScheme cs,
    IconData subjectIcon,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
                ),
                child: Icon(subjectIcon, size: 28, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${trv(widget.subject)} 綜合題庫',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '累計收錄 $_totalSubjectQuestions 題 • 支援隨機抽題與全冊混合練',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 雙核心行動按鈕（全科隨機特訓 + 全科題目池，與考卷按鈕一體同色）
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () => _showRandomQuizDialog(context, cs),
                  icon: const Icon(Icons.bolt_rounded, size: 20, color: Colors.white),
                  label: const Text(
                    '全科隨機特訓（混合練習）',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shadowColor: cs.primary.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => _openAllSubjectQuestions(context),
                  icon: const Icon(Icons.format_list_bulleted_rounded, size: 16),
                  label: const Text(
                    '瀏覽題庫',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. 精選主題考卷清單（全站統一主色）
  Widget _buildCuratedPapers(BuildContext context, ColorScheme cs) {
    return Column(
      children: [
        _buildPaperCard(
          context: context,
          cs: cs,
          title: '${trv(widget.subject)} 全冊綜合大考模擬卷',
          subtitle: '跨章節隨機混合 • 20 題 • 預估 25 分鐘',
          tags: const ['全冊混合', '大考實戰'],
          icon: Icons.workspace_premium_rounded,
          onStart: () => _startRandomPractice(
            count: 20,
            customTitle: '${trv(widget.subject)} 全冊綜合大考模擬卷',
          ),
        ),
        const SizedBox(height: 10),
        _buildPaperCard(
          context: context,
          cs: cs,
          title: '${trv(widget.subject)} 基礎觀念精練卷',
          subtitle: '快速複習核心概念 • 15 題 • 預估 15 分鐘',
          tags: const ['基礎鞏固', '觀念快掃'],
          icon: Icons.checklist_rounded,
          onStart: () => _startRandomPractice(
            count: 15,
            difficulty: 'easy_medium',
            customTitle: '${trv(widget.subject)} 基礎觀念精練卷',
          ),
        ),
        const SizedBox(height: 10),
        _buildPaperCard(
          context: context,
          cs: cs,
          title: '${trv(widget.subject)} 易錯拔高突破卷',
          subtitle: '進階攻堅易錯考點 • 10 題 • 預估 15 分鐘',
          tags: const ['進階挑戰', '滿分衝刺'],
          icon: Icons.local_fire_department_rounded,
          onStart: () => _startRandomPractice(
            count: 10,
            difficulty: 'hard',
            customTitle: '${trv(widget.subject)} 易錯拔高突破卷',
          ),
        ),
      ],
    );
  }

  Widget _buildPaperCard({
    required BuildContext context,
    required ColorScheme cs,
    required String title,
    required String subtitle,
    required List<String> tags,
    required IconData icon,
    required VoidCallback onStart,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (final tag in tags) ...[
                      Container(
                        margin: const EdgeInsets.only(right: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '測驗',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 2),
                Icon(Icons.play_arrow_rounded, size: 15),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. 使用者自訂試卷清單（顏色全站一致）
  Widget _buildUserPapersList(BuildContext context, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _relatedPapers.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            thickness: 1,
            indent: 54,
            color: Colors.grey.shade100,
          ),
          itemBuilder: (context, index) {
            final paper = _relatedPapers[index];
            final pid = int.tryParse(paper['id']?.toString() ?? '0') ?? 0;
            final name = paper['name']?.toString() ?? '自訂試卷';
            final count = (paper['question_count'] as num?)?.toInt() ?? 0;
            final dateStr = (paper['created_at'] ?? '').toString().split(' ')[0];

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
                ),
                child: Icon(Icons.assignment_rounded, color: cs.primary, size: 18),
              ),
              title: Text(
                name,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                dateStr.isNotEmpty ? '$dateStr • $count 題' : '$count 題試卷',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
              trailing: ElevatedButton(
                onPressed: () => _openPaper(context, pid, name),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('寫卷', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              onTap: () => _openPaper(context, pid, name),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyUserPapersCard(BuildContext context, ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.note_add_outlined, size: 32, color: Colors.grey.shade400),
          const SizedBox(height: 6),
          Text(
            '尚未有針對 ${trv(widget.subject)} 的自訂試卷',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '可用 AI 拍照把學校考卷匯入為專屬題本，或手動自由挑題組卷',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final res = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiUploadPaperPage(
                        currentUser: widget.currentUser,
                        allSubjects: widget.allSubjects,
                        subjectChapters: widget.subjectChapters,
                      ),
                    ),
                  );
                  if (res == true) _loadData();
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                label: const Text('AI 拍照匯入', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.primary,
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final res = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaperBuilderPage(
                        currentUser: widget.currentUser,
                      ),
                    ),
                  );
                  if (res == true) _loadData();
                },
                icon: const Icon(Icons.tune_rounded, size: 14),
                label: const Text('自選組卷', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. 章節專項補強（折疊收納）
  Widget _buildChaptersAccordion(
    BuildContext context,
    List<String> chapters,
    ColorScheme cs,
  ) {
    if (chapters.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.tune_rounded, color: cs.primary, size: 18),
          ),
          title: const Text(
            '單元章節專項練習',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          subtitle: Text(
            '需要針對特定單元弱點加強時點開 (${chapters.length} 個單元)',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          children: [
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: chapters.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: Color(0xFFF8FAFC),
              ),
              itemBuilder: (ctx, index) {
                final chapter = chapters[index];
                final count = _chapterQuestionCounts[chapter] ?? 0;

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  title: Text(
                    chapter,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$count 題',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                    ],
                  ),
                  onTap: () => _openChapter(context, chapter),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 區塊標題（統一全站品牌主色）
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required ColorScheme cs,
    Widget? action,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
        if (action != null) action,
      ],
    );
  }
}
