import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'question_set_detail_page.dart';
import 'paper_builder_page.dart';
import 'wrong_questions_page.dart';
import 'subject_chapters_page.dart';

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
  bool _isLoadingPapers = true;
  List<Map<String, dynamic>> _userPapers = [];
  Map<String, int> _subjectCounts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadSubjects(),
      _loadUserPapers(),
    ]);
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

  Future<void> _loadSubjects() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT subject, COUNT(id) as count
        FROM questions
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
      
      if (!mounted) return;
      setState(() {
        _subjectCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('載入科目失敗: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePaper(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除考卷'),
        content: const Text('確定要刪除這份考卷嗎？'),
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

    if (confirm != true) return;

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
    ).then((_) {
      // 重新載入以防有題目被刪除
      _loadData();
    });
  }

  Widget _buildFolderCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final cs = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 32),
                  ),
                  if (onEdit != null || onDelete != null)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                      onSelected: (val) {
                        if (val == 'edit' && onEdit != null) onEdit();
                        if (val == 'delete' && onDelete != null) onDelete();
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(value: 'edit', child: Text('編輯考卷')),
                        if (onDelete != null)
                          const PopupMenuItem(value: 'delete', child: Text('刪除考卷', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
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
    final subjects = widget.allSubjects.where((s) => _subjectCounts.containsKey(s)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('題庫分類'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          IconButton(
            tooltip: '錯題本',
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => WrongQuestionsPage(currentUser: widget.currentUser)),
              );
              if (result == true) _loadData();
            },
            icon: const Icon(Icons.error_outline_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading || _isLoadingPapers
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // 我的考卷區塊
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '自訂題本 (我的考卷)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaperBuilderPage(
                                currentUser: widget.currentUser,
                              ),
                            ),
                          );
                          if (result == true) await _loadUserPapers();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('新增考卷'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_userPapers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text('尚無自訂題本，點擊右上角新增。', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _userPapers.length,
                      itemBuilder: (context, index) {
                        final p = _userPapers[index];
                        final pid = int.tryParse(p['id'].toString()) ?? 0;
                        final name = p['name'] ?? '未命名考卷';
                        return _buildFolderCard(
                          title: name,
                          subtitle: '建立於 ${p['created_at'].toString().split(' ')[0]}',
                          icon: Icons.assignment_rounded,
                          color: Colors.orange,
                          onTap: () => _openSetDetail(paperId: pid, title: name),
                          onEdit: () async {
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaperBuilderPage(
                                  currentUser: widget.currentUser,
                                  paperId: pid,
                                ),
                              ),
                            );
                            if (result == true) await _loadUserPapers();
                          },
                          onDelete: () => _deletePaper(pid),
                        );
                      },
                    ),

                  const SizedBox(height: 32),
                  // 科目題庫區塊
                  Text(
                    '科目題庫',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (subjects.isEmpty)
                    const Center(child: Text('目前沒有科目題目'))
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: subjects.length,
                      itemBuilder: (context, index) {
                        final subject = subjects[index];
                        final count = _subjectCounts[subject] ?? 0;
                        return _buildFolderCard(
                          title: subject,
                          subtitle: '共 $count 題',
                          icon: Icons.folder_rounded,
                          color: Colors.blue,
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
                ],
              ),
      ),
    );
  }
}
