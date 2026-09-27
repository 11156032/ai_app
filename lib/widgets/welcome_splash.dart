import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common_widgets.dart';

// ─────────────────────────────────────────────────────
// WelcomeSplash — 頂級 Apple 白底風格（Light Theme）
// 🌟 旗艦動態系統：
// 0. 極簡純淨迎賓封面頁（Welcome Landing Cover）
// 1. Apple 物理彈簧曲線（Spring Physics Bezier）
// 2. 微延遲瀑布流交錯進場（Step-Aware Staggered Waterfall Cascade）
// 3. 觸覺回饋彈性縮放（Tactile Spring Bouncing Tap）
// 4. 首屏 100% 全覽學科分類 Tab（零垂直滾動）
// ─────────────────────────────────────────────────────

// Apple 經典流體物理曲線（比擬 iOS 原生轉場手感）
const Curve kAppleSpringCurve = Cubic(0.22, 1.0, 0.36, 1.0);
const Curve kAppleBounceBack = Curves.easeOutBack;

class UserOnboardingPreferences {
  final String goal;
  final List<String> painPoints;
  final String learningMode;
  final List<String> topicIds;

  const UserOnboardingPreferences({
    required this.goal,
    required this.painPoints,
    required this.learningMode,
    required this.topicIds,
  });
}

class WelcomeSplash extends StatefulWidget {
  final void Function(List<String> selectedTopicIds,
      [UserOnboardingPreferences? preferences]) onDone;
  final VoidCallback? onSkip;
  final String? userName;
  final List<String>? initialTopicIds;

  const WelcomeSplash({
    super.key,
    required this.onDone,
    this.onSkip,
    this.userName,
    this.initialTopicIds,
  });

  @override
  State<WelcomeSplash> createState() => _WelcomeSplashState();
}

class _WelcomeSplashState extends State<WelcomeSplash>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0; // 0: 迎賓封面, 1: 目標, 2: 困擾, 3: 模式, 4: 學科

  // 步驟 4：當前選中的學科分類 Tab 索引（0 ~ 3）
  int _selectedSubjectCategoryIndex = 0;

  late AnimationController _entryAnim;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  late AnimationController _exitAnim;
  late Animation<double> _fadeOut;
  late Animation<Offset> _slideOut;

  // 4 題答案狀態收集
  String _selectedGoal = 'exam'; // Q1: 目標與動機 (單選)
  final Set<String> _selectedPainPoints = {
    'stuck_questions',
    'scattered_notes',
  }; // Q2: 痛點共鳴 (多選 Bento)
  String _selectedIncentive = 'peer'; // Q3: 學習模式偏好 (單選 情境大卡片)
  late Set<String> _selectedTopicIds; // Q4: 關注學科 (多選 標籤雲)

  // 學科分類與標籤定義
  static const List<({
    String categoryId,
    String categoryName,
    String categoryShortName,
    String categoryEmoji,
    List<({String id, String name, String emoji})> topics,
  })> _subjectGroups = [
    (
      categoryId: 'cat_stem',
      categoryName: '數理邏輯與自然科學',
      categoryShortName: '數理自然',
      categoryEmoji: '📐',
      topics: [
        (id: 'topic_math', name: '數學解題', emoji: '📐'),
        (id: 'topic_science', name: '自然理化', emoji: '🔬'),
        (id: 'topic_physics', name: '高中物理', emoji: '⚡'),
        (id: 'topic_chemistry', name: '化學實驗', emoji: '🧪'),
        (id: 'topic_biology', name: '生物地科', emoji: '🌱'),
      ],
    ),
    (
      categoryId: 'cat_humanities',
      categoryName: '語文素養與人文社會',
      categoryShortName: '語文社會',
      categoryEmoji: '📚',
      topics: [
        (id: 'topic_literature', name: '國文賞析', emoji: '📖'),
        (id: 'topic_english', name: '英語外語', emoji: '🌍'),
        (id: 'topic_social', name: '社會公民', emoji: '⚖️'),
        (id: 'topic_history', name: '歷史地理', emoji: '🏛️'),
      ],
    ),
    (
      categoryId: 'cat_tech',
      categoryName: 'AI 科技與前沿跨域',
      categoryShortName: 'AI 科技',
      categoryEmoji: '💡',
      topics: [
        (id: 'topic_ai', name: 'AI 人工智慧', emoji: '🤖'),
        (id: 'topic_coding', name: '程式開發', emoji: '💻'),
        (id: 'topic_creative', name: '心智圖圖解', emoji: '🧠'),
        (id: 'topic_tech', name: '前沿科普', emoji: '🚀'),
      ],
    ),
    (
      categoryId: 'cat_exam_daily',
      categoryName: '大考衝刺與自律日常',
      categoryShortName: '升學日常',
      categoryEmoji: '🎯',
      topics: [
        (id: 'topic_exam', name: '會考學測歷屆', emoji: '📝'),
        (id: 'topic_daily', name: '自律打卡讀書會', emoji: '⏰'),
        (id: 'topic_toeic', name: '多益檢定', emoji: '🏆'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedTopicIds = Set<String>.from(
      widget.initialTopicIds ??
          ['topic_math', 'topic_science', 'topic_ai', 'topic_exam'],
    );

    _entryAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryAnim, curve: kAppleSpringCurve));
    _entryAnim.forward();

    _exitAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitAnim, curve: Curves.easeInCubic),
    );
    _slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.04),
    ).animate(CurvedAnimation(parent: _exitAnim, curve: Curves.easeInCubic));
  }

  @override
  void dispose() {
    _entryAnim.dispose();
    _exitAnim.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < 4) {
      _pageCtrl.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 520),
        curve: kAppleSpringCurve,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prevPage() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageCtrl.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 520),
        curve: kAppleSpringCurve,
      );
    } else {
      _exitAnim.forward().then((_) {
        widget.onSkip?.call();
      });
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  void _finishOnboarding() async {
    HapticFeedback.mediumImpact();
    if (_exitAnim.isAnimating || _exitAnim.isCompleted) return;
    await _exitAnim.forward();
    if (!mounted) return;
    if (_selectedTopicIds.isEmpty) {
      _selectedTopicIds.addAll(['topic_math', 'topic_ai']);
    }
    final normalizedCommunities = normalizeCommunityTopicIds(_selectedTopicIds);
    widget.onDone(
      normalizedCommunities,
      UserOnboardingPreferences(
        goal: _selectedGoal,
        painPoints: _selectedPainPoints.toList(),
        learningMode: _selectedIncentive,
        topicIds: normalizedCommunities,
      ),
    );
  }

  void _togglePainPoint(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedPainPoints.contains(id)) {
        if (_selectedPainPoints.length > 1) {
          _selectedPainPoints.remove(id);
        }
      } else {
        _selectedPainPoints.add(id);
      }
    });
  }

  void _toggleTopic(String topicId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedTopicIds.contains(topicId)) {
        if (_selectedTopicIds.length > 1) {
          _selectedTopicIds.remove(topicId);
        }
      } else {
        _selectedTopicIds.add(topicId);
      }
    });
  }

  void _toggleGroupAll(List<String> topicIds) {
    HapticFeedback.selectionClick();
    final allSelected = topicIds.every((id) => _selectedTopicIds.contains(id));
    setState(() {
      if (allSelected) {
        if (_selectedTopicIds.length > topicIds.length) {
          _selectedTopicIds.removeAll(topicIds);
        }
      } else {
        _selectedTopicIds.addAll(topicIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC), // Apple 純淨典雅白底
      child: FadeTransition(
        opacity: _fadeOut,
        child: SlideTransition(
          position: _slideOut,
          child: Stack(
            children: [
              // 頂級 Apple 白底氛圍背景漸層與微光（微視差浮動）
              _buildAppleLightBackground(),

              SafeArea(
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideIn,
                    child: Column(
                      children: [
                        // 頂部導航列：迎賓標章 / 返回 / 4 段進度條
                        _buildTopBar(),

                        // 中央 5 大步驟多元互動 PageView
                        Expanded(
                          child: PageView(
                            controller: _pageCtrl,
                            onPageChanged: _onPageChanged,
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            children: [
                              _buildWelcomeCoverStep(), // Step 0: 迎賓封面頁
                              _buildGoalStep(), // Step 1: 學習目標
                              _buildPainPointsStep(), // Step 2: 學習困擾
                              _buildIncentiveStep(), // Step 3: 學習模式
                              _buildSubjectsStep(), // Step 4: 關注學科（方案 A 頂部 Tab）
                            ],
                          ),
                        ),

                        // 底部固定全寬彈性反饋膠囊按鈕
                        _buildBottomBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Apple 白底柔和氛圍背景 ──
  Widget _buildAppleLightBackground() {
    return AnimatedBuilder(
      animation: _pageCtrl,
      builder: (context, _) {
        double pageOffset = 0.0;
        if (_pageCtrl.hasClients && _pageCtrl.position.hasContentDimensions) {
          pageOffset = _pageCtrl.page ?? 0.0;
        }

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF8FAFC),
                Color(0xFFF1F5F9),
              ],
            ),
          ),
          child: Stack(
            children: [
              // 右上方柔和冰藍微光
              Positioned(
                top: -60 - (pageOffset * 12),
                right: -60 + (pageOffset * 15),
                child: Container(
                  width: 330,
                  height: 330,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF38BDF8).withValues(alpha: 0.14),
                        const Color(0xFF38BDF8).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // 左側中央柔和暖金微光
              Positioned(
                top: 240 + (pageOffset * 15),
                left: -80 - (pageOffset * 10),
                child: Container(
                  width: 310,
                  height: 310,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFFB74D).withValues(alpha: 0.13),
                        const Color(0xFFFFB74D).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              // 右下方柔和紫羅蘭微光
              Positioned(
                bottom: 30 - (pageOffset * 10),
                right: -60 - (pageOffset * 12),
                child: Container(
                  width: 270,
                  height: 270,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF818CF8).withValues(alpha: 0.11),
                        const Color(0xFF818CF8).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 頂部導航與進度條 ──
  Widget _buildTopBar() {
    final isCoverPage = _currentPage == 0;
    final questionIndex = _currentPage - 1; // 0, 1, 2, 3

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          // 左側返回上一題按鈕 / 封面頁精緻 Sparkle 品牌標章
          if (_currentPage > 0)
            _BouncingTap(
              onTap: _prevPage,
              scaleDown: 0.90,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.90),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF334155),
                  size: 15,
                ),
              ),
            )
          else
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFD8A8)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFEA580C),
                  size: 18,
                ),
              ),
            ),
          const SizedBox(width: 12),

          // 中央區域：封面頁保持開闊 / 問卷頁顯示 Apple 4 段流體進度條
          Expanded(
            child: isCoverPage
                ? const SizedBox.shrink()
                : Row(
                    key: const ValueKey('progress_bar'),
                    children: List.generate(4, (index) {
                      final isCurrent = questionIndex == index;
                      final isPassed = questionIndex > index;

                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 380),
                          curve: kAppleSpringCurve,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: isCurrent ? 5.5 : 4.0,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: isCurrent || isPassed
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFF9F0A),
                                      Color(0xFFF57C00)
                                    ],
                                  )
                                : null,
                            color: isCurrent || isPassed
                                ? null
                                : const Color(0xFFE2E8F0),
                            boxShadow: isCurrent
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF9F0A)
                                          .withValues(alpha: 0.45),
                                      blurRadius: 8,
                                      offset: const Offset(0, 1),
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
          ),
          const SizedBox(width: 12),

          // 右側：略過按鈕（若有提供 onSkip）或空佔位
          if (widget.onSkip != null && _currentPage < 4)
            _BouncingTap(
              onTap: () {
                HapticFeedback.lightImpact();
                _finishOnboarding();
              },
              scaleDown: 0.92,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '略過',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(width: 38, height: 38),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════
  // Step 0: 迎賓封面頁 (Top-Tier Silicon Valley / Apple Aesthetic)
  // ═════════════════════════════════════════════════════
  Widget _buildWelcomeCoverStep() {
    // 若名稱為純數字（如學生學號），友善轉換為高質感問候
    final rawName = widget.userName?.trim() ?? '';
    final isPureNumber = RegExp(r'^\d+$').hasMatch(rawName);
    final greetingTitle = (rawName.isNotEmpty && !isPureNumber)
        ? '嗨，$rawName！\n開啟專屬於你的智慧學習'
        : '歡迎加入！\n開啟專屬於你的智慧學習';

    return _StepContainer(
      stepIndex: 0,
      activePageIndex: _currentPage,
      stepBadge: '✦ AI 智慧伴學 · 個人化啟程',
      title: greetingTitle,
      subtitle: '只需 30 秒回答 4 個小問題，為你即時配置最適切的 AI 解題特助、題庫與心智圖筆記系統。',
      children: const [
        SizedBox(height: 8),

        // 3 大極致質感 Bento 亮點卡片
        _WelcomeFeatureCard(
          emoji: '🎯',
          tag: '精準組卷',
          title: '目標導向題庫與弱項分析',
          description: '依大考或段考進度，推薦最適切的練習難度並即時診斷能力盲點',
          accentColor: Color(0xFF0284C7),
          gradientColors: [Color(0xFF0284C7), Color(0xFF0369A1)],
          bgTint: Color(0xFFF0F9FF),
        ),
        SizedBox(height: 12),
        _WelcomeFeatureCard(
          emoji: '🤖',
          tag: '24H 伴學',
          title: 'AI 步驟詳解與觀念啟發',
          description: '遇到難題即時提供破題思路，引導式教學而非直接給死答案',
          accentColor: Color(0xFFEA580C),
          gradientColors: [Color(0xFFFF9F0A), Color(0xFFEA580C)],
          bgTint: Color(0xFFFFF7ED),
        ),
        SizedBox(height: 12),
        _WelcomeFeatureCard(
          emoji: '🧠',
          tag: '語音速記',
          title: '語音秒轉結構化心智圖',
          description: '課堂錄音自動萃取重點並轉換為視覺化架構，輕鬆梳理知識脈絡',
          accentColor: Color(0xFF7C3AED),
          gradientColors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          bgTint: Color(0xFFF5F3FF),
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════
  // Step 1: 目標與動機 (題目 1 / 4)
  // ═════════════════════════════════════════════════════
  Widget _buildGoalStep() {
    return _StepContainer(
      stepIndex: 1,
      activePageIndex: _currentPage,
      stepBadge: '步驟 1 / 4 · 學習目標',
      title: '你的主要學習目標是什麼？',
      subtitle: '選擇目前最符合的方向，為你推薦合適的內容與工具',
      children: [
        _AppleLinearCard(
          emoji: '🎓',
          title: '升學大考衝刺',
          subtitle: '會考、學測、統測與分科測驗重點複習',
          isSelected: _selectedGoal == 'exam',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedGoal = 'exam');
          },
        ),
        _AppleLinearCard(
          emoji: '📚',
          title: '學校課業鞏固',
          subtitle: '緊跟平時進度，掌握單元核心概念與段考複習',
          isSelected: _selectedGoal == 'school',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedGoal = 'school');
          },
        ),
        _AppleLinearCard(
          emoji: '💡',
          title: '科技與程式探索',
          subtitle: '學習 AI 應用、程式開發與跨學科新知',
          isSelected: _selectedGoal == 'tech',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedGoal = 'tech');
          },
        ),
        _AppleLinearCard(
          emoji: '📝',
          title: '自律習慣與日常',
          subtitle: '規劃每日讀書節奏、整理筆記與打卡記錄',
          isSelected: _selectedGoal == 'daily',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedGoal = 'daily');
          },
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════
  // Step 2: 痛點與需求 (題目 2 / 4)
  // ═════════════════════════════════════════════════════
  Widget _buildPainPointsStep() {
    return _StepContainer(
      stepIndex: 2,
      activePageIndex: _currentPage,
      stepBadge: '步驟 2 / 4 · 學習困擾 (可多選)',
      title: '平時學習最常遇到哪些困擾？',
      subtitle: '選取你的需求，系統將優先為你配置智慧輔助工具',
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _BentoSquareCard(
                  width: cardWidth,
                  emoji: '🧩',
                  badgeText: 'AI 破題',
                  title: '遇到難題卡關',
                  subtitle: '即時引導解題思路與盲點',
                  isSelected: _selectedPainPoints.contains('stuck_questions'),
                  onTap: () => _togglePainPoint('stuck_questions'),
                ),
                _BentoSquareCard(
                  width: cardWidth,
                  emoji: '📑',
                  badgeText: '語音轉大綱',
                  title: '筆記散亂繁雜',
                  subtitle: '口述秒轉心智圖與重點架構',
                  isSelected: _selectedPainPoints.contains('scattered_notes'),
                  onTap: () => _togglePainPoint('scattered_notes'),
                ),
                _BentoSquareCard(
                  width: cardWidth,
                  emoji: '⏰',
                  badgeText: '智慧排程',
                  title: '缺乏自律規劃',
                  subtitle: '自動產生計畫並同步日曆',
                  isSelected: _selectedPainPoints.contains('procrastination'),
                  onTap: () => _togglePainPoint('procrastination'),
                ),
                _BentoSquareCard(
                  width: cardWidth,
                  emoji: '📦',
                  badgeText: '資源共享',
                  title: '缺少練習資源',
                  subtitle: '同儕優質題庫與試卷一鍵獲取',
                  isSelected: _selectedPainPoints.contains('resource_lacking'),
                  onTap: () => _togglePainPoint('resource_lacking'),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════
  // Step 3: 學習模式偏好 (題目 3 / 4)
  // ═════════════════════════════════════════════════════
  Widget _buildIncentiveStep() {
    return _StepContainer(
      stepIndex: 3,
      activePageIndex: _currentPage,
      stepBadge: '步驟 3 / 4 · 學習模式',
      title: '你偏好哪種學習氛圍？',
      subtitle: '依照你的學習習慣，為你打造最舒服的使用方式',
      children: [
        _ImmersiveHeroCard(
          emoji: '🧘',
          tag: '個人專注',
          title: '安靜沉浸，個人專注學習',
          description: '以個人題庫、專屬筆記與 AI 解題為主，不受外界打擾',
          accentColor: const Color(0xFF0284C7),
          tintBgColor: const Color(0xFFF0F9FF),
          isSelected: _selectedIncentive == 'solo',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedIncentive = 'solo');
          },
        ),
        _ImmersiveHeroCard(
          emoji: '🤝',
          tag: '同儕交流',
          title: '社群互動，與同儕互相交流',
          description: '參與熱門主題討論、查看同學分享的筆記與心得資源',
          accentColor: const Color(0xFF7C3AED),
          tintBgColor: const Color(0xFFF5F3FF),
          isSelected: _selectedIncentive == 'peer',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedIncentive = 'peer');
          },
        ),
        _ImmersiveHeroCard(
          emoji: '🔥',
          tag: '目標排行',
          title: '打卡激勵，成就排行榜挑戰',
          description: '結合學習點數、累積連續天數與成就榜激勵自己前進',
          accentColor: const Color(0xFFEA580C),
          tintBgColor: const Color(0xFFFFF7ED),
          isSelected: _selectedIncentive == 'team',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedIncentive = 'team');
          },
        ),
        _ImmersiveHeroCard(
          emoji: '🤖',
          tag: 'AI 伴學',
          title: '專屬教練，24 小時智慧隨行',
          description: '隨時提問解惑、提供弱點診斷與即時精準回饋',
          accentColor: const Color(0xFF059669),
          tintBgColor: const Color(0xFFECFDF5),
          isSelected: _selectedIncentive == 'ai_coach',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedIncentive = 'ai_coach');
          },
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════
  // Step 4: 關注學科 (題目 4 / 4 · 方案 A 頂部 Tab 零垂直滾動)
  // ═════════════════════════════════════════════════════
  Widget _buildSubjectsStep() {
    final totalSelected = _selectedTopicIds.length;
    final currentGroup = _subjectGroups[_selectedSubjectCategoryIndex];
    final currentGroupTopicIds =
        currentGroup.topics.map((t) => t.id).toList();
    final isCurrentGroupAllSelected =
        currentGroupTopicIds.every((id) => _selectedTopicIds.contains(id));

    return _StepContainer(
      stepIndex: 4,
      activePageIndex: _currentPage,
      stepBadge: '步驟 4 / 4 · 關注學科 (可多選)',
      title: '選擇你想關注的學科領域',
      subtitle: '點選上方分類隨時探索切換，為你優先推薦相關題目與筆記',
      headerExtra: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 總選取徽章
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5.5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFFD8A8),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 14,
                  color: Color(0xFFF57C00),
                ),
                const SizedBox(width: 6),
                Text(
                  '已選取 $totalSelected 個領域標籤',
                  style: const TextStyle(
                    color: Color(0xFFC2410C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // 🌟 方案 A 核心：頂部橫向分類切換 Segmented Tab Bar（帶彈簧回彈）
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(_subjectGroups.length, (index) {
                  final group = _subjectGroups[index];
                  final isSelectedTab = _selectedSubjectCategoryIndex == index;
                  final selectedInGroup = group.topics
                      .where((t) => _selectedTopicIds.contains(t.id))
                      .length;

                  return _BouncingTap(
                    scaleDown: 0.93,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedSubjectCategoryIndex = index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: kAppleSpringCurve,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8.5),
                      decoration: BoxDecoration(
                        color: isSelectedTab ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelectedTab
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.07),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            group.categoryEmoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            group.categoryShortName,
                            style: TextStyle(
                              color: isSelectedTab
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF64748B),
                              fontSize: 12.5,
                              fontWeight: isSelectedTab
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          if (selectedInGroup > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5.5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelectedTab
                                    ? const Color(0xFFFF9F0A)
                                    : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$selectedInGroup',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
      children: [
        // 🌟 當前選中分類的標籤雲面板（單屏完整容納 + 標籤彈簧瀑布流）
        _AnimatedCategoryCard(
          key: ValueKey<int>(_selectedSubjectCategoryIndex),
          groupEmoji: currentGroup.categoryEmoji,
          groupName: currentGroup.categoryName,
          isAllSelected: isCurrentGroupAllSelected,
          onToggleAll: () => _toggleGroupAll(currentGroupTopicIds),
          topics: currentGroup.topics,
          selectedTopicIds: _selectedTopicIds,
          onToggleTopic: _toggleTopic,
        ),

        const SizedBox(height: 12),

        // 底部貼心提示小徽章
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 15,
                color: Color(0xFF94A3B8),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '點選上方分類標籤可自由切換，隨時於個人設定隨心調整',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 底部固定全寬膠囊按鈕（帶彈性按壓回饋與光暈） ──
  Widget _buildBottomBar() {
    final isCoverPage = _currentPage == 0;
    final isLastPage = _currentPage == 4;

    String buttonText = '下一步';
    if (isCoverPage) {
      buttonText = '開啟 30 秒專屬配置';
    } else if (isLastPage) {
      buttonText = '開始使用';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BouncingTap(
            scaleDown: 0.95,
            onTap: _nextPage,
            child: Container(
              height: 54,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF9F0A), // 暖亮琥珀
                    Color(0xFFEA580C), // 活力暖橙
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF9F0A).withValues(alpha: 0.42),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                            CurvedAnimation(parent: anim, curve: kAppleBounceBack),
                          ),
                          child: child,
                        ),
                      ),
                      child: Text(
                        buttonText,
                        key: ValueKey<String>(buttonText),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      transitionBuilder: (child, anim) => RotationTransition(
                        turns: anim,
                        child: ScaleTransition(scale: anim, child: child),
                      ),
                      child: Icon(
                        isLastPage
                            ? Icons.auto_awesome_rounded
                            : Icons.arrow_forward_rounded,
                        key: ValueKey<bool>(isLastPage),
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isCoverPage) ...[
            const SizedBox(height: 6),
            Text(
              '⚡ 約需 30 秒 · 隨時可於「個人檔案」調整所有偏好',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// 題目外框容器：微延遲瀑布流交錯進場（Step-Aware Staggered Waterfall）
// 每次步驟切換時，徽章 ➔ 標題 ➔ 副標題 ➔ 卡片 依序流暢展開
// ─────────────────────────────────────────────────────

class _StepContainer extends StatefulWidget {
  final int stepIndex;
  final int activePageIndex;
  final String stepBadge;
  final String title;
  final String subtitle;
  final Widget? headerExtra;
  final List<Widget> children;

  const _StepContainer({
    required this.stepIndex,
    required this.activePageIndex,
    required this.stepBadge,
    required this.title,
    required this.subtitle,
    this.headerExtra,
    required this.children,
  });

  @override
  State<_StepContainer> createState() => _StepContainerState();
}

class _StepContainerState extends State<_StepContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _cascadeCtrl;

  @override
  void initState() {
    super.initState();
    _cascadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );

    if (widget.activePageIndex == widget.stepIndex) {
      _cascadeCtrl.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _StepContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 當切換至本頁時，重啟優雅的微延遲瀑布流進場
    if (widget.activePageIndex == widget.stepIndex &&
        oldWidget.activePageIndex != widget.stepIndex) {
      _cascadeCtrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _cascadeCtrl.dispose();
    super.dispose();
  }

  Widget _buildCascadeItem({
    required int index,
    required Widget child,
  }) {
    // 每個元素之間相差微小的 0.07 延遲，營造像水波般的層次展開
    final double start = (index * 0.07).clamp(0.0, 0.60);
    final double end = (start + 0.38).clamp(0.0, 1.0);

    final slideAndFade = CurvedAnimation(
      parent: _cascadeCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    final springScale = CurvedAnimation(
      parent: _cascadeCtrl,
      curve: Interval(start, end, curve: kAppleBounceBack),
    );

    return AnimatedBuilder(
      animation: _cascadeCtrl,
      builder: (context, _) {
        final opacity = slideAndFade.value.clamp(0.0, 1.0);
        final offsetY = (1.0 - slideAndFade.value) * 28.0;
        final scale = 0.91 + (springScale.value * 0.09);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, offsetY),
            child: Transform.scale(
              scale: scale.clamp(0.80, 1.04),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int itemCounter = 0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 頂部小膠囊徽章
          _buildCascadeItem(
            index: itemCounter++,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD8A8),
                  width: 1.0,
                ),
              ),
              child: Text(
                widget.stepBadge,
                style: const TextStyle(
                  color: Color(0xFFEA580C),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 醒目大標題 (Deep Charcoal)
          _buildCascadeItem(
            index: itemCounter++,
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 22.5,
                fontWeight: FontWeight.w800,
                height: 1.25,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 5),

          // 引導副標題 (Slate Grey)
          _buildCascadeItem(
            index: itemCounter++,
            child: Text(
              widget.subtitle,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 步驟頂部額外內容（如學科 Tab）
          if (widget.headerExtra != null)
            _buildCascadeItem(
              index: itemCounter++,
              child: widget.headerExtra!,
            ),

          // 步驟主互動內容（依序微延遲浮現）
          ...widget.children.map(
            (child) => _buildCascadeItem(
              index: itemCounter++,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Step 0: 迎賓封面專屬極簡特色迷你卡片
// ─────────────────────────────────────────────────────

class _WelcomeFeatureCard extends StatelessWidget {
  final String emoji;
  final String tag;
  final String title;
  final String description;
  final Color accentColor;
  final List<Color> gradientColors;
  final Color bgTint;

  const _WelcomeFeatureCard({
    required this.emoji,
    required this.tag,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.gradientColors,
    required this.bgTint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 頂級 3D 質感漸層 Squircle 徽章
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),

          // 卡片標題、標籤與說明文案
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: bgTint,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3.5),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Step 4 專屬組件：切換 Tab 時標籤雲的彈簧瀑布流卡片
// ─────────────────────────────────────────────────────

class _AnimatedCategoryCard extends StatefulWidget {
  final String groupEmoji;
  final String groupName;
  final bool isAllSelected;
  final VoidCallback onToggleAll;
  final List<({String id, String name, String emoji})> topics;
  final Set<String> selectedTopicIds;
  final void Function(String id) onToggleTopic;

  const _AnimatedCategoryCard({
    super.key,
    required this.groupEmoji,
    required this.groupName,
    required this.isAllSelected,
    required this.onToggleAll,
    required this.topics,
    required this.selectedTopicIds,
    required this.onToggleTopic,
  });

  @override
  State<_AnimatedCategoryCard> createState() => _AnimatedCategoryCardState();
}

class _AnimatedCategoryCardState extends State<_AnimatedCategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _chipsCtrl;

  @override
  void initState() {
    super.initState();
    _chipsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _chipsCtrl.forward();
  }

  @override
  void dispose() {
    _chipsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分類標題與快速「全選 / 取消全選」小按鈕
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    widget.groupEmoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.groupName,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
              _BouncingTap(
                scaleDown: 0.90,
                onTap: widget.onToggleAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.isAllSelected
                        ? const Color(0xFFFFF7ED)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.isAllSelected
                          ? const Color(0xFFFFD8A8)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    widget.isAllSelected ? '取消全選' : '全選此類',
                    style: TextStyle(
                      color: widget.isAllSelected
                          ? const Color(0xFFEA580C)
                          : const Color(0xFF64748B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 標籤雲清單（每個標籤彈簧交錯進場）
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: List.generate(widget.topics.length, (idx) {
              final t = widget.topics[idx];
              final isSelected = widget.selectedTopicIds.contains(t.id);

              final start = (idx * 0.08).clamp(0.0, 0.6);
              final end = (start + 0.40).clamp(0.0, 1.0);
              final anim = CurvedAnimation(
                parent: _chipsCtrl,
                curve: Interval(start, end, curve: kAppleBounceBack),
              );

              return ScaleTransition(
                scale: anim,
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _chipsCtrl,
                    curve: Interval(start, end, curve: Curves.easeOut),
                  ),
                  child: _CapsuleTopicChip(
                    emoji: t.emoji,
                    label: t.name,
                    isSelected: isSelected,
                    onTap: () => widget.onToggleTopic(t.id),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// 互動組件：Apple 物理按壓彈簧回彈（Spring Bouncing Tap）
// ─────────────────────────────────────────────────────

class _BouncingTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleDown;

  const _BouncingTap({
    required this.child,
    required this.onTap,
    this.scaleDown = 0.95,
  });

  @override
  State<_BouncingTap> createState() => _BouncingTapState();
}

class _BouncingTapState extends State<_BouncingTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _scale = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: kAppleBounceBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Step 1: Apple 白底精緻直列卡片（附彈簧微縮放與邊框漸層）
// ─────────────────────────────────────────────────────

class _AppleLinearCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _AppleLinearCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _BouncingTap(
        onTap: onTap,
        scaleDown: 0.965,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: kAppleSpringCurve,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFF9F0A)
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF9F0A).withValues(alpha: 0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // 左側圖示容器
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: kAppleSpringCurve,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFFEDD5)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFFD8A8)
                        : const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // 主標題與副標題
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF9A3412)
                            : const Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFC2410C)
                            : const Color(0xFF64748B),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // 右側單選勾選圓圈
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: kAppleBounceBack,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? const Color(0xFFFF9F0A)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFFF9F0A)
                        : const Color(0xFFCBD5E1),
                    width: 1.6,
                  ),
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Step 2: Apple 白底 2x2 Bento 網格方形卡片
// ─────────────────────────────────────────────────────

class _BentoSquareCard extends StatelessWidget {
  final double width;
  final String emoji;
  final String badgeText;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _BentoSquareCard({
    required this.width,
    required this.emoji,
    required this.badgeText,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 152,
      child: _BouncingTap(
        onTap: onTap,
        scaleDown: 0.95,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: kAppleSpringCurve,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFFF9F0A)
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF9F0A).withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 頂部圖示與 Checkbox
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFFEDD5)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFFD8A8)
                            : const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(emoji,
                          style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: kAppleBounceBack,
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: isSelected
                          ? const Color(0xFFFF9F0A)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF9F0A)
                            : const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ],
              ),

              // 中下方標題與副標
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF9A3412)
                          : const Color(0xFF0F172A),
                      fontSize: 14.5,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFFC2410C)
                          : const Color(0xFF64748B),
                      fontSize: 11,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Step 3: Apple 白底 沉浸風格情境大卡片 (Immersive Hero Cards)
// ─────────────────────────────────────────────────────

class _ImmersiveHeroCard extends StatelessWidget {
  final String emoji;
  final String tag;
  final String title;
  final String description;
  final Color accentColor;
  final Color tintBgColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _ImmersiveHeroCard({
    required this.emoji,
    required this.tag,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.tintBgColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: _BouncingTap(
        onTap: onTap,
        scaleDown: 0.965,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: kAppleSpringCurve,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isSelected ? tintBgColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? accentColor : const Color(0xFFE2E8F0),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
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
              // 頂部 Tag 膠囊與勾選指示
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withValues(alpha: 0.14)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.4)
                            : const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color:
                            isSelected ? accentColor : const Color(0xFF475569),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: kAppleBounceBack,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? accentColor : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? accentColor
                            : const Color(0xFFCBD5E1),
                        width: 1.6,
                      ),
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 主標題與描述
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF334155)
                                : const Color(0xFF64748B),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Step 4: Apple 白底 靈活多選膠囊標籤雲 (Capsule Topic Chip)
// ─────────────────────────────────────────────────────

class _CapsuleTopicChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CapsuleTopicChip({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _BouncingTap(
      onTap: onTap,
      scaleDown: 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: kAppleSpringCurve,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFF7ED)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF9F0A)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF9F0A).withValues(alpha: 0.20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF9A3412)
                    : const Color(0xFF334155),
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.check_rounded,
                size: 13,
                color: Color(0xFFEA580C),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
