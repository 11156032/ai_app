import 'dart:convert';

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'review_page.dart';

class QuestionPracticePage extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final int initialIndex;
  final String title;
  final Map<String, dynamic>? currentUser;
  final bool isPaper;
  final bool saveResult;

  const QuestionPracticePage({
    super.key,
    required this.questions,
    this.initialIndex = 0,
    this.title = '題目練習',
    this.currentUser,
    this.isPaper = false,
    this.saveResult = false,
  });

  @override
  State<QuestionPracticePage> createState() => _QuestionPracticePageState();
}

class _QuestionPracticePageState extends State<QuestionPracticePage> {
  late int _currentIndex;
  final Map<int, int> _selectedAnswers = {};
  final Set<int> _revealed = {};
  final Set<int> _marked = {};
  final Set<int> _wrongSaved = {};
  bool _isGridExpanded = false;
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
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
      if (!_isGridExpanded && _horizontalScrollController.hasClients) {
        const double itemWidth = 48.0; // 40px item + 8px margins
        final double viewportWidth = MediaQuery.of(context).size.width;
        // Center the active element in the viewport
        final double targetOffset = (itemWidth * _currentIndex) - (viewportWidth / 2) + (itemWidth / 2) + 16.0;
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

  String _questionChapter(Map<String, dynamic> question) {
    final chapter = question['chapter']?.toString() ?? '';
    return chapter.isEmpty ? '未分類' : chapter;
  }

  void _resetSession() {
    setState(() {
      _selectedAnswers.clear();
      _revealed.clear();
      _currentIndex = widget.questions.isEmpty
          ? 0
          : widget.initialIndex.clamp(0, widget.questions.length - 1);
    });
    _scrollToCurrentIndex();
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

    return InkWell(
      onTap: () => _updateCurrentIndex(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
    );
  }

  Widget _buildCollapsibleNavigationGrid(ColorScheme cs) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Icon(Icons.grid_view_rounded, color: cs.primary),
            title: Text(
              '題號快速跳轉 (${widget.questions.length} 題)',
              style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            trailing: TextButton(
              onPressed: () {
                setState(() {
                  _isGridExpanded = !_isGridExpanded;
                });
                if (!_isGridExpanded) {
                  _scrollToCurrentIndex();
                }
              },
              child: Text(
                _isGridExpanded ? '收起' : '展開',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _isGridExpanded
                ? GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: widget.questions.length,
                    itemBuilder: (context, index) {
                      return _buildNavigationItem(cs, index);
                    },
                  )
                : SizedBox(
                    height: 40,
                    child: ListView.builder(
                      controller: _horizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.questions.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: SizedBox(
                            width: 40,
                            child: _buildNavigationItem(cs, index),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
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
    final currentQid = currentQuestion['id'] as int? ?? int.tryParse(currentQuestion['id'].toString()) ?? 0;
    final options = _parseOptions(currentQuestion['options']);
    final answerIndex = _correctIndex(currentQuestion);
    final selectedIndex = _selectedAnswers[_currentIndex];
    final revealed = _revealed.contains(_currentIndex);
    final answeredCount = _selectedAnswers.length;
    final correctCount = widget.questions
        .asMap()
        .entries
        .where((entry) => _revealed.contains(entry.key) && _isCorrect(entry.key, entry.value))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        actions: [
          IconButton(
            tooltip: _marked.contains(currentQid) ? '取消標記' : '標記題目',
            onPressed: () async {
              // toggle bookmarked in DB and local state
              try {
                final db = await DatabaseHelper.instance.database;
                final nextVal = _marked.contains(currentQid) ? 0 : 1;
                await db.update('questions', {'bookmarked': nextVal}, where: 'id = ?', whereArgs: [currentQid]);
                setState(() {
                  if (nextVal == 1) {
                    _marked.add(currentQid);
                  } else {
                    _marked.remove(currentQid);
                  }
                });
              } catch (e) {
                debugPrint('切換收藏失敗: $e');
              }
            },
            icon: Icon(_marked.contains(currentQid) ? Icons.bookmark : Icons.bookmark_outline),
          ),
          IconButton(
            tooltip: '加入筆記',
            onPressed: () => _addNoteDialog(currentQuestion),
            icon: const Icon(Icons.note_add_rounded),
          ),
          IconButton(
            tooltip: '重新開始',
            onPressed: _resetSession,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  cs.primary,
                  cs.primary.withValues(alpha: 0.82),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '練習進度',
                        style: TextStyle(
                          color: cs.onPrimary.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_currentIndex + 1} / ${widget.questions.length}',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: (widget.questions.isEmpty)
                              ? 0
                              : (_currentIndex + 1) / widget.questions.length,
                          backgroundColor: cs.onPrimary.withValues(alpha: 0.16),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(cs.onPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SummaryChip(label: '已作答', value: '$answeredCount', foreground: cs.onPrimary),
                    const SizedBox(height: 8),
                    _SummaryChip(label: '正確', value: '$correctCount', foreground: cs.onPrimary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildCollapsibleNavigationGrid(cs),
          const SizedBox(height: 16),
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
                  children: [
                    _TagChip(label: currentQuestion['subject']?.toString() ?? '未分類', color: cs.primary),
                    const SizedBox(width: 8),
                    _TagChip(label: _questionChapter(currentQuestion), color: cs.secondary),
                    const SizedBox(width: 8),
                    _TagChip(label: currentQuestion['difficulty']?.toString() ?? '中', color: cs.tertiary),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  currentQuestion['type']?.toString() ?? '單選題',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
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
                      ? null
                      : () => _updateCurrentIndex(_currentIndex + 1),
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: Text(
                    _currentIndex >= widget.questions.length - 1 ? '已到底' : '下一題',
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
          const SizedBox(height: 12),
          // 交卷按鈕
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _selectedAnswers.isEmpty ? null : _submitPaper,
              icon: const Icon(Icons.send_rounded),
              label: const Text('交卷並檢討'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_currentIndex == widget.questions.length - 1 && revealed)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本次練習完成',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '答對 $correctCount 題，共 ${widget.questions.length} 題。',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _addNoteDialog(Map<String, dynamic> question) async {
    final titleCtrl = TextEditingController(text: '筆記：題 ${question['id'] ?? ''}');
    final contentCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('加入筆記'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '標題')),
            const SizedBox(height: 8),
            TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: '內容'), minLines: 3, maxLines: 6),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('儲存')),
        ],
      ),
    );

    if (result != true) return;
    final uid = widget.currentUser?['id'] ?? widget.currentUser?['user_id'] ?? 'u1';
    try {
      await DatabaseHelper.instance.createNote(uid.toString(), titleCtrl.text.trim(), contentCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('筆記已儲存')));
    } catch (e) {
      debugPrint('儲存筆記失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('儲存失敗')));
    }
  }

  Future<void> _submitPaper() async {
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
      try {
        final db = await DatabaseHelper.instance.database;
        await db.insert('quiz_results', {
          'user_id': uid.toString(),
          'total': total,
          'correct': correct,
          'wrong_question_ids': jsonEncode(wrongIds),
          'duration_seconds': 0,
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('Saved paper quiz result to history.');
      } catch (e) {
        debugPrint('Failed to save paper quiz result: $e');
      }
    }

    if (!mounted) return;
    final action = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('成績：$correct / $total'),
        content: const Text('你可以檢視答案與解析，或進入檢討頁加入錯題與筆記。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'close'), child: const Text('關閉')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'reveal'), child: const Text('直接顯示答案')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, 'review'), child: const Text('檢視並檢討')),
        ],
      ),
    );

    if (action == 'reveal') {
      final uid = widget.currentUser?['id'] ?? widget.currentUser?['user_id'];
      setState(() {
        for (int i = 0; i < widget.questions.length; i++) {
          _revealed.add(i);
          if (uid != null && widget.saveResult) {
            final q = widget.questions[i];
            final qid = q['id'] as int? ?? int.tryParse(q['id'].toString()) ?? 0;
            final ans = _selectedAnswers[i];
            final correctIdx = _correctIndex(q);
            if (ans != null && ans != correctIdx && qid > 0 && !_wrongSaved.contains(qid)) {
              DatabaseHelper.instance.addWrongQuestion(uid.toString(), qid);
              _wrongSaved.add(qid);
            }
          }
        }
      });
      return;
    }

    if (action == 'review') {
      // build selected answers map keyed by index
      final Map<int,int> sel = {};
      for (int i = 0; i < widget.questions.length; i++) {
        if (_selectedAnswers.containsKey(i)) sel[i] = _selectedAnswers[i]!;
      }
      if (!mounted) return;
      Navigator.push(
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
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color foreground;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TagChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
