import 'dart:ui';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../database/database_helper.dart';
import '../widgets/common_widgets.dart';

// ── 通用精美進場組件 ─────────────────────────────────────────────────────────
Widget _exquisiteFadeIn({
  required Widget child,
  required int delayMs,
  double from = 40,
}) {
  // Disable animate_do timers during widget tests to avoid pending Timer issues
  final bool isInTest = WidgetsBinding.instance.runtimeType
      .toString()
      .toLowerCase()
      .contains('test');
  if (isInTest) return child;

  return FadeInUp(
    delay: Duration(milliseconds: (delayMs * 0.7).toInt()), // 縮短延遲時間
    duration: const Duration(milliseconds: 500), // 從 800ms 縮短
    curve: Curves.easeOutExpo,
    from: from,
    child: ZoomIn(
      delay: Duration(milliseconds: (delayMs * 0.7).toInt()), // 縮短延遲時間
      duration: const Duration(milliseconds: 400), // 從 700ms 縮短
      curve: Curves.easeOutBack,
      child: child,
    ),
  );
}

// ── 抽象品牌圖示（替代 Gemini 圖示）────────────────────────────────────────
class _BrandMark extends StatefulWidget {
  const _BrandMark();

  @override
  State<_BrandMark> createState() => _BrandMarkState();
}

class _BrandMarkState extends State<_BrandMark> with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late AnimationController _introCtrl;

  late Animation<double> _rotateAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _drawAnim;
  late Animation<double> _leftLeafScaleAnim;
  late Animation<double> _rightLeafScaleAnim;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    final bool isInTest = WidgetsBinding.instance.runtimeType
        .toString()
        .toLowerCase()
        .contains('test');

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (!isInTest) _ctrl.repeat();

    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _rotateAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.linear),
    );

    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _drawAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _introCtrl,
          curve: const Interval(0.0, 0.6, curve: Curves.easeInOutCubic)),
    );

    _leftLeafScaleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _introCtrl,
          curve: const Interval(0.5, 0.85, curve: Curves.easeOutBack)),
    );

    _rightLeafScaleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _introCtrl,
          curve: const Interval(0.6, 1.0, curve: Curves.easeOutBack)),
    );

    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine),
    );

    _introCtrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _introCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_ctrl, _introCtrl]),
      builder: (_, __) {
        return Transform.scale(
          scale: _pulseAnim.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 外光暈 (青色柔和發光)
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4DD0E1).withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // 旋轉外環 (綠色至青色漸變)
              Transform.rotate(
                angle: _rotateAnim.value * 6.2832,
                child: CustomPaint(
                  size: const Size(130, 130),
                  painter: _ArcRingPainter(),
                ),
              ),
              // 中心圓形容器 (白底加精美投影)
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9CCC65).withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(72, 72),
                    painter: _LeafYLogoPainter(
                      progress: _drawAnim.value,
                      leftLeafScale: _leftLeafScaleAnim.value,
                      rightLeafScale: _rightLeafScaleAnim.value,
                      shimmerProgress: _shimmerAnim.value,
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
}

class _ArcRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 弧段 1: 青藍色
    paint.color = const Color(0xFF4DD0E1).withValues(alpha: 0.8);
    canvas.drawArc(rect, 0, 1.8, false, paint);

    // 弧段 2: 綠色
    paint.color = const Color(0xFF9CCC65).withValues(alpha: 0.6);
    canvas.drawArc(rect, 2.4, 1.2, false, paint);

    // 弧段 3: 淺綠/藍綠色
    paint.color = const Color(0xFF80CBC4).withValues(alpha: 0.4);
    canvas.drawArc(rect, 4.0, 0.6, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LeafYLogoPainter extends CustomPainter {
  final double progress;
  final double leftLeafScale;
  final double rightLeafScale;
  final double shimmerProgress;

  const _LeafYLogoPainter({
    required this.progress,
    required this.leftLeafScale,
    required this.rightLeafScale,
    required this.shimmerProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final Rect bounds = Rect.fromLTWH(0, 0, w, h);

    // 主漸層色彩 (綠色至青色)
    final baseGradient = LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: const [
        Color(0xFF9CCC65), // 綠色
        Color(0xFF4DD0E1), // 青色/藍綠色
      ],
    );

    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // 當生長完成，加入一束白色扫光的漸層效果
    if (progress >= 1.0) {
      final double shimmerWidth = 0.4;
      final double start = shimmerProgress - shimmerWidth;
      final double end = shimmerProgress + shimmerWidth;

      strokePaint.shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          const Color(0xFF9CCC65),
          const Color(0xFF4DD0E1),
          Colors.white,
          const Color(0xFF4DD0E1),
          const Color(0xFF9CCC65),
        ],
        stops: [
          0.0,
          (start.clamp(0.0, 1.0)),
          (shimmerProgress.clamp(0.0, 1.0)),
          (end.clamp(0.0, 1.0)),
          1.0,
        ],
      ).createShader(bounds);
    } else {
      strokePaint.shader = baseGradient.createShader(bounds);
    }

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;

    // 繪製 y 的草寫主莖幹
    final yBodyPath = Path();
    yBodyPath.moveTo(w * 0.25, h * 0.42);
    yBodyPath.quadraticBezierTo(w * 0.28, h * 0.62, w * 0.42, h * 0.62);
    yBodyPath.quadraticBezierTo(w * 0.52, h * 0.62, w * 0.55, h * 0.42);
    yBodyPath.cubicTo(
        w * 0.55, h * 0.65, w * 0.50, h * 0.88, w * 0.38, h * 0.88);
    yBodyPath.cubicTo(
        w * 0.24, h * 0.88, w * 0.24, h * 0.70, w * 0.35, h * 0.58);
    yBodyPath.quadraticBezierTo(w * 0.45, h * 0.48, w * 0.65, h * 0.62);
    yBodyPath.quadraticBezierTo(w * 0.72, h * 0.68, w * 0.70, h * 0.55);

    if (progress < 1.0) {
      final metrics = yBodyPath.computeMetrics();
      final animPath = Path();
      for (final metric in metrics) {
        animPath.addPath(
            metric.extractPath(0.0, metric.length * progress), Offset.zero);
      }
      canvas.drawPath(animPath, strokePaint);
    } else {
      canvas.drawPath(yBodyPath, strokePaint);
    }

    // 繪製左小葉 (含萌芽縮放)
    if (leftLeafScale > 0) {
      canvas.save();
      final Offset base = Offset(w * 0.25, h * 0.42);
      canvas.translate(base.dx, base.dy);
      canvas.scale(leftLeafScale);
      canvas.translate(-base.dx, -base.dy);

      final leftLeaf = Path();
      leftLeaf.moveTo(w * 0.25, h * 0.42);
      leftLeaf.cubicTo(
          w * 0.20, h * 0.35, w * 0.12, h * 0.30, w * 0.10, h * 0.32);
      leftLeaf.cubicTo(
          w * 0.14, h * 0.45, w * 0.22, h * 0.48, w * 0.25, h * 0.42);

      fillPaint.shader = LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: [
          const Color(0xFF9CCC65).withValues(alpha: 0.15 * leftLeafScale),
          const Color(0xFF9CCC65).withValues(alpha: 0.4 * leftLeafScale),
        ],
      ).createShader(bounds);
      canvas.drawPath(leftLeaf, fillPaint);
      canvas.drawPath(leftLeaf, strokePaint);

      // 左葉脈
      final leftVein = Path();
      leftVein.moveTo(w * 0.25, h * 0.42);
      leftVein.quadraticBezierTo(w * 0.18, h * 0.37, w * 0.11, h * 0.33);

      final Paint veinPaint = Paint()
        ..shader = strokePaint.shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(leftVein, veinPaint);

      canvas.restore();
    }

    // 繪製右大葉 (含萌芽縮放)
    if (rightLeafScale > 0) {
      canvas.save();
      final Offset base = Offset(w * 0.55, h * 0.42);
      canvas.translate(base.dx, base.dy);
      canvas.scale(rightLeafScale);
      canvas.translate(-base.dx, -base.dy);

      final rightLeaf = Path();
      rightLeaf.moveTo(w * 0.55, h * 0.42);
      rightLeaf.cubicTo(
          w * 0.60, h * 0.28, w * 0.72, h * 0.10, w * 0.85, h * 0.15);
      rightLeaf.cubicTo(
          w * 0.78, h * 0.32, w * 0.64, h * 0.45, w * 0.55, h * 0.42);

      fillPaint.shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          const Color(0xFF4DD0E1).withValues(alpha: 0.15 * rightLeafScale),
          const Color(0xFF4DD0E1).withValues(alpha: 0.4 * rightLeafScale),
        ],
      ).createShader(bounds);
      canvas.drawPath(rightLeaf, fillPaint);
      canvas.drawPath(rightLeaf, strokePaint);

      // 右葉脈
      final rightVein = Path();
      rightVein.moveTo(w * 0.55, h * 0.42);
      rightVein.quadraticBezierTo(w * 0.68, h * 0.28, w * 0.82, h * 0.17);

      final Paint veinPaint = Paint()
        ..shader = strokePaint.shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(rightVein, veinPaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _LeafYLogoPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.leftLeafScale != leftLeafScale ||
        oldDelegate.rightLeafScale != rightLeafScale ||
        oldDelegate.shimmerProgress != shimmerProgress;
  }
}

// ── 登入成功動畫 Overlay ────────────────────────────────────────────────────
class _LoginSuccessOverlay extends StatefulWidget {
  final String displayName;
  final VoidCallback onComplete;

  const _LoginSuccessOverlay({
    required this.displayName,
    required this.onComplete,
  });

  @override
  State<_LoginSuccessOverlay> createState() => _LoginSuccessOverlayState();
}

class _LoginSuccessOverlayState extends State<_LoginSuccessOverlay>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl; // Ambient drift
  late AnimationController _shimmerCtrl; // Text shimmer reflection
  late AnimationController _entranceCtrl; // Elements slide/fade/scale
  late AnimationController _exitCtrl; // Overall fade out

  late Animation<double> _entranceOpacity;
  late Animation<double> _textSlideY;
  late Animation<double> _dividerProgress;
  late Animation<double> _welcomeOpacity;
  late Animation<double> _exitOpacity;

  final List<_LeafParticle> _leaves = [];

  @override
  void initState() {
    super.initState();

    _bgCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat(reverse: true);
    _shimmerCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _entranceOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0, 0.4, curve: Curves.easeOut)));
    _textSlideY = Tween<double>(begin: 30, end: 0).animate(CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic)));
    _dividerProgress = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOut)));
    _welcomeOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut)));

    _exitOpacity = Tween<double>(begin: 1, end: 0)
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    // Initialize 6 drifting leaves
    final random = math.Random();
    for (int i = 0; i < 6; i++) {
      _leaves.add(_LeafParticle(
        x: random.nextDouble(),
        y: random.nextDouble() * 0.6 - 0.2, // Start in upper half
        size: 10 + random.nextDouble() * 12,
        rotation: random.nextDouble() * 2 * math.pi,
        speedY: 0.04 + random.nextDouble() * 0.04,
        speedX: -0.015 + random.nextDouble() * 0.03,
        spinSpeed: -0.3 + random.nextDouble() * 0.6,
      ));
    }

    _runSequence();
  }

  Future<void> _runSequence() async {
    _entranceCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 2200));
    await _exitCtrl.forward();
    widget.onComplete();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _shimmerCtrl.dispose();
    _entranceCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation:
          Listenable.merge([_bgCtrl, _shimmerCtrl, _entranceCtrl, _exitCtrl]),
      builder: (_, __) {
        return Opacity(
          opacity: _exitOpacity.value,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                // Natural Ambient Light Background
                Positioned.fill(
                  child: Opacity(
                    opacity: _entranceOpacity.value,
                    child: Container(
                      color: const Color(0xFFF7F3F0), // Warm off-white
                      child: CustomPaint(
                        painter: _DriftingLeavesPainter(
                          leaves: _leaves,
                          animationValue: _bgCtrl.value,
                        ),
                      ),
                    ),
                  ),
                ),

                // Center Content: Shimmer Text, Minimalist Divider, Welcome
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Shimmer Brand text
                      Opacity(
                        opacity: _entranceOpacity.value,
                        child: Transform.translate(
                          offset: Offset(0, _textSlideY.value),
                          child: ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                colors: const [
                                  Color(0xFF4E342E), // Deep brown
                                  Color(0xFF8D6E63), // Light warm brown
                                  Color(0xFF4E342E), // Deep brown
                                ],
                                stops: [
                                  0.0,
                                  0.5 +
                                      0.5 *
                                          math.sin(
                                              _shimmerCtrl.value * 2 * math.pi),
                                  1.0,
                                ],
                              ).createShader(bounds);
                            },
                            child: const Text(
                              'YeLaiYeBang',
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: Colors.white, // Required for ShaderMask
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Minimalist leaf divider
                      Opacity(
                        opacity: _entranceOpacity.value,
                        child: CustomPaint(
                          size: const Size(200, 30),
                          painter: _LeafBranchDivider(
                            progress: _dividerProgress.value,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Welcome text
                      Opacity(
                        opacity: _welcomeOpacity.value,
                        child: Transform.translate(
                          offset: Offset(0, _textSlideY.value * 0.5),
                          child: Text(
                            'Welcome, ${widget.displayName}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8D6E63),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LeafParticle {
  double x;
  double y;
  double size;
  double rotation;
  double speedY;
  double speedX;
  double spinSpeed;

  _LeafParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.rotation,
    required this.speedY,
    required this.speedX,
    required this.spinSpeed,
  });
}

class _DriftingLeavesPainter extends CustomPainter {
  final List<_LeafParticle> leaves;
  final double animationValue;

  _DriftingLeavesPainter({required this.leaves, required this.animationValue});

  // Helper: fractional part, always 0..1
  static double _frac(double v) => v - v.floor();

  @override
  void paint(Canvas canvas, Size size) {
    // Fill colour: a warm sage-green visible on the off-white (#F7F3F0) background
    final paint = Paint()
      ..color = const Color(0xFF7CB38A).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = const Color(0xFF5A8C6A).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (var leaf in leaves) {
      // Each leaf has its own perpetual fall: wraps at 1.0
      final rawY = leaf.y + leaf.speedY * animationValue * 12;
      final rawX = leaf.x + leaf.speedX * animationValue * 12;
      // Slight sinusoidal sway so leaves drift side-to-side as they fall
      final swayX = math.sin(rawY * 2 * math.pi * 1.5) * 0.04;

      final nx = _frac(rawX + swayX + 1.0); // normalised 0-1
      final ny = _frac(rawY); // normalised 0-1

      final px = nx * size.width;
      final py = ny * size.height;
      final rotation = leaf.rotation + leaf.spinSpeed * animationValue * 8;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rotation);

      final path = Path();
      path.moveTo(0, 0);
      path.quadraticBezierTo(
          -leaf.size * 0.45, -leaf.size * 0.5, 0, -leaf.size * 1.2);
      path.quadraticBezierTo(leaf.size * 0.45, -leaf.size * 0.5, 0, 0);

      canvas.drawPath(path, paint);
      canvas.drawPath(path, strokePaint);
      // leaf vein
      canvas.drawLine(Offset.zero, Offset(0, -leaf.size * 0.9), strokePaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _DriftingLeavesPainter oldDelegate) => true;
}

class _LeafBranchDivider extends CustomPainter {
  final double progress;
  _LeafBranchDivider({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8D6E63).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF8D6E63).withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Draw central horizontal line with a slight organic curve
    final path = Path();
    path.moveTo(cx - (w * 0.3 * progress), cy);
    path.quadraticBezierTo(cx, cy - 2 * math.sin(progress * math.pi),
        cx + (w * 0.3 * progress), cy);
    canvas.drawPath(path, paint);

    // Leaves branching out
    if (progress > 0.4) {
      final t = (progress - 0.4) / 0.6; // 0.0 to 1.0

      // Leaf 1 (Left-top)
      _drawLeaf(
          canvas, Offset(cx - w * 0.12, cy - 1), -0.8, t, paint, fillPaint);

      // Leaf 2 (Right-top)
      _drawLeaf(
          canvas, Offset(cx + w * 0.12, cy - 1), 0.8, t, paint, fillPaint);

      // Leaf 3 (Center-bottom)
      _drawLeaf(canvas, Offset(cx, cy + 1), math.pi + 0.1, t, paint, fillPaint);
    }
  }

  void _drawLeaf(Canvas canvas, Offset origin, double angle, double scale,
      Paint strokePaint, Paint fillPaint) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    canvas.scale(scale);

    final leafPath = Path();
    leafPath.moveTo(0, 0);
    leafPath.quadraticBezierTo(-5, -8, 0, -14);
    leafPath.quadraticBezierTo(5, -8, 0, 0);

    canvas.drawPath(leafPath, fillPaint);
    canvas.drawPath(leafPath, strokePaint);

    // Draw leaf vein
    canvas.drawLine(const Offset(0, 0), const Offset(0, -10), strokePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LeafBranchDivider oldDelegate) =>
      oldDelegate.progress != progress;
}

// ── 磨砂玻璃容器卡片 ─────────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8D6E63).withValues(alpha: 0.08),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── 動態流光背景組件 ─────────────────────────────────────────────────────────────
class _AmbientFlowBackground extends StatefulWidget {
  const _AmbientFlowBackground();

  @override
  State<_AmbientFlowBackground> createState() => _AmbientFlowBackgroundState();
}

class _AmbientFlowBackgroundState extends State<_AmbientFlowBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final bool isInTest = WidgetsBinding.instance.runtimeType
        .toString()
        .toLowerCase()
        .contains('test');

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
    if (!isInTest) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _FlowBackgroundPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _FlowBackgroundPainter extends CustomPainter {
  final double progress;

  _FlowBackgroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // 基底純色
    paint.color = const Color(0xFFF3ECE6); // 稍微加深基底暖色，提升與毛玻璃卡片的對比
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    final double angle = progress * 2 * math.pi;

    // 氣泡 1: 溫柔粉蜜桃 (右上) - 加深色彩與不透明度
    final double b1x = size.width * 0.75 + math.sin(angle) * 70;
    final double b1y = size.height * 0.2 + math.cos(angle) * 60;
    _drawBlurCircle(canvas, Offset(b1x, b1y), 260,
        const Color(0xFFFFD4C2).withValues(alpha: 0.75), paint);

    // 氣泡 2: 鼠尾草綠 (左下) - 使用整數倍頻率確保無縫循環
    final double b2x = size.width * 0.25 - math.cos(angle) * 80;
    final double b2y = size.height * 0.8 + math.sin(angle * 2) * 70;
    _drawBlurCircle(canvas, Offset(b2x, b2y), 300,
        const Color(0xFFD4EAD7).withValues(alpha: 0.70), paint);

    // 氣泡 3: 金黃沙丘 (右中) - 使用整數倍頻率確保無縫循環
    final double b3x = size.width * 0.8 + math.cos(angle * 2) * 60;
    final double b3y = size.height * 0.65 - math.sin(angle) * 70;
    _drawBlurCircle(canvas, Offset(b3x, b3y), 230,
        const Color(0xFFFDE4C3).withValues(alpha: 0.72), paint);

    // 氣泡 4: 輕柔暖灰茶 (左上) - 使用整數倍頻率確保無縫循環
    final double b4x = size.width * 0.15 + math.sin(angle) * 50;
    final double b4y = size.height * 0.15 + math.cos(angle * 2) * 45;
    _drawBlurCircle(canvas, Offset(b4x, b4y), 210,
        const Color(0xFFE9DEC4).withValues(alpha: 0.75), paint);
  }

  void _drawBlurCircle(
      Canvas canvas, Offset center, double radius, Color color, Paint paint) {
    paint.color = color;
    paint.shader = RadialGradient(
      colors: [
        color,
        color.withValues(alpha: 0.45), // 提高中間停止點的色彩濃度以增強流光效果
        Colors.transparent,
      ],
      stops: const [0.0, 0.6, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, paint);
    paint.shader = null;
  }

  @override
  bool shouldRepaint(covariant _FlowBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ── 焦點呼吸燈輸入框外框 ─────────────────────────────────────────────────────────────
class _FocusedGlowField extends StatefulWidget {
  final Widget child;
  final FocusNode? focusNode;
  const _FocusedGlowField({required this.child, this.focusNode});

  @override
  State<_FocusedGlowField> createState() => _FocusedGlowFieldState();
}

class _FocusedGlowFieldState extends State<_FocusedGlowField> {
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _hasFocus
                ? const Color(0xFF8D6E63).withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.01),
            blurRadius: _hasFocus ? 14 : 4,
            spreadRadius: _hasFocus ? 1 : 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: widget.child,
    );
  }
}

// ── 主體 ─────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  bool _isSuccess = false; // 用於登入成功後隱藏表單，避免閃現登入畫面
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false; // 註冊時必須勾選吀意服務條款與隱私權政策

  // ── 登入成功動畫 ────────────────────────────────────────────────────────
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = '@gmail.com';
    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus) {
        if (_emailCtrl.text == '@gmail.com') {
          _emailCtrl.selection = const TextSelection.collapsed(offset: 0);
        }
      }
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _emailCtrl.dispose();
    _emailFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _showSuccessOverlay(Map<String, dynamic> userMap) {
    setState(() => _isSuccess = true);
    final displayName =
        (userMap['display_name'] ?? userMap['username'] ?? '您').toString();
    _overlayEntry = OverlayEntry(
      builder: (_) => Material(
        color: Colors.transparent,
        child: _LoginSuccessOverlay(
          displayName: displayName,
          onComplete: () {
            _overlayEntry?.remove();
            _overlayEntry = null;
            widget.onLogin(userMap);
          },
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  // ── 樣式常數 ──────────────────────────────────────────────────────────────
  static const _primaryColor = Color(0xFF8D6E63);
  static const _bgColor = Color(0xFFF7F3F0);

  InputDecoration _inputDeco(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF8D6E63), fontSize: 13.5),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.45),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:
            BorderSide(color: Colors.white.withValues(alpha: 0.45), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
            color: const Color(0xFF8D6E63).withValues(alpha: 0.7), width: 1.8),
      ),
      suffixIcon: suffix,
    );
  }

  Future<void> _forgotPassword() async {
    final TextEditingController emailResetCtrl = TextEditingController();
    if (_emailCtrl.text.isNotEmpty && _emailCtrl.text != '@gmail.com') {
      emailResetCtrl.text = _emailCtrl.text;
    }

    final bool? emailExists = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('忘記密碼'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('請輸入您註冊時使用的電子信箱，以進行密碼重設。'),
            const SizedBox(height: 14),
            TextField(
              controller: emailResetCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDeco('電子信箱',
                  suffix: const Icon(Icons.email_outlined,
                      color: Color(0xFFBCAAA4))),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final email = emailResetCtrl.text.trim();
              if (email.isEmpty || email == '@gmail.com') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請輸入有效的信箱')),
                );
                return;
              }

              try {
                final db = await DatabaseHelper.instance.database;
                final res = await db
                    .query('users', where: 'email = ?', whereArgs: [email]);
                if (res.isEmpty) {
                  if (!ctx.mounted) return;
                  showDialog(
                    context: ctx,
                    builder: (c) => AlertDialog(
                      title: const Text('提示'),
                      content: const Text('找不到此信箱對應的帳號，請確認信箱是否輸入正確。'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('確定'),
                        ),
                      ],
                    ),
                  );
                } else {
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, true);
                }
              } catch (e) {
                debugPrint('查詢帳號失敗: $e');
              }
            },
            child: const Text('下一步'),
          ),
        ],
      ),
    );

    if (emailExists == true) {
      final targetEmail = emailResetCtrl.text.trim();
      if (!mounted) return;

      final TextEditingController newPasswordCtrl = TextEditingController();
      final TextEditingController confirmPasswordCtrl = TextEditingController();
      bool obscureNew = true;
      bool obscureConfirm = true;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('重設新密碼'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('帳號驗證成功！請輸入您的新密碼。'),
                const SizedBox(height: 14),
                TextField(
                  controller: newPasswordCtrl,
                  obscureText: obscureNew,
                  decoration: _inputDeco(
                    '新密碼',
                    suffix: IconButton(
                      icon: Icon(
                        obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFFBCAAA4),
                      ),
                      onPressed: () => setState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmPasswordCtrl,
                  obscureText: obscureConfirm,
                  decoration: _inputDeco(
                    '確認新密碼',
                    suffix: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFFBCAAA4),
                      ),
                      onPressed: () =>
                          setState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final newPass = newPasswordCtrl.text;
                  final confPass = confirmPasswordCtrl.text;

                  if (newPass.isEmpty || confPass.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('欄位不可為空')),
                    );
                    return;
                  }
                  if (newPass != confPass) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('兩次輸入密碼不同')),
                    );
                    return;
                  }

                  try {
                    final db = await DatabaseHelper.instance.database;
                    await db.update(
                      'users',
                      {'hashed_password': newPass},
                      where: 'email = ?',
                      whereArgs: [targetEmail],
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);

                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('重設成功'),
                        content: const Text('您的密碼已成功更新！請使用新密碼進行登入。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('確定'),
                          ),
                        ],
                      ),
                    );
                  } catch (e) {
                    debugPrint('更新密碼失敗: $e');
                  }
                },
                child: const Text('完成重設'),
              ),
            ],
          );
        }),
      );
    }
  }

  // 登入頁內嵌條款/隱私彈窗（服務條款與隱私權政策的精簡版本）
  void _showInlineDialog({
    required BuildContext context,
    required String title,
    required IconData icon,
  }) {
    final isTerms = title == '服務條款';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: const Color(0xFF8D6E63)),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 320,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: isTerms
                  ? [
                      _buildInlineSection('1. 接受條款', '您使用本服務即代表您已閱讀、理解並同意受本服務條款約束。若您未滿 13 歲，請停止使用本服務。'),
                      _buildInlineSection('2. 帳號責任', '您有責任妥善保管帳號憑證，並對帳號下發生的所有活動負責。如發現帳號遭未經授權使用，請立即通知我們。'),
                      _buildInlineSection('3. 使用者行為規範', '不得散佈違法、騷擾、誹謗或侵權內容；不得傳播惡意程式；不得以自動化方式大量存取服務。我們保留移除違規內容及停權帳號的權利。'),
                      _buildInlineSection('4. AI 功能聲明', 'AI 智慧功能（含 AI 診斷、AI 分身、AI 行事曆助手等）由第三方 AI 模型提供支援，其回覆內容僅供參考，不構成專業建議。'),
                      _buildInlineSection('5. 免責聲明', '本服務「依現狀」提供，不附帶任何形式的保證。在法律允許的範圍內，我們不對因使用本服務所造成的損害負責。'),
                      _buildInlineSection('6. 條款修改', '我們保留隨時修訂本條款的權利，修訂後的條款將於 App 內公告。繼續使用即代表接受修訂後的條款。'),
                    ]
                  : [
                      _buildInlineSection('1. 蒐集的資料類型', '帳號資訊（使用者名稱、電子郵件）、學習歷程（測驗紀錄、筆記）、功能使用偏好及裝置作業系統版本。'),
                      _buildInlineSection('2. 資料使用目的', '僅用於提供、維護及改善服務功能，以及個人化您的學習體驗。我們不會出售您的個人資料給任何第三方。'),
                      _buildInlineSection('3. 資料儲存', '資料主要儲存於您裝置本地的 SQLite 資料庫中。AI 對話等功能需透過加密連線（HTTPS）傳輸至第三方 AI 服務。'),
                      _buildInlineSection('4. 您的資料權利', '您可隨時查詢、修改個人資料，或申請刪除帳號（我們將於 30 天內清除您的個人資料）。'),
                      _buildInlineSection('5. 第三方服務', '使用 Google 登入、Google Gemini AI 及 OpenRouter AI 等服務時，相關資料將依各自的隱私權政策處理。'),
                    ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8D6E63),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我已了解'),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8D6E63))),
          const SizedBox(height: 4),
          Text(content,
              style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade700,
                  height: 1.5)),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (isLogin) {
      if (_emailCtrl.text.isEmpty ||
          _emailCtrl.text == '@gmail.com' ||
          _passwordCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('信箱與密碼不得為空')));
        return;
      }
    } else {
      if (_usernameCtrl.text.isEmpty ||
          _emailCtrl.text.isEmpty ||
          _emailCtrl.text == '@gmail.com' ||
          _passwordCtrl.text.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('所有欄位皆不得為空')));
        return;
      }
      if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: const Text('提示'),
                  content: const Text('兩次輸入的密碼不相同，請重新確認！'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('確定'))
                  ],
                ));
        return;
      }
      if (!_agreedToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('請先閱讀並勾選同意「服務條款」與「隱私權政策」才能完成註冊。'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    try {
      final db = await DatabaseHelper.instance.database;

      if (isLogin) {
        final res = await db.query('users',
            where: 'email = ? AND hashed_password = ?',
            whereArgs: [_emailCtrl.text, _passwordCtrl.text]);
        if (!mounted) return;
        if (res.isNotEmpty) {
          final userMap = Map<String, dynamic>.from(res.first);

          // 處理刪除復原邏輯 (自動刪除由系統背景或啟動時處理)
          if (userMap['deleted_at'] != null) {
            if (!mounted) return;
            final shouldRestore = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('帳號復原提示'),
                content: const Text('您的帳號已排程刪除。是否要取消刪除並復原帳號？'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('確認復原')),
                ],
              ),
            );
            if (shouldRestore == true) {
              await db.update('users', {'deleted_at': null},
                  where: 'id = ?', whereArgs: [userMap['id']]);
              userMap['deleted_at'] = null;
            } else {
              return; // 放棄登入
            }
          }

          userMap['session_post_ids'] = <int>{};
          userMap['session_comment_ids'] = <int>{};
          _showSuccessOverlay(userMap);
        } else {
          final userCheck = await db
              .query('users', where: 'email = ?', whereArgs: [_emailCtrl.text]);
          if (!mounted) return;
          if (userCheck.isNotEmpty) {
            showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                      title: const Text('密碼錯誤'),
                      content: const Text('您輸入的密碼不正確，請重新輸入。'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('確定'))
                      ],
                    ));
          } else {
            showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                      title: const Text('找不到帳號'),
                      content: const Text('此信箱尚未註冊，請先建立新帳號再登入。'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('確定'))
                      ],
                    ));
          }
        }
      } else {
        // 註冊
        try {
          String newId = 'u_${DateTime.now().millisecondsSinceEpoch}';
          await db.insert('users', {
            'id': newId,
            'username': _usernameCtrl.text,
            'email': _emailCtrl.text,
            'hashed_password': _passwordCtrl.text,
            'display_name': _usernameCtrl.text,
          });
          _passwordCtrl.clear();
          _confirmPasswordCtrl.clear();
          if (!mounted) return;
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: const Text('註冊成功'),
                    content: const Text('帳號建立完成！請使用帳號密碼登入。'),
                    actions: [
                      TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() => isLogin = true);
                          },
                          child: const Text('前往登入'))
                    ],
                  ));
        } catch (e) {
          if (!mounted) return;
          String errorMsg = '帳號名稱或信箱可能已被使用，請換一個試試。';
          // 如果不是 UNIQUE constraint 錯誤，才顯示詳細訊息，或者是乾脆不顯示詳細訊息以維持簡潔
          if (!e.toString().contains('UNIQUE constraint failed')) {
            errorMsg += '\n錯誤詳情：$e';
          }

          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: const Text('註冊失敗'),
                    content: Text(errorMsg),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('確定'))
                    ],
                  ));
        }
      }
    } catch (e) {
      debugPrint('資料庫連線失敗: $e');
    }
  }

  // ── Google 登入邏輯 ────────────────────────────────────────────────────────
  void _showGoogleSignInDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Google Sign In',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value) * 0.12 + 0.88,
          child: Opacity(
            opacity: anim1.value,
            child: _GoogleSignInModal(
              onAccountSelected: (email, name) async {
                Navigator.pop(ctx);
                await _handleGoogleLogin(email, name);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleGoogleLogin(String email, String displayName) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res =
          await db.query('users', where: 'email = ?', whereArgs: [email]);
      if (!mounted) return;

      Map<String, dynamic> userMap;
      if (res.isNotEmpty) {
        userMap = Map<String, dynamic>.from(res.first);
        // 如果存在但尚未標記為 google 登入，則更新為 google 登入
        if (userMap['is_google'] != 1) {
          await db.update('users', {'is_google': 1},
              where: 'id = ?', whereArgs: [userMap['id']]);
          userMap['is_google'] = 1;
        }

        // 處理刪除復原邏輯
        if (userMap['deleted_at'] != null) {
          if (!mounted) return;
          final shouldRestore = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('帳號復原提示'),
              content: const Text('您的帳號已排程刪除。是否要取消刪除並復原帳號？'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('確認復原')),
              ],
            ),
          );
          if (shouldRestore == true) {
            await db.update('users', {'deleted_at': null},
                where: 'id = ?', whereArgs: [userMap['id']]);
            userMap['deleted_at'] = null;
          } else {
            return; // 放棄登入
          }
        }
      } else {
        // 註冊新的 Google 帳號
        String baseUsername = displayName.trim().isNotEmpty
            ? displayName.trim()
            : (email.contains('@') ? email.split('@')[0] : 'google_user');

        String uniqueUsername = baseUsername;
        int counter = 1;
        while (true) {
          final existing = await db.query('users',
              where: 'username = ?', whereArgs: [uniqueUsername]);
          if (existing.isEmpty) break;
          uniqueUsername = '${baseUsername}_$counter';
          counter++;
        }

        String newId = 'g_${DateTime.now().millisecondsSinceEpoch}';
        final newUserData = {
          'id': newId,
          'username': uniqueUsername,
          'email': email,
          'hashed_password': 'google_oauth_bypass',
          'display_name': displayName.trim().isNotEmpty ? displayName : uniqueUsername,
          'is_google': 1,
          'is_email_verified': 1,
        };
        await db.insert('users', newUserData);
        userMap = newUserData;
      }

      userMap['session_post_ids'] = <int>{};
      userMap['session_comment_ids'] = <int>{};
      _showSuccessOverlay(userMap);
    } catch (e) {
      debugPrint('Google 登入失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google 登入失敗：$e')),
        );
      }
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return const Scaffold(backgroundColor: _bgColor);
    }
    // 每次切換 isLogin 時，key 重建讓動畫重播
    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // 動態流光背景
          const Positioned.fill(
            child: _AmbientFlowBackground(),
          ),

          // 主體內容
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 品牌圖示
                  _exquisiteFadeIn(
                    child: const _BrandMark(),
                    delayMs: 0,
                    from: 25,
                  ),
                  const SizedBox(height: 24),

                  // 毛玻璃登入卡片
                  _exquisiteFadeIn(
                    delayMs: 400,
                    from: 35,
                    child: _GlassCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 標題
                          Text(
                            isLogin ? 'YeBang 家教' : '建立新帳號',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4E342E),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isLogin ? '請輸入您的信箱與密碼' : '填寫資料以完成註冊',
                            style: const TextStyle(
                                fontSize: 13.5, color: Color(0xFF8D6E63)),
                          ),
                          const SizedBox(height: 28),

                          // 欄位組
                          // Gmail 欄
                          _FocusedGlowField(
                            focusNode: _emailFocusNode,
                            child: TextField(
                              controller: _emailCtrl,
                              focusNode: _emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                              onTap: () {
                                if (_emailCtrl.text == '@gmail.com') {
                                  _emailCtrl.selection =
                                      const TextSelection.collapsed(offset: 0);
                                }
                              },
                              decoration: _inputDeco('信箱',
                                  suffix: const Icon(Icons.email_outlined,
                                      color: Color(0xFFBCAAA4))),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 帳號名稱欄（僅註冊）
                          if (!isLogin) ...[
                            _FocusedGlowField(
                              focusNode: _usernameFocusNode,
                              child: TextField(
                                controller: _usernameCtrl,
                                focusNode: _usernameFocusNode,
                                decoration: _inputDeco('帳號名稱',
                                    suffix: const Icon(
                                        Icons.person_outline_rounded,
                                        color: Color(0xFFBCAAA4))),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // 密碼欄
                          _FocusedGlowField(
                            focusNode: _passwordFocusNode,
                            child: TextField(
                              controller: _passwordCtrl,
                              focusNode: _passwordFocusNode,
                              obscureText: _obscurePassword,
                              decoration: _inputDeco('密碼',
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFFBCAAA4),
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  )),
                            ),
                          ),
                          if (isLogin) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _forgotPassword,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  '忘記密碼？',
                                  style: TextStyle(
                                    color: Color(0xFF8D6E63),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ] else ...[
                            const SizedBox(height: 14),
                          ],

                          // 確認密碼（僅註冊）
                          if (!isLogin) ...[
                            _FocusedGlowField(
                              focusNode: _confirmPasswordFocusNode,
                              child: TextField(
                                controller: _confirmPasswordCtrl,
                                focusNode: _confirmPasswordFocusNode,
                                obscureText: _obscureConfirm,
                                decoration: _inputDeco('確認密碼',
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: const Color(0xFFBCAAA4),
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscureConfirm = !_obscureConfirm),
                                    )),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // 查閱與同意服務條款（僅註冊模式）
                          if (!isLogin) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _agreedToTerms,
                                      onChanged: (v) =>
                                          setState(() => _agreedToTerms = v ?? false),
                                      activeColor: const Color(0xFF8D6E63),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4)),
                                      side: const BorderSide(
                                          color: Color(0xFF8D6E63), width: 1.5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text('我已閱讀並同意本應用程式的 ',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600)),
                                        GestureDetector(
                                          onTap: () => _showInlineDialog(
                                              context: context,
                                              title: '服務條款',
                                              icon: Icons.gavel_outlined),
                                          child: const Text('服務條款',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF8D6E63),
                                                  fontWeight: FontWeight.bold,
                                                  decoration: TextDecoration.underline)),
                                        ),
                                        Text(' 與 ',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600)),
                                        GestureDetector(
                                          onTap: () => _showInlineDialog(
                                              context: context,
                                              title: '隱私權政策',
                                              icon: Icons.privacy_tip_outlined),
                                          child: const Text('隱私權政策',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF8D6E63),
                                                  fontWeight: FontWeight.bold,
                                                  decoration: TextDecoration.underline)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 主按鈕（登入 / 註冊）
                          Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF8D6E63),
                                  Color(0xFFA1887F),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8D6E63)
                                      .withValues(alpha: 0.32),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _submit,
                              child: Text(
                                isLogin ? '登入' : '註冊',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 切換登入 / 註冊
                          TextButton(
                            onPressed: () => setState(() {
                              isLogin = !isLogin;
                              _passwordCtrl.clear();
                              _confirmPasswordCtrl.clear();
                              if (_emailCtrl.text.isEmpty) {
                                _emailCtrl.text = '@gmail.com';
                              }
                            }),
                            child: Text(
                              isLogin ? '還沒有帳號？點此註冊' : '已有帳號？點此登入',
                              style: const TextStyle(
                                  color: Color(0xFF8D6E63),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Google 登入按鈕
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.55),
                                side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    width: 1.2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              onPressed: _showGoogleSignInDialog,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const GoogleLogo(size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    isLogin
                                        ? '使用 Google 帳號登入'
                                        : '使用 Google 帳號註冊',
                                    style: const TextStyle(
                                      color: Color(0xFF3C4043),
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 分隔線
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Expanded(
                                  child: Divider(color: Color(0xFFE5DCD3))),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('或',
                                    style: TextStyle(
                                        color: Color(0xFFBCAAA4),
                                        fontSize: 12)),
                              ),
                              Expanded(
                                  child: Divider(color: Color(0xFFE5DCD3))),
                            ]),
                          ),
                          const SizedBox(height: 12),

                          // 訪客登入
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.35),
                                side: BorderSide(
                                    color: const Color(0xFF8D6E63)
                                        .withValues(alpha: 0.4),
                                    width: 1.2),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.person_outline_rounded,
                                  color: _primaryColor, size: 20),
                              label: const Text(
                                '以訪客身份直接登入',
                                style: TextStyle(
                                    color: _primaryColor,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5),
                              ),
                              onPressed: () async {
                                try {
                                  final db =
                                      await DatabaseHelper.instance.database;
                                  final res = await db.query('users',
                                      where: 'username = ?', whereArgs: ['訪客']);
                                  if (!mounted) return;
                                  if (res.isNotEmpty) {
                                    final userMap =
                                        Map<String, dynamic>.from(res.first);
                                    userMap['session_post_ids'] = <int>{};
                                    userMap['session_comment_ids'] = <int>{};
                                    _showSuccessOverlay(userMap);
                                  } else {
                                    _showSuccessOverlay({
                                      'id': 'u4',
                                      'username': '訪客',
                                      'display_name': '訪客',
                                      'session_post_ids': <int>{},
                                      'session_comment_ids': <int>{},
                                    });
                                  }
                                } catch (e) {
                                  debugPrint('訪客登入失敗: $e');
                                  if (!mounted) return;
                                  _showSuccessOverlay({
                                    'id': 'u4',
                                    'username': '訪客',
                                    'display_name': '訪客',
                                    'session_post_ids': <int>{},
                                    'session_comment_ids': <int>{},
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Google 專屬模擬登入視窗組件 ──────────────────────────────────────────────────

class GoogleSpinner extends StatefulWidget {
  const GoogleSpinner({super.key});
  @override
  State<GoogleSpinner> createState() => _GoogleSpinnerState();
}

class _GoogleSpinnerState extends State<GoogleSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: SizedBox(
        width: 45,
        height: 45,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            Color color;
            if (_controller.value < 0.25) {
              color = const Color(0xFF4285F4); // Blue
            } else if (_controller.value < 0.5) {
              color = const Color(0xFFEA4335); // Red
            } else if (_controller.value < 0.75) {
              color = const Color(0xFFFBBC05); // Yellow
            } else {
              color = const Color(0xFF34A853); // Green
            }
            return CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            );
          },
        ),
      ),
    );
  }
}

class _GoogleSignInModal extends StatefulWidget {
  final Function(String email, String name) onAccountSelected;
  const _GoogleSignInModal({required this.onAccountSelected});

  @override
  State<_GoogleSignInModal> createState() => _GoogleSignInModalState();
}

class _GoogleSignInModalState extends State<_GoogleSignInModal> {
  bool _isLoading = false;
  bool _isAddingAccount = false;
  bool _isRemovingMode = false;

  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, String>> _presetAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadExistingAccounts();
  }

  Future<void> _loadExistingAccounts() async {
    try {
      final db = await DatabaseHelper.instance.database;
      // 查詢 SQLite 中所有曾以 Google 登入 (is_google = 1) 的使用者
      final res = await db.query(
        'users',
        where: 'is_google = 1',
      );
      if (!mounted) return;
      setState(() {
        _presetAccounts = res.map((row) {
          final name =
              (row['display_name'] ?? row['username'] ?? '').toString();
          final email = (row['email'] ?? '').toString();
          final initial = name.isNotEmpty ? name.substring(0, 1) : '?';
          return {
            'name': name,
            'email': email,
            'initial': initial,
          };
        }).toList();

        // 若無任何已登入的 Google 帳號，直接進入輸入畫面
        if (_presetAccounts.isEmpty) {
          _isAddingAccount = true;
          _isRemovingMode = false;
        }
      });
    } catch (e) {
      debugPrint('載入 Google 帳號清單失敗: $e');
    }
  }

  Future<void> _removeAccount(String email) async {
    try {
      final db = await DatabaseHelper.instance.database;
      // 方案一：僅將 is_google 設為 0
      await db.update(
        'users',
        {'is_google': 0},
        where: 'email = ?',
        whereArgs: [email],
      );
      await _loadExistingAccounts();
    } catch (e) {
      debugPrint('移除 Google 帳號連結失敗: $e');
    }
  }

  Future<void> _confirmRemoveAccount(String email, String name) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除帳號？'),
        content: Text('這會將「$name ($email)」從此裝置的登入清單中移除。\n\n您在此APP所有資料仍會妥善保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('確認移除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _removeAccount(email);
    }
  }

  void _selectAccount(String email, String name) {
    setState(() {
      _isLoading = true;
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        widget.onAccountSelected(email, name);
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Widget _buildGoogleLogoText() {
    final styles = [
      const TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.bold),
      const TextStyle(color: Color(0xFFEA4335), fontWeight: FontWeight.bold),
      const TextStyle(color: Color(0xFFFBBC05), fontWeight: FontWeight.bold),
      const TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.bold),
      const TextStyle(color: Color(0xFF34A853), fontWeight: FontWeight.bold),
      const TextStyle(color: Color(0xFFEA4335), fontWeight: FontWeight.bold),
    ];
    final letters = ['G', 'o', 'o', 'g', 'l', 'e'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(6, (i) {
        return Text(
          letters[i],
          style: styles[i].copyWith(fontSize: 22, letterSpacing: 0.5),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double modalWidth =
        MediaQuery.of(context).size.width.clamp(300.0, 420.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: modalWidth,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _isLoading
              ? _buildLoadingState()
              : (_isAddingAccount
                  ? _buildAddAccountState()
                  : _buildAccountSelectorState()),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        const GoogleSpinner(),
        const SizedBox(height: 24),
        Text(
          '正在透過 Google 安全驗證...',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAccountSelectorState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildGoogleLogoText(),
        const SizedBox(height: 16),
        const Text(
          '選取帳號',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF202124),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '以繼續前往 YeBang 家教',
          style: TextStyle(
            fontSize: 13.5,
            color: Color(0xFF5F6368),
          ),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: _presetAccounts.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFF1F3F4)),
            itemBuilder: (ctx, i) {
              final acc = _presetAccounts[i];
              return InkWell(
                onTap: _isRemovingMode
                    ? () => _confirmRemoveAccount(acc['email']!, acc['name']!)
                    : () => _selectAccount(acc['email']!, acc['name']!),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Row(
                    children: [
                      _buildAccountAvatar(acc['initial']!, i),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              acc['name']!,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3C4043),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              acc['email']!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF5F6368),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _isRemovingMode
                          ? const Icon(Icons.remove_circle_outline_rounded,
                              size: 20, color: Colors.redAccent)
                          : const Icon(Icons.chevron_right_rounded,
                              size: 18, color: Color(0xFF747775)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1F3F4)),
        if (!_isRemovingMode) ...[
          InkWell(
            onTap: () => setState(() => _isAddingAccount = true),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded,
                      size: 20, color: Color(0xFF1A73E8)),
                  SizedBox(width: 14),
                  Text(
                    '使用其他帳號',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A73E8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F3F4)),
          InkWell(
            onTap: () => setState(() => _isRemovingMode = true),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Row(
                children: [
                  Icon(Icons.remove_circle_outline_rounded,
                      size: 20, color: Color(0xFF5F6368)),
                  SizedBox(width: 14),
                  Text(
                    '移除帳號',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5F6368),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          InkWell(
            onTap: () => setState(() => _isRemovingMode = false),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 20, color: Color(0xFF1A73E8)),
                  SizedBox(width: 8),
                  Text(
                    '完成',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A73E8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text(
          '若要繼續，Google 會將您的姓名、電子郵件地址和個人資料相片與 YeBang 家教共用。請務必詳閱 YeBang 家教的服務條款和隱私權政策。',
          textAlign: TextAlign.start,
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF70757A),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildAddAccountState() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildGoogleLogoText(),
          const SizedBox(height: 16),
          const Text(
            '新增 Google 帳號',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF202124),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: '電子郵件地址 (Google 帳號)',
              hintText: 'user@gmail.com',
              labelStyle: const TextStyle(fontSize: 14),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF1A73E8), width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return '請輸入電子郵件';
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(val.trim())) return '電子郵件格式不正確';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: '您的姓名',
              hintText: '如：小明',
              labelStyle: const TextStyle(fontSize: 14),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF1A73E8), width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return '請輸入姓名';
              return null;
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _isAddingAccount = false),
                child: const Text('返回',
                    style: TextStyle(
                        color: Color(0xFF1A73E8), fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _selectAccount(
                        _emailCtrl.text.trim(), _nameCtrl.text.trim());
                  }
                },
                child: const Text('下一步',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountAvatar(String initial, int index) {
    final colors = [
      const Color(0xFF4285F4), // Blue
      const Color(0xFFEA4335), // Red
      const Color(0xFFFBBC05), // Yellow
      const Color(0xFF34A853), // Green
      Colors.purple,
    ];
    final color = colors[index % colors.length];
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
