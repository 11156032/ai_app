import 'dart:async';
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
  final VoidCallback onSkip;
  final String? userName;
  final List<String>? initialTopicIds;

  const WelcomeSplash({
    super.key,
    required this.onDone,
    required this.onSkip,
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
  Timer? _autoAdvanceTimer;

  late AnimationController _entryAnim;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

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
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _entryAnim, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryAnim, curve: Curves.easeOutCubic));
    _entryAnim.forward();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _entryAnim.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  /// 250ms 自動延遲平滑跳轉下一頁（單選題流暢體驗）
  void _triggerAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted && _currentPage < 3) {
        _nextPage();
      }
    });
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
    _autoAdvanceTimer?.cancel();
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  void _finishOnboarding() {
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
                    // 頂部導航列：返回、分段式膠囊進度條、略過按鈕
                    _buildTopBar(),

                    // 中央 4 大步驟多元互動 PageView
                    Expanded(
                      child: PageView(
                        controller: _pageCtrl,
                        onPageChanged: _onPageChanged,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildGoalStep(), // Step 1: 直列卡片 + 250ms 自動跳轉
                          _buildPainPointsStep(), // Step 2: 2x2 Bento 網格方形卡片
                          _buildIncentiveStep(), // Step 3: 沉浸情境大卡片
                          _buildSubjectsStep(), // Step 4: 靈活多選膠囊標籤雲
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
          AnimatedOpacity(
            opacity: _currentPage > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF334155),
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: _currentPage > 0 ? _prevPage : null,
              tooltip: '上一題',
            ),
          ),
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

          // 右側晶透略過按鈕
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onSkip,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  '略過',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════
  // Step 1: 目標與動機 (白底直列卡片 + 250ms 自動跳轉)
  // ═════════════════════════════════════════════════════
  Widget _buildGoalStep() {
    final name = (widget.userName != null && widget.userName!.trim().isNotEmpty)
        ? widget.userName!.trim()
        : '同學';

    return _StepContainer(
      stepBadge: 'STEP 01 / 04 · 目標與動機',
      title: '$name，你目前的學習目標是？',
      subtitle: '點選後將為你客製化推薦內容與診斷深度（單選即自動前進）',
      children: [
        _AppleLinearCard(
          emoji: '🎓',
          title: '升學大考衝刺',
          subtitle: '會考、學測、分科測驗重點複習與弱點突破',
          isSelected: _selectedGoal == 'exam',
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedGoal = 'exam');
            _triggerAutoAdvance();
          },
        ),
        _AppleLinearCard(
          emoji: '📚',
          title: '段考與課業鞏固',
          subtitle: '緊跟課堂進度，精準掌握單元核心概念',
          isSelected: _selectedGoal == 'school',
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedGoal = 'school');
            _triggerAutoAdvance();
          },
        ),
        _AppleLinearCard(
          emoji: '💡',
          title: '科技與跨域自學',
          subtitle: '探索 AI 程式、前沿科普與跨學科新知',
          isSelected: _selectedGoal == 'tech',
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedGoal = 'tech');
            _triggerAutoAdvance();
          },
        ),
        _AppleLinearCard(
          emoji: '📝',
          title: '日常自律與習慣養成',
          subtitle: '持續打卡記錄、整理心智圖與讀書心得',
          isSelected: _selectedGoal == 'daily',
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedGoal = 'daily');
            _triggerAutoAdvance();
          },
        ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════
  // Step 2: 痛點共鳴 (白底 2x2 Bento 網格方形卡片)
  // ═════════════════════════════════════════════════════
  Widget _buildPainPointsStep() {
    return _StepContainer(
      stepBadge: 'STEP 02 / 04 · 痛點共鳴 (可多選)',
      title: '在學習過程中，你遇到最大的挑戰？',
      subtitle: '點選你的痛點，系統將為你優先配置對應的 AI 伴學工具',
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
                  badgeText: 'AI 破題盲點',
                  title: '卡題無人指引',
                  subtitle: '即時自然語言破題，循序引導思考',
                  isSelected: _selectedPainPoints.contains('stuck_questions'),
                  onTap: () => _togglePainPoint('stuck_questions'),
                ),
                _BentoSquareCard(
                  width: cardWidth,
                  emoji: '📑',
                  badgeText: '口述轉心智圖',
                  title: '筆記散亂繁雜',
                  subtitle: '語音錄音秒轉樹狀大綱與知識架構',
                  isSelected: _selectedPainPoints.contains('scattered_notes'),
                  onTap: () => _togglePainPoint('scattered_notes'),
                ),
                _BentoSquareCard(
                  width: cardWidth,
                  emoji: '⏰',
                  badgeText: '智慧排程日曆',
                  title: '缺乏自律拖延',
                  subtitle: '自動生成讀書計畫並同步行事曆',
                  isSelected: _selectedPainPoints.contains('procrastination'),
                  onTap: () => _togglePainPoint('procrastination'),
                ),
                _BentoSquareCard(
                  width: cardWidth,
                  emoji: '📦',
                  badgeText: '社群 Pack 模組',
                  title: '缺優質題庫試卷',
                  subtitle: '同儕優質資源與考題一鍵匯入刷題',
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
  // Step 3: 同儕與動機誘因 (白底 沉浸情境大卡片)
  // ═════════════════════════════════════════════════════
  Widget _buildIncentiveStep() {
    return _StepContainer(
      stepBadge: 'STEP 03 / 04 · 學習模式偏好',
      title: '你喜歡自己專注，還是與他人一起進步？',
      subtitle: '依你的偏好決定推薦社群互動、組隊打卡或安靜個人模式',
      children: [
        _ImmersiveHeroCard(
          emoji: '🧘',
          tag: '極簡私密 · AI 隨行',
          title: '個人深度專注，安靜沈浸學習',
          description: '個人隱私模式優先，沉浸於個人題庫、筆記與 AI 解題，不受干擾',
          accentColor: const Color(0xFF0284C7),
          tintBgColor: const Color(0xFFF0F9FF),
          isSelected: _selectedIncentive == 'solo',
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedIncentive = 'solo');
            _triggerAutoAdvance();
          },
        ),
        _ImmersiveHeroCard(
          emoji: '🤝',
          tag: '同儕互動 · 心得共享',
          title: '喜歡與他人交流，互相激勵打氣',
          description: '推薦社群互動、熱門討論主題與同學筆記心得資源共享',
          accentColor: const Color(0xFF7C3AED),
          tintBgColor: const Color(0xFFF5F3FF),
          isSelected: _selectedIncentive == 'peer',
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedIncentive = 'peer');
            _triggerAutoAdvance();
          },
        ),
        _ImmersiveHeroCard(
          emoji: '🔥',
          tag: '榮譽成就 · 組隊激勵',
          title: '喜歡組隊打卡與成就排行榜',
          description: '結合學習點數、成就排行榜與同儕組隊激勵前行',
          accentColor: const Color(0xFFEA580C),
          tintBgColor: const Color(0xFFFFF7ED),
          isSelected: _selectedIncentive == 'team',
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedIncentive = 'team');
            _triggerAutoAdvance();
          },
        ),
        _ImmersiveHeroCard(
          emoji: '🤖',
          tag: '24H 即時 · 弱點診斷',
          title: '只要 AI 智慧教練專屬隨身陪伴',
          description: '24 小時伴學解題，提供量化弱點診斷與即時精準反饋',
          accentColor: const Color(0xFF059669),
          tintBgColor: const Color(0xFFECFDF5),
          isSelected: _selectedIncentive == 'ai_coach',
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedIncentive = 'ai_coach');
            _triggerAutoAdvance();
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
      stepBadge: 'STEP 04 / 04 · 關注學科 (可多選)',
      title: '選擇你想優先關注的學科領域',
      subtitle: '可靈活點選下方膠囊標籤，優先推薦對應動態與精選題庫',
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
              '已選取 $totalSelected 個關注標籤',
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
                    isLastPage ? '開啟專屬學習旅程' : '下一步',
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
