import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'question_set_detail_page.dart';
import 'paper_builder_page.dart';
import 'wrong_questions_page.dart';
import 'subject_chapters_page.dart';
import 'question_edit_page.dart';

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
  int _customQuestionCount = 0;
  int _selectedTab = 0; // 0: 挑題庫, 1: 自訂題本, 2: 錯題本, 3: 我的收藏
  final GlobalKey<WrongQuestionsPageState> _wrongQuestionsKey = GlobalKey<WrongQuestionsPageState>();
  final GlobalKey<WrongQuestionsPageState> _favoritesKey = GlobalKey<WrongQuestionsPageState>();

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

      final uid = widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
      final customRows = await db.rawQuery('''
        SELECT COUNT(id) as count
        FROM questions
        WHERE user_id = ? AND is_public = 0
      ''', [uid.toString()]);
      final customCount = int.tryParse(customRows.first['count']?.toString() ?? '0') ?? 0;
      
      if (!mounted) return;
      setState(() {
        _subjectCounts = counts;
        _customQuestionCount = customCount;
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
            Text('雲端發佈功能', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          '雲端發佈功能開發中！\n未來版本將支援一鍵備份同步，並將您的精選題本分享給社群其他使用者練習！',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('期待！', style: TextStyle(fontWeight: FontWeight.bold)),
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
    ).then((_) {
      // 重新載入以防有題目被刪除或收藏狀態變更
      _loadData();
      _wrongQuestionsKey.currentState?.loadWrongQuestions();
      _favoritesKey.currentState?.loadWrongQuestions();
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
    VoidCallback? onPublish,
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
                  if (onEdit != null || onDelete != null || onPublish != null)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                      onSelected: (val) {
                        if (val == 'edit' && onEdit != null) onEdit();
                        if (val == 'delete' && onDelete != null) onDelete();
                        if (val == 'publish' && onPublish != null) onPublish();
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(value: 'edit', child: Text('編輯考卷')),
                        if (onPublish != null)
                          const PopupMenuItem(value: 'publish', child: Text('發佈至公共題庫')),
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
                  ).then((_) {
                    _loadData();
                    _wrongQuestionsKey.currentState?.loadWrongQuestions();
                    _favoritesKey.currentState?.loadWrongQuestions();
                  });
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildCustomPaperContent(BuildContext context, ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          '我的自訂內容',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
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
          itemCount: _userPapers.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildFolderCard(
                title: '自訂題目',
                subtitle: '共 $_customQuestionCount 題',
                icon: Icons.app_registration_rounded,
                color: cs.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuestionSetDetailPage(
                        currentUser: widget.currentUser,
                        title: '自訂題目',
                        isCustomOnly: true,
                        allSubjects: widget.allSubjects,
                        subjectChapters: widget.subjectChapters,
                      ),
                    ),
                  ).then((_) {
                    _loadData();
                    _wrongQuestionsKey.currentState?.loadWrongQuestions();
                    _favoritesKey.currentState?.loadWrongQuestions();
                  });
                },
              );
            }

            final p = _userPapers[index - 1];
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
              onPublish: () => _publishPaper(pid, name),
            );
          },
        ),
        if (_userPapers.isEmpty) ...[
          const SizedBox(height: 30),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 48,
                  color: cs.primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  '尚無自訂考卷',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '點擊右下角按鈕或下方連結建立考卷',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
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
                  label: const Text('建立自訂考卷'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            // 每次切換分頁時，如果切換到錯題本或我的收藏，自動重新載入最新資料，避免畫面快取沒有更新
            if (index == 2) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _wrongQuestionsKey.currentState?.loadWrongQuestions();
              });
            } else if (index == 3) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _favoritesKey.currentState?.loadWrongQuestions();
              });
            }
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
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
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

  void _showAddCustomContentBottomSheet(BuildContext context, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: cs.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '新增自訂內容',
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
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.post_add_rounded, color: cs.primary, size: 24),
                  ),
                  title: const Text('新增自訂題目', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('撰寫全新的自訂題目、選項與解析'),
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
                const SizedBox(height: 12),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.assignment_rounded, color: Colors.orange, size: 24),
                  ),
                  title: const Text('建立自訂考卷', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('從題庫中挑選題目組裝成專屬考卷'),
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
                      _loadUserPapers();
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subjects = widget.allSubjects.where((s) => _subjectCounts.containsKey(s)).toList();

    return Scaffold(
      body: _isLoading || _isLoadingPapers
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
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
                      _buildTabItem(3, '我的收藏', Icons.star_rounded, cs),
                    ],
                  ),
                ),
                // 內容區域
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      if (_selectedTab == 2) {
                        await _wrongQuestionsKey.currentState?.loadWrongQuestions();
                      } else if (_selectedTab == 3) {
                        await _favoritesKey.currentState?.loadWrongQuestions();
                      } else {
                        await _loadData();
                      }
                    },
                    child: _selectedTab == 0
                        ? _buildSubjectBankContent(context, subjects, cs)
                        : _selectedTab == 1
                            ? _buildCustomPaperContent(context, cs)
                            : _selectedTab == 2
                                ? WrongQuestionsPage(
                                    key: _wrongQuestionsKey,
                                    currentUser: widget.currentUser,
                                    embed: true,
                                    mode: 0,
                                  )
                                : WrongQuestionsPage(
                                    key: _favoritesKey,
                                    currentUser: widget.currentUser,
                                    embed: true,
                                    mode: 1,
                                  ),
                  ),
                ),
              ],
            ),
          ),
      floatingActionButton: _selectedTab == 1
          ? FloatingActionButton.extended(
              heroTag: 'custom_add_fab',
              onPressed: () => _showAddCustomContentBottomSheet(context, cs),
              icon: const Icon(Icons.add),
              label: const Text('新增'),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            )
          : null,
    );
  }
}
