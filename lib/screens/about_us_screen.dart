import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'about/about_us_painters.dart';
import 'about/about_us_animations.dart';
import '../services/app_locale_service.dart';

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
  static String get _missionText =>
      tr('about_mission');

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
          child: Text(
            tr('about_title'),
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
                          tr('about_ai_assistant'),
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
                          tr('about_tagline'),
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
                  child: _sectionLabel(tr('about_this_app'), '🚀', primaryColor, isDark),
                ),
                const SizedBox(height: 14),
                _RevealOnScroll(
                  scrollController: _scrollController,
                  delay: const Duration(milliseconds: 100),
                  slideBegin: const Offset(0, 0.12),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  child: Text(
                    tr('about_intro'),
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
                  child: _sectionLabel(tr('about_origin'), '💡', primaryColor, isDark),
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
                  child: _sectionLabel(tr('about_core'), '✨', primaryColor, isDark),
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
        tag: tr('about_tag_time'),
        title: tr('about_p1_title'),
        themeColor: const Color(0xFFFF7043),
        problemText:
            tr('about_p1_problem'),
        solutionText:
            tr('about_p1_solution'),
      ),
      _SimpleDesignIntent(
        icon: Icons.hub_rounded,
        tag: tr('about_tag_knowledge'),
        title: tr('about_p2_title'),
        themeColor: const Color(0xFF0288D1),
        problemText:
            tr('about_p2_problem'),
        solutionText:
            tr('about_p2_solution'),
      ),
      _SimpleDesignIntent(
        icon: Icons.people_alt_rounded,
        tag: tr('about_tag_peer'),
        title: tr('about_p3_title'),
        themeColor: const Color(0xFF8E24AA),
        problemText:
            tr('about_p3_problem'),
        solutionText:
            tr('about_p3_solution'),
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
                    tr('about_mission_sum'),
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
      (Icons.mic_rounded, tr('about_f1'), tr('about_f1_d')),
      (Icons.menu_book_rounded, tr('about_f2'), tr('about_f2_d')),
      (
        Icons.edit_note_rounded,
        tr('about_f3'),
        tr('about_f3_d')
      ),
      (Icons.bar_chart_rounded, tr('about_f4'), tr('about_f4_d')),
      (
        Icons.calendar_month_rounded,
        tr('about_f5'),
        tr('about_f5_d')
      ),
      (Icons.forum_rounded, tr('about_f6'), tr('about_f6_d')),
      (
        Icons.support_agent_rounded,
        tr('about_f7'),
        tr('about_f7_d')
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
                    Text(tr('about_goal'),
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
                tr('about_version'),
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

