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
  int _selectedTab = 0; // 0: 挑題庫, 1: 自訂題本, 2: 錯題本
  final GlobalKey<WrongQuestionsPageState> _wrongQuestionsKey = GlobalKey<WrongQuestionsPageState>();

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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
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
                  fontSize: 15,
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
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectBankContent(
      BuildContext context, List<String> subjects, ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          children: [
            Icon(Icons.tips_and_updates_outlined, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              '請選擇科目，再依章節挑選題目',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (subjects.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text('目前沒有科目題目'),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.92, // 調整寬高比以容納多行文字，防止底部溢出
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
    );
  }

  Widget _buildCustomPaperContent(BuildContext context, ColorScheme cs) {
    if (_userPapers.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                Icon(
                  Icons.assignment_outlined,
                  size: 80,
                  color: cs.primary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  '尚無自訂題本',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '您可以將不同的題目打包成專屬考卷',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
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
                  label: const Text('建立第一份考卷'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '我的自訂考卷',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            Text(
              '共 ${_userPapers.length} 份',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.92, // 調整寬高比以容納多行文字，防止底部溢出
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
        const SizedBox(height: 80), // 為 FloatingActionButton 留空
      ],
    );
  }

  Widget _buildTabItem(int index, String title, IconData icon, ColorScheme cs) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedTab != index) {
            setState(() {
              _selectedTab = index;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
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
        title: const Text('題庫功能'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          if (_selectedTab == 2) ...[
            IconButton(
              tooltip: '重新整理',
              onPressed: () => _wrongQuestionsKey.currentState?.loadWrongQuestions(),
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              tooltip: '清空錯題本',
              onPressed: () => _wrongQuestionsKey.currentState?.clearAll(),
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
          ],
        ],
      ),
      body: _isLoading || _isLoadingPapers
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 頂部切換按鈕
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      _buildTabItem(0, '挑題庫', Icons.folder_open_rounded, cs),
                      _buildTabItem(1, '自訂題本', Icons.assignment_outlined, cs),
                      _buildTabItem(2, '錯題本', Icons.error_outline_rounded, cs),
                    ],
                  ),
                ),
                // 內容區域
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      if (_selectedTab == 2) {
                        await _wrongQuestionsKey.currentState?.loadWrongQuestions();
                      } else {
                        await _loadData();
                      }
                    },
                    child: _selectedTab == 0
                        ? _buildSubjectBankContent(context, subjects, cs)
                        : _selectedTab == 1
                            ? _buildCustomPaperContent(context, cs)
                            : WrongQuestionsPage(
                                key: _wrongQuestionsKey,
                                currentUser: widget.currentUser,
                                embed: true,
                              ),
                  ),
                ),
              ],
            ),
      floatingActionButton: _selectedTab == 1 && _userPapers.isNotEmpty
          ? FloatingActionButton.extended(
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
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}
