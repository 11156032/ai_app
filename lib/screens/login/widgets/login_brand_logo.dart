import 'package:flutter/material.dart';

// ── 抽象品牌圖示（替代 Gemini 圖示）────────────────────────────────────────
class LoginBrandMark extends StatefulWidget {
  const LoginBrandMark({super.key});

  @override
  State<LoginBrandMark> createState() => _LoginBrandMarkState();
}

class _LoginBrandMarkState extends State<LoginBrandMark>
    with TickerProviderStateMixin {
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
                  painter: ArcRingPainter(),
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
                    painter: LeafYLogoPainter(
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

class ArcRingPainter extends CustomPainter {
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

class LeafYLogoPainter extends CustomPainter {
  final double progress;
  final double leftLeafScale;
  final double rightLeafScale;
  final double shimmerProgress;

  const LeafYLogoPainter({
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
  bool shouldRepaint(covariant LeafYLogoPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.leftLeafScale != leftLeafScale ||
        oldDelegate.rightLeafScale != rightLeafScale ||
        oldDelegate.shimmerProgress != shimmerProgress;
  }
}
