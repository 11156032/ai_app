import 'package:flutter/material.dart';
// import 'dart:convert';
import '../database/database_helper.dart';
import '../services/notebook_helper.dart';
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
  bool _sortAscending = false; // default false = newest first

  @override
  void initState() {
    super.initState();
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
        await db.update('questions', {'bookmarked': 0},
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
    if (_selected.isEmpty) return;
    final titleCtrl =
        TextEditingController(text: _currentMode == 0 ? '錯題筆記' : '收藏筆記');
    final contentCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('為選取題目新增筆記（批次）'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '標題')),
            const SizedBox(height: 8),
            TextField(
                controller: contentCtrl,
                decoration: const InputDecoration(labelText: '內容'),
                minLines: 3,
                maxLines: 8),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('儲存')),
        ],
      ),
    );
    if (res != true) return;

    try {
      final uid =
          widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
      for (final r in _rows) {
        final rid = int.tryParse(r['id'].toString()) ?? 0;
        final qid = int.tryParse(r['question_id'].toString()) ?? 0;
        final key = _currentMode == 0 ? rid : qid;
        if (_selected.contains(key)) {
          final noteTitle = '${titleCtrl.text.trim()}：題 $qid';
          await DatabaseHelper.instance
              .createNote(uid.toString(), noteTitle, contentCtrl.text.trim());
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('筆記已新增')));
      _exitSelectionMode();
    } catch (e) {
      debugPrint('批次新增筆記失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('新增失敗')));
    }
  }

  // void _shareQuestion(int qid) async {
  //   final confirm = await showDialog<bool>(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //       title: const Row(
  //         children: [
  //           Icon(Icons.share, color: Color(0xFF8D6E63)),
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
  //             backgroundColor: const Color(0xFF8D6E63),
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
  //         child: CircularProgressIndicator(color: Color(0xFF8D6E63)),
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
  //       await db.insert('posts', {
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
  //             backgroundColor: Color(0xFF8D6E63),
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
        final ids = _rows
            .map((r) => int.tryParse(r['id'].toString()) ?? 0)
            .where((v) => v > 0)
            .toList();
        await DatabaseHelper.instance.deleteWrongQuestionsBulk(ids);
      } else {
        final db = await DatabaseHelper.instance.database;
        await db.update('questions', {'bookmarked': 0},
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
                color: Colors.white,
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
                                selectedColor: const Color(0xFF8D6E63),
                                backgroundColor: const Color(0xFFF5F0EE),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
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
                                          : Colors.grey.shade300),
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
                    const SizedBox(width: 8),
                    // Sort button
                    IconButton(
                      icon: Icon(
                        _sortAscending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: const Color(0xFF8D6E63),
                        size: 20,
                      ),
                      tooltip: _sortAscending ? '最早加入' : '最新加入',
                      onPressed: () {
                        setState(() {
                          _sortAscending = !_sortAscending;
                        });
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: displayList.isEmpty
                    ? Center(
                        child: Text(
                          _selectedSubject == '全部'
                              ? (_currentMode == 0 ? '目前沒有錯題記錄' : '目前沒有收藏題目')
                              : '目前在「$_selectedSubject」下沒有${_currentMode == 0 ? '錯題' : '收藏'}',
                          style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.7)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
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

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 0.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color: Colors.grey.shade200, width: 1.2),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
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
                                padding: const EdgeInsets.all(14),
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
                                              value: _selected
                                                  .contains(selectionKey),
                                              activeColor:
                                                  const Color(0xFF8D6E63),
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
                                        ],
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.blue
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            subject,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
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

                                              await db.update('questions',
                                                  {'bookmarked': nextVal},
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
                                                          await db.update(
                                                              'questions',
                                                              {'bookmarked': 1},
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
                                    const SizedBox(height: 8),

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
                                    const SizedBox(height: 10),

                                    // Compact options view (highlighting the correct option)
                                    if (options.isNotEmpty)
                                      Column(
                                        children: List.generate(options.length,
                                            (optIdx) {
                                          final isCorrect =
                                              optIdx == correctIndex;
                                          return Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 4),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isCorrect
                                                  ? Colors.green
                                                      .withValues(alpha: 0.08)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              children: [
                                                Text(
                                                  '${String.fromCharCode(65 + optIdx)}.',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isCorrect
                                                        ? Colors.green.shade700
                                                        : Colors.black54,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    options[optIdx],
                                                    style: TextStyle(
                                                      color: isCorrect
                                                          ? Colors
                                                              .green.shade800
                                                          : Colors.black87,
                                                      fontSize: 12,
                                                      fontWeight: isCorrect
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                    ),
                                                  ),
                                                ),
                                                if (isCorrect)
                                                  const Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      color: Colors.green,
                                                      size: 14),
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
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFF8E7),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: const Color(0xFFFFD966),
                                              width: 0.6),
                                        ),
                                        child: Text(
                                          '解析: ${r['explanation']}',
                                          style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF92400E),
                                              height: 1.4),
                                        ),
                                      ),
                                    ],

                                    // Note display if available (only for wrong questions mode)
                                    if (_currentMode == 0 &&
                                        note.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 4.0),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.edit_note_rounded,
                                                size: 16,
                                                color: Color(0xFF8D6E63)),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                note,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontStyle: FontStyle.italic,
                                                    color: Color(0xFF5D4037)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 10),
                                    const Divider(height: 1, thickness: 0.5),
                                    const SizedBox(height: 8),

                                    // Action buttons row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        // Add to notebook
                                        IconButton(
                                          tooltip: '加入筆記本',
                                          icon: const Icon(
                                              Icons.note_add_outlined,
                                              color: Colors.blueGrey,
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
                                                await db.update('questions',
                                                    {'bookmarked': 0},
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
                                                          await db.update(
                                                              'questions',
                                                              {'bookmarked': 1},
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
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _deleteSelected,
                            child: Text(_currentMode == 0 ? '移除選取' : '取消收藏選取',
                                style: const TextStyle(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _batchAddNotes,
                            child: const Text('批次筆記',
                                style: TextStyle(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _startPracticeSelected,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: const Color(0xFF8D6E63),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(_currentMode == 0 ? '複習選取' : '練習選取',
                                style: const TextStyle(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );

    if (widget.embed) {
      return content;
    }

    return Scaffold(
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
              actions: [
                IconButton(
                    onPressed: loadWrongQuestions,
                    icon: const Icon(Icons.refresh_rounded)),
                IconButton(
                  onPressed: clearAll,
                  icon: const Icon(Icons.delete_sweep_rounded),
                  tooltip: _currentMode == 0 ? '清空錯題本' : '清空收藏',
                ),
              ],
            ),
      body: content,
    );
  }
}
