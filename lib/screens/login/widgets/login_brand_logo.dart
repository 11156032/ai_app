import 'package:flutter/material.dart';

/// 登入介面品牌標誌：維持經典外框旋轉弧環 (Orbit Ring)，Logo 保持固定大小無縮放跳動
class LoginBrandMark extends StatefulWidget {
  final double size;
  const LoginBrandMark({super.key, this.size = 110});

  @override
  State<LoginBrandMark> createState() => _LoginBrandMarkState();
}

class _LoginBrandMarkState extends State<LoginBrandMark>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotateCtrl;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    final bool isInTest = WidgetsBinding.instance.runtimeType
        .toString()
        .toLowerCase()
        .contains('test');

    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _rotateAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateCtrl, curve: Curves.linear),
    );

    if (!isInTest) {
      _rotateCtrl.repeat();
    }
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double coreSize = widget.size;
    final double ringSize = coreSize * 1.32;

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. 原先優雅的外框旋轉弧環效果 (Arc Ring)
          AnimatedBuilder(
            animation: _rotateAnim,
            builder: (_, __) {
              return Transform.rotate(
                angle: _rotateAnim.value * 6.2831853,
                child: CustomPaint(
                  size: Size(ringSize, ringSize),
                  painter: const ArcRingPainter(),
                ),
              );
            },
          ),
          // 2. 中心圓形白底容器 (大小恆定不忽大忽小，立體陰影)
          Container(
            width: coreSize,
            height: coreSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9CCC65).withValues(alpha: 0.20),
                  blurRadius: coreSize * 0.20,
                  offset: Offset(0, coreSize * 0.06),
                ),
                BoxShadow(
                  color: const Color(0xFF4DD0E1).withValues(alpha: 0.15),
                  blurRadius: coreSize * 0.12,
                  offset: Offset(0, coreSize * 0.02),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/app_logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 外框優雅旋轉弧環繪製器
class ArcRingPainter extends CustomPainter {
  const ArcRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (size.width * 0.02).clamp(2.0, 3.5)
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(
      size.width * 0.04,
      size.height * 0.04,
      size.width * 0.92,
      size.height * 0.92,
    );

    // 弧段 1: 湖水青藍色
    paint.color = const Color(0xFF4DD0E1).withValues(alpha: 0.85);
    canvas.drawArc(rect, 0.0, 1.8, false, paint);

    // 弧段 2: 嫩綠色
    paint.color = const Color(0xFF9CCC65).withValues(alpha: 0.75);
    canvas.drawArc(rect, 2.4, 1.2, false, paint);

    // 弧段 3: 淺薄荷綠色
    paint.color = const Color(0xFF80CBC4).withValues(alpha: 0.50);
    canvas.drawArc(rect, 4.0, 0.6, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
