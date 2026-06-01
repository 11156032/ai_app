import 'dart:convert';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class ReviewPage extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final Map<int, int> selectedAnswers; // key: questionIndex in questions, value: chosen option index
  final Map<String, dynamic>? currentUser;

  const ReviewPage({super.key, required this.questions, required this.selectedAnswers, this.currentUser});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final Set<int> _toSaveWrong = {};
  final Map<int, TextEditingController> _noteCtrls = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.questions.length; i++) {
      _noteCtrls[i] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _noteCtrls.values) c.dispose();
    super.dispose();
  }

  List<String> _parseOptions(dynamic raw) {
    try {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String && raw.trim().isNotEmpty) {
        final d = jsonDecode(raw);
        if (d is List) return d.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    if (raw is String) {
      return raw.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  int _correctIndex(Map<String, dynamic> q) {
    final raw = q['answerIndex'] ?? q['answer'] ?? 0;
    return int.tryParse(raw.toString()) ?? 0;
  }

  Future<void> _saveSelectedWrongAndNotes() async {
    setState(() => _saving = true);
    final uid = widget.currentUser?['id'] ?? widget.currentUser?['user_id'];
    if (uid != null) {
      for (int i = 0; i < widget.questions.length; i++) {
        final q = widget.questions[i];
        final qid = q['id'] is int ? q['id'] as int : int.tryParse(q['id'].toString()) ?? 0;
        if (_toSaveWrong.contains(i) && qid > 0) {
          try {
            await DatabaseHelper.instance.addWrongQuestion(uid.toString(), qid, note: _noteCtrls[i]?.text ?? '');
          } catch (_) {}
        }
        // also save note separately if provided
        final noteText = _noteCtrls[i]?.text.trim();
        if (noteText != null && noteText.isNotEmpty) {
          try {
            await DatabaseHelper.instance.createNote(uid.toString(), '筆記：題 $qid', noteText);
          } catch (_) {}
        }
      }
    }
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已儲存錯題與筆記')));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('交卷檢討'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: widget.questions.length,
        itemBuilder: (context, idx) {
          final q = widget.questions[idx];
          final options = _parseOptions(q['options']);
          final correct = _correctIndex(q);
          final chosen = widget.selectedAnswers[idx];
          final isWrong = chosen != null && chosen != correct;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text('${idx + 1}. ${(q['question'] ?? q['text'] ?? '').toString()}', style: TextStyle(fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          Icon(isWrong ? Icons.cancel_rounded : Icons.check_circle_rounded, color: isWrong ? Colors.red : Colors.green),
                          const SizedBox(height: 4),
                          Text(isWrong ? '錯' : '對', style: TextStyle(color: isWrong ? Colors.red : Colors.green)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (options.isNotEmpty)
                    ...options.asMap().entries.map((e) {
                      final i = e.key;
                      final text = e.value;
                      final isChosen = chosen == i;
                      final isCorrect = correct == i;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isCorrect ? Colors.green.withOpacity(0.06) : (isChosen ? Colors.orange.withOpacity(0.06) : null),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isCorrect ? Colors.green : (isChosen ? Colors.orange : Colors.grey.shade200)),
                        ),
                        child: Row(children: [Text(String.fromCharCode(65 + i)), const SizedBox(width: 8), Expanded(child: Text(text))]),
                      );
                    }).toList(),
                  const SizedBox(height: 8),
                  if ((q['explanation'] ?? '').toString().trim().isNotEmpty)
                    Text('解析：${q['explanation']}', style: TextStyle(color: cs.onSurface.withOpacity(0.8))),
                  const SizedBox(height: 12),
                  TextField(controller: _noteCtrls[idx], minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: '筆記（選填）')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(value: _toSaveWrong.contains(idx), onChanged: (v) => setState(() { if (v==true) _toSaveWrong.add(idx); else _toSaveWrong.remove(idx); })),
                      const SizedBox(width: 8),
                      const Text('加入錯題本'),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _saveSelectedWrongAndNotes,
            icon: const Icon(Icons.save_rounded),
            label: Text(_saving ? '儲存中...' : '儲存錯題與筆記'),
          ),
        ),
      ),
    );
  }
}
