import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'question_set_detail_page.dart';
import 'paper_builder_page.dart';
import 'wrong_questions_page.dart';
import 'subject_chapters_page.dart';
import 'question_edit_page.dart';
import 'ai_upload_paper_page.dart';

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
      final uid = (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1').toString();

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
      final customCount = int.tryParse(customRows.first['count']?.toString() ?? '0') ?? 0;

      // 4. Load Wrong Questions Count
      final wrongRows = await db.rawQuery('''
        SELECT COUNT(id) as count
        FROM wrong_questions
        WHERE user_id = ?
      ''', [uid]);
      final wrongCount = int.tryParse(wrongRows.first['count']?.toString() ?? '0') ?? 0;

      // 5. Load Favorite Questions Count
      final favRows = await db.rawQuery('''
        SELECT COUNT(id) as count
        FROM questions
        WHERE bookmarked = 1
      ''');
      final favCount = int.tryParse(favRows.first['count']?.toString() ?? '0') ?? 0;

      // 6. Load Total Questions
      final totalQRows = await db.rawQuery('SELECT COUNT(id) as count FROM questions');
      final totalQ = int.tryParse(totalQRows.first['count']?.toString() ?? '0') ?? 0;

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
        title: const Text('刪除題本'),
        content: const Text('確定要刪除這份自訂題本嗎？裡面的題目仍會保存在您的題庫中。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確認刪除', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await DatabaseHelper.instance.deletePaper(id);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除題本')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('刪除失敗')));
    }
  }

  Future<void> _publishPaper(int paperId, String paperName) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('雲端分享功能', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          '社群題本分享功能開發中！\n未來版本將支援一鍵將您的精選題本分享給同儕或群組同學共同練習！',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好的', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '建立新內容',
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
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.purple, size: 24),
                  ),
                  title: const Text('AI 智慧拍考卷匯入', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('上傳 PDF 或照片，AI 自動辨識並建立題本'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    child: Icon(Icons.edit_note_rounded, color: cs.primary, size: 24),
                  ),
                  title: const Text('手動新增題目', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('撰寫全新題目、選項與解析'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    child: const Icon(Icons.library_add_rounded, color: Colors.orange, size: 24),
                  ),
                  title: const Text('從題庫挑選組卷', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('從現有題目中自由勾選組合題本'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    final subjects = widget.allSubjects.where((s) => _subjectCounts.containsKey(s)).toList();

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
        '學習者';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '你好，$displayName 👋',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '共收錄 $_totalQuestionCount 題 · 隨時開啟高效測驗',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('AI 拍考卷', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        const Text(
          '快速複習',
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
                title: '錯題複習',
                count: '$_wrongQuestionCount 題',
                icon: Icons.flash_on_rounded,
                iconColor: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEF2F2),
                badgeColor: const Color(0xFFEF4444),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('錯題本複習')),
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
                title: '精選收藏',
                count: '$_favoriteQuestionCount 題',
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFFFBEB),
                badgeColor: const Color(0xFFF59E0B),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('精選收藏題目')),
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
    required Color bgColor,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Container(
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
                    color: bgColor,
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
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 18),
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
            Row(
              children: [
                const Text(
                  '我的題本',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$totalPapers',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => _showCreateOptionsBottomSheet(context, cs),
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text('新增題本', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: TextButton.styleFrom(
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
                Icon(Icons.assignment_outlined, size: 36, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                const Text(
                  '尚未建立任何題本',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 2),
                Text(
                  '拍考卷或自訂題目，一鍵生成專屬題本！',
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.app_registration_rounded, color: cs.primary, size: 20),
                      ),
                      title: const Text(
                        '自訂題目總庫',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF111827)),
                      ),
                      subtitle: Text(
                        '所有自建題目精選',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$_customQuestionCount 題',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: cs.primary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 18),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuestionSetDetailPage(
                              currentUser: widget.currentUser,
                              title: '自訂題目總庫',
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
                  final name = paper['name'] ?? '未命名題本';
                  final dateStr = (paper['created_at'] ?? '').toString().split(' ')[0];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_rounded, color: Colors.orange, size: 20),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF111827)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      dateStr.isNotEmpty ? '建立於 $dateStr' : '專屬練習題本',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Colors.grey.shade400, size: 18),
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
                            const PopupMenuItem(value: 'edit', child: Text('編輯題本')),
                            const PopupMenuItem(value: 'publish', child: Text('分享至社群')),
                            const PopupMenuItem(value: 'delete', child: Text('刪除題本', style: TextStyle(color: Colors.redAccent))),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 18),
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
        const Text(
          '學科分類',
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
            child: const Center(child: Text('目前尚無科目題庫')),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Text(
                      subject,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    subtitle: Text(
                      '按單元循序漸進練習',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$count 題',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 18),
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
