import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'question_practice_page.dart';

class WrongQuestionsPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const WrongQuestionsPage({super.key, required this.currentUser});

  @override
  State<WrongQuestionsPage> createState() => _WrongQuestionsPageState();
}

class _WrongQuestionsPageState extends State<WrongQuestionsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = []; // rows from wrong_questions
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadWrongQuestions();
  }

  Future<void> _loadWrongQuestions() async {
    setState(() => _loading = true);
    try {
      final uid = widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
      final rows = await DatabaseHelper.instance.getWrongQuestions(uid.toString());
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _selected.clear();
        _loading = false;
      });
    } catch (e) {
      debugPrint('載入錯題本失敗: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除選取'),
        content: const Text('確定要從錯題本移除選取項目嗎？此動作不會刪除原題目。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('刪除')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await DatabaseHelper.instance.deleteWrongQuestionsBulk(_selected.toList());
      await _loadWrongQuestions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已從錯題本移除')));
    } catch (e) {
      debugPrint('刪除錯題失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('刪除失敗')));
    }
  }

  Future<void> _startPracticeSelected() async {
    if (_selected.isEmpty) return;
    try {
      final qids = <int>[];
      for (final r in _rows) {
        final rid = int.tryParse(r['id'].toString()) ?? 0;
        if (_selected.contains(rid)) {
          final qid = int.tryParse(r['question_id'].toString()) ?? 0;
          if (qid > 0) qids.add(qid);
        }
      }
      if (qids.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('選取項目無題目')));
        return;
      }
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('questions', where: 'id IN (${List.filled(qids.length, '?').join(',')})', whereArgs: qids);
      final mapped = rows.map((row) => {
        'id': int.tryParse(row['id'].toString()) ?? 0,
        'question': row['text'] ?? '',
        'options': row['options'] is String ? (row['options']) : (row['options'] ?? []),
        'answerIndex': int.tryParse((row['answer'] ?? '0').toString()) ?? 0,
        'explanation': row['explanation'] ?? '',
        'subject': row['subject'] ?? '',
        'type': row['type'] ?? '單選題',
      }).toList();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => QuestionPracticePage(questions: mapped, currentUser: widget.currentUser, title: '錯題本練習')),
      );
    } catch (e) {
      debugPrint('啟動錯題本練習失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('無法啟動練習')));
    }
  }

  Future<void> _batchAddNotes() async {
    if (_selected.isEmpty) return;
    final titleCtrl = TextEditingController(text: '錯題筆記');
    final contentCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('為選取題目新增筆記（批次）'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '標題')),
            const SizedBox(height: 8),
            TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: '內容'), minLines: 3, maxLines: 8),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('儲存')),
        ],
      ),
    );
    if (res != true) return;

    try {
      final uid = widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1';
      for (final r in _rows) {
        final rid = int.tryParse(r['id'].toString()) ?? 0;
        if (_selected.contains(rid)) {
          final qid = int.tryParse(r['question_id'].toString()) ?? 0;
          final noteTitle = '${titleCtrl.text.trim()}：題 $qid';
          await DatabaseHelper.instance.createNote(uid.toString(), noteTitle, contentCtrl.text.trim());
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('筆記已新增')));
    } catch (e) {
      debugPrint('批次新增筆記失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('新增失敗')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('錯題本'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          IconButton(onPressed: _loadWrongQuestions, icon: const Icon(Icons.refresh_rounded)),
          IconButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('清空錯題本'),
                  content: const Text('確定要清空所有錯題本記錄？此動作無法還原。'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清空')),
                  ],
                ),
              );
              if (confirmed != true) return;
              try {
                final ids = _rows.map((r) => int.tryParse(r['id'].toString()) ?? 0).where((v) => v > 0).toList();
                await DatabaseHelper.instance.deleteWrongQuestionsBulk(ids);
                await _loadWrongQuestions();
                messenger.showSnackBar(const SnackBar(content: Text('錯題本已清空')));
              } catch (e) {
                debugPrint('清空失敗: $e');
                messenger.showSnackBar(const SnackBar(content: Text('清空失敗')));
              }
            },
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: '清空錯題本',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(child: Text('錯題本目前為空', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _rows.length,
                        itemBuilder: (context, idx) {
                          final r = _rows[idx];
                          final rid = int.tryParse(r['id'].toString()) ?? 0;
                          final qid = int.tryParse(r['question_id'].toString()) ?? 0;
                          final note = (r['note'] ?? '').toString();
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: Checkbox(
                                value: _selected.contains(rid),
                                onChanged: (v) => setState(() => v == true ? _selected.add(rid) : _selected.remove(rid)),
                              ),
                              title: Text('題目 ID: $qid', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
                              subtitle: note.isEmpty ? null : Text(note, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.8))),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    await DatabaseHelper.instance.deleteWrongQuestionByRecordId(rid);
                                    await _loadWrongQuestions();
                                    messenger.showSnackBar(const SnackBar(content: Text('已移除')));
                                  } catch (e) {
                                    debugPrint('移除失敗: $e');
                                  }
                                }, icon: const Icon(Icons.delete_outline_rounded)),
                                IconButton(onPressed: () async {
                                  // open single question practice
                                  final navigator = Navigator.of(context);
                                  try {
                                    final db = await DatabaseHelper.instance.database;
                                    final rows = await db.query('questions', where: 'id = ?', whereArgs: [qid]);
                                    if (rows.isEmpty) return;
                                    final row = rows.first;
                                    final mapped = {
                                      'id': int.tryParse(row['id'].toString()) ?? 0,
                                      'question': row['text'] ?? '',
                                      'options': row['options'] is String ? (row['options']) : (row['options'] ?? []),
                                      'answerIndex': int.tryParse((row['answer'] ?? '0').toString()) ?? 0,
                                      'explanation': row['explanation'] ?? '',
                                      'subject': row['subject'] ?? '',
                                      'type': row['type'] ?? '單選題',
                                    };
                                    navigator.push(MaterialPageRoute(builder: (_) => QuestionPracticePage(questions: [mapped], currentUser: widget.currentUser, title: '錯題練習')));
                                  } catch (e) {
                                    debugPrint('啟動題目練習失敗: $e');
                                  }
                                }, icon: const Icon(Icons.play_arrow_rounded)),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(child: OutlinedButton.icon(onPressed: _deleteSelected, icon: const Icon(Icons.delete_outline_rounded), label: const Text('移除選取'))),
                            const SizedBox(width: 8),
                            Expanded(child: OutlinedButton.icon(onPressed: _batchAddNotes, icon: const Icon(Icons.note_add_rounded), label: const Text('批次加入筆記'))),
                            const SizedBox(width: 8),
                            Expanded(child: ElevatedButton.icon(onPressed: _startPracticeSelected, icon: const Icon(Icons.play_arrow_rounded), label: const Text('複習選取'))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
