import 'package:flutter/material.dart';
import 'dart:typed_data';

// 預設插圖頭像（emoji 角色 + 背景色）
const List<Map<String, dynamic>> kPresetAvatars = [
  {'emoji': '😊', 'color': Color(0xFFFFD54F), 'label': '開心'},
  {'emoji': '🐱', 'color': Color(0xFFFFAB91), 'label': '小貓'},
  {'emoji': '🐶', 'color': Color(0xFFA5D6A7), 'label': '小狗'},
  {'emoji': '🦊', 'color': Color(0xFFFFCC80), 'label': '狐狸'},
  {'emoji': '🐼', 'color': Color(0xFF90A4AE), 'label': '熊貓'},
  {'emoji': '🦁', 'color': Color(0xFFFFF176), 'label': '獅子'},
  {'emoji': '🐸', 'color': Color(0xFF80CBC4), 'label': '青蛙'},
  {'emoji': '🐧', 'color': Color(0xFF90CAF9), 'label': '企鹅'},
];

/// 根據名稱字串推算頭像顏色索引
int getAvatarColorIdx(String name) => name.isEmpty
    ? 0
    : name.codeUnits.fold(0, (a, b) => a + b) % kPresetAvatars.length;

/// 通用頭像 Widget
Widget buildAvatar({
  Uint8List? blob,
  int colorIdx = 0,
  String initial = '',
  double radius = 18,
  bool usePreset = false,
}) {
  if (blob != null) {
    return CircleAvatar(radius: radius, backgroundImage: MemoryImage(blob));
  }
  if (usePreset) {
    final preset = kPresetAvatars[colorIdx % kPresetAvatars.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: preset['color'] as Color,
      child: Text(preset['emoji'] as String,
          style: TextStyle(fontSize: radius * 0.95)),
    );
  }
  return CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFBDBDBD),
    child: Icon(Icons.person, color: Colors.white, size: radius),
  );
}

/// 格式化相對時間
String formatRelativeTime(dynamic timeStr) {
  if (timeStr == null) return '';
  try {
    DateTime dt = DateTime.parse(timeStr.toString());
    Duration diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '剛剛';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
    if (diff.inHours < 24) return '${diff.inHours} 小時前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return '${dt.month}/${dt.day}';
  } catch (e) {
    return timeStr.toString();
  }
}

// ── Google 專屬向量圖示 ────────────────────────────────────────────────────────

class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final double strokeWidth = r * 0.42;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;

    final double radius = r - strokeWidth / 2;
    final Rect arcRect = Rect.fromCircle(center: Offset(r, r), radius: radius);

    // 紅色 (Top)
    canvas.drawArc(arcRect, -0.785 - 1.57, 1.57, false,
        paint..color = const Color(0xFFEA4335));
    // 黃色 (Left)
    canvas.drawArc(
        arcRect, 1.57, 1.57, false, paint..color = const Color(0xFFFBBC05));
    // 綠色 (Bottom)
    canvas.drawArc(
        arcRect, 0.785, 1.57, false, paint..color = const Color(0xFF34A853));

    // 藍色 (Right arc + horizontal bar)
    canvas.drawArc(
        arcRect, -0.785, 1.57, false, paint..color = const Color(0xFF4285F4));

    // 繪製藍色橫條
    final Paint barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
        Rect.fromLTWH(r, r - strokeWidth / 2, r - strokeWidth / 2, strokeWidth),
        barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
