import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import 'review_page.dart';

class QuestionPracticePage extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final int initialIndex;
  final String title;
  final Map<String, dynamic>? currentUser;
  final bool isPaper;
  final bool saveResult;
  final String? subject;
  final int? paperId;

  const QuestionPracticePage({
    super.key,
    required this.questions,
    this.initialIndex = 0,
    this.title = '題目練習',
    this.currentUser,
    this.isPaper = false,
    this.saveResult = false,
    this.subject,
    this.paperId,
  });

  @override
  State<QuestionPracticePage> createState() => _QuestionPracticePageState();
}

class _QuestionPracticePageState extends State<QuestionPracticePage> {
  late int _currentIndex;
  late final DateTime _practiceStartTime;
  final Map<int, int> _selectedAnswers = {};
  final Set<int> _revealed = {};
  final Set<int> _marked = {};
  final Set<int> _flagged = {};
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _practiceStartTime = DateTime.now();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _currentIndex = widget.questions.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.questions.length - 1);
    for (final q in widget.questions) {
      final id = q['id'] as int? ?? int.tryParse(q['id'].toString()) ?? 0;
      if (q['isFavorite'] == true) _marked.add(id);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentIndex();
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentIndex() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_horizontalScrollController.hasClients) {
        const double itemWidth = 46.0; // 38px item + 8px margins (4px left + 4px right)
        final double viewportWidth = MediaQuery.of(context).size.width;
        // Center the active element in the viewport
        final double targetOffset = (itemWidth * _currentIndex) - (viewportWidth / 2) + (itemWidth / 2) + 12.0;
        _horizontalScrollController.animateTo(
          targetOffset.clamp(0.0, _horizontalScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _updateCurrentIndex(int index) {
    if (index < 0 || index >= widget.questions.length) return;
    setState(() {
      _currentIndex = index;
    });
    _scrollToCurrentIndex();
  }

  List<String> _parseOptions(dynamic rawOptions) {
    if (rawOptions is List) {
      return rawOptions.map((item) => item.toString()).toList();
    }
    if (rawOptions is String && rawOptions.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawOptions);
        if (decoded is List) {
          return decoded.map((item) => item.toString()).toList();
        }
      } catch (_) {
        return rawOptions
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '')
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  int _correctIndex(Map<String, dynamic> question) {
    final raw = question['answerIndex'] ?? question['answer'] ?? 0;
    return int.tryParse(raw.toString()) ?? 0;
  }

  String _questionText(Map<String, dynamic> question) {
    return (question['question'] ?? question['text'] ?? '').toString();
  }



  Widget _buildNavigationItem(ColorScheme cs, int index) {
    final isCurrent = index == _currentIndex;
    final hasAnswered = _selectedAnswers.containsKey(index);
    final isRevealed = _revealed.contains(index);
    
    Color bgColor;
    Color textColor;
    Border? border;

    if (isCurrent) {
      bgColor = cs.primary;
      textColor = cs.onPrimary;
      border = Border.all(color: cs.primary, width: 2);
    } else if (hasAnswered) {
      if (isRevealed) {
        final question = widget.questions[index];
        final correct = _isCorrect(index, question);
        if (correct) {
          bgColor = Colors.green.withValues(alpha: 0.15);
          textColor = Colors.green.shade800;
          border = Border.all(color: Colors.green.withValues(alpha: 0.5));
        } else {
          bgColor = Colors.red.withValues(alpha: 0.15);
          textColor = Colors.red.shade800;
          border = Border.all(color: Colors.red.withValues(alpha: 0.5));
        }
      } else {
        bgColor = cs.primaryContainer.withValues(alpha: 0.7);
        textColor = cs.onPrimaryContainer;
        border = Border.all(color: cs.primary.withValues(alpha: 0.2));
      }
    } else {
      bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.4);
      textColor = cs.onSurfaceVariant;
      border = Border.all(color: cs.outline.withValues(alpha: 0.12));
    }

    final isFlagged = _flagged.contains(index);

    return InkWell(
      onTap: () {
        _updateCurrentIndex(index);
      },
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: border,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (isFlagged)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFixedTopNavigationRow(ColorScheme cs) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.12))),
      ),
      child: ListView.builder(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: widget.questions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              width: 38,
              child: _buildNavigationItem(cs, index),
            ),
          );
        },
      ),
    );
  }

  bool _isCorrect(int index, Map<String, dynamic> question) {
    if (!_selectedAnswers.containsKey(index)) return false;
    return _selectedAnswers[index] == _correctIndex(question);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
        ),
        body: Center(
          child: Text(
            '目前沒有可練習的題目',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
          ),
        ),
      );
    }

    final currentQuestion = widget.questions[_currentIndex];
    final options = _parseOptions(currentQuestion['options']);
    final answerIndex = _correctIndex(currentQuestion);
    final selectedIndex = _selectedAnswers[_currentIndex];
    final revealed = _revealed.contains(_currentIndex);
    final answeredCount = _selectedAnswers.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          TextButton(
            onPressed: _selectedAnswers.isEmpty ? null : _submitPaper,
            child: Text(
              '交卷',
              style: TextStyle(
                color: _selectedAnswers.isEmpty
                    ? cs.onPrimary.withValues(alpha: 0.5)
                    : cs.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFixedTopNavigationRow(cs),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.questions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '答題進度',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$answeredCount / ${widget.questions.length}',
                              style: TextStyle(
                                color: cs.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            value: widget.questions.isEmpty
                                ? 0
                                : answeredCount / widget.questions.length,
                            backgroundColor: cs.outline.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '第 ${_currentIndex + 1} 題  •  ${currentQuestion['type']?.toString() ?? '單選題'}',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    IconButton(
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      tooltip: _flagged.contains(_currentIndex) ? '取消標記' : '標記此題',
                      onPressed: () {
                        setState(() {
                          if (_flagged.contains(_currentIndex)) {
                            _flagged.remove(_currentIndex);
                          } else {
                            _flagged.add(_currentIndex);
                          }
                        });
                      },
                      icon: Icon(
                        _flagged.contains(_currentIndex)
                            ? Icons.flag_rounded
                            : Icons.flag_outlined,
                      ),
                      color: _flagged.contains(_currentIndex)
                          ? Colors.orange.shade700
                          : cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _questionText(currentQuestion).isEmpty
                      ? '題目內容遺失'
                      : _questionText(currentQuestion),
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    height: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '請選擇答案',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (options.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
              ),
              child: Text(
                '這題沒有設定選項，請直接閱讀解析。',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
              ),
            )
          else
            ...List.generate(options.length, (index) {
              final isSelected = selectedIndex == index;
              final isCorrect = revealed && index == answerIndex;
              final isWrongSelection = revealed && isSelected && !isCorrect;
              final borderColor = isCorrect
                  ? Colors.green
                  : isWrongSelection
                      ? Colors.red
                      : (isSelected ? cs.primary : cs.outline.withValues(alpha: 0.18));
              final backgroundColor = isCorrect
                  ? Colors.green.withValues(alpha: 0.08)
                  : isWrongSelection
                      ? Colors.red.withValues(alpha: 0.08)
                      : isSelected
                          ? cs.primary.withValues(alpha: 0.08)
                          : cs.surface;

              return GestureDetector(
                onTap: revealed
                    ? null
                    : () => setState(() {
                          _selectedAnswers[_currentIndex] = index;
                        }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor, width: 1.4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: borderColor,
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index),
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          options[index],
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      if (revealed && isCorrect)
                        Icon(Icons.check_circle_rounded, color: Colors.green.shade700)
                      else if (revealed && isWrongSelection)
                        Icon(Icons.cancel_rounded, color: Colors.red.shade700),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
          if (revealed)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (selectedIndex == answerIndex)
                    ? Colors.green.withValues(alpha: 0.08)
                    : Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: (selectedIndex == answerIndex) ? Colors.green : Colors.red,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        (selectedIndex == answerIndex)
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        color: (selectedIndex == answerIndex)
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        (selectedIndex == answerIndex) ? '答對了' : '再想想',
                        style: TextStyle(
                          color: (selectedIndex == answerIndex)
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '正確答案：${String.fromCharCode(65 + answerIndex)} ${options.isNotEmpty && answerIndex < options.length ? options[answerIndex] : ''}',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if ((currentQuestion['explanation'] ?? '').toString().trim().isNotEmpty)
                    Text(
                      currentQuestion['explanation'].toString(),
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.8),
                        height: 1.6,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _currentIndex == 0
                      ? null
                      : () => _updateCurrentIndex(_currentIndex - 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('上一題'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _currentIndex >= widget.questions.length - 1
                      ? (_selectedAnswers.isEmpty ? null : _submitPaper)
                      : () => _updateCurrentIndex(_currentIndex + 1),
                  icon: Icon(
                    _currentIndex >= widget.questions.length - 1
                        ? Icons.send_rounded
                        : Icons.chevron_right_rounded,
                  ),
                  label: Text(
                    _currentIndex >= widget.questions.length - 1 ? '確認交卷' : '下一題',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  ],
),
    );
  }


  Future<void> _submitPaper() async {
    final unanswered = widget.questions.length - _selectedAnswers.length;
    final flaggedCount = _flagged.length;

    String contentText;
    if (unanswered > 0 && flaggedCount > 0) {
      contentText = '您還有 $unanswered 題尚未作答，且尚有 $flaggedCount 題已標記的題目，確定要結束作答並直接交卷嗎？';
    } else if (unanswered > 0) {
      contentText = '您還有 $unanswered 題尚未作答，確定要結束作答並直接交卷嗎？';
    } else if (flaggedCount > 0) {
      contentText = '您尚有 $flaggedCount 題標記的題目，確定要交卷並查看檢討報告嗎？';
    } else {
      contentText = '確定要交卷並查看檢討報告嗎？';
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('確認交卷'),
          ],
        ),
        content: Text(
          contentText,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('繼續作答', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('確認交卷'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final total = widget.questions.length;
    int correct = 0;
    final wrongIds = <int>[];
    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final qid = q['id'] as int? ?? int.tryParse(q['id'].toString()) ?? 0;
      final ans = _selectedAnswers[i];
      final correctIdx = _correctIndex(q);
      if (ans != null && ans == correctIdx) {
        correct++;
      }
      if (ans != null && ans != correctIdx) {
        wrongIds.add(qid);
      }
    }

    if (widget.saveResult && widget.currentUser != null) {
      final uid = widget.currentUser?['id'] ?? widget.currentUser?['user_id'] ?? 'u1';
      final int durationSeconds = DateTime.now().difference(_practiceStartTime).inSeconds.clamp(1, 86400);
      try {
        final db = await DatabaseHelper.instance.database;
        await db.insert('quiz_results', <String, Object?>{
          'user_id': uid.toString(),
          'total': total,
          'correct': correct,
          'wrong_question_ids': jsonEncode(wrongIds),
          'duration_seconds': durationSeconds,
          'subject': widget.subject ?? widget.title,
          'paper_id': widget.paperId,
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('Saved paper quiz result to history.');

        // 自動將所有錯題存入錯題本中
        for (final qid in wrongIds) {
          if (qid > 0) {
            await DatabaseHelper.instance.addWrongQuestion(uid.toString(), qid);
          }
        }
        debugPrint('Auto-saved wrong questions to wrong questions book.');
      } catch (e) {
        debugPrint('Failed to save paper quiz result: $e');
      }
    }

    if (!mounted) return;
    final Map<int, int> sel = {};
    for (int i = 0; i < widget.questions.length; i++) {
      if (_selectedAnswers.containsKey(i)) sel[i] = _selectedAnswers[i]!;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewPage(
          questions: widget.questions,
          selectedAnswers: sel,
          currentUser: widget.currentUser,
          saveResult: widget.saveResult,
        ),
      ),
    );
  }
}




