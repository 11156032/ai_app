import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'common_widgets.dart';

// ─────────────────────────────────────────────────────
// WelcomeSplash — 頂級 Apple 白底風格（Light Theme）多元互動歡迎引導介面
// 包含：純白晶透背景、直列自動跳轉、2x2 Bento 網格、沉浸情境大卡片、膠囊標籤雲
// ─────────────────────────────────────────────────────

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
  int _currentPage = 0;

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
  static const List<({String categoryId, String categoryName, String categoryEmoji, List<({String id, String name, String emoji})> topics})>
      _subjectGroups = [
    (
      categoryId: 'cat_stem',
      categoryName: '數理邏輯與自然科學',
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
      duration: const Duration(milliseconds: 550),
    );
    _fadeIn = CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryAnim, curve: Curves.easeOutCubic));
    _entryAnim.forward();

    _exitAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitAnim, curve: Curves.easeInCubic),
    );
    _slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.03),
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
    if (_currentPage < 3) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prevPage() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
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
    HapticFeedback.lightImpact();
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
              // 頂級 Apple 白底氛圍背景漸層與柔和微光
              _buildAppleLightBackground(),

              SafeArea(
                child: FadeTransition(
                  opacity: _fadeIn,
                  child: SlideTransition(
                    position: _slideIn,
                    child: Column(
                      children: [
                        // 頂部導航列：返回與分段式膠囊進度條（無略過按鈕）
                        _buildTopBar(),

                        // 中央 4 大步驟多元互動 PageView
                        Expanded(
                          child: PageView(
                            controller: _pageCtrl,
                            onPageChanged: _onPageChanged,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              _buildGoalStep(), // Step 1: 學習目標
                              _buildPainPointsStep(), // Step 2: 學習困擾
                              _buildIncentiveStep(), // Step 3: 學習模式
                              _buildSubjectsStep(), // Step 4: 關注學科
                            ],
                          ),
                        ),

                        // 底部固定全寬膠囊按鈕
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
            top: -60,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF38BDF8).withValues(alpha: 0.12),
                    const Color(0xFF38BDF8).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // 左側中央柔和暖金微光
          Positioned(
            top: 240,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFB74D).withValues(alpha: 0.12),
                    const Color(0xFFFFB74D).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // 右下方柔和紫羅蘭微光
          Positioned(
            bottom: 30,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF818CF8).withValues(alpha: 0.10),
                    const Color(0xFF818CF8).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 頂部導航與分段膠囊進度條 ──
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          // 左側返回上一題按鈕
          if (_currentPage > 0)
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF334155),
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: _prevPage,
              tooltip: '上一步',
            )
          else
            const SizedBox(width: 36, height: 36),
          const SizedBox(width: 8),

          // 中央 Apple 膠囊分段進度條 (4 段)
          Expanded(
            child: Row(
              children: List.generate(4, (index) {
                final isCurrent = _currentPage == index;
                final isPassed = _currentPage > index;

                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: isCurrent ? 5.0 : 4.0,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: isCurrent || isPassed
                          ? const LinearGradient(
                              colors: [Color(0xFFFF9F0A), Color(0xFFF57C00)],
                            )
                          : null,
                      color: isCurrent || isPassed
                          ? null
                          : const Color(0xFFE2E8F0),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFF9F0A)
                                    .withValues(alpha: 0.35),
                                blurRadius: 6,
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
          const SizedBox(width: 8),

          // 右側佔位保持進度條置中平衡
          const SizedBox(width: 36, height: 36),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════
  // Step 1: 目標與動機 (點選不自動跳轉，文案清晰精簡)
  // ═════════════════════════════════════════════════════
  Widget _buildGoalStep() {
    return _StepContainer(
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
  // Step 2: 痛點與需求 (白底 2x2 Bento 網格方形卡片)
  // ═════════════════════════════════════════════════════
  Widget _buildPainPointsStep() {
    return _StepContainer(
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
  // Step 3: 學習模式偏好 (點選不自動跳轉，情境大卡片)
  // ═════════════════════════════════════════════════════
  Widget _buildIncentiveStep() {
    return _StepContainer(
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
  // Step 4: 關注學科 (白底 靈活多選膠囊標籤雲 Chip/Wrap)
  // ═════════════════════════════════════════════════════
  Widget _buildSubjectsStep() {
    final totalSelected = _selectedTopicIds.length;

    return _StepContainer(
      stepBadge: '步驟 4 / 4 · 關注學科 (可多選)',
      title: '選擇你想關注的學科領域',
      subtitle: '優先為你推薦相關的題目與學習動態',
      headerExtra: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
      children: _subjectGroups.map((group) {
        final groupTopicIds = group.topics.map((t) => t.id).toList();
        final isGroupAllSelected =
            groupTopicIds.every((id) => _selectedTopicIds.contains(id));

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 分類標題與全選小按鈕
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(group.categoryEmoji,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        group.categoryName,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => _toggleGroupAll(groupTopicIds),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      child: Text(
                        isGroupAllSelected ? '取消全選' : '全選',
                        style: TextStyle(
                          color: isGroupAllSelected
                              ? const Color(0xFFEA580C)
                              : const Color(0xFF64748B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 膠囊標籤雲 (Wrap of Capsule Chips)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: group.topics.map((t) {
                  final isSelected = _selectedTopicIds.contains(t.id);
                  return _CapsuleTopicChip(
                    emoji: t.emoji,
                    label: t.name,
                    isSelected: isSelected,
                    onTap: () => _toggleTopic(t.id),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── 底部固定全寬膠囊按鈕 ──
  Widget _buildBottomBar() {
    final isLastPage = _currentPage == 3;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _nextPage,
          borderRadius: BorderRadius.circular(28),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 54,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF9F0A), // 暖亮琥珀
                  Color(0xFFF57C00), // 活力深橙
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9F0A).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLastPage ? '開始使用' : '下一步',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isLastPage
                        ? Icons.auto_awesome_rounded
                        : Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// 題目外框容器：舒適留白、層次分明的大標題與副標題
// ─────────────────────────────────────────────────────

class _StepContainer extends StatelessWidget {
  final String stepBadge;
  final String title;
  final String subtitle;
  final Widget? headerExtra;
  final List<Widget> children;

  const _StepContainer({
    required this.stepBadge,
    required this.title,
    required this.subtitle,
    this.headerExtra,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 頂部小膠囊徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFD8A8),
                width: 1.0,
              ),
            ),
            child: Text(
              stepBadge,
              style: const TextStyle(
                color: Color(0xFFEA580C),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 醒目大標題 (Deep Charcoal)
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 22.5,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 5),

          // 引導副標題 (Slate Grey)
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          if (headerExtra != null) headerExtra!,

          // 步驟主互動內容
          ...children,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// Step 1: Apple 白底精緻直列卡片
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFFF7ED)
                  : Colors.white,
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
            child: Row(
              children: [
                // 左側圖示容器
                Container(
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
                  duration: const Duration(milliseconds: 200),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFFF7ED)
                  : Colors.white,
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
                        color: const Color(0xFFFF9F0A).withValues(alpha: 0.16),
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
                      duration: const Duration(milliseconds: 200),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
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
                        color: accentColor.withValues(alpha: 0.18),
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
                          color: isSelected ? accentColor : const Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7.5),
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
                      color: const Color(0xFFFF9F0A).withValues(alpha: 0.16),
                      blurRadius: 6,
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
      ),
    );
  }
}
