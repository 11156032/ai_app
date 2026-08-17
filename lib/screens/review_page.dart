import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../services/ai_diagnosis_service.dart';

class ReviewPage extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final Map<int, int> selectedAnswers;
  final Map<String, dynamic>? currentUser;
  final bool saveResult;

  const ReviewPage({
    super.key,
    required this.questions,
    required this.selectedAnswers,
    this.currentUser,
    this.saveResult = false,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage>
    with SingleTickerProviderStateMixin {
  final Set<int> _toSaveWrong = {};
  final Map<int, TextEditingController> _noteCtrls = {};
  bool _saving = false;
  // bool _isAnalyzing = false;
  // DiagnosisResult? _diagnosisResult;
  // late AnimationController _animController;
  // late Animation<double> _fadeAnim;
  late final List<GlobalKey> _itemKeys;
  final Set<int> _bookmarkedQids = {};
  bool _showOnlyWrong = false;
  final Map<int, String> _cachedAiExplanations = {};

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _itemKeys = List.generate(widget.questions.length, (_) => GlobalKey());
    for (int i = 0; i < widget.questions.length; i++) {
      _noteCtrls[i] = TextEditingController();
      final q = widget.questions[i];

      // 答錯或未答題目預設加入錯題本勾選集合
      final correct = _correctIndex(q);
      final chosen = widget.selectedAnswers[i];
      if (chosen == null || chosen != correct) {
        _toSaveWrong.add(i);
      }

      final isFav = q['isFavorite'] == true ||
          q['bookmarked'] == 1 ||
          (q['bookmarked'] is bool && q['bookmarked'] == true);
      if (isFav) {
        final qid = q['id'] as int? ?? int.tryParse(q['id'].toString()) ?? 0;
        if (qid > 0) {
          _bookmarkedQids.add(qid);
        }
      }
    }
    // _animController = AnimationController(
    //     vsync: this, duration: const Duration(milliseconds: 600));
    // _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    // _animController.dispose();
    for (final c in _noteCtrls.values) {
      c.dispose();
    }
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
      return raw
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
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
        final qid = q['id'] is int
            ? q['id'] as int
            : int.tryParse(q['id'].toString()) ?? 0;
        if (qid > 0) {
          if (_toSaveWrong.contains(i)) {
            try {
              await DatabaseHelper.instance.addWrongQuestion(
                  uid.toString(), qid,
                  note: _noteCtrls[i]?.text ?? '');
            } catch (_) {}
          } else {
            // 如果使用者手動取消勾選，則將其自資料庫的錯題本移除
            try {
              final db = await DatabaseHelper.instance.database;
              await db.delete(
                'wrong_questions',
                where: 'user_id = ? AND question_id = ?',
                whereArgs: [uid.toString(), qid],
              );
            } catch (_) {}
          }
        }
        final noteText = _noteCtrls[i]?.text.trim();
        if (noteText != null && noteText.isNotEmpty) {
          try {
            await DatabaseHelper.instance
                .createNote(uid.toString(), '筆記：題 $qid', noteText);
          } catch (_) {}
        }
      }
    }
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('已儲存錯題與筆記'),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /*
  Future<void> _generateDiagnosis() async {
    setState(() => _isAnalyzing = true);
    final uid = widget.currentUser?['id'] ?? widget.currentUser?['user_id'] ?? 'u4';

    final wrongQuestions = <Map<String, dynamic>>[];
    final correctQuestions = <Map<String, dynamic>>[];
    for (int i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      final correct = _correctIndex(q);
      final chosen = widget.selectedAnswers[i];
      if (chosen != null && chosen == correct) {
        correctQuestions.add(q);
      } else {
        wrongQuestions.add(q);
      }
    }

    try {
      final res = await AiDiagnosisService.generate(
        userId: uid.toString(),
        wrongQuestions: wrongQuestions,
        correctQuestions: correctQuestions,
        score: widget.questions.isEmpty
            ? 0
            : (correctQuestions.length / widget.questions.length * 100).round(),
        total: widget.questions.length,
        subject: '題目練習',
      );
      if (mounted) {
        setState(() {
          _diagnosisResult = res;
          _isAnalyzing = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('分析失敗：$e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  */

  void _showAiExplanationSheet(
      BuildContext context, int qIdx, Map<String, dynamic> q, int correctIndex, int? chosenIndex) {
    final uid = widget.currentUser?['id'] ?? widget.currentUser?['user_id'] ?? 'u4';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AiExplanationSheet(
          question: q,
          correctIndex: correctIndex,
          chosenIndex: chosenIndex,
          userId: uid.toString(),
          cachedText: _cachedAiExplanations[qIdx],
          onSaveCache: (text) {
            _cachedAiExplanations[qIdx] = text;
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final correctCount = widget.selectedAnswers.entries
        .where((e) => _correctIndex(widget.questions[e.key]) == e.value)
        .length;
    final total = widget.questions.length;
    final score = total == 0 ? 0 : (correctCount / total * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title:
            const Text('交卷檢討', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: '回到題庫頁面',
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          // ── Score Banner ──
          Container(
            margin: const EdgeInsets.only(bottom: 16, top: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('本次測驗成績',
                          style: TextStyle(
                              color: cs.onPrimary.withValues(alpha: 0.8),
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('$score 分',
                          style: TextStyle(
                              color: cs.onPrimary,
                              fontSize: 36,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text('答對 $correctCount / $total 題',
                          style: TextStyle(
                              color: cs.onPrimary.withValues(alpha: 0.85),
                              fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Circular progress
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: total == 0 ? 0 : correctCount / total,
                        strokeWidth: 7,
                        backgroundColor: cs.onPrimary.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                      ),
                      Text(
                          '${total == 0 ? 0 : (correctCount / total * 100).round()}%',
                          style: TextStyle(
                              color: cs.onPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Switch & Title Row ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('題目詳解 (${widget.questions.length} 題)',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor)),
                Row(
                  children: [
                    Text(
                      '只看錯題',
                      style: TextStyle(
                        fontSize: 14,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: _showOnlyWrong,
                      activeThumbColor: Theme.of(context).primaryColor,
                      onChanged: (val) {
                        setState(() {
                          _showOnlyWrong = val;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Question Cards ──
          for (int i = 0; i < widget.questions.length; i++) ...[
            Builder(
              builder: (context) {
                final q = widget.questions[i];
                final options = _parseOptions(q['options']);
                final correct = _correctIndex(q);
                final chosen = widget.selectedAnswers[i];
                final isWrong = chosen != null && chosen != correct;
                final isIncorrect = chosen == null || chosen != correct;

                if (_showOnlyWrong && !isIncorrect) {
                  return const SizedBox.shrink();
                }

                return _buildQuestionCard(
                    cs, i, q, options, correct, chosen, isWrong);
              },
            ),
          ],
        ],
      ),
      bottomNavigationBar: widget.saveResult
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveSelectedWrongAndNotes,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? '儲存中...' : '儲存錯題與筆記',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  /*
  Widget _buildCallToAction(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Theme.of(context).primaryColor, Color(0xFFBCAAA4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _generateDiagnosis,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('取得 AI 學習診斷',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('讓 AI 分析您的弱點並給予個人化建議',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withValues(alpha: 0.7), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzingCard(ColorScheme cs) {
    return const _ReviewDiagnosisLoadingProgress();
  }

  Widget _buildDiagnosisCard(ColorScheme cs) {
    final d = _diagnosisResult!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header gradient bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
               gradient: LinearGradient(
                 colors: [Theme.of(context).primaryColor, Color(0xFFBCAAA4)],
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
               ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('AI 學習診斷報告',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    d.isAiGenerated ? 'AI 生成' : '本機分析',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Summary ──
                _DiagnosisSection(
                  icon: Icons.summarize_rounded,
                  iconColor: Theme.of(context).primaryColor,
                  bgColor: const Color(0xFFF5F0EB),
                  title: '整體摘要',
                  child: Text(d.summary,
                      style: const TextStyle(
                          fontSize: 14, height: 1.65, color: Color(0xFF333333))),
                ),

                if (d.weaknesses.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  // ── Weaknesses ──
                  _DiagnosisSection(
                    icon: Icons.warning_amber_rounded,
                    iconColor: const Color(0xFFD84040),
                    bgColor: const Color(0xFFFFF0F0),
                    title: '需加強弱項',
                    child: Column(
                      children: d.weaknesses
                          .map((w) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(top: 5),
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFD84040),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Text(w,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                height: 1.55,
                                                color: Color(0xFF333333)))),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],

                if (d.suggestion.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  // ── Suggestion ──
                  _DiagnosisSection(
                    icon: Icons.lightbulb_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    bgColor: const Color(0xFFFFFBEB),
                    title: '學習建議',
                    child: Text(d.suggestion,
                        style: const TextStyle(
                            fontSize: 14, height: 1.65, color: Color(0xFF333333))),
                  ),
                ],

                if (d.encouragement.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  // ── Encouragement ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF0FDF4), Color(0xFFEFFAFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💪', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(d.encouragement,
                              style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: Color(0xFF166534),
                                  fontStyle: FontStyle.italic)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                // Re-run button
                OutlinedButton.icon(
                  onPressed: _isAnalyzing ? null : () {
                    setState(() => _diagnosisResult = null);
                    _animController.reset();
                    _generateDiagnosis();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('重新分析'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).primaryColor,
                    side: const BorderSide(color: Theme.of(context).primaryColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  */

  Widget _buildQuestionCard(ColorScheme cs, int qIdx, Map<String, dynamic> q,
      List<String> options, int correct, int? chosen, bool isWrong) {
    final qid = q['id'] as int? ?? int.tryParse(q['id'].toString()) ?? 0;
    final bool isFav = qid > 0 && _bookmarkedQids.contains(qid);
    final bool isUnanswered = chosen == null;
    final bool isCorrect = chosen != null && chosen == correct;

    // Define colors/icons based on state
    final Color borderClr;
    final Color headerBgClr;
    final Color badgeBgClr;
    final IconData statusIcon;
    final String statusText;
    final Color statusTextColor;

    if (isUnanswered) {
      borderClr = cs.outline.withValues(alpha: 0.15);
      headerBgClr = cs.surfaceContainerHighest.withValues(alpha: 0.3);
      badgeBgClr = cs.outline.withValues(alpha: 0.5);
      statusIcon = Icons.remove_rounded;
      statusText = '未作答';
      statusTextColor = cs.onSurfaceVariant;
    } else if (isCorrect) {
      borderClr = Colors.green.withValues(alpha: 0.25);
      headerBgClr = Colors.green.withValues(alpha: 0.06);
      badgeBgClr = Colors.green;
      statusIcon = Icons.check_rounded;
      statusText = '答對';
      statusTextColor = Colors.green.shade700;
    } else {
      borderClr = Colors.red.withValues(alpha: 0.25);
      headerBgClr = Colors.red.withValues(alpha: 0.06);
      badgeBgClr = Colors.red;
      statusIcon = Icons.close_rounded;
      statusText = '答錯';
      statusTextColor = Colors.red.shade700;
    }

    return Container(
      key: _itemKeys[qIdx],
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderClr,
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: headerBgClr,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: badgeBgClr,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusIcon,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text('第 ${qIdx + 1} 題',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: statusTextColor)),
                const Spacer(),
                Text(statusText,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusTextColor)),
                if (qid > 0) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    tooltip: isFav ? '取消收藏' : '收藏題目',
                    onPressed: () async {
                      try {
                        final db = await DatabaseHelper.instance.database;
                        final nextVal = isFav ? 0 : 1;
                        await db.update('questions', <String, Object?>{'bookmarked': nextVal},
                            where: 'id = ?', whereArgs: [qid]);
                        setState(() {
                          if (isFav) {
                            _bookmarkedQids.remove(qid);
                          } else {
                            _bookmarkedQids.add(qid);
                          }
                        });
                      } catch (e) {
                        debugPrint('切換收藏失敗: $e');
                      }
                    },
                    icon: Icon(
                      isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                    ),
                    color: isFav
                        ? Colors.amber.shade700
                        : statusTextColor.withValues(alpha: 0.6),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((q['question'] ?? q['text'] ?? '').toString(),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.55)),
                const SizedBox(height: 12),
                if (options.isNotEmpty)
                  ...options.asMap().entries.map((e) {
                    final i = e.key;
                    final optText = e.value;
                    final isChosen = chosen == i;
                    final isCorrect = correct == i;

                    Color borderColor = const Color(0xFFE5E7EB);
                    Color bgColor = Colors.transparent;
                    Widget? trailingIcon;

                    if (isCorrect) {
                      borderColor = Colors.green;
                      bgColor = Colors.green.withValues(alpha: 0.07);
                      trailingIcon = const Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 18);
                    } else if (isChosen && !isCorrect) {
                      borderColor = Colors.red;
                      bgColor = Colors.red.withValues(alpha: 0.07);
                      trailingIcon = const Icon(Icons.cancel_rounded,
                          color: Colors.red, size: 18);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor, width: 1.4),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCorrect
                                  ? Colors.green
                                  : (isChosen
                                      ? Colors.red
                                      : const Color(0xFFE5E7EB)),
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + i),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: (isCorrect || isChosen)
                                        ? Colors.white
                                        : Colors.grey.shade600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(optText,
                                  style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: isCorrect
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isCorrect
                                          ? Colors.green.shade800
                                          : (isChosen
                                              ? Colors.red.shade800
                                              : const Color(0xFF374151))))),
                          if (trailingIcon != null) trailingIcon,
                        ],
                      ),
                    );
                  }),
                if ((q['explanation'] ?? '').toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E7),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: const Color(0xFFFFD966), width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 16, color: Color(0xFFB45309)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(q['explanation'].toString(),
                              style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.6,
                                  color: Color(0xFF92400E))),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showAiExplanationSheet(context, qIdx, q, correct, chosen),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('詢問 AI 解析'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).primaryColor,
                    side: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                if (widget.saveResult) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteCtrls[qIdx],
                    minLines: 2,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: '新增筆記（選填）',
                      hintText: '記錄這題的思路或心得...',
                      labelStyle: const TextStyle(fontSize: 13),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFD1D5DB))),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      prefixIcon: const Icon(Icons.edit_note_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Transform.scale(
                        scale: 0.9,
                        child: Checkbox(
                          value: _toSaveWrong.contains(qIdx),
                          activeColor: const Color(0xFF5C6BC0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _toSaveWrong.add(qIdx);
                            } else {
                              _toSaveWrong.remove(qIdx);
                            }
                          }),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.bookmark_add_outlined,
                          size: 16, color: Color(0xFF5C6BC0)),
                      const SizedBox(width: 6),
                      const Text('加入錯題本',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF5C6BC0))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable diagnosis section card.
/*
/// Reusable diagnosis section card.
class _DiagnosisSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final Widget child;

  const _DiagnosisSection({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: iconColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ReviewDiagnosisLoadingProgress extends StatefulWidget {
  const _ReviewDiagnosisLoadingProgress();

  @override
  State<_ReviewDiagnosisLoadingProgress> createState() =>
      _ReviewDiagnosisLoadingProgressState();
}

class _ReviewDiagnosisLoadingProgressState
    extends State<_ReviewDiagnosisLoadingProgress> {
  double _value = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        if (_value < 0.92) {
          _value += 0.015;
          if (_value > 0.92) _value = 0.92;
        } else {
          _value += (0.999 - _value) * 0.03;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int step = (_value * 4).ceil();
    if (step > 4) step = 4;
    if (step < 1) step = 1;

    String loadingText = '';
    switch (step) {
      case 1:
        loadingText = '資料彙整中... (1/4)';
        break;
      case 2:
        loadingText = '分析答錯概念... (2/4)';
        break;
      case 3:
        loadingText = '深度診斷運算中... (3/4)';
        break;
      case 4:
        loadingText = '生成個人化建議... (4/4)';
        break;
    }

    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Theme.of(context).primaryColor, Color(0xFFBCAAA4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'AI 正在分析中...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loadingText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(_value * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '系統正在為您量身打造專屬報告，請稍候...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
*/

class _AiExplanationSheet extends StatefulWidget {
  final Map<String, dynamic> question;
  final int correctIndex;
  final int? chosenIndex;
  final String userId;
  final String? cachedText;
  final ValueChanged<String>? onSaveCache;

  const _AiExplanationSheet({
    required this.question,
    required this.correctIndex,
    required this.chosenIndex,
    required this.userId,
    this.cachedText,
    this.onSaveCache,
  });

  @override
  State<_AiExplanationSheet> createState() => _AiExplanationSheetState();
}

class _AiExplanationSheetState extends State<_AiExplanationSheet> {
  final StringBuffer _explanationBuffer = StringBuffer();
  bool _isLoading = true;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    if (widget.cachedText != null && widget.cachedText!.isNotEmpty) {
      _explanationBuffer.write(widget.cachedText);
      _isLoading = false;
    } else {
      _startAiStream();
    }
  }

  void _startAiStream() {
    _sub = AiDiagnosisService.askQuestionExplanationStream(
      userId: widget.userId,
      question: widget.question,
      correctIndex: widget.correctIndex,
      chosenIndex: widget.chosenIndex,
    ).listen(
      (chunk) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _explanationBuffer.write(chunk);
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _explanationBuffer.write('\n\n[連線錯誤] 無法取得 AI 解析：$err');
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        widget.onSaveCache?.call(_explanationBuffer.toString());
      },
    );
  }

  void _regenerate() {
    _sub?.cancel();
    setState(() {
      _explanationBuffer.clear();
      _isLoading = true;
    });
    _startAiStream();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final rawText = _explanationBuffer.toString();
    
    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.85),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'AI 專屬解析',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: '重新生成解析',
                  onPressed: _isLoading ? null : _regenerate,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Explanation Content Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 題目與作答回顧卡片
                  _buildQuestionPreview(cs),
                  const SizedBox(height: 16),

                  // AI 解析導師標題提示
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.psychology_rounded, size: 16, color: cs.primary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI 導師觀念剖析',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_isLoading && rawText.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: cs.primary),
                            const SizedBox(height: 16),
                            const Text(
                              'AI 導師正在深度解析本題觀念...',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    _buildStructuredExplanationContent(rawText, cs),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 題目內容、選項與作答狀況回顧卡片
  Widget _buildQuestionPreview(ColorScheme cs) {
    final qText = (widget.question['question'] ?? widget.question['text'] ?? '').toString();
    final chapter = widget.question['chapter'] ?? widget.question['unit'];
    final difficulty = widget.question['difficulty'];
    final rawOptions = widget.question['options'];
    List<String> options = [];
    if (rawOptions is List) {
      options = rawOptions.map((e) => e.toString()).toList();
    } else if (rawOptions is String) {
      try {
        final decoded = jsonDecode(rawOptions);
        if (decoded is List) {
          options = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        options = rawOptions
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '')
            .split(',')
            .map((e) => e.trim())
            .toList();
      }
    }

    final correctOpt = String.fromCharCode(65 + widget.correctIndex);
    final chosenOpt = widget.chosenIndex != null ? String.fromCharCode(65 + widget.chosenIndex!) : '未作答';
    final isCorrect = widget.chosenIndex == widget.correctIndex;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 頂部章節與狀態列
          Row(
            children: [
              if (chapter != null && chapter.toString().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    chapter.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
              if (difficulty != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '難度 $difficulty',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isCorrect ? Colors.green.shade50 : (widget.chosenIndex != null ? Colors.red.shade50 : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isCorrect ? Colors.green.shade200 : (widget.chosenIndex != null ? Colors.red.shade200 : Colors.grey.shade300)),
                ),
                child: Text(
                  isCorrect ? '✓ 答對' : (widget.chosenIndex != null ? '✗ 答錯' : '未作答'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isCorrect ? Colors.green.shade800 : (widget.chosenIndex != null ? Colors.red.shade700 : Colors.grey.shade700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 題目內文
          if (qText.isNotEmpty)
            Text(
              qText,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                height: 1.5,
              ),
            ),
          
          if (options.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...options.asMap().entries.map((e) {
              final idx = e.key;
              final optText = e.value;
              final isOptCorrect = idx == widget.correctIndex;
              final isOptChosen = idx == widget.chosenIndex;

              Color bgClr = const Color(0xFFF8FAFC);
              Color borderClr = const Color(0xFFE2E8F0);
              Color textClr = const Color(0xFF334155);

              if (isOptCorrect) {
                bgClr = const Color(0xFFF0FDF4);
                borderClr = Colors.green.shade300;
                textClr = Colors.green.shade900;
              } else if (isOptChosen && !isOptCorrect) {
                bgClr = const Color(0xFFFEF2F2);
                borderClr = Colors.red.shade300;
                textClr = Colors.red.shade900;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: bgClr,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderClr),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOptCorrect ? Colors.green : (isOptChosen ? Colors.red : Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + idx),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: (isOptCorrect || isOptChosen) ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        optText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isOptCorrect ? FontWeight.bold : FontWeight.normal,
                          color: textClr,
                        ),
                      ),
                    ),
                    if (isOptCorrect)
                      const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green)
                    else if (isOptChosen)
                      const Icon(Icons.cancel_rounded, size: 16, color: Colors.red),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),

          // 正確解答 vs 學生作答提示
          Row(
            children: [
              Text('正確答案：($correctOpt)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
              const Spacer(),
              Text('您的作答：${widget.chosenIndex != null ? '($chosenOpt)' : '未作答'}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isCorrect ? Colors.green.shade800 : Colors.red.shade700)),
            ],
          ),
        ],
      ),
    );
  }

  /// 將 AI 的純文字解析為結構化的高質感區塊卡片
  Widget _buildStructuredExplanationContent(String text, ColorScheme cs) {
    final cleaned = AiDiagnosisService.cleanAiExplanationText(text);
    if (cleaned.isEmpty) return const SizedBox.shrink();

    // 依行拆分或段落拆分
    final lines = cleaned.split('\n');
    final List<Widget> cardList = [];
    String? currentTitle;
    List<String> currentBodyLines = [];

    void flushSection() {
      if (currentTitle != null || currentBodyLines.isNotEmpty) {
        cardList.add(_buildSectionCard(currentTitle, currentBodyLines, cs));
        currentBodyLines = [];
        currentTitle = null;
      }
    }

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 檢查是否為區塊標題（如 🎯 觀念剖析、🔍 盲點檢視、💡 核心大通關、觀念剖析：...）
      String formatTitle = trimmed;
      bool isHeading = false;

      if (trimmed.startsWith('🎯') ||
          trimmed.startsWith('🔍') ||
          trimmed.startsWith('💡') ||
          trimmed.startsWith('【觀念') ||
          trimmed.startsWith('【盲點') ||
          trimmed.startsWith('【迷思') ||
          trimmed.startsWith('【重點') ||
          trimmed.startsWith('【核心') ||
          trimmed.startsWith('【口訣') ||
          trimmed.startsWith('觀念精華') ||
          trimmed.startsWith('觀念剖析') ||
          trimmed.startsWith('觀念解析') ||
          trimmed.startsWith('迷思快剖') ||
          trimmed.startsWith('盲點檢視') ||
          trimmed.startsWith('盲點分析') ||
          trimmed.startsWith('常見誤解') ||
          trimmed.startsWith('一秒口訣') ||
          trimmed.startsWith('核心大通關') ||
          trimmed.startsWith('核心總結') ||
          trimmed.startsWith('觀念總結') ||
          trimmed.startsWith('重點整理') ||
          RegExp(r'^\d+[\.\重\觀\盲\迷\一\、]').hasMatch(trimmed)) {
        isHeading = true;

        if (trimmed.contains('觀念') || trimmed.contains('正確')) {
          if (!formatTitle.startsWith('🎯')) formatTitle = '🎯 $formatTitle';
        } else if (trimmed.contains('盲點') || trimmed.contains('誤解') || trimmed.contains('迷思')) {
          if (!formatTitle.startsWith('🔍')) formatTitle = '🔍 $formatTitle';
        } else if (trimmed.contains('核心') || trimmed.contains('總結') || trimmed.contains('口訣') || trimmed.contains('一秒')) {
          if (!formatTitle.startsWith('💡')) formatTitle = '💡 $formatTitle';
        }
      }

      if (isHeading) {
        flushSection();
        currentTitle = formatTitle;
      } else {
        currentBodyLines.add(line);
      }
    }
    flushSection();

    // 如果完全沒有解析出區塊標題或只有單一大卡片，進行智慧分段
    if (cardList.isEmpty || (cardList.length == 1 && currentTitle == null)) {
      final paragraphs = cleaned.split(RegExp(r'\n\s*\n'));
      if (paragraphs.length > 1) {
        final List<Widget> autoCards = [];
        for (int i = 0; i < paragraphs.length; i++) {
          final pLines = paragraphs[i].split('\n').where((l) => l.trim().isNotEmpty).toList();
          if (pLines.isEmpty) continue;
          
          String autoTitle;
          if (i == 0) {
            autoTitle = '🎯 觀念剖析與正確解答';
          } else if (i == 1) {
            autoTitle = '🔍 盲點檢視與誤解釐清';
          } else {
            autoTitle = '💡 核心總結與重點複習';
          }
          autoCards.add(_buildSectionCard(autoTitle, pLines, cs));
        }
        if (autoCards.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: autoCards,
          );
        }
      }
      return _buildSectionCard('🎯 觀念剖析與解析', lines, cs);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cardList,
    );
  }

  /// 渲染單一結構區塊卡片（簡潔優雅白底 + 微質感主題 Header）
  Widget _buildSectionCard(String? title, List<String> bodyLines, ColorScheme cs) {
    // 依標題類型決定主題顏色與圖示
    Color primaryColor = cs.primary;
    Color headerBgColor = cs.primary.withValues(alpha: 0.06);
    IconData iconData = Icons.auto_awesome_rounded;

    if (title != null) {
      if (title.contains('🎯') || title.contains('正確') || title.contains('觀念')) {
        primaryColor = const Color(0xFF0F766E); // 質感深翡翠綠 (Deep Emerald/Teal)
        headerBgColor = const Color(0xFFF0FDF4); // 極淡柔和薄荷色
        iconData = Icons.task_alt_rounded;
      } else if (title.contains('🔍') || title.contains('盲點') || title.contains('誤解') || title.contains('迷思')) {
        primaryColor = const Color(0xFFC2410C); // 質感溫暖琥珀赤陶 (Warm Amber/Orange)
        headerBgColor = const Color(0xFFFFF7ED); // 極淡暖色
        iconData = Icons.find_in_page_rounded;
      } else if (title.contains('💡') || title.contains('口訣') || title.contains('總結') || title.contains('一秒')) {
        primaryColor = const Color(0xFF4338CA); // 質感深綻藍紫 (Deep Indigo)
        headerBgColor = const Color(0xFFEEF2FF); // 極淡靛藍色
        iconData = Icons.lightbulb_rounded;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: headerBgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  Icon(iconData, size: 17, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ],
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: bodyLines.map((line) {
                final trimmed = line.trim();
                final isBullet = trimmed.startsWith('•') || trimmed.startsWith('-');
                final cleanContent = isBullet ? trimmed.substring(1).trim() : line;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isBullet)
                        Padding(
                          padding: const EdgeInsets.only(top: 5.0, right: 8.0),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      Expanded(
                        child: _buildRichTextWithKeywordChips(
                          cleanContent,
                          const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Color(0xFF334155),
                          ),
                          primaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 將 【關鍵字】 解析為獨立視覺化的微型標籤 (WidgetSpan Chip)
  Widget _buildRichTextWithKeywordChips(String text, TextStyle baseStyle, Color primaryColor) {
    final List<InlineSpan> spans = [];
    final RegExp regExp = RegExp(r'【([^】]+)】');
    int lastIndex = 0;

    for (final Match match in regExp.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start), style: baseStyle));
      }
      final keyword = match.group(1) ?? '';
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: primaryColor.withValues(alpha: 0.3), width: 0.8),
            ),
            child: Text(
              keyword,
              style: TextStyle(
                fontSize: (baseStyle.fontSize ?? 14) * 0.88,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ),
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: baseStyle,
    );
  }
}