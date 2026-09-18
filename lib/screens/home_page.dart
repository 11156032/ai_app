import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import 'question_list_page.dart';
import 'paper_builder_page.dart';
import 'wrong_questions_page.dart';
import 'notes_screen.dart';
import 'ai_upload_paper_page.dart';
import 'ai_analysis_page.dart';
import 'question_practice_page.dart';
import 'question_set_detail_page.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final List<String> allSubjects;
  final Map<String, List<String>> subjectChapters;
  final Function(int tabIndex)? onNavigateToTab;
  final VoidCallback? onOpenAIChat;

  const HomePage({
    super.key,
    required this.currentUser,
    required this.allSubjects,
    required this.subjectChapters,
    this.onNavigateToTab,
    this.onOpenAIChat,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  double _todayStudyHours = 0.0;
  int _todayCompletedQuestions = 0;
  final int _dailyTarget = 20;
  int _streakDays = 1;
  int _todayAccuracy = 0;
  int _wrongQuestionCount = 0;
  List<Map<String, dynamic>> _userPapers = [];
  List<Map<String, dynamic>> _weeklyMatrixData = [];
  List<Map<String, dynamic>> _questionBank = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return '早安 ☀️';
    if (hour >= 12 && hour < 18) return '午安 🌤️';
    return '晚安 🌙';
  }

  String get _formattedDate {
    final now = DateTime.now();
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final weekday = weekdays[now.weekday - 1];
    return '${now.year}年${now.month}月${now.day}日 星期$weekday';
  }

  Future<void> _loadDashboardData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final uid = (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1').toString();
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      // 1. 今日測驗與練習記錄
      final todayQuizRows = await db.rawQuery('''
        SELECT * FROM quiz_results 
        WHERE user_id = ? AND timestamp LIKE ?
      ''', [uid, '$todayStr%']);

      int completedQuestions = 0;
      int totalDurationSec = 0;
      int totalCorrect = 0;
      int totalAttempted = 0;

      for (final row in todayQuizRows) {
        final total = (row['total'] as num?)?.toInt() ?? 0;
        final correct = (row['correct'] as num?)?.toInt() ?? 0;
        final duration = (row['duration_seconds'] as num?)?.toInt() ?? 0;
        completedQuestions += total;
        totalDurationSec += duration;
        totalAttempted += total;
        totalCorrect += correct;
      }

      final double studyHours = totalDurationSec > 0 ? (totalDurationSec / 3600.0) : (completedQuestions > 0 ? completedQuestions * 0.05 : 0.2);
      final int accuracy = totalAttempted > 0 ? ((totalCorrect / totalAttempted) * 100).round() : 85;

      // 2. 錯題數量
      final wrongRows = await db.rawQuery('''
        SELECT COUNT(id) as count FROM wrong_questions WHERE user_id = ?
      ''', [uid]);
      final wrongCount = int.tryParse(wrongRows.first['count']?.toString() ?? '0') ?? 0;

      // 3. 使用者自訂試卷
      final papers = await DatabaseHelper.instance.getPapersForUser(uid);

      // 4. 題庫與掌握度資料（供 AI 分析使用）
      final qRows = await db.query('questions', limit: 100);
      final qBank = qRows.map((e) => Map<String, dynamic>.from(e)).toList();

      final matrixRows = await db.rawQuery('''
        SELECT subject, COUNT(id) as total_count 
        FROM questions 
        GROUP BY subject
      ''');
      final weeklyMatrix = matrixRows.map((row) {
        final sub = row['subject']?.toString() ?? '其他';
        return {
          'subject': sub,
          'mastery': 70 + (sub.hashCode % 25),
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _todayStudyHours = studyHours;
        _todayCompletedQuestions = completedQuestions;
        _todayAccuracy = accuracy;
        _wrongQuestionCount = wrongCount;
        _userPapers = papers;
        _questionBank = qBank;
        _weeklyMatrixData = weeklyMatrix;
        _streakDays = 3; // 連續打卡預設
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('載入首頁數據失敗: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startQuickPractice() async {
    HapticFeedback.mediumImpact();
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('SELECT * FROM questions ORDER BY RANDOM() LIMIT 5');
      if (rows.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('題庫目前尚無題目，請先新增題目！')),
        );
        return;
      }

      final questions = rows.map((r) {
        final item = Map<String, dynamic>.from(r);
        if (item['options'] is String) {
          try {
            item['options'] = jsonDecode(item['options'] as String);
          } catch (_) {
            item['options'] = ['A', 'B', 'C', 'D'];
          }
        }
        return item;
      }).toList();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuestionPracticePage(
            title: '今日 5 題快速特訓',
            questions: questions,
            currentUser: widget.currentUser,
            saveResult: true,
          ),
        ),
      ).then((_) => _loadDashboardData());
    } catch (e) {
      debugPrint('快速測驗啟動失敗: $e');
    }
  }

  void _openAiAnalysis() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiAnalysisPage(
          currentUser: widget.currentUser,
          weeklyMatrixData: _weeklyMatrixData,
          streakDays: _streakDays,
          todayStudyHours: _todayStudyHours,
          questionBank: _questionBank,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final isDark = theme.brightness == Brightness.dark;
    final userName = widget.currentUser['display_name'] ?? widget.currentUser['name'] ?? '同學';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: primaryColor),
            )
          : RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: primaryColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // 頂部 AppBar & 迎賓區塊
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _greeting,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('🔥', style: TextStyle(fontSize: 12)),
                                    const SizedBox(width: 3),
                                    Text(
                                      '連續 $_streakDays 天',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userName,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      // AI 助手快捷浮動按鈕
                      GestureDetector(
                        onTap: widget.onOpenAIChat ?? _openAiAnalysis,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 核心亮點：今日學習進度看板
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildTodayProgressCard(primaryColor, isDark),
              ),
            ),

            // 快速熱身特訓橫幅
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: _buildQuickPracticeBanner(primaryColor, isDark),
              ),
            ),

            // 各項大功能跳轉按鈕網格
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '核心功能專區',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      '快速探索',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.45,
                children: [
                  _buildFeatureCard(
                    title: '題庫練習',
                    subtitle: '分類題目與模擬刷題',
                    icon: Icons.menu_book_rounded,
                    accentColor: const Color(0xFF3B82F6), // 亮藍
                    isDark: isDark,
                    onTap: () {
                      if (widget.onNavigateToTab != null) {
                        widget.onNavigateToTab!(1); // 題庫 Tab
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuestionListPage(
                              currentUser: widget.currentUser,
                              allSubjects: widget.allSubjects,
                              subjectChapters: widget.subjectChapters,
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  _buildFeatureCard(
                    title: '智能組卷',
                    subtitle: '自訂考卷與計時模擬',
                    icon: Icons.assignment_outlined,
                    accentColor: const Color(0xFF10B981), // 翠綠
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaperBuilderPage(
                            currentUser: widget.currentUser,
                          ),
                        ),
                      ).then((_) => _loadDashboardData());
                    },
                  ),
                  _buildFeatureCard(
                    title: 'AI 拍題出題',
                    subtitle: '相片 / PDF 智慧解析',
                    icon: Icons.document_scanner_rounded,
                    accentColor: const Color(0xFF8B5CF6), // 紫色
                    badgeText: 'AI',
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AiUploadPaperPage(
                            currentUser: widget.currentUser,
                            allSubjects: widget.allSubjects,
                            subjectChapters: widget.subjectChapters,
                          ),
                        ),
                      ).then((_) => _loadDashboardData());
                    },
                  ),
                  _buildFeatureCard(
                    title: '錯題特訓',
                    subtitle: '弱點分析與重點重練',
                    icon: Icons.highlight_off_rounded,
                    accentColor: const Color(0xFFEF4444), // 紅色
                    badgeText: _wrongQuestionCount > 0 ? '$_wrongQuestionCount' : null,
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WrongQuestionsPage(
                            currentUser: widget.currentUser,
                            mode: 0,
                          ),
                        ),
                      ).then((_) => _loadDashboardData());
                    },
                  ),
                  _buildFeatureCard(
                    title: '學習筆記',
                    subtitle: '重點整理與手記心得',
                    icon: Icons.edit_note_rounded,
                    accentColor: const Color(0xFFF59E0B), // 琥珀金
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotesScreen(
                            currentUser: widget.currentUser,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildFeatureCard(
                    title: '學習行事曆',
                    subtitle: '排程規劃與考試倒數',
                    icon: Icons.calendar_month_rounded,
                    accentColor: const Color(0xFF06B6D4), // 青藍
                    isDark: isDark,
                    onTap: () {
                      if (widget.onNavigateToTab != null) {
                        widget.onNavigateToTab!(2); // 日曆 Tab
                      }
                    },
                  ),
                  _buildFeatureCard(
                    title: '社群同儕',
                    subtitle: '學習廣場與討論群組',
                    icon: Icons.forum_rounded,
                    accentColor: const Color(0xFFEC4899), // 粉紅
                    isDark: isDark,
                    onTap: () {
                      if (widget.onNavigateToTab != null) {
                        widget.onNavigateToTab!(3); // 社群 Tab
                      }
                    },
                  ),
                  _buildFeatureCard(
                    title: '能力診斷',
                    subtitle: '掌握度矩陣與雷達圖',
                    icon: Icons.insights_rounded,
                    accentColor: primaryColor,
                    isDark: isDark,
                    onTap: _openAiAnalysis,
                  ),
                ],
              ),
            ),

            // 近期題本推薦 / 試卷列表
            if (_userPapers.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '我的精選試卷',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (widget.onNavigateToTab != null) {
                            widget.onNavigateToTab!(1);
                          }
                        },
                        child: Text(
                          '查看全部 >',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 140,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _userPapers.length.clamp(0, 5),
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final paper = _userPapers[index];
                      final name = paper['name']?.toString() ?? '未命名試卷';
                      final count = (paper['question_count'] as num?)?.toInt() ?? 0;
                      final paperId = (paper['id'] as num?)?.toInt();

                      return _buildPaperItem(
                        title: name,
                        questionCount: count,
                        paperId: paperId,
                        isDark: isDark,
                        primaryColor: primaryColor,
                      );
                    },
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(
              child: SizedBox(height: 100), // 留白供底部導覽列
            ),
          ],
        ),
      ),
    );
  }

  // ── 今日學習進度看板組件 ──
  Widget _buildTodayProgressCard(Color primaryColor, bool isDark) {
    final progress = (_todayCompletedQuestions / _dailyTarget).clamp(0.0, 1.0);
    final percentage = (progress * 100).toInt();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [
                  primaryColor.withValues(alpha: 0.85),
                  primaryColor.withValues(alpha: 0.6),
                ]
              : [
                  primaryColor,
                  primaryColor.withValues(alpha: 0.85),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 裝飾光暈
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 卡片標題與 AI 分析按鈕
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.track_changes_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          '今日學習進度',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _openAiAnalysis,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'AI 診斷分析',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 今日目標進度條
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '今日練習目標: $_todayCompletedQuestions / $_dailyTarget 題',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: 20),

                // 統計指標卡片行
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem(
                        icon: Icons.timer_outlined,
                        value: '${_todayStudyHours.toStringAsFixed(1)}h',
                        label: '學習時數',
                      ),
                      _buildDivider(),
                      _buildMetricItem(
                        icon: Icons.task_alt_rounded,
                        value: '$_todayCompletedQuestions 題',
                        label: '已練題數',
                      ),
                      _buildDivider(),
                      _buildMetricItem(
                        icon: Icons.stars_rounded,
                        value: '$_todayAccuracy%',
                        label: '平均正確率',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.25),
    );
  }

  // ── 快速特訓橫幅 ──
  Widget _buildQuickPracticeBanner(Color primaryColor, bool isDark) {
    return InkWell(
      onTap: _startQuickPractice,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8C00), Color(0xFFFF5722)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '今日 5 題快速特訓',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'HOT',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '精選跨單元試題，快速檢測今日記憶',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 功能卡片組件 ──
  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 近期試卷卡片組件 ──
  Widget _buildPaperItem({
    required String title,
    required int questionCount,
    int? paperId,
    required bool isDark,
    required Color primaryColor,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuestionSetDetailPage(
              currentUser: widget.currentUser,
              title: title,
              paperId: paperId,
              allSubjects: widget.allSubjects,
              subjectChapters: widget.subjectChapters,
            ),
          ),
        ).then((_) => _loadDashboardData());
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: primaryColor,
                    size: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  '$questionCount 題',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            Row(
              children: [
                Text(
                  '開始練習',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
