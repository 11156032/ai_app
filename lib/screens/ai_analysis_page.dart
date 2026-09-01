import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/database_helper.dart';
import '../services/ai_diagnosis_service.dart';
import 'ai_training_page.dart';

class AiAnalysisPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final List<Map<String, dynamic>> weeklyMatrixData;
  final int streakDays;
  final double todayStudyHours;
  final List<Map<String, dynamic>> questionBank;

  const AiAnalysisPage({
    super.key,
    required this.currentUser,
    required this.weeklyMatrixData,
    required this.streakDays,
    required this.todayStudyHours,
    required this.questionBank,
  });

  @override
  State<AiAnalysisPage> createState() => _AiAnalysisPageState();
}

class _AiAnalysisPageState extends State<AiAnalysisPage>
    with SingleTickerProviderStateMixin {
  // ── Data ──────────────────────────────────────────────────────────
  List<double> _dailyHours = List.filled(7, 0.0); // Mon~Sun
  List<Map<String, dynamic>> _subjectStats = [];
  double _overallProficiency = 0.0;
  String _weakestSubject = '';
  String _strongestSubject = '';

  // ── AI Insight ─────────────────────────────────────────────────────
  String _aiInsightStrength = '';
  String _aiInsightWeakness = '';
  bool _isLoadingInsight = true;

  // ── Animation ─────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Load real data ─────────────────────────────────────────────────
  Future<void> _loadData() async {
    await Future.wait([_loadWeeklyHours(), _loadSubjectStats()]);
    if (mounted) {
      _fadeCtrl.forward();
      setState(() {});
      _loadAiInsight();
    }
  }

  Future<void> _loadWeeklyHours() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final userId = widget.currentUser['id']?.toString() ?? '';
      final now = DateTime.now();
      final monday = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));

      final rows = await db.rawQuery('''
        SELECT date(timestamp, 'localtime') as day,
               SUM(duration_seconds) as total_sec
        FROM quiz_results
        WHERE user_id = ?
          AND date(timestamp, 'localtime') >= ?
        GROUP BY day
      ''', [userId, monday.toIso8601String().substring(0, 10)]);

      final List<double> hours = List.filled(7, 0.0);
      for (final r in rows) {
        final dayStr = r['day'] as String?;
        if (dayStr == null) continue;
        final d = DateTime.tryParse(dayStr);
        if (d == null) continue;
        final idx = d.weekday - 1; // 0=Mon .. 6=Sun
        if (idx >= 0 && idx < 7) {
          hours[idx] = ((r['total_sec'] as num?)?.toDouble() ?? 0) / 3600.0;
        }
      }
      if (mounted) setState(() => _dailyHours = hours);
    } catch (e) {
      debugPrint('_loadWeeklyHours error: $e');
    }
  }

  Future<void> _loadSubjectStats() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final userId = widget.currentUser['id']?.toString() ?? '';

      final rows = await db.rawQuery('''
        SELECT subject,
               SUM(correct) as cor,
               SUM(total) as tot
        FROM quiz_results
        WHERE user_id = ? AND total > 0
        GROUP BY subject
        ORDER BY SUM(total) DESC
      ''', [userId]);

      final List<Map<String, dynamic>> stats = [];
      for (final r in rows) {
        final subj = ((r['subject'] as String?) ?? '').isNotEmpty
            ? (r['subject'] as String)
            : '綜合測驗';
        final int cor = (r['cor'] as num?)?.toInt() ?? 0;
        final int tot = (r['tot'] as num?)?.toInt() ?? 0;
        if (tot > 0) {
          stats.add({
            'subject': subj,
            'accuracy': cor / tot,
            'correct': cor,
            'total': tot,
          });
        }
      }

      double totalCor = 0, totalTot = 0;
      for (final s in stats) {
        totalCor += (s['correct'] as int);
        totalTot += (s['total'] as int);
      }
      final proficiency = totalTot > 0 ? totalCor / totalTot : 0.0;

      String strongest = '', weakest = '';
      if (stats.isNotEmpty) {
        final sorted = [...stats]
          ..sort((a, b) =>
              (b['accuracy'] as double).compareTo(a['accuracy'] as double));
        strongest = sorted.first['subject'] as String;
        weakest = sorted.last['subject'] as String;
      }

      if (mounted) {
        setState(() {
          _subjectStats = stats;
          _overallProficiency = proficiency;
          _strongestSubject = strongest;
          _weakestSubject = weakest;
        });
      }
    } catch (e) {
      debugPrint('_loadSubjectStats error: $e');
    }
  }

  Future<void> _loadAiInsight() async {
    if (_subjectStats.isEmpty) {
      if (mounted) {
        setState(() {
          _aiInsightStrength = '尚無足夠數據，請先完成幾次測驗後再來查看！';
          _aiInsightWeakness = '完成更多題目後，AI 會為你分析弱點所在。';
          _isLoadingInsight = false;
        });
      }
      return;
    }

    final statsLines = _subjectStats
        .map((s) =>
            '${s['subject']}: 正確率 ${((s['accuracy'] as double) * 100).toStringAsFixed(1)}%（${s['correct']}/${s['total']} 題）')
        .join('\n');
    final weeklyTotal = _dailyHours.fold(0.0, (a, b) => a + b);

    final prompt =
        '根據以下學習數據，輸出繁體中文 JSON {"strength":"...","weakness":"..."}，各1~2句。\n\n各科數據：\n$statsLines\n本週學習：${weeklyTotal.toStringAsFixed(1)}h，連續${widget.streakDays}天。';

    String strength = '';
    String weakness = '';
    try {
      final buffer = StringBuffer();
      await for (final chunk
          in AiDiagnosisService.generateOpenRouterGuideStream(
        userInput: prompt,
        history: const [],
        customSystemPrompt: '你是學習分析 AI，只輸出 JSON，不說廢話。',
      )) {
        buffer.write(chunk.text);
      }
      final raw = AiDiagnosisService.cleanThinkingTags(buffer.toString());
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(raw);
      if (jsonMatch != null) {
        final decoded =
            json.decode(jsonMatch.group(0)!) as Map<String, dynamic>;
        strength = (decoded['strength'] as String?) ?? '';
        weakness = (decoded['weakness'] as String?) ?? '';
      }
    } catch (e) {
      debugPrint('AI insight error: $e');
    }

    if (strength.isEmpty) {
      strength =
          '${_strongestSubject.isNotEmpty ? _strongestSubject : "您"}的學習表現亮眼！正確率高，建議可以挑戰更進階的題型。';
    }
    if (weakness.isEmpty) {
      weakness =
          '${_weakestSubject.isNotEmpty ? _weakestSubject : "部分科目"}仍有進步空間，建議多做練習題來鞏固基礎。';
    }

    if (mounted) {
      setState(() {
        _aiInsightStrength = strength;
        _aiInsightWeakness = weakness;
        _isLoadingInsight = false;
      });
    }
  }

  // ── Radar dimensions ────────────────────────────────────────────────
  List<Map<String, dynamic>> get _radarDimensions {
    const defaultDims = [
      '語法基礎', '資料結構', '演算法', '物件導向', '邏輯思考', '除錯能力'
    ];
    if (_subjectStats.isEmpty) {
      return List.generate(6, (i) => {'label': defaultDims[i], 'value': 1.0});
    }
    final dims = <Map<String, dynamic>>[];
    for (int i = 0; i < _subjectStats.length && i < 6; i++) {
      final acc = (_subjectStats[i]['accuracy'] as double).clamp(0.0, 1.0);
      dims.add({
        'label': _subjectStats[i]['subject'] as String,
        'value': 1.0 + acc * 4.0,
      });
    }
    int padIdx = 0;
    while (dims.length < 6) {
      dims.add({'label': defaultDims[padIdx % defaultDims.length], 'value': 1.0});
      padIdx++;
    }
    return dims;
  }

  Color _barColor(double hours) {
    if (hours >= 1.0) return const Color(0xFF4CAF50);
    if (hours >= 0.5) return const Color(0xFFFFC107);
    if (hours > 0) return const Color(0xFFF44336);
    return Colors.grey.shade300;
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    const primaryBrown = Color(0xFF6D5448);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('AI 學習分析報告',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildBanner(primaryBrown),
              const SizedBox(height: 16),
              _buildCard(cardColor: cardColor, child: _buildBarChartSection(textColor)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildStreakCard(cardColor, textColor)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildProficiencyCard(cardColor, textColor)),
                ],
              ),
              const SizedBox(height: 16),
              _buildCard(cardColor: cardColor, child: _buildRadarSection(textColor)),
              const SizedBox(height: 16),
              _buildCard(cardColor: cardColor, child: _buildInsightSection(textColor)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AiTrainingPage(
                          currentUser: widget.currentUser,
                          weakestSubject: _weakestSubject,
                          subjectStats: _subjectStats,
                          questionBank: widget.questionBank,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrown,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fitness_center, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('開始今日專屬特訓',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Color cardColor, required Widget child}) {
    return Container(
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
      child: child,
    );
  }

  Widget _buildBanner(Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('✨', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 洞察已更新',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('根據您的學習歷程，已產生最新能力評估。',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartSection(Color textColor) {
    final days = ['一', '二', '三', '四', '五', '六', '日'];
    final maxH = _dailyHours.isEmpty
        ? 1.0
        : _dailyHours.reduce((a, b) => a > b ? a : b);
    final scale = maxH > 0 ? 80.0 / maxH : 80.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('學習歷程',
                style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            const Text('(本週學習時數)',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final h = _dailyHours[i];
            final barH = h > 0 ? (h * scale).clamp(8.0, 80.0) : 8.0;
            final isToday = i == DateTime.now().weekday - 1;
            return _buildBarItem(
              day: days[i],
              height: barH,
              color: _barColor(h),
              label: h > 0 ? '${h.toStringAsFixed(1)}h' : null,
              isToday: isToday,
              textColor: textColor,
            );
          }),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendDot(const Color(0xFF4CAF50), '≥ 1h'),
            const SizedBox(width: 16),
            _buildLegendDot(const Color(0xFFFFC107), '0.5~1h'),
            const SizedBox(width: 16),
            _buildLegendDot(const Color(0xFFF44336), '< 0.5h'),
          ],
        ),
      ],
    );
  }

  Widget _buildBarItem({
    required String day,
    required double height,
    required Color color,
    String? label,
    bool isToday = false,
    required Color textColor,
  }) {
    return Column(
      children: [
        if (label != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF6D5448),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 9)),
          ),
          const SizedBox(height: 4),
        ] else
          const SizedBox(height: 20),
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          width: 22,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(11),
            border: isToday
                ? Border.all(color: const Color(0xFF6D5448), width: 2)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(day,
            style: TextStyle(
                color: isToday ? const Color(0xFF6D5448) : textColor,
                fontSize: 12,
                fontWeight:
                    isToday ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildStreakCard(Color cardColor, Color textColor) {
    const maxStreak = 30;
    final ratio = (widget.streakDays / maxStreak).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
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
              Icon(Icons.local_fire_department,
                  color: Color(0xFFFF6B35), size: 18),
              SizedBox(width: 4),
              Text('連續學習',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${widget.streakDays} 天',
              style: TextStyle(
                  color: textColor,
                  fontSize: 26,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF6B35)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProficiencyCard(Color cardColor, Color textColor) {
    final pct = (_overallProficiency * 100).round();
    return Container(
      padding: const EdgeInsets.all(18),
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
              Icon(Icons.auto_awesome, color: Color(0xFF6D5448), size: 18),
              SizedBox(width: 4),
              Text('AI 評估熟練度',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text('$pct%',
              style: TextStyle(
                  color: textColor,
                  fontSize: 26,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _overallProficiency.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF6D5448)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarSection(Color textColor) {
    final dims = _radarDimensions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('能力雷達圖',
            style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        SizedBox(
          height: 220,
          child: RadarChart(
            RadarChartData(
              dataSets: [
                RadarDataSet(
                  fillColor:
                      const Color(0xFF6D5448).withValues(alpha: 0.15),
                  borderColor: const Color(0xFF6D5448),
                  entryRadius: 5,
                  dataEntries: dims
                      .map((d) => RadarEntry(
                          value:
                              (d['value'] as double).clamp(1.0, 5.0)))
                      .toList(),
                  borderWidth: 2.5,
                ),
              ],
              radarBackgroundColor: Colors.transparent,
              borderData: FlBorderData(show: false),
              radarBorderData:
                  const BorderSide(color: Colors.transparent),
              tickCount: 5,
              ticksTextStyle: const TextStyle(
                  color: Colors.transparent, fontSize: 10),
              tickBorderData:
                  BorderSide(color: Colors.grey.shade300, width: 1),
              gridBorderData:
                  BorderSide(color: Colors.grey.shade300, width: 1),
              getTitle: (index, angle) {
                return RadarChartTitle(
                  text: dims[index]['label'] as String,
                  angle: angle,
                );
              },
            ),
          ),
        ),
        if (_subjectStats.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: dims.map((d) {
              final acc =
                  (((d['value'] as double) - 1) / 4 * 100).round();
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6D5448).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${d['label']} $acc%',
                  style: const TextStyle(
                      color: Color(0xFF6D5448), fontSize: 11),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildInsightSection(Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('AI 智慧洞察',
                style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (_isLoadingInsight)
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF6D5448))),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoadingInsight)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFF6D5448)),
                  SizedBox(height: 12),
                  Text('AI 正在分析您的學習數據...',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        else ...[
          _buildInsightCard(
            icon: Icons.emoji_events,
            iconColor: Colors.amber.shade600,
            indicatorColor: Colors.green,
            title:
                '強項：${_strongestSubject.isNotEmpty ? _strongestSubject : "整體表現"}',
            desc: _aiInsightStrength,
            textColor: textColor,
          ),
          const SizedBox(height: 12),
          _buildInsightCard(
            icon: Icons.lightbulb,
            iconColor: Colors.orange,
            indicatorColor: Colors.amber,
            title:
                '建議加強：${_weakestSubject.isNotEmpty ? _weakestSubject : "持續練習"}',
            desc: _aiInsightWeakness,
            textColor: textColor,
          ),
        ],
      ],
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required Color iconColor,
    required Color indicatorColor,
    required String title,
    required String desc,
    required Color textColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF8F6F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: indicatorColor,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: iconColor, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(desc,
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  height: 1.6)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
