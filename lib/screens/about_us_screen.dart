import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  late AnimationController _idleController;      // background loop + orbital
  late AnimationController _entranceController;  // hero entrance
  late AnimationController _typewriterController;
  late AnimationController _shimmerController;   // mission card shimmer
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

    _entranceController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
          ..forward();

    _typewriterController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));

    _shimmerController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
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
                      Color.lerp(const Color(0xFF080818),
                          const Color(0xFF040C20), t)!,
                      Color.lerp(const Color(0xFF160D30),
                          const Color(0xFF080E28), t)!,
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
                  child:
                      _sectionLabel('關於這款 App', '🚀', primaryColor, isDark),
                ),
                const SizedBox(height: 14),
                _RevealOnScroll(
                  scrollController: _scrollController,
                  delay: const Duration(milliseconds: 100),
                  slideBegin: const Offset(0, 0.12),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  child: Text(
                    '業來業棒 是一款融合人工智慧技術、題庫與互動學習社群的全方位學習平台。以市面上穩定 AI 作為核心引擎，為每位使用者打造專屬於你的學習體驗。',
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

                // ✏️ [修改處 5] 技術運用 — 交錯飛入
                _RevealOnScroll(
                  scrollController: _scrollController,
                  slideBegin: const Offset(-0.10, 0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  child: _sectionLabel('技術運用', '⚙️', primaryColor, isDark),
                ),
                const SizedBox(height: 18),
                _buildTechGrid(primaryColor, isDark),
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

  // ✏️ [修改處 5 項目] 技術運用 — 行間交錯方向飛入
  Widget _buildTechGrid(Color primaryColor, bool isDark) {
    final techs = [
      _TechItem('Flutter', 'UI Framework', Icons.phone_android_rounded,
          const Color(0xFF54C5F8)),
      _TechItem('Dart', 'Programming Language', Icons.code_rounded,
          const Color(0xFF0175C2)),
      _TechItem('Gemini AI', 'Intelligent Engine', Icons.auto_awesome_rounded,
          const Color(0xFF8E24AA)),
      _TechItem('SQLite', 'Local Database', Icons.storage_rounded,
          const Color(0xFF43A047)),
      _TechItem('fl_chart', 'Data Visualization', Icons.bar_chart_rounded,
          const Color(0xFFEF6C00)),
      _TechItem('Material 3', 'Design System', Icons.palette_outlined,
          primaryColor),
    ];

    // Row 0: left←, right→ | Row 1: left→, right← | Row 2: left←, right→
    final slideDirections = [
      [const Offset(-0.12, 0.05), const Offset(0.12, 0.05)],
      [const Offset(0.12, 0.05), const Offset(-0.12, 0.05)],
      [const Offset(-0.12, 0.05), const Offset(0.12, 0.05)],
    ];
    final rotateAngles = [
      [-0.022, 0.022],
      [0.022, -0.022],
      [-0.022, 0.022],
    ];

    Widget card(int i) {
      final t = techs[i];
      final row = i ~/ 2;
      final col = i % 2;
      return Expanded(
        child: _RevealOnScroll(
          scrollController: _scrollController,
          delay: Duration(milliseconds: i * 70),
          slideBegin: slideDirections[row][col],
          scaleBegin: 0.82,
          rotateBegin: rotateAngles[row][col],
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutBack,
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? t.color.withValues(alpha: 0.08)
                  : t.color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: t.color.withValues(alpha: 0.28), width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      color: t.color.withValues(alpha: 0.18),
                      shape: BoxShape.circle),
                  child: Icon(t.icon, color: t.color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87),
                          overflow: TextOverflow.ellipsis),
                      Text(t.subtitle,
                          style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : Colors.grey.shade500),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(children: [card(0), const SizedBox(width: 12), card(1)]),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(children: [card(2), const SizedBox(width: 12), card(3)]),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(children: [card(4), const SizedBox(width: 12), card(5)]),
        ),
      ],
    );
  }

  // ✏️ [修改處 6 項目] 核心功能 — 奇偶項交錯左右飛入
  List<Widget> _buildFeatureList(Color primaryColor, bool isDark) {
    final List<(IconData, String, String)> features = [
      (Icons.auto_awesome_rounded, 'AI 智能解答',
          '長按文字即可呼叫 Gemini AI 解釋任何概念'),
      (Icons.menu_book_rounded, '題庫', '分類題目、錯題本與個人化複習排程'),
      (Icons.forum_rounded, '學習社群', '分享心得、互動交流，與同學共同進步'),
      (Icons.calendar_month_rounded, '行程規劃', '自然語言輸入即可新增與管理學習行程'),
      (Icons.bar_chart_rounded, '學習歷程分析', '視覺化圖表追蹤每週答題正確率'),
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
    return _ShimmerCard(
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
    );
  }
}

// ======================================================
//  _ShimmerCard — Diagonal sweep light on Mission Card
// ======================================================
class _ShimmerCard extends StatelessWidget {
  final AnimationController shimmerController;
  final Color primaryColor;
  final double borderRadius;
  final Widget child;

  const _ShimmerCard({
    required this.shimmerController,
    required this.primaryColor,
    required this.child,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AnimatedBuilder(
        animation: shimmerController,
        builder: (context, childWidget) {
          return Stack(
            children: [
              childWidget!,
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ShimmerPainter(
                      progress: shimmerController.value,
                      primaryColor: primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: child,
      ),
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;

  _ShimmerPainter({required this.progress, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    const shimmerHalfW = 90.0;
    const tilt = 32.0;
    // Sweep from left-off to right-off
    final x = -shimmerHalfW - tilt + (size.width + (shimmerHalfW + tilt) * 2) * progress;

    final path = Path()
      ..moveTo(x - shimmerHalfW - tilt, 0)
      ..lineTo(x + shimmerHalfW - tilt, 0)
      ..lineTo(x + shimmerHalfW + tilt, size.height)
      ..lineTo(x - shimmerHalfW + tilt, size.height)
      ..close();

    final shaderRect = Rect.fromLTWH(
        x - shimmerHalfW - tilt, 0, (shimmerHalfW + tilt) * 2, size.height);

    final gradient = LinearGradient(
      colors: [
        Colors.transparent,
        primaryColor.withValues(alpha: 0.09),
        Colors.white.withValues(alpha: 0.07),
        primaryColor.withValues(alpha: 0.09),
        Colors.transparent,
      ],
      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
    );

    canvas.drawPath(path, Paint()..shader = gradient.createShader(shaderRect));
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

// ======================================================
//  _RevealOnScroll — Upgraded scroll-triggered animation
//  新增：rotateBegin, curve 參數；觸發閾值調整至 0.88
// ======================================================
class _RevealOnScroll extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;
  final Duration delay;
  final Offset slideBegin;
  final double? scaleBegin;
  final double? rotateBegin; // 弧度 radians
  final Duration duration;
  final Curve curve;
  final VoidCallback? onTriggered;

  const _RevealOnScroll({
    required this.child,
    required this.scrollController,
    this.delay = Duration.zero,
    this.slideBegin = const Offset(0, 0.08),
    this.scaleBegin,
    this.rotateBegin,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
    this.onTriggered,
  });

  @override
  State<_RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<_RevealOnScroll>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  Animation<double>? _scale;
  Animation<double>? _rotate;
  final _key = GlobalKey();
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    final curved = CurvedAnimation(parent: _ctrl, curve: widget.curve);

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: widget.slideBegin, end: Offset.zero)
        .animate(curved);

    if (widget.scaleBegin != null) {
      _scale = Tween<double>(begin: widget.scaleBegin!, end: 1.0)
          .animate(curved);
    }
    if (widget.rotateBegin != null) {
      _rotate = Tween<double>(begin: widget.rotateBegin!, end: 0.0)
          .animate(curved);
    }

    widget.scrollController.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_triggered || !mounted) return;
    final ctx = _key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final pos = box.localToGlobal(Offset.zero);
    final screenH = MediaQuery.of(ctx).size.height;
    // 閾值從 0.92 → 0.88，更早觸發、更順暢的感知
    if (pos.dy < screenH * 0.88) {
      _triggered = true;
      widget.onTriggered?.call();
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_check);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget w = widget.child;
    if (_scale != null) {
      w = ScaleTransition(scale: _scale!, child: w);
    }
    if (_rotate != null) {
      final rot = _rotate!;
      w = AnimatedBuilder(
        animation: rot,
        builder: (_, child) =>
            Transform.rotate(angle: rot.value, child: child),
        child: w,
      );
    }
    w = SlideTransition(position: _slide, child: w);
    w = FadeTransition(opacity: _opacity, child: w);
    return Container(key: _key, child: w);
  }
}

// ======================================================
//  NebulaPainter — Soft drifting nebula clouds
// ======================================================
class NebulaPainter extends CustomPainter {
  final double time;
  final double scrollOffset;
  final Color primaryColor;

  NebulaPainter({
    required this.time,
    required this.scrollOffset,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = time * 2 * math.pi;
    final purpleAccentColor = Color.lerp(primaryColor, Colors.purpleAccent, 0.5)!;
    final blueAccentColor = Color.lerp(primaryColor, Colors.blueAccent, 0.4)!;
    final deepPurpleColor = Color.lerp(primaryColor, Colors.deepPurple, 0.55)!;

    // (relX, relY, radiusX, radiusY, driftPhase, alpha, color)
    final blobs = [
      (0.14, 0.10, 190.0, 130.0, 0.0,  0.070, primaryColor),
      (0.82, 0.20, 155.0, 105.0, 1.2,  0.055, purpleAccentColor),
      (0.32, 0.72, 205.0, 135.0, 2.4,  0.062, blueAccentColor),
      (0.72, 0.82, 145.0, 92.0,  3.7,  0.048, deepPurpleColor),
    ];

    for (final blob in blobs) {
      final relX = blob.$1;
      final relY = blob.$2;
      final rX = blob.$3;
      final rY = blob.$4;
      final phase = blob.$5;
      final alpha = blob.$6;
      final color = blob.$7;

      final driftX = math.sin(t * 0.28 + phase) * 18.0;
      final driftY = math.cos(t * 0.19 + phase) * 13.0 - scrollOffset * 0.11;

      final cx = relX * size.width + driftX;
      final cy = relY * size.height + driftY;

      final rect =
          Rect.fromCenter(center: Offset(cx, cy), width: rX * 2, height: rY * 2);

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.38),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect);

      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(1.0, rY / rX);
      canvas.translate(-cx, -cy);
      canvas.drawCircle(Offset(cx, cy), rX, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(NebulaPainter old) =>
      old.time != time || old.scrollOffset != scrollOffset;
}

// ======================================================
//  FlowGridPainter — Animated hexagonal grid
// ======================================================
class FlowGridPainter extends CustomPainter {
  final double time;
  final double scrollOffset;
  final Color primaryColor;

  FlowGridPainter({
    required this.time,
    required this.scrollOffset,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    const hexR = 22.0;
    final hexW = math.sqrt(3) * hexR;   // ~38.1
    const hexH = 2.0 * hexR;            // 44.0
    const rowStep = hexH * 0.75;        // 33.0

    final t = time * 2 * math.pi;
    // Grid drifts slowly downward with scroll for parallax depth
    final yShift = (scrollOffset * 0.055) % rowStep;

    final linePaint = Paint()
      ..strokeWidth = 0.55
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint();
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    int nodeIndex = 0;
    final colCount = (size.width / hexW + 3).ceil();
    final rowCount = (size.height / rowStep + 3).ceil();

    for (int col = -1; col < colCount; col++) {
      for (int row = -1; row < rowCount; row++) {
        final cx = col * hexW + (row.isOdd ? hexW * 0.5 : 0.0);
        final cy = row * rowStep + yShift;

        // Each node pulses independently
        final pulse = math.sin(t * 0.55 + nodeIndex * 0.43) * 0.5 + 0.5;
        final lineAlpha = 0.022 + pulse * 0.022;
        final nodeAlpha = 0.028 + pulse * 0.042;

        // Hex outline
        final path = Path();
        for (int v = 0; v <= 6; v++) {
          final angle = (v * 60 - 30) * math.pi / 180.0;
          final px = cx + hexR * math.cos(angle);
          final py = cy + hexR * math.sin(angle);
          if (v == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();
        linePaint.color = primaryColor.withValues(alpha: lineAlpha);
        canvas.drawPath(path, linePaint);

        // Center node dot
        nodePaint.color = primaryColor.withValues(alpha: nodeAlpha);
        canvas.drawCircle(Offset(cx, cy), 1.2, nodePaint);

        // Periodic glow nodes (every 11th)
        if (nodeIndex % 11 == 0) {
          glowPaint.color = primaryColor.withValues(alpha: pulse * 0.075);
          canvas.drawCircle(Offset(cx, cy), 4.0, glowPaint);
        }

        nodeIndex++;
      }
    }
  }

  @override
  bool shouldRepaint(FlowGridPainter old) =>
      old.time != time || old.scrollOffset != scrollOffset;
}

// ======================================================
//  OrbitalSpherePainter — Pure Flutter 3D
// ======================================================
class OrbitalSpherePainter extends CustomPainter {
  final double rotation;
  final Color primaryColor;

  OrbitalSpherePainter({required this.rotation, required this.primaryColor});

  Offset _project(double x, double y, double z, Offset center) {
    const f = 480.0;
    final p = f / (f + z * 0.18);
    return Offset(center.dx + x * p, center.dy + y * p);
  }

  (double, double, double) _rotY(double x, double y, double z, double a) {
    final c = math.cos(a), s = math.sin(a);
    return (x * c + z * s, y, -x * s + z * c);
  }

  (double, double, double) _rotX(double x, double y, double z, double a) {
    final c = math.cos(a), s = math.sin(a);
    return (x, y * c - z * s, y * s + z * c);
  }

  void _drawRing(Canvas canvas, Offset center, double radius, double tiltX,
      double phaseY, Color color, double sw) {
    const seg = 96;
    final path = Path();
    bool started = false;
    for (int i = 0; i <= seg; i++) {
      final angle = i * 2 * math.pi / seg;
      double x = radius * math.cos(angle),
          y = 0.0,
          z = radius * math.sin(angle);
      var (rx, ry, rz) = _rotX(x, y, z, tiltX);
      var (fx, fy, fz) = _rotY(rx, ry, rz, phaseY);
      final p = _project(fx, fy, fz, center);
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round);
  }

  void _drawNode(Canvas canvas, Offset center, double radius, double nodeAngle,
      double tiltX, double phaseY, Color color, double nodeR) {
    double x = radius * math.cos(nodeAngle),
        y = 0.0,
        z = radius * math.sin(nodeAngle);
    var (rx, ry, rz) = _rotX(x, y, z, tiltX);
    var (fx, fy, fz) = _rotY(rx, ry, rz, phaseY);
    final p = _project(fx, fy, fz, center);
    final depth = ((fz + radius) / (2 * radius)).clamp(0.2, 1.0);
    final r = nodeR * (0.8 + depth * 0.4);
    canvas.drawCircle(
        p,
        r * 2.8,
        Paint()
          ..color = color.withValues(alpha: 0.16 * depth)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(
        p,
        r,
        Paint()
          ..color =
              color.withValues(alpha: (0.5 + depth * 0.5).clamp(0, 1)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 16);
    final pc = primaryColor;
    final accent = Color.lerp(pc, Colors.purpleAccent, 0.45)!;

    canvas.drawCircle(
        center,
        130,
        Paint()
          ..shader = RadialGradient(colors: [
            pc.withValues(alpha: 0.22),
            pc.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: center, radius: 130)));

    _drawRing(
        canvas, center, 90, 1.15, rotation, pc.withValues(alpha: 0.72), 1.5);
    for (int i = 0; i < 3; i++) {
      _drawNode(canvas, center, 90, rotation + i * 2 * math.pi / 3, 1.15,
          rotation, pc, 5.5);
    }
    _drawRing(canvas, center, 114, -0.75, -rotation * 0.8,
        accent.withValues(alpha: 0.48), 1.2);
    for (int i = 0; i < 4; i++) {
      _drawNode(canvas, center, 114,
          -rotation * 0.8 + i * math.pi / 2, -0.75, -rotation * 0.8, accent, 4.0);
    }
    _drawRing(canvas, center, 68, 0.22, rotation * 1.3,
        Colors.white.withValues(alpha: 0.22), 1.0);

    canvas.drawCircle(
        center,
        34,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            colors: [
              Colors.white.withValues(alpha: 0.95),
              pc.withValues(alpha: 0.9),
              pc.withValues(alpha: 0.4),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: 34)));
    canvas.drawCircle(
        center + const Offset(-10, -10),
        10,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(
        center,
        38,
        Paint()
          ..color = pc.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
  }

  @override
  bool shouldRepaint(OrbitalSpherePainter old) => old.rotation != rotation;
}

// ======================================================
//  ParticlePainter — 3-layer depth floating particles
// ======================================================
class ParticlePainter extends CustomPainter {
  final List<ParticleData> particles;
  final double time;
  final double scrollOffset;
  final Color primaryColor;

  ParticlePainter({
    required this.particles,
    required this.time,
    required this.scrollOffset,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final accent = Color.lerp(primaryColor, Colors.purpleAccent, 0.35)!;

    for (final p in particles) {
      final x = p.x * size.width;
      final rawY = p.y * size.height - scrollOffset * p.speed;
      final y = rawY % size.height;
      final pulse =
          (math.sin(time * 2 * math.pi * 1.5 + p.phase) * 0.35 + 0.5)
              .clamp(0.0, 1.0);

      final double baseAlpha;
      final double blurFactor;
      final Color color;

      if (p.layer == 0) {
        // Far: small, dim, purple-tinted
        baseAlpha = 0.26;
        blurFactor = 0.65;
        color = Color.lerp(primaryColor, accent, 0.65)!;
      } else if (p.layer == 2) {
        // Near: large, bright, with halo glow
        baseAlpha = 0.68;
        blurFactor = 1.5;
        color = Color.lerp(primaryColor, Colors.white, 0.22)!;
        // Extra soft halo
        canvas.drawCircle(
          Offset(x, y),
          p.radius * 2.4,
          Paint()
            ..color = primaryColor.withValues(alpha: pulse * 0.11)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.radius * 2.2),
        );
      } else {
        // Mid: default
        baseAlpha = 0.46;
        blurFactor = 0.95;
        color = primaryColor;
      }

      canvas.drawCircle(
        Offset(x, y),
        p.radius,
        Paint()
          ..color = color.withValues(alpha: pulse * baseAlpha)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, p.radius * blurFactor),
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter old) =>
      old.time != time || old.scrollOffset != scrollOffset;
}

// ======================================================
//  TypewriterText — Animated character-by-character reveal
// ======================================================
class TypewriterText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final AnimationController controller;

  const TypewriterText({
    super.key,
    required this.text,
    required this.controller,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final n =
            (controller.value * text.length).round().clamp(0, text.length);
        return Text(text.substring(0, n), style: style);
      },
    );
  }
}

// ======================================================
//  Data classes
// ======================================================
class _TechItem {
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  _TechItem(this.name, this.subtitle, this.icon, this.color);
}

class ParticleData {
  final double x;
  final double y;
  final double radius;
  final double speed;
  final double phase;
  final int layer; // 0 = 遠景, 1 = 中景, 2 = 近景

  const ParticleData({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
    this.layer = 1,
  });
}
