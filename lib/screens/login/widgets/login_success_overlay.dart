import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/app_locale_service.dart';

// ── 登入成功動畫 Overlay ────────────────────────────────────────────────────
class LoginSuccessOverlay extends StatefulWidget {
  final String displayName;
  final VoidCallback onComplete;

  const LoginSuccessOverlay({
    super.key,
    required this.displayName,
    required this.onComplete,
  });

  @override
  State<LoginSuccessOverlay> createState() => _LoginSuccessOverlayState();
}

class _LoginSuccessOverlayState extends State<LoginSuccessOverlay>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl; // Ambient drift
  late AnimationController _shimmerCtrl; // Text shimmer reflection
  late AnimationController _dotsCtrl; // Jumping dots bounce
  late AnimationController _entranceCtrl; // Elements slide/fade/scale
  late AnimationController _exitCtrl; // Overall fade out

  late Animation<double> _entranceOpacity;
  late Animation<double> _textSlideY;
  late Animation<double> _loadingOpacity;
  late Animation<double> _exitOpacity;

  final List<LeafParticle> _leaves = [];

  @override
  void initState() {
    super.initState();

    _bgCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat(reverse: true);
    _shimmerCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
    _dotsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _entranceOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0, 0.45, curve: Curves.easeOut)));
    _textSlideY = Tween<double>(begin: 20, end: 0).animate(CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.05, 0.75, curve: Curves.easeOutCubic)));
    _loadingOpacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.35, 0.9, curve: Curves.easeOut)));

    _exitOpacity = Tween<double>(begin: 1, end: 0)
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic));

    // Initialize 6 drifting leaves
    final random = math.Random();
    for (int i = 0; i < 6; i++) {
      _leaves.add(LeafParticle(
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
    if (!mounted) return;
    _entranceCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;
    await _exitCtrl.forward();
    if (!mounted) return;
    widget.onComplete();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _shimmerCtrl.dispose();
    _dotsCtrl.dispose();
    _entranceCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
          [_bgCtrl, _shimmerCtrl, _dotsCtrl, _entranceCtrl, _exitCtrl]),
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
                        painter: DriftingLeavesPainter(
                          leaves: _leaves,
                          animationValue: _bgCtrl.value,
                        ),
                      ),
                    ),
                  ),
                ),

                // Center Content: Shimmer Text & Bouncing Loading Dots
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

                      const SizedBox(height: 20),

                      // 載入中.... (跳動點點動畫)
                      Opacity(
                        opacity: _loadingOpacity.value,
                        child: Transform.translate(
                          offset: Offset(0, _textSlideY.value * 0.4),
                          child: _BouncingDotsIndicator(
                            animationValue: _dotsCtrl.value,
                            color: const Color(0xFF8D6E63),
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

/// 帶有節奏跳動點點的載入指示器組件
class _BouncingDotsIndicator extends StatelessWidget {
  final double animationValue; // 0.0 to 1.0 from AnimationController
  final Color color;

  const _BouncingDotsIndicator({
    required this.animationValue,
    this.color = const Color(0xFF8D6E63),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          tr('common_loading'),
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 4),
        ...List.generate(4, (index) {
          // Staggered bounce wave
          final delay = index * 0.18;
          final t = (animationValue + delay) % 1.0;
          final bounce = math.sin(t * math.pi);
          final offsetY = bounce > 0 ? -6.0 * bounce : 0.0;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Transform.translate(
              offset: Offset(0, offsetY),
              child: Container(
                width: 4.8,
                height: 4.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.45 + 0.55 * (bounce > 0 ? bounce : 0)),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class LeafParticle {
  double x;
  double y;
  double size;
  double rotation;
  double speedY;
  double speedX;
  double spinSpeed;

  LeafParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.rotation,
    required this.speedY,
    required this.speedX,
    required this.spinSpeed,
  });
}

class DriftingLeavesPainter extends CustomPainter {
  final List<LeafParticle> leaves;
  final double animationValue;

  DriftingLeavesPainter({required this.leaves, required this.animationValue});

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
  bool shouldRepaint(covariant DriftingLeavesPainter oldDelegate) => true;
}

class LeafBranchDivider extends CustomPainter {
  final double progress;
  LeafBranchDivider({required this.progress});

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
  bool shouldRepaint(covariant LeafBranchDivider oldDelegate) =>
      oldDelegate.progress != progress;
}
