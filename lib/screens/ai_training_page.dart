import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/ai_diagnosis_service.dart';

class AiTrainingPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final String weakestSubject;
  final List<Map<String, dynamic>> subjectStats;
  final List<Map<String, dynamic>> questionBank;

  const AiTrainingPage({
    super.key,
    required this.currentUser,
    required this.weakestSubject,
    required this.subjectStats,
    required this.questionBank,
  });

  @override
  State<AiTrainingPage> createState() => _AiTrainingPageState();
}

class _AiTrainingPageState extends State<AiTrainingPage>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────
  bool _isLoading = true;
  String _loadingStatus = 'AI 正在為您規劃今日特訓...';
  List<_TrainingQuestion> _questions = [];
  int _currentIndex = 0;
  int _selectedOption = -1;
  bool _answered = false;
  int _correctCount = 0;
  bool _finished = false;
  String _aiFeedback = '';
  bool _isLoadingFeedback = false;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _generateQuestions();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Generate questions via AI ──────────────────────────────────────
  Future<void> _generateQuestions() async {
    // Build subject focus info
    final focus = widget.weakestSubject.isNotEmpty
        ? widget.weakestSubject
        : (widget.subjectStats.isNotEmpty
            ? widget.subjectStats.first['subject'] as String
            : '綜合練習');

    final statsInfo = widget.subjectStats.isEmpty
        ? '使用者尚無答題紀錄'
        : widget.subjectStats
            .take(3)
            .map((s) =>
                '${s['subject']}: 正確率${((s['accuracy'] as double) * 100).toStringAsFixed(0)}%')
            .join('，');

    final prompt = '''
你是一位出題老師。請為以下學生出 5 道繁體中文選擇題，重點科目：$focus。
學生數據：$statsInfo

題目要求：
- 每題都有 4 個選項 (A/B/C/D)
- 難度適中，針對 $focus 的核心概念
- 嚴格輸出合法 JSON 陣列，格式如下，不要有任何其他文字：

[
  {
    "question": "題目內容",
    "options": ["A. 選項一", "B. 選項二", "C. 選項三", "D. 選項四"],
    "answer": 0,
    "explanation": "解析說明"
  }
]

answer 為正確選項的 index（0=A, 1=B, 2=C, 3=D）。
''';

    try {
      setState(() => _loadingStatus = 'AI 正在生成專屬題目，請稍候...');
      final buffer = StringBuffer();
      await for (final chunk
          in AiDiagnosisService.generateOpenRouterGuideStream(
        userInput: prompt,
        history: const [],
        customSystemPrompt: '你是出題老師，只輸出合法 JSON 陣列，不輸出其他文字。',
      )) {
        buffer.write(chunk.text);
      }

      final raw = AiDiagnosisService.cleanThinkingTags(buffer.toString());
      // Extract JSON array
      final jsonMatch =
          RegExp(r'\[.*\]', dotAll: true).firstMatch(raw);
      if (jsonMatch != null) {
        final decoded =
            json.decode(jsonMatch.group(0)!) as List<dynamic>;
        final questions = decoded.map((item) {
          final m = item as Map<String, dynamic>;
          return _TrainingQuestion(
            question: m['question'] as String? ?? '',
            options: (m['options'] as List<dynamic>)
                .map((o) => o.toString())
                .toList(),
            answer: (m['answer'] as num?)?.toInt() ?? 0,
            explanation: m['explanation'] as String? ?? '',
          );
        }).toList();

        if (mounted) {
          setState(() {
            _questions = questions;
            _isLoading = false;
          });
          _slideCtrl.forward();
        }
        return;
      }
    } catch (e) {
      debugPrint('AI question generation error: $e');
    }

    // Fallback: use existing question bank questions
    if (widget.questionBank.isNotEmpty) {
      final bank = [...widget.questionBank]..shuffle();
      final fallback = bank.take(5).map((q) {
        List<String> opts = [];
        try {
          final raw = q['options'];
          if (raw is String) {
            opts = (json.decode(raw) as List).map((o) => o.toString()).toList();
          } else if (raw is List) {
            opts = raw.map((o) => o.toString()).toList();
          }
        } catch (_) {}
        int ans = 0;
        try {
          final answerRaw = q['answer']?.toString() ?? 'A';
          ans = 'ABCD'.indexOf(answerRaw.toUpperCase().trim());
          if (ans < 0) ans = 0;
        } catch (_) {}
        return _TrainingQuestion(
          question: q['text'] as String? ?? '題目載入失敗',
          options: opts.isNotEmpty
              ? opts
              : ['A. 選項A', 'B. 選項B', 'C. 選項C', 'D. 選項D'],
          answer: ans,
          explanation: q['explanation'] as String? ?? '',
        );
      }).toList();

      if (mounted) {
        setState(() {
          _questions = fallback;
          _isLoading = false;
          _loadingStatus = '已載入題庫題目';
        });
        _slideCtrl.forward();
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingStatus = '載入失敗，請稍後再試';
        });
      }
    }
  }

  // ── Answer logic ────────────────────────────────────────────────────
  void _selectOption(int idx) {
    if (_answered) return;
    final isCorrect = idx == _questions[_currentIndex].answer;
    setState(() {
      _selectedOption = idx;
      _answered = true;
      if (isCorrect) _correctCount++;
    });
  }

  void _nextQuestion() {
    if (_currentIndex >= _questions.length - 1) {
      _finishTraining();
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedOption = -1;
      _answered = false;
    });
    _slideCtrl.reset();
    _slideCtrl.forward();
  }

  Future<void> _finishTraining() async {
    setState(() {
      _finished = true;
      _isLoadingFeedback = true;
    });

    final pct = (_correctCount / _questions.length * 100).round();
    final prompt =
        '學生在「${widget.weakestSubject.isNotEmpty ? widget.weakestSubject : "綜合"}」專題特訓中答對 $_correctCount/${_questions.length} 題（$pct 分）。請用1~2句繁體中文給予具體鼓勵與學習建議。';
    try {
      final buffer = StringBuffer();
      await for (final chunk
          in AiDiagnosisService.generateOpenRouterGuideStream(
        userInput: prompt,
        history: const [],
        customSystemPrompt: '你是鼓勵學生的老師，用1~2句繁體中文給予鼓勵與建議。',
      )) {
        buffer.write(chunk.text);
      }
      final feedback =
          AiDiagnosisService.cleanThinkingTags(buffer.toString()).trim();
      if (mounted) {
        setState(() {
          _aiFeedback = feedback.isNotEmpty ? feedback : _defaultFeedback(pct);
          _isLoadingFeedback = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiFeedback = _defaultFeedback(pct);
          _isLoadingFeedback = false;
        });
      }
    }
  }

  String _defaultFeedback(int pct) {
    if (pct >= 80) return '太棒了！本次特訓表現優異，繼續保持這樣的學習節奏！';
    if (pct >= 60) return '不錯的表現！建議針對答錯的題目再複習一次，會進步更快！';
    return '加油！每一次練習都是進步的基石，建議再複習相關概念後重新挑戰！';
  }

  // ── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    const primaryBrown = Color(0xFF6D5448);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.weakestSubject.isNotEmpty ? '${widget.weakestSubject} 專屬特訓' : '今日專屬特訓',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _finished
              ? _buildResultView(isDark)
              : _buildQuizView(isDark),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6D5448).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Text('🤖', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: Color(0xFF6D5448)),
          const SizedBox(height: 16),
          Text(_loadingStatus,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildQuizView(bool isDark) {
    if (_questions.isEmpty) {
      return const Center(
        child: Text('無法載入題目，請稍後再試',
            style: TextStyle(color: Colors.grey)),
      );
    }

    final q = _questions[_currentIndex];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    const primary = Color(0xFF6D5448);

    return Column(
      children: [
        // Progress bar
        Container(
          color: primary,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('第 ${_currentIndex + 1} / ${_questions.length} 題',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  Text('✓ $_correctCount 題正確',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentIndex + 1) / _questions.length,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Text(q.question,
                        style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            height: 1.6,
                            fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 16),
                  // Options
                  ...List.generate(q.options.length, (i) {
                    Color optionBg = cardColor;
                    Color optionBorder = Colors.transparent;
                    Color optionText = textColor;

                    if (_answered) {
                      if (i == q.answer) {
                        optionBg = Colors.green.withValues(alpha: 0.15);
                        optionBorder = Colors.green;
                        optionText = Colors.green.shade700;
                      } else if (i == _selectedOption) {
                        optionBg = Colors.red.withValues(alpha: 0.12);
                        optionBorder = Colors.red.shade300;
                        optionText = Colors.red.shade700;
                      }
                    } else if (_selectedOption == i) {
                      optionBg = primary.withValues(alpha: 0.12);
                      optionBorder = primary;
                    }

                    return GestureDetector(
                      onTap: () => _selectOption(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: optionBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: optionBorder, width: 2),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _answered && i == q.answer
                                    ? Colors.green
                                    : _answered && i == _selectedOption
                                        ? Colors.red
                                        : primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: _answered && i == q.answer
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 16)
                                    : _answered && i == _selectedOption
                                        ? const Icon(Icons.close,
                                            color: Colors.white, size: 16)
                                        : Text('ABCD'[i],
                                            style: TextStyle(
                                                color: primary,
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(q.options[i],
                                  style: TextStyle(
                                      color: optionText, fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  // Explanation (shown after answered)
                  if (_answered && q.explanation.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.blue, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(q.explanation,
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.blue.shade200
                                        : Colors.blue.shade800,
                                    fontSize: 13,
                                    height: 1.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Next button
                  if (_answered)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _nextQuestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          _currentIndex < _questions.length - 1
                              ? '下一題 →'
                              : '查看結果 🎉',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    const primary = Color(0xFF6D5448);
    final pct = _questions.isNotEmpty
        ? (_correctCount / _questions.length * 100).round()
        : 0;

    Color scoreColor;
    String scoreEmoji;
    if (pct >= 80) {
      scoreColor = Colors.green;
      scoreEmoji = '🏆';
    } else if (pct >= 60) {
      scoreColor = Colors.orange;
      scoreEmoji = '👍';
    } else {
      scoreColor = Colors.red.shade400;
      scoreEmoji = '💪';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Score circle
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scoreColor.withValues(alpha: 0.1),
              border: Border.all(color: scoreColor, width: 4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(scoreEmoji, style: const TextStyle(fontSize: 32)),
                Text('$pct',
                    style: TextStyle(
                        color: scoreColor,
                        fontSize: 36,
                        fontWeight: FontWeight.bold)),
                Text('分', style: TextStyle(color: scoreColor, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('特訓完成！',
              style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('答對 $_correctCount / ${_questions.length} 題',
              style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 24),
          // AI feedback card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        color: Color(0xFF6D5448), size: 18),
                    SizedBox(width: 8),
                    Text('AI 老師的話',
                        style: TextStyle(
                            color: Color(0xFF6D5448),
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoadingFeedback)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Color(0xFF6D5448)),
                    ),
                  )
                else
                  Text(_aiFeedback,
                      style: TextStyle(
                          color: textColor, fontSize: 14, height: 1.7)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6D5448)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('返回',
                      style: TextStyle(
                          color: Color(0xFF6D5448),
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentIndex = 0;
                      _selectedOption = -1;
                      _answered = false;
                      _correctCount = 0;
                      _finished = false;
                      _isLoading = true;
                      _aiFeedback = '';
                    });
                    _generateQuestions();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('再來一輪',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrainingQuestion {
  final String question;
  final List<String> options;
  final int answer;
  final String explanation;

  const _TrainingQuestion({
    required this.question,
    required this.options,
    required this.answer,
    required this.explanation,
  });
}
