import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'about/about_us_painters.dart';
import 'about/about_us_animations.dart';

typedef _ShimmerCard = ShimmerCard;
typedef _RevealOnScroll = RevealOnScroll;

// ======================================================
//  AboutUsScreen — 關於我們頁面（進階滾動動畫 & 3D 背景）
// ======================================================
class AboutUsScreen extends StatefulWidget {
  const AboutUsScreen({super.key});

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _idleController; // background loop + orbital
  late AnimationController _entranceController; // hero entrance
  late AnimationController _typewriterController;
  late AnimationController _shimmerController; // mission card shimmer
  late List<ParticleData> _particles;

  double _scrollProgress = 0.0;
  double _scrollOffset = 0.0;

  // ✏️ [修改處 1] 我們所打造的目標
  static const _missionText =
      '「讓每一位學習者都能享有規劃時間管理、系統化知識整理並提供即時 AI 智慧伴學。\n無論身在何處，解決您時間管理、知識統整及獨自學習的困擾！」';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);

    _idleController =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..repeat();

    _entranceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();

    _typewriterController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..addListener(() {
        if (_typewriterController.isAnimating && _scrollController.hasClients) {
          final maxScroll = _scrollController.position.maxScrollExtent;
          if (_scrollController.offset < maxScroll) {
            _scrollController.jumpTo(maxScroll);
          }
        }
      });

    _shimmerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();

    final rng = math.Random(42);
    _particles = [
      // Far layer (15): small, slow, purple-tinted
      ...List.generate(
          15,
          (i) => ParticleData(
                x: rng.nextDouble(),
                y: rng.nextDouble(),
                radius: 0.7 + rng.nextDouble() * 1.0,
                speed: 0.04 + rng.nextDouble() * 0.07,
                phase: rng.nextDouble() * math.pi * 2,
                layer: 0,
              )),
      // Mid layer (20): default
      ...List.generate(
          20,
          (i) => ParticleData(
                x: rng.nextDouble(),
                y: rng.nextDouble(),
                radius: 1.2 + rng.nextDouble() * 1.8,
                speed: 0.10 + rng.nextDouble() * 0.16,
                phase: rng.nextDouble() * math.pi * 2,
                layer: 1,
              )),
      // Near layer (10): large, fast, glowing
      ...List.generate(
          10,
          (i) => ParticleData(
                x: rng.nextDouble(),
                y: rng.nextDouble(),
                radius: 2.5 + rng.nextDouble() * 2.2,
                speed: 0.20 + rng.nextDouble() * 0.28,
                phase: rng.nextDouble() * math.pi * 2,
                layer: 2,
              )),
    ];
  }

  void _onScroll() {
    if (!mounted) return;
    final maxE = _scrollController.position.maxScrollExtent;
    setState(() {
      _scrollOffset = _scrollController.offset;
      _scrollProgress =
          maxE > 0 ? (_scrollController.offset / maxE).clamp(0.0, 1.0) : 0.0;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _idleController.dispose();
    _entranceController.dispose();
    _typewriterController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topBarOpacity = (1.0 - (_scrollOffset / 80.0)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF080818),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IgnorePointer(
          ignoring: topBarOpacity < 0.1,
          child: Opacity(
            opacity: topBarOpacity,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        // ✏️ [修改處 2] 頁面頂部標題
        title: Opacity(
          opacity: topBarOpacity,
          child: const Text(
            '關於我們',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5),
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Layer 1: Shifting base gradient ─────────────
          AnimatedBuilder(
            animation: _idleController,
            builder: (context, _) {
              final t = _scrollProgress;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                          const Color(0xFF080818), const Color(0xFF040C20), t)!,
                      Color.lerp(
                          const Color(0xFF160D30), const Color(0xFF080E28), t)!,
                      Color.lerp(
                        primaryColor.withValues(alpha: 0.22),
                        const Color(0xFF1A2060).withValues(alpha: 0.3),
                        t,
                      )!,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              );
            },
          ),

          // ── Layer 2: Nebula clouds ───────────────────────
          AnimatedBuilder(
            animation: _idleController,
            builder: (context, _) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: NebulaPainter(
                time: _idleController.value,
                scrollOffset: _scrollOffset,
                primaryColor: primaryColor,
              ),
            ),
          ),

          // ── Layer 3: Hex flow grid ───────────────────────
          AnimatedBuilder(
            animation: _idleController,
            builder: (context, _) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: FlowGridPainter(
                time: _idleController.value,
                scrollOffset: _scrollOffset,
                primaryColor: primaryColor,
              ),
            ),
          ),

          // ── Main scrollable content ──────────────────────
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHero(primaryColor)),
              SliverToBoxAdapter(
                  child: _buildBody(context, primaryColor, isDark)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── HERO ─────────────────────────────────────────────
  Widget _buildHero(Color primaryColor) {
    // Parallax: sphere shrinks + fades as user scrolls down
    final heroScale = (1.0 - _scrollOffset / 900.0).clamp(0.85, 1.0);
    final heroOpacity = (1.0 - _scrollOffset / 280.0).clamp(0.0, 1.0);

    return SizedBox(
      height: 380,
      child: Stack(
        children: [
          // 3-layer particles (always present)
          AnimatedBuilder(
            animation: _idleController,
            builder: (_, __) => CustomPaint(
              size: const Size(double.infinity, 380),
              painter: ParticlePainter(
                particles: _particles,
                time: _idleController.value,
                scrollOffset: _scrollOffset,
                primaryColor: primaryColor,
              ),
            ),
          ),

          // 3D orbital sphere — parallax scale + fade
          Opacity(
            opacity: heroOpacity,
            child: Transform.scale(
              scale: heroScale,
              child: AnimatedBuilder(
                animation: _idleController,
                builder: (_, __) {
                  final idleRot = _idleController.value * 2 * math.pi;
                  final scrollRot = _scrollProgress * 3 * math.pi;
                  return CustomPaint(
                    size: const Size(double.infinity, 380),
                    painter: OrbitalSpherePainter(
                      rotation: idleRot + scrollRot,
                      primaryColor: primaryColor,
                    ),
                  );
                },
              ),
            ),
          ),

          // ✏️ [修改處 3] 標題 — parallax translate + entrance
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Transform.translate(
              offset: Offset(0, -_scrollOffset * 0.28),
              child: Opacity(
                opacity: heroOpacity,
                child: FadeTransition(
                  opacity: _entranceController,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.45),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                        parent: _entranceController,
                        curve: Curves.easeOutCubic)),
                    child: Column(
                      children: [
                        Text(
                          'AI 學習助手',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                  color: primaryColor.withValues(alpha: 0.9),
                                  blurRadius: 28),
                              const Shadow(
                                  color: Colors.black54,
                                  blurRadius: 12,
                                  offset: Offset(0, 4)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '智慧伴學 × 學習無界',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.65),
                            letterSpacing: 3.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bounce scroll hint
          Positioned(
            bottom: 4,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: CurvedAnimation(
                  parent: _entranceController,
                  curve: const Interval(0.65, 1.0)),
              child: Center(
                child: AnimatedBuilder(
                  animation: _idleController,
                  builder: (_, __) {
                    final b =
                        math.sin(_idleController.value * 2 * math.pi * 2) * 5;
                    return Transform.translate(
                      offset: Offset(0, b),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withValues(alpha: 0.4), size: 28),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BODY ─────────────────────────────────────────────
  Widget _buildBody(BuildContext context, Color primaryColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D1C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: primaryColor.withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, -12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✏️ [修改處 4] 關於這款 App — 從左飛入
                _RevealOnScroll(
                  scrollController: _scrollController,
                  slideBegin: const Offset(-0.10, 0),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.easeOutCubic,
                  child: _sectionLabel('關於這款 App', '🚀', primaryColor, isDark),
                ),
                const SizedBox(height: 14),
                _RevealOnScroll(
                  scrollController: _scrollController,
                  delay: const Duration(milliseconds: 100),
                  slideBegin: const Offset(0, 0.12),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  child: Text(
                    'YeBang 家教 是一款融合人工智慧技術、題庫與互動學習社群的全方位學習平台。以市面上穩定 AI 作為核心引擎，為每位使用者打造專屬於你的學習體驗。',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.9,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // ✏️ [修改處 5] 設計初衷 — 交錯飛入
                _RevealOnScroll(
                  scrollController: _scrollController,
                  slideBegin: const Offset(-0.10, 0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  child: _sectionLabel('設計初衷', '💡', primaryColor, isDark),
                ),
                const SizedBox(height: 18),
                _buildDesignIntentGrid(primaryColor, isDark),
                const SizedBox(height: 36),

                // ✏️ [修改處 6] 核心功能 — 交錯左右飛入
                _RevealOnScroll(
                  scrollController: _scrollController,
                  slideBegin: const Offset(-0.10, 0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  child: _sectionLabel('核心功能', '✨', primaryColor, isDark),
                ),
                const SizedBox(height: 16),
                ..._buildFeatureList(primaryColor, isDark),
                const SizedBox(height: 36),

                // ✏️ [修改處 7] 目標卡片 — 縮放+微旋轉飛入 + shimmer
                _RevealOnScroll(
                  scrollController: _scrollController,
                  slideBegin: const Offset(0, 0.14),
                  scaleBegin: 0.92,
                  rotateBegin: 0.016,
                  duration: const Duration(milliseconds: 750),
                  curve: Curves.easeOutBack,
                  onTriggered: () {
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (mounted) _typewriterController.forward();
                    });
                  },
                  child: _buildMissionCard(primaryColor, isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(
      String title, String emoji, Color primaryColor, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Text(emoji, style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // ✏️ [修改處 5 項目] 設計初衷 — 依據系統手冊第 6 頁背景三大困擾與一站式解法重構
  Widget _buildDesignIntentGrid(Color primaryColor, bool isDark) {
    final intents = [
      _SimpleDesignIntent(
        icon: Icons.hourglass_bottom_rounded,
        tag: '時間管理',
        title: '無法有效識別並善用空閒時間',
        themeColor: const Color(0xFFFF7043),
        problemText:
            '日常課業繁忙常產生「沒時間學習」的盲點。關鍵在於無法清楚視覺化整天的時間軸以找出空閒時間；同時因缺乏整合的待辦事項，短暫空閒時無法快速篩選適合在該時長內完成的任務，白白浪費零星時間。',
        solutionText:
            '提供視覺化時間軸與智慧待辦整合，一眼判斷空檔長度並自動挑選合適時長的學習任務，搭配隨手 AI 語音速記與 3 分鐘微測驗，充分活用零星時間。',
      ),
      _SimpleDesignIntent(
        icon: Icons.hub_rounded,
        tag: '知識整合',
        title: '知識整理與產出格式混亂',
        themeColor: const Color(0xFF0288D1),
        problemText:
            '在自主學習與刷題過程中，學生的知識點往往散落於各處（如線上筆記或本機檔案）。這種「知識分散」的現況，使得在需要快速複習時，難以進行高效的檢索與系統化整理。',
        solutionText:
            '一站式整合個人筆記、心智圖、錯題本與題庫，打破檔案分散孤島，建立雙向關聯知識圖譜，讓考點檢索與複習條理清晰、一目了然。',
      ),
      _SimpleDesignIntent(
        icon: Icons.people_alt_rounded,
        tag: '伴學反饋',
        title: '孤獨學習缺乏同儕與反饋',
        themeColor: const Color(0xFF8E24AA),
        problemText:
            '自主學習屬於高度個體化過程。練習題庫遇到瓶頸或對知識點產生疑惑時，常因缺乏即時討論機制而容易受挫放棄；且缺乏客觀的歷程量化數據，難以評估自身盲點。',
        solutionText:
            '提供 24 小時在線的 AI 智慧伴學即時解惑，搭配同學社群互動打氣，並具備學習歷程量化數據分析，精準定位弱項、陪伴持續進步。',
      ),
    ];

    return Column(
      children: [
        ...intents.indexed.map((entry) {
          final (i, item) = entry;
          final isEven = i % 2 == 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _RevealOnScroll(
              scrollController: _scrollController,
              delay: Duration(milliseconds: i * 100),
              slideBegin:
                  isEven ? const Offset(-0.06, 0.03) : const Offset(0.06, 0.03),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark
                      ? item.themeColor.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? item.themeColor.withValues(alpha: 0.28)
                        : item.themeColor.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.25)
                          : item.themeColor.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 標題與圖示
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: item.themeColor
                                .withValues(alpha: isDark ? 0.2 : 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child:
                              Icon(item.icon, color: item.themeColor, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E2022),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.themeColor
                                .withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.tag,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: item.themeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // 痛點簡述
                    Text(
                      item.problemText,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.75)
                            : const Color(0xFF5D4037),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 我們的做法
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: item.themeColor
                            .withValues(alpha: isDark ? 0.14 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('👉 ', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Text(
                              item.solutionText,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.95)
                                    : const Color(0xFF1E2022),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),

        // 系統手冊結論總結卡片
        _RevealOnScroll(
          scrollController: _scrollController,
          delay: const Duration(milliseconds: 320),
          slideBegin: const Offset(0, 0.08),
          duration: const Duration(milliseconds: 550),
          curve: Curves.easeOutCubic,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? primaryColor.withValues(alpha: 0.08)
                  : const Color(0xFFF7F2FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? primaryColor.withValues(alpha: 0.25)
                    : primaryColor.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡 ', style: TextStyle(fontSize: 15)),
                Expanded(
                  child: Text(
                    '本系統旨在改變分散式工具現況，透過高度整合的數位平台，為自主學習者提供時間軸、知識中樞與社群數據的全方位支持。',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.8)
                          : const Color(0xFF4A148C),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ✏️ [修改處 6 項目] 核心功能 — 奇偶項交錯左右飛入
  List<Widget> _buildFeatureList(Color primaryColor, bool isDark) {
    final List<(IconData, String, String)> features = [
      (Icons.mic_rounded, 'AI 代理人助理 (語音即時輸入)', '支援邊講話邊即時文字轉寫、自然語言意圖排程與全站智慧導覽'),
      (Icons.menu_book_rounded, '題庫測驗與錯題本', '學科單元測驗、歷屆試卷、AI 步驟深度詳解與自動收錄錯題複習'),
      (
        Icons.edit_note_rounded,
        '智慧個人筆記 (Markdown 富文字)',
        '支援豐富文字排版與一鍵 AI 重點摘要整理'
      ),
      (Icons.bar_chart_rounded, '學習歷程與弱項診斷', '知識掌握度矩陣圖、能力雷達圖與一鍵生成客製化弱項補強教材'),
      (
        Icons.calendar_month_rounded,
        '智慧行事曆與待辦排程',
        '自然語言直覺新增行程與待辦事項 (Todo)，並支援推播提醒'
      ),
      (Icons.forum_rounded, '學習社群與筆記分享', '同學學習心得貼文交流、優質筆記一鍵匯入與按讚互動'),
      (
        Icons.support_agent_rounded,
        '24H 智慧線上客服',
        '各功能常見問答教學、在線智慧客服專員與問題意見回饋表單'
      ),
    ];

    return features.indexed.map((entry) {
      final (idx, f) = entry;
      // Even → from right, Odd → from left, for a weaving feel
      final slideDir =
          idx.isEven ? const Offset(0.09, 0) : const Offset(-0.09, 0);
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _RevealOnScroll(
          scrollController: _scrollController,
          delay: Duration(milliseconds: idx * 85),
          slideBegin: slideDir,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon — pop-in scale with spring
              _RevealOnScroll(
                scrollController: _scrollController,
                delay: Duration(milliseconds: idx * 85 + 55),
                slideBegin: Offset.zero,
                scaleBegin: 0.45,
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(f.$1, color: primaryColor, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.$2,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 3),
                    Text(f.$3,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.55)
                                : Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildMissionCard(Color primaryColor, bool isDark) {
    return Column(
      children: [
        _ShimmerCard(
          shimmerController: _shimmerController,
          primaryColor: primaryColor,
          borderRadius: 20,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withValues(alpha: 0.18),
                  primaryColor.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryColor.withValues(alpha: 0.28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag_rounded, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text('我們所打造的目標',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryColor)),
                  ],
                ),
                const SizedBox(height: 12),
                TypewriterText(
                  text: _missionText,
                  controller: _typewriterController,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.8,
                    fontStyle: FontStyle.italic,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.75)
                        : Colors.black.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 版本資訊徽章
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_outlined, size: 16, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                '版本 v1.7.8  |  2026 年 9 月 21 日 最新發布',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ======================================================
//  Data classes
// ======================================================
class _SimpleDesignIntent {
  final IconData icon;
  final String tag;
  final String title;
  final Color themeColor;
  final String problemText;
  final String solutionText;

  const _SimpleDesignIntent({
    required this.icon,
    required this.tag,
    required this.title,
    required this.themeColor,
    required this.problemText,
    required this.solutionText,
  });
}

