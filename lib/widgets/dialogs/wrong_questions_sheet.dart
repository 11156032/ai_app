import 'dart:convert';
import 'package:flutter/material.dart';
import '../../database/database_helper.dart';

/// 顯示指定錯題 ID 清單的複習 BottomSheet
Future<void> showWrongQuestionsSheet(
  BuildContext context,
  List<dynamic> wrongIds,
) async {
  if (wrongIds.isEmpty) return;
  final db = await DatabaseHelper.instance.database;
  final placeholders = wrongIds.map((_) => '?').join(', ');
  final rows = await db.rawQuery(
    'SELECT * FROM questions WHERE id IN ($placeholders)',
    wrongIds,
  );
  if (!context.mounted) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => WrongQuestionsSheet(rows: rows),
  );
}

/// 錯題複習內容展示元件
class WrongQuestionsSheet extends StatelessWidget {
  final List<Map<String, Object?>> rows;

  const WrongQuestionsSheet({
    super.key,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '錯題複習（${rows.length} 題）',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('找不到對應的題目資料'))
                  : ListView.separated(
                      controller: sc,
                      padding: const EdgeInsets.all(16),
                      separatorBuilder: (_, __) => const Divider(height: 24),
                      itemCount: rows.length,
                      itemBuilder: (ctx, i) {
                        final q = rows[i];
                        final options =
                            jsonDecode(q['options'] as String) as List;
                        final correctIdx = int.parse(q['answer'] as String);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Q${i + 1}．${q['text']}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(options.length, (oi) {
                              final isCorrect = oi == correctIdx;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isCorrect
                                      ? Colors.green.shade50
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: isCorrect
                                      ? Border.all(
                                          color: Colors.green.shade300)
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    if (isCorrect)
                                      Icon(
                                        Icons.check_circle,
                                        size: 16,
                                        color: Colors.green.shade600,
                                      ),
                                    if (!isCorrect)
                                      Icon(
                                        Icons.radio_button_unchecked,
                                        size: 16,
                                        color: Colors.grey.shade400,
                                      ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        options[oi].toString(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isCorrect
                                              ? Colors.green.shade700
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (q['explanation'] != null &&
                                (q['explanation'] as String).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.amber.shade200,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      size: 16,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        q['explanation'] as String,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.amber.shade900,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
