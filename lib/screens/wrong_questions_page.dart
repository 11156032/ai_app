import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'dart:convert';
import '../database/database_helper.dart';
import '../services/notebook_helper.dart';
import '../widgets/tour_overlay.dart';
import 'question_practice_page.dart';

class WrongQuestionsPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final bool embed;
  final int mode; // 0: 我的錯題, 1: 我的收藏

  const WrongQuestionsPage({
    super.key,
    required this.currentUser,
    this.embed = false,
    this.mode = 0,
  });

  @override
  State<WrongQuestionsPage> createState() => WrongQuestionsPageState();
}

class WrongQuestionsPageState extends State<WrongQuestionsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows =
      []; // wrong questions or favorites merged in-memory
  final Set<int> _selected = {};
  bool _isSelectionMode = false; // 新增多選模式狀態

  late int _currentMode;

  // Filtering & Sorting State
  String _selectedSubject = '全部';
  final bool _sortAscending = false; // default false = newest first

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _currentMode = widget.mode;
    loadWrongQuestions();
  }

  void _exitSelectionMode() {
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> loadWrongQuestions() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final uid =
          widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';

      if (_currentMode == 0) {
        // Load wrong questions
        final rows =
            await DatabaseHelper.instance.getWrongQuestions(uid.toString());
        final mapped =
            rows.map((row) => Map<String, dynamic>.from(row)).toList();
        if (!mounted) return;
        setState(() {
          _rows = mapped;
          _selected.clear();
          _isSelectionMode = false;
          _loading = false;
        });
      } else {
        // Load favorited questions
        final db = await DatabaseHelper.instance.database;
        final rows = await db.query('questions',
            where: 'bookmarked = 1', orderBy: 'created_at DESC');

        final mapped = rows
            .map((row) => {
                  ...row,
                  'question_id': row['id'],
                  'note': '',
                })
            .toList();

        if (!mounted) return;
        setState(() {
          _rows = mapped;
          _selected.clear();
          _isSelectionMode = false;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('載入資料失敗: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // Get dynamic subject list
  List<String> get _subjects {
    final set = <String>{};
    for (final r in _rows) {
      final s = r['subject']?.toString() ?? '一般';
      if (s.isNotEmpty) set.add(s);
    }
    return ['全部', ...set];
  }

  // Get filtered and sorted list
  List<Map<String, dynamic>> get _displayRows {
    var list = _rows;
    if (_selectedSubject != '全部') {
      list = list
          .where((r) => (r['subject']?.toString() ?? '一般') == _selectedSubject)
          .toList();
    }

    final sortedList = List<Map<String, dynamic>>.from(list);
    if (_sortAscending) {
      sortedList.sort((a, b) {
        final timeA = a['created_at']?.toString() ?? '';
        final timeB = b['created_at']?.toString() ?? '';
        return timeA.compareTo(timeB);
      });
    } else {
      sortedList.sort((a, b) {
        final timeA = a['created_at']?.toString() ?? '';
        final timeB = b['created_at']?.toString() ?? '';
        return timeB.compareTo(timeA);
      });
    }
    return sortedList;
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;

    final title = _currentMode == 0 ? '刪除選取' : '取消收藏選取';
    final content = _currentMode == 0 ? '確定要從錯題本移除選取項目嗎？' : '確定要取消收藏選取的項目嗎？';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('確定')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (_currentMode == 0) {
        await DatabaseHelper.instance
            .deleteWrongQuestionsBulk(_selected.toList());
      } else {
        final db = await DatabaseHelper.instance.database;
        final placeholders = List.filled(_selected.length, '?').join(',');
        await db.update('questions', <String, Object?>{'bookmarked': 0},
            where: 'id IN ($placeholders)', whereArgs: _selected.toList());
      }
      await loadWrongQuestions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_currentMode == 0 ? '已從錯題本移除' : '已取消收藏')));
    } catch (e) {
      debugPrint('操作失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('操作失敗')));
    }
  }

  Future<void> _startPracticeSelected() async {
    if (_selected.isEmpty) return;
    try {
      final qids = <int>[];
      if (_currentMode == 0) {
        for (final r in _rows) {
          final rid = int.tryParse(r['id'].toString()) ?? 0;
          if (_selected.contains(rid)) {
            final qid = int.tryParse(r['question_id'].toString()) ?? 0;
            if (qid > 0) qids.add(qid);
          }
        }
      } else {
        qids.addAll(_selected);
      }

      if (qids.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('選取項目無題目')));
        return;
      }
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('questions',
          where: 'id IN (${List.filled(qids.length, '?').join(',')})',
          whereArgs: qids);
      final mapped = rows
          .map((row) => {
                'id': int.tryParse(row['id'].toString()) ?? 0,
                'question': row['text'] ?? '',
                'options': row['options'] is String
                    ? (row['options'])
                    : (row['options'] ?? []),
                'answerIndex':
                    int.tryParse((row['answer'] ?? '0').toString()) ?? 0,
                'explanation': row['explanation'] ?? '',
                'subject': row['subject'] ?? '',
                'type': row['type'] ?? '單選題',
                'isFavorite': (row['bookmarked'] as int? ?? 0) == 1,
              })
          .toList();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => QuestionPracticePage(
                questions: mapped,
                currentUser: widget.currentUser,
                title: _currentMode == 0 ? '錯題本練習' : '收藏練習')),
      ).then((_) {
        if (mounted) {
          loadWrongQuestions();
        }
      });
    } catch (e) {
      debugPrint('啟動練習失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('無法啟動練習')));
    }
  }

  Future<void> _batchAddNotes() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('批次新增筆記', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          '批次筆記功能開發中！\n未來版本將支援一鍵備份同步您的學習筆記，並能批次為精選錯題加入解題心得！',
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

  Future<void> _batchAddToPaper() async {
    if (_selected.isEmpty) return;

    // 1. Get actual question IDs
    final qids = <int>[];
    if (_currentMode == 0) {
      for (final r in _rows) {
        final rid = int.tryParse(r['id'].toString()) ?? 0;
        if (_selected.contains(rid)) {
          final qid = int.tryParse(r['question_id'].toString()) ?? 0;
          if (qid > 0) qids.add(qid);
        }
      }
    } else {
      qids.addAll(_selected);
    }

    if (qids.isEmpty) return;

    try {
      final uid = widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
      final papers = await DatabaseHelper.instance.getPapersForUser(uid.toString());

      if (!mounted) return;

      // Show selection dialog
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
        final defaultName = '新題本 ${papers.length + 1}';

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
          qids,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已建立並成功加入「$newPaperName」')),
        );
        _exitSelectionMode();
        return;
      }

      final paperId = int.tryParse(selectedPaper['id'].toString()) ?? 0;
      final paperName = selectedPaper['name'] ?? '未命名題本';

      final ids = await DatabaseHelper.instance.getQuestionIdsForPaper(paperId);
      final int originalCount = ids.length;
      final Set<int> mergedSet = {...ids, ...qids};
      final int addedCount = mergedSet.length - originalCount;

      await DatabaseHelper.instance.updatePaper(paperId, paperName, mergedSet.toList());

      if (!mounted) return;
      if (addedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('選取的題目已存在於「$paperName」中')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已成功加入 $addedCount 題至「$paperName」！')),
        );
      }
      _exitSelectionMode();
    } catch (e) {
      debugPrint('批次加到題本失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加入失敗，請稍後再試')),
      );
    }
  }

  // void _shareQuestion(int qid) async {
  //   final confirm = await showDialog<bool>(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //       title: const Row(
  //         children: [
  //           Icon(Icons.share, color: Theme.of(context).primaryColor),
  //           SizedBox(width: 8),
  //           Text('分享題目'),
  //         ],
  //       ),
  //       content: const Text('確定要將這道題目分享至社群論壇嗎？\n這將會產生一篇包含此題目的公開分享貼文。'),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(ctx, false),
  //           child: const Text('取消', style: TextStyle(color: Colors.grey)),
  //         ),
  //         ElevatedButton(
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: Theme.of(context).primaryColor,
  //             foregroundColor: Colors.white,
  //             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //           ),
  //           onPressed: () => Navigator.pop(ctx, true),
  //           child: const Text('確定分享'),
  //         ),
  //       ],
  //     ),
  //   );
  //
  //   if (confirm == true) {
  //     if (!mounted) return;
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (ctx) => const Center(
  //         child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
  //       ),
  //     );
  //
  //     try {
  //       final db = await DatabaseHelper.instance.database;
  //       final rows = await db.query('questions', where: 'id = ?', whereArgs: [qid]);
  //       if (rows.isEmpty) {
  //         if (mounted) {
  //           Navigator.pop(context);
  //           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('找不到題目資料')));
  //         }
  //         return;
  //       }
  //       final row = rows.first;
  //       final rawOptions = row['options'];
  //       final decodedOptions = rawOptions is String
  //           ? (rawOptions)
  //           : (rawOptions ?? '[]');
  //
  //       final uid = widget.currentUser['id'] ?? 'u1';
  //       final snippet = row['text']?.toString() ?? '';
  //       final summary = snippet.length > 30 ? '${snippet.substring(0, 30)}...' : snippet;
  //
  //       await db.insert('posts', <String, Object?>{
  //         'user_id': uid,
  //         'content': '我分享了一道《${row['subject'] ?? "學科"}》題目，快來挑戰看看！ 📄\n題目：「$summary」',
  //         'type': 'doc',
  //         'attached_data': jsonEncode({
  //           'shared_type': 'question',
  //           'text': row['text'] ?? '',
  //           'options': decodedOptions is String ? jsonDecode(decodedOptions) : decodedOptions,
  //           'answer': row['answer']?.toString() ?? '0',
  //           'explanation': row['explanation'] ?? '',
  //           'subject': row['subject'] ?? '',
  //           'difficulty': row['difficulty'] ?? '中',
  //         }),
  //         'created_at': DateTime.now().toIso8601String(),
  //       });
  //
  //       if (mounted) {
  //         Navigator.pop(context); // 關閉讀取框
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           const SnackBar(
  //             content: Text('🎉 題目已成功分享至社群論壇！'),
  //             backgroundColor: Theme.of(context).primaryColor,
  //           ),
  //         );
  //       }
  //     } catch (e) {
  //       if (mounted) {
  //         Navigator.pop(context); // 關閉讀取框
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text('分享失敗: $e'),
  //             backgroundColor: Colors.redAccent,
  //           ),
  //         );
  //       }
  //     }
  //   }
  // }

  Future<void> clearAll() async {
    final title = _currentMode == 0 ? '清空錯題本' : '清空收藏';
    final content =
        _currentMode == 0 ? '確定要清空所有錯題本記錄？此動作無法還原。' : '確定要清空所有收藏？此動作無法還原。';

    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (_currentMode == 0) {
        final ids = _rows
            .map((r) => int.tryParse(r['id'].toString()) ?? 0)
            .where((v) => v > 0)
            .toList();
        await DatabaseHelper.instance.deleteWrongQuestionsBulk(ids);
      } else {
        final db = await DatabaseHelper.instance.database;
        await db.update('questions', <String, Object?>{'bookmarked': 0},
            where: 'bookmarked = 1');
      }
      await loadWrongQuestions();
      messenger.showSnackBar(
          SnackBar(content: Text(_currentMode == 0 ? '錯題本已清空' : '已清空所有收藏')));
    } catch (e) {
      debugPrint('清空失敗: $e');
      messenger.showSnackBar(const SnackBar(content: Text('清空失敗')));
    }
  }

  Widget _buildEmptyState(ColorScheme cs) {
    final isWrongMode = _currentMode == 0;
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), // Ensures refresh works even when empty
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isWrongMode
                    ? Colors.green.shade50.withValues(alpha: 0.5)
                    : Colors.amber.shade50.withValues(alpha: 0.5),
              ),
              child: Icon(
                isWrongMode ? Icons.verified_rounded : Icons.star_rounded,
                size: 72,
                color: isWrongMode ? Colors.green.shade600 : Colors.amber.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isWrongMode ? '太棒了！' : '收藏庫空空如也',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedSubject == '全部'
                  ? (isWrongMode
                      ? '目前沒有任何錯題記錄，請繼續保持優良表現！'
                      : '目前還沒有收藏題目，快去題庫挑選你感興趣的題目吧！')
                  : '目前在「$_selectedSubject」下沒有${isWrongMode ? '錯題' : '收藏記錄'}。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayList = _displayRows;
    final subjectList = _subjects;

    Widget content = _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              if (_isSelectionMode && widget.embed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    border: Border(
                        bottom: BorderSide(
                            color: cs.outline.withValues(alpha: 0.12))),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: cs.onSecondaryContainer, size: 20),
                        onPressed: _exitSelectionMode,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '已選取 ${_selected.length} 項',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            final allKeys = displayList
                                .map((r) {
                                  final rid =
                                      int.tryParse(r['id'].toString()) ?? 0;
                                  final qid = int.tryParse(
                                          r['question_id'].toString()) ??
                                      0;
                                  return _currentMode == 0 ? rid : qid;
                                })
                                .where((k) => k > 0)
                                .toList();
                            _selected.addAll(allKeys);
                          });
                        },
                        child: Text(
                          '全選',
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Classification chips and Sort Toggle
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.transparent,
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: subjectList.map((subject) {
                            final isSelected = _selectedSubject == subject;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(subject),
                                selected: isSelected,
                                selectedColor: cs.primary,
                                backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? cs.onPrimary
                                      : cs.onSurfaceVariant,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                      color: isSelected
                                          ? Colors.transparent
                                          : cs.outline.withValues(alpha: 0.15)),
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedSubject = subject;
                                    });
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: displayList.isEmpty
                    ? _buildEmptyState(cs)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                        itemCount: displayList.length,
                        itemBuilder: (context, idx) {
                          final r = displayList[idx];
                          final rid = int.tryParse(r['id'].toString()) ?? 0;
                          final qid =
                              int.tryParse(r['question_id'].toString()) ?? 0;
                          final note = (r['note'] ?? '').toString();
                          final String questionText =
                              (r['text'] ?? '').toString();
                          final String subject =
                              (r['subject'] ?? '一般').toString();

                          final options =
                              NotebookHelper.parseOptions(r['options']);
                          final rawAns = r['answerIndex'] ?? r['answer'] ?? 0;
                          final int correctIndex =
                              int.tryParse(rawAns.toString()) ?? 0;

                          // Checkbox key: for wrong questions it's rid; for favorites it's qid
                          final selectionKey = _currentMode == 0 ? rid : qid;
                          final isSelected = _selected.contains(selectionKey);

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: isSelected
                                    ? cs.primary.withValues(alpha: 0.5)
                                    : cs.outline.withValues(alpha: 0.08),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onLongPress: () {
                                if (!_isSelectionMode) {
                                  setState(() {
                                    _isSelectionMode = true;
                                    _selected.add(selectionKey);
                                  });
                                }
                              },
                              onTap: _isSelectionMode
                                  ? () {
                                      setState(() {
                                        if (_selected.contains(selectionKey)) {
                                          _selected.remove(selectionKey);
                                          if (_selected.isEmpty) {
                                            _isSelectionMode = false;
                                          }
                                        } else {
                                          _selected.add(selectionKey);
                                        }
                                      });
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header row
                                    Row(
                                      children: [
                                        if (_isSelectionMode) ...[
                                          Transform.scale(
                                            scale: 0.9,
                                            child: Checkbox(
                                              value: isSelected,
                                              activeColor: cs.primary,
                                              onChanged: (v) {
                                                setState(() {
                                                  if (v == true) {
                                                    _selected.add(selectionKey);
                                                  } else {
                                                    _selected
                                                        .remove(selectionKey);
                                                    if (_selected.isEmpty) {
                                                      _isSelectionMode = false;
                                                    }
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: cs.primary.withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            subject,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: cs.primary),
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: Icon(
                                            (r['bookmarked'] as int? ?? 0) ==
                                                         1 ||
                                                     r['bookmarked'] == true
                                                 ? Icons.star_rounded
                                                 : Icons.star_outline_rounded,
                                            color: (r['bookmarked'] as int? ??
                                                            0) ==
                                                         1 ||
                                                     r['bookmarked'] == true
                                                 ? Colors.amber
                                                 : Colors.grey.shade400,
                                            size: 20,
                                          ),
                                          onPressed: () async {
                                            final messenger =
                                                ScaffoldMessenger.of(context);
                                            try {
                                              final db = await DatabaseHelper
                                                  .instance.database;
                                              final isFav =
                                                  (r['bookmarked'] as int? ??
                                                              0) ==
                                                          1 ||
                                                      r['bookmarked'] == true;
                                              final nextVal = isFav ? 0 : 1;

                                              await db.update('questions', <String, Object?>{'bookmarked': nextVal},
                                                  where: 'id = ?',
                                                  whereArgs: [qid]);

                                              setState(() {
                                                r['bookmarked'] = nextVal;
                                              });

                                              messenger.hideCurrentSnackBar();
                                              if (nextVal == 0) {
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content:
                                                        const Text('已取消收藏'),
                                                    duration: const Duration(
                                                        seconds: 3),
                                                    action: SnackBarAction(
                                                      label: '復原',
                                                      textColor: Colors.amber,
                                                      onPressed: () async {
                                                        try {
                                                          await db.update('questions', <String, Object?>{'bookmarked': 1},
                                                              where: 'id = ?',
                                                              whereArgs: [qid]);
                                                          setState(() {
                                                            r['bookmarked'] = 1;
                                                          });
                                                        } catch (e) {
                                                          debugPrint(
                                                              '復原收藏失敗: $e');
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                );
                                              } else {
                                                messenger.showSnackBar(
                                                  const SnackBar(
                                                    content: Text('已加入收藏'),
                                                    duration: Duration(
                                                        milliseconds: 1000),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              debugPrint('切換收藏失敗: $e');
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Question Text
                                    Text(
                                      questionText.isEmpty
                                          ? '（載入中或找不到題目資料，ID: $qid）'
                                          : questionText,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.5,
                                          height: 1.45),
                                    ),
                                    const SizedBox(height: 14),

                                    // Compact options view (highlighting the correct option)
                                    if (options.isNotEmpty)
                                      Column(
                                        children: List.generate(options.length,
                                            (optIdx) {
                                          final isCorrect =
                                              optIdx == correctIndex;
                                          return Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 6),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isCorrect
                                                  ? Colors.green.shade50.withValues(alpha: 0.5)
                                                  : const Color(0xFFFAF8F6),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isCorrect
                                                    ? Colors.green.withValues(alpha: 0.25)
                                                    : Colors.grey.shade100,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 20,
                                                  height: 20,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: isCorrect ? Colors.green.shade600 : Colors.grey.shade300,
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    String.fromCharCode(65 + optIdx),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    options[optIdx],
                                                    style: TextStyle(
                                                      color: isCorrect
                                                          ? Colors.green.shade900
                                                          : Colors.black87,
                                                      fontSize: 12.5,
                                                      fontWeight: isCorrect
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                    ),
                                                  ),
                                                ),
                                                if (isCorrect)
                                                  Icon(
                                                    Icons.check_circle_rounded,
                                                    color: Colors.green.shade600,
                                                    size: 16,
                                                  ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ),

                                    // Explanation section
                                    if (r['explanation'] != null &&
                                        r['explanation']
                                            .toString()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50.withValues(alpha: 0.3),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.amber.withValues(alpha: 0.2),
                                              width: 0.8),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.lightbulb_outline_rounded,
                                                color: Colors.amber.shade800, size: 16),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '解析：${r['explanation']}',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.amber.shade900,
                                                    height: 1.45),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // Note display if available (only for wrong questions mode)
                                    if (_currentMode == 0 &&
                                        note.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: cs.primary.withValues(alpha: 0.04),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                              color: cs.primary.withValues(alpha: 0.1),
                                              width: 0.8),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.edit_note_rounded,
                                                size: 18,
                                                color: cs.primary),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '筆記：$note',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: cs.primary,
                                                    height: 1.45),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 12),
                                    const Divider(height: 1, thickness: 0.5),
                                    const SizedBox(height: 8),

                                    // Action buttons row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Add to notebook
                                        IconButton(
                                          tooltip: '加入筆記本',
                                          icon: Icon(
                                              Icons.note_add_outlined,
                                              color: cs.primary.withValues(alpha: 0.8),
                                              size: 18),
                                          onPressed: () {
                                            final questionMap = {
                                              'subject': subject,
                                              'text': questionText,
                                              'options': r['options'],
                                              'answerIndex': correctIndex,
                                              'explanation':
                                                  r['explanation'] ?? '',
                                            };
                                            NotebookHelper
                                                .showAddToNotebookDialog(
                                                    context,
                                                    widget.currentUser,
                                                    questionMap);
                                          },
                                        ),
                                        const SizedBox(width: 12),
                                        // Delete single (or Unfavorite)
                                        IconButton(
                                          tooltip: _currentMode == 0
                                              ? '移除錯題'
                                              : '取消收藏',
                                          onPressed: () async {
                                            final messenger =
                                                ScaffoldMessenger.of(context);
                                            try {
                                              if (_currentMode == 0) {
                                                await DatabaseHelper.instance
                                                    .deleteWrongQuestionByRecordId(
                                                        rid);
                                                messenger.showSnackBar(
                                                    const SnackBar(
                                                        content:
                                                            Text('已從錯題本移除')));
                                                await loadWrongQuestions();
                                              } else {
                                                final db = await DatabaseHelper
                                                    .instance.database;
                                                await db.update('questions', <String, Object?>{'bookmarked': 0},
                                                    where: 'id = ?',
                                                    whereArgs: [qid]);
                                                setState(() {
                                                  r['bookmarked'] = 0;
                                                });

                                                messenger.hideCurrentSnackBar();
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content:
                                                        const Text('已取消收藏'),
                                                    duration: const Duration(
                                                        seconds: 3),
                                                    action: SnackBarAction(
                                                      label: '復原',
                                                      textColor: Colors.amber,
                                                      onPressed: () async {
                                                        try {
                                                          await db.update('questions', <String, Object?>{'bookmarked': 1},
                                                              where: 'id = ?',
                                                              whereArgs: [qid]);
                                                          setState(() {
                                                            r['bookmarked'] = 1;
                                                          });
                                                        } catch (e) {
                                                          debugPrint(
                                                              '復原收藏失敗: $e');
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              debugPrint('操作失敗: $e');
                                            }
                                          },
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.redAccent,
                                              size: 18),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_isSelectionMode && displayList.isNotEmpty)
                SafeArea(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: _currentMode == 0 ? '從錯題本移除選取' : '取消收藏選取',
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                          onPressed: _deleteSelected,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: '批次新增筆記',
                          icon: Icon(Icons.note_alt_outlined, color: cs.primary),
                          onPressed: _batchAddNotes,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: '批次加到自訂題本',
                          icon: const Icon(Icons.create_new_folder_outlined, color: Colors.orange),
                          onPressed: _batchAddToPaper,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _startPracticeSelected,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(
                              _currentMode == 0 ? '複習選取' : '練習選取',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );

    if (widget.embed) {
      final fab = !_isSelectionMode && displayList.isNotEmpty
          ? FloatingActionButton.extended(
              key: TourKeys.startPracticeFabKey,
              heroTag: _currentMode == 0 ? 'wrong_quiz_fab' : 'fav_quiz_fab',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuestionPracticePage(
                      questions: displayList,
                      title: _currentMode == 0
                          ? (_selectedSubject == '全部' ? '全錯題複習' : '錯題複習 ($_selectedSubject)')
                          : (_selectedSubject == '全部' ? '全收藏練習' : '收藏練習 ($_selectedSubject)'),
                      currentUser: widget.currentUser,
                    ),
                  ),
                ).then((_) {
                  loadWrongQuestions();
                });
              },
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: Text(
                _selectedSubject == '全部'
                    ? '開始練習全部 (${displayList.length} 題)'
                    : '練習「$_selectedSubject」(${displayList.length} 題)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null;

      return Stack(
        children: [
          content,
          if (fab != null)
            Positioned(
              right: 16,
              bottom: 80 + MediaQuery.of(context).padding.bottom,
              child: fab,
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F6),
      appBar: _isSelectionMode
          ? AppBar(
              title: Text('已選取 ${_selected.length} 項'),
              backgroundColor: cs.secondaryContainer,
              foregroundColor: cs.onSecondaryContainer,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      final allKeys = displayList
                          .map((r) {
                            final rid = int.tryParse(r['id'].toString()) ?? 0;
                            final qid =
                                int.tryParse(r['question_id'].toString()) ?? 0;
                            return _currentMode == 0 ? rid : qid;
                          })
                          .where((k) => k > 0)
                          .toList();
                      _selected.addAll(allKeys);
                    });
                  },
                  child: Text(
                    '全選',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          : AppBar(
              title: Text(_currentMode == 0 ? '錯題本' : '我的收藏'),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
            ),
      body: content,
      floatingActionButton: _isSelectionMode
          ? null
          : (displayList.isNotEmpty
              ? FloatingActionButton.extended(
                  key: TourKeys.startPracticeFabKey,
                  heroTag: _currentMode == 0 ? 'wrong_quiz_fab' : 'fav_quiz_fab',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuestionPracticePage(
                          questions: displayList,
                          title: _currentMode == 0
                              ? (_selectedSubject == '全部' ? '全錯題複習' : '錯題複習 ($_selectedSubject)')
                              : (_selectedSubject == '全部' ? '全收藏練習' : '收藏練習 ($_selectedSubject)'),
                          currentUser: widget.currentUser,
                        ),
                      ),
                    ).then((_) {
                      loadWrongQuestions();
                    });
                  },
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  icon: const Icon(Icons.play_arrow_rounded, size: 24),
                  label: Text(
                    _selectedSubject == '全部'
                        ? '開始練習全部 (${displayList.length} 題)'
                        : '練習「$_selectedSubject」(${displayList.length} 題)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
              : null),
    );
  }
}
