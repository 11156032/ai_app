import 'package:flutter/material.dart';
import 'about_us_painters.dart';

// ======================================================
//  ShimmerCard — Diagonal sweep light on Mission Card
// ======================================================
class ShimmerCard extends StatelessWidget {
  final AnimationController shimmerController;
  final Color primaryColor;
  final double borderRadius;
  final Widget child;

  const ShimmerCard({
    super.key,
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
                    painter: ShimmerPainter(
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

// ======================================================
//  RevealOnScroll — Upgraded scroll-triggered animation
// ======================================================
class RevealOnScroll extends StatefulWidget {
  final Widget child;
  final ScrollController scrollController;
  final Duration delay;
  final Offset slideBegin;
  final double? scaleBegin;
  final double? rotateBegin; // 弧度 radians
  final Duration duration;
  final Curve curve;
  final VoidCallback? onTriggered;

  const RevealOnScroll({
    super.key,
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
  State<RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<RevealOnScroll>
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

    _opacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: widget.slideBegin, end: Offset.zero)
        .animate(curved);

    if (widget.scaleBegin != null) {
      _scale =
          Tween<double>(begin: widget.scaleBegin!, end: 1.0).animate(curved);
    }
    if (widget.rotateBegin != null) {
      _rotate =
          Tween<double>(begin: widget.rotateBegin!, end: 0.0).animate(curved);
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
    // 閾值 0.88，更早觸發、更順暢的感知
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
        builder: (_, child) => Transform.rotate(angle: rot.value, child: child),
        child: w,
      );
    }
    w = SlideTransition(position: _slide, child: w);
    w = FadeTransition(opacity: _opacity, child: w);
    return Container(key: _key, child: w);
  }
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
