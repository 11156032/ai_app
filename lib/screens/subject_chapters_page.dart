import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../services/ai_paper_generator_service.dart';
import 'question_set_detail_page.dart';
import 'question_practice_page.dart';
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
  bool _isGeneratingAIPaper = false;
  Map<String, int> _chapterQuestionCounts = {};
  int _totalSubjectQuestions = 0;
  final TextEditingController _aiPromptCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _loadData();
  }

  @override
  void dispose() {
    _aiPromptCtrl.dispose();
    super.dispose();
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

      if (!mounted) return;
      setState(() {
        _chapterQuestionCounts = chapterCounts;
        _totalSubjectQuestions = totalQ;
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

  // 執行 AI 智慧選題出卷
  Future<void> _handleAIPaperGenerate([String? customPrompt]) async {
    final prompt = (customPrompt ?? _aiPromptCtrl.text).trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請輸入或點選你想要的考卷需求，例如「第 1、2 章 基礎題 10 題」'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isGeneratingAIPaper = true);

    try {
      final chapters = widget.subjectChapters[widget.subject] ?? [];
      final spec = await AIPaperGeneratorService.parseUserPrompt(
        subject: widget.subject,
        availableChapters: chapters,
        userPrompt: prompt,
      );

      final questions = await AIPaperGeneratorService.fetchQuestionsForSpec(
        subject: widget.subject,
        spec: spec,
      );

      if (!mounted) return;
      setState(() => _isGeneratingAIPaper = false);

      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${trv(widget.subject)} 題庫目前尚無符合該條件的題目，請嘗試其他關鍵字或章節！'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // 彈出 AI 出卷結果預覽面板
      _showAIPaperResultSheet(spec, questions);
    } catch (e) {
      debugPrint('AI 出卷失敗: $e');
      if (!mounted) return;
      setState(() => _isGeneratingAIPaper = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI 出卷發生異常: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 顯示 AI 組卷完成結果面板
  void _showAIPaperResultSheet(
    AIPaperSpec spec,
    List<Map<String, dynamic>> questions,
  ) {
    final cs = Theme.of(context).colorScheme;

    String diffLabel = '綜合難度';
    if (spec.difficulty == 'easy') diffLabel = '基礎觀念';
    if (spec.difficulty == 'medium') diffLabel = '中等一般';
    if (spec.difficulty == 'hard') diffLabel = '進階攻堅';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 頂部小把手
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

              // 標題與 AI 圖示
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.auto_awesome_rounded,
                        color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spec.title,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'AI 已直接從題庫為你篩選出最匹配的題目',
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 規格標籤
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildSpecChip(Icons.format_list_numbered_rounded,
                      '${questions.length} 題'),
                  _buildSpecChip(Icons.speed_rounded, diffLabel),
                  if (spec.targetChapters.isNotEmpty)
                    _buildSpecChip(
                        Icons.folder_rounded, spec.targetChapters.join('、'))
                  else
                    _buildSpecChip(Icons.all_inclusive_rounded, '全冊精選'),
                ],
              ),
              const SizedBox(height: 18),

              // 抽題預覽清單 (前 3 題)
              const Text(
                '題目預覽：',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < questions.length.clamp(0, 3); i++) ...[
                      if (i > 0)
                        const Divider(
                            height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        leading: CircleAvatar(
                          radius: 11,
                          backgroundColor: cs.primary.withValues(alpha: 0.15),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          questions[i]['question']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: Color(0xFF1E293B)),
                        ),
                        trailing: Text(
                          questions[i]['difficulty']?.toString() ?? '',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 雙功能按鈕：立即測驗 + 儲存至我的題本
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuestionPracticePage(
                              questions: questions,
                              title: spec.title,
                              currentUser: widget.currentUser,
                              isPaper: true,
                              saveResult: true,
                              subject: widget.subject,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 20),
                      label: const Text(
                        '立即測驗',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uid = (widget.currentUser['id'] ??
                                widget.currentUser['user_id'] ??
                                'u1')
                            .toString();
                        final qIds = questions
                            .map((q) => q['id'] as int)
                            .where((id) => id > 0)
                            .toList();

                        await DatabaseHelper.instance
                            .createPaper(uid, spec.title, qIds);
                        if (!mounted) return;
                        if (ctx.mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已將「${spec.title}」儲存至題庫首頁的「我的題本」！'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                      label: const Text(
                        '存為試卷',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
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
              '${trv(widget.subject)} 題庫',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 60),
                children: [
                  // 1. 學科概況與全部題目
                  _buildSubjectSummaryBar(context, cs, subjectIcon),
                  const SizedBox(height: 20),

                  // 2. 章節目錄列表（主要核心）
                  _buildSectionHeader(
                    title: '章節主題',
                    subtitle: '點選主題直接練習或檢視題目',
                    badgeText: '${chapters.length} 個主題',
                    icon: Icons.format_list_bulleted_rounded,
                    cs: cs,
                  ),
                  const SizedBox(height: 12),
                  if (chapters.isEmpty)
                    _buildEmptyChaptersCard(cs)
                  else
                    _buildChaptersList(context, chapters, cs),

                  const SizedBox(height: 24),

                  // 3. AI 智慧抽題出卷（純粹俐落的 AI 組卷功能）
                  _buildSectionHeader(
                    title: 'AI 智慧組卷',
                    subtitle: '輸入想要練習的主題與條件，AI 直接從題庫抽題',
                    badgeText: 'AI 抽題',
                    icon: Icons.auto_awesome_rounded,
                    cs: cs,
                  ),
                  const SizedBox(height: 12),
                  _buildAIPaperCard(context, cs, chapters),
                ],
              ),
            ),
    );
  }

  // 1. 學科總覽摘要卡片
  Widget _buildSubjectSummaryBar(
    BuildContext context,
    ColorScheme cs,
    IconData subjectIcon,
  ) {
    return Container(
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
            child: Icon(subjectIcon, size: 24, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trv(widget.subject)} 題庫總題數',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '累計收錄 $_totalSubjectQuestions 題',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _openAllSubjectQuestions(context),
            icon: const Icon(Icons.format_list_bulleted_rounded, size: 15),
            label: const Text('全部題目',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // 2. 章節目錄清單列表（清晰條列目錄）
  Widget _buildChaptersList(
    BuildContext context,
    List<String> chapters,
    ColorScheme cs,
  ) {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: chapters.length,
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            thickness: 1,
            indent: 56,
            endIndent: 16,
            color: Color(0xFFF1F5F9),
          ),
          itemBuilder: (context, index) {
            final chapter = chapters[index];
            final count = _chapterQuestionCounts[chapter] ?? 0;

            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: cs.primary,
                  size: 20,
                ),
              ),
              title: Text(
                chapter,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count 題',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ],
              ),
              onTap: () => _openChapter(context, chapter),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyChaptersCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.folder_open_rounded,
                size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(tr('chapters_empty'),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }

  // 3. AI 智慧選題出卷卡片
  Widget _buildAIPaperCard(
    BuildContext context,
    ColorScheme cs,
    List<String> chapters,
  ) {
    final promptSuggestions = <String>[
      '隨機綜合 15 題',
      '基礎觀念 10 題',
      '進階攻堅 10 題',
      if (chapters.isNotEmpty) '${chapters.first} 觀念 10 題',
      if (chapters.length > 1) '${chapters[1]} 10 題',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
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
                child:
                    Icon(Icons.psychology_rounded, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI 智慧抽題出卷',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '輸入測驗主題、難度或題數，AI 自動挑題組卷',
                      style:
                          TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 快捷推薦標籤
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: promptSuggestions.map((suggestion) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      suggestion,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    backgroundColor: cs.primary.withValues(alpha: 0.06),
                    side: BorderSide(color: cs.primary.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    onPressed: () {
                      _aiPromptCtrl.text = suggestion;
                      _handleAIPaperGenerate(suggestion);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // 輸入框與生成按鈕
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _aiPromptCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: '例：第 1、2 章 基礎觀念 10 題...',
                      hintStyle:
                          TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (val) => _handleAIPaperGenerate(val),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isGeneratingAIPaper
                    ? null
                    : () => _handleAIPaperGenerate(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isGeneratingAIPaper
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
                        children: [
                          Icon(Icons.bolt_rounded,
                              size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text('出卷',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white)),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 區塊標題元件
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
