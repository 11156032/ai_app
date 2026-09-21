import 'dart:convert';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';

// --- 測驗歷史頁面 ---
class QuizHistoryPage extends StatefulWidget {
  final String currentUserId;
  final void Function(List<dynamic> wrongIds) onViewWrongQuestions;

  const QuizHistoryPage({
    super.key,
    required this.currentUserId,
    required this.onViewWrongQuestions,
  });

  @override
  State<QuizHistoryPage> createState() => _QuizHistoryPageState();
}

class _QuizHistoryPageState extends State<QuizHistoryPage> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT * FROM quiz_results
      WHERE user_id = ?
      ORDER BY timestamp DESC
    ''', [widget.currentUserId]);
    if (mounted) {
      setState(() {
        _records = rows.map((r) => Map<String, dynamic>.from(r)).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('測驗歷史'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('尚無測驗或學習紀錄',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final r = _records[i];
                    final int total = (r['total'] as num?)?.toInt() ?? 0;
                    final int correct = (r['correct'] as num?)?.toInt() ?? 0;
                    final int durationSec =
                        (r['duration_seconds'] as num?)?.toInt() ?? 0;
                    final String tsStr = r['timestamp'] as String? ?? '';
                    final DateTime? ts = DateTime.tryParse(tsStr);
                    final String timeLabel = ts != null
                        ? '${ts.year}/${ts.month.toString().padLeft(2, '0')}/${ts.day.toString().padLeft(2, '0')} '
                            '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
                        : tsStr;
                    final int mins = durationSec ~/ 60;
                    final int secs = durationSec % 60;
                    final String durationLabel =
                        mins > 0 ? '$mins 分 $secs 秒' : '$secs 秒';

                    final bool isQuizRecord = total > 0;
                    List<dynamic> wrongIds = [];
                    try {
                      final raw = r['wrong_question_ids'];
                      if (raw != null && (raw as String).isNotEmpty) {
                        wrongIds = jsonDecode(raw);
                      }
                    } catch (_) {}

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isQuizRecord
                                      ? primaryColor.withValues(alpha: 0.1)
                                      : Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isQuizRecord
                                          ? Icons.quiz_outlined
                                          : Icons.menu_book_outlined,
                                      size: 12,
                                      color: isQuizRecord
                                          ? primaryColor
                                          : Colors.teal.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isQuizRecord ? '測驗模式' : '自主學習瀏覽',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isQuizRecord
                                            ? primaryColor
                                            : Colors.teal.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(timeLabel,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (isQuizRecord) ...[
                            Row(
                              children: [
                                _statChip(Icons.check_circle_outline,
                                    '$correct/$total 題', Colors.green.shade600),
                                const SizedBox(width: 12),
                                _statChip(
                                    Icons.star_outline,
                                    '${total > 0 ? ((correct / total) * 100).round() : 0} 分',
                                    primaryColor),
                                const SizedBox(width: 12),
                                _statChip(Icons.timer_outlined, durationLabel,
                                    Colors.orange.shade600),
                              ],
                            ),
                            if (wrongIds.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () =>
                                    widget.onViewWrongQuestions(wrongIds),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.replay_outlined,
                                          size: 14, color: Colors.red.shade600),
                                      const SizedBox(width: 6),
                                      Text('錯題複習（${wrongIds.length} 題）',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ] else ...[
                            _statChip(Icons.timer_outlined,
                                '自主瀏覽 $durationLabel', Colors.teal.shade600),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
