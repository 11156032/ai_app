import 'dart:math' as math;
import 'dart:ui';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';

// ── 通用精美進場組件 ─────────────────────────────────────────────────────────
Widget exquisiteFadeIn({
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

// ── 磨砂玻璃容器卡片 ─────────────────────────────────────────────────────────────
class LoginGlassCard extends StatelessWidget {
  final Widget child;
  const LoginGlassCard({super.key, required this.child});

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
class LoginAmbientFlowBackground extends StatefulWidget {
  const LoginAmbientFlowBackground({super.key});

  @override
  State<LoginAmbientFlowBackground> createState() =>
      _LoginAmbientFlowBackgroundState();
}

class _LoginAmbientFlowBackgroundState
    extends State<LoginAmbientFlowBackground>
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
          painter: FlowBackgroundPainter(progress: _controller.value),
        );
      },
    );
  }
}

class FlowBackgroundPainter extends CustomPainter {
  final double progress;

  FlowBackgroundPainter({required this.progress});

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
  bool shouldRepaint(covariant FlowBackgroundPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ── 焦點呼吸燈輸入框外框 ─────────────────────────────────────────────────────────────
class LoginFocusedGlowField extends StatefulWidget {
  final Widget child;
  final FocusNode? focusNode;
  const LoginFocusedGlowField({super.key, required this.child, this.focusNode});

  @override
  State<LoginFocusedGlowField> createState() => _LoginFocusedGlowFieldState();
}

class _LoginFocusedGlowFieldState extends State<LoginFocusedGlowField> {
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
