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
