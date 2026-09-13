import 'package:flutter/material.dart';
import 'dart:typed_data';

// 預設插圖頭像（emoji 角色 + 背景色）
const List<Map<String, dynamic>> kPresetAvatars = [
  {'emoji': '😊', 'color': Color(0xFFA1887F), 'label': '開心'}, // 預設暖棕
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
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.transparent,
      child: ClipOval(
        child: Image.memory(
          blob,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _buildFallbackAvatar(
              colorIdx, initial, radius,
              usePreset: usePreset),
        ),
      ),
    );
  }
  return _buildFallbackAvatar(colorIdx, initial, radius, usePreset: usePreset);
}

Widget _buildFallbackAvatar(int colorIdx, String initial, double radius,
    {bool usePreset = false}) {
  final preset = kPresetAvatars[colorIdx.abs() % kPresetAvatars.length];
  final bool hasValidInitial =
      initial.isNotEmpty && initial != '我' && initial != '?';
  final bool showEmoji = usePreset || !hasValidInitial;

  return CircleAvatar(
    radius: radius,
    backgroundColor: preset['color'] as Color,
    child: Text(
      showEmoji ? (preset['emoji'] as String) : initial,
      style: TextStyle(
        fontSize: radius * (showEmoji ? 0.9 : 0.85),
        fontWeight: FontWeight.bold,
        color: showEmoji ? null : Colors.black87,
      ),
    ),
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

// ── YeBang 官方代表 Logo 向量組件 (芽苗 y 標章 + 軌道環) ─────────────────────

class YeBangAppLogo extends StatelessWidget {
  final double size;
  final bool showOrbitRings;
  final bool hasShadow;
  final Color? backgroundColor;

  const YeBangAppLogo({
    super.key,
    this.size = 64,
    this.showOrbitRings = true,
    this.hasShadow = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final ringSize = size * (showOrbitRings ? 1.25 : 1.0);
    final coreSize = size;
    final leafSize = size * 0.65;

    Widget core = Container(
      width: coreSize,
      height: coreSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.white,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF9CCC65).withValues(alpha: 0.25),
                  blurRadius: size * 0.25,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: Center(
        child: CustomPaint(
          size: Size(leafSize, leafSize),
          painter: const LeafYLogoPainter(
            progress: 1.0,
            leftLeafScale: 1.0,
            rightLeafScale: 1.0,
            shimmerProgress: 0.0,
          ),
        ),
      ),
    );

    if (!showOrbitRings) return core;

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(ringSize, ringSize),
            painter: const ArcRingPainter(),
          ),
          core,
        ],
      ),
    );
  }
}

class ArcRingPainter extends CustomPainter {
  const ArcRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.024
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 弧段 1: 青藍色
    paint.color = const Color(0xFF4DD0E1).withValues(alpha: 0.85);
    canvas.drawArc(rect, 0, 1.8, false, paint);

    // 弧段 2: 綠色
    paint.color = const Color(0xFF9CCC65).withValues(alpha: 0.7);
    canvas.drawArc(rect, 2.4, 1.2, false, paint);

    // 弧段 3: 淺綠/藍綠色
    paint.color = const Color(0xFF80CBC4).withValues(alpha: 0.5);
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
    this.progress = 1.0,
    this.leftLeafScale = 1.0,
    this.rightLeafScale = 1.0,
    this.shimmerProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final Rect bounds = Rect.fromLTWH(0, 0, w, h);

    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.052
      ..strokeCap = StrokeCap.round;

    strokePaint.shader = const LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [
        Color(0xFF9CCC65),
        Color(0xFF4DD0E1),
      ],
    ).createShader(bounds);

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

    canvas.drawPath(yBodyPath, strokePaint);

    // 繪製左小葉
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
          const Color(0xFF9CCC65).withValues(alpha: 0.45 * leftLeafScale),
        ],
      ).createShader(bounds);
      canvas.drawPath(leftLeaf, fillPaint);
      canvas.drawPath(leftLeaf, strokePaint);

      final leftVein = Path();
      leftVein.moveTo(w * 0.25, h * 0.42);
      leftVein.quadraticBezierTo(w * 0.18, h * 0.37, w * 0.11, h * 0.33);

      final Paint veinPaint = Paint()
        ..shader = strokePaint.shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.028
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(leftVein, veinPaint);

      canvas.restore();
    }

    // 繪製右大葉
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
          const Color(0xFF4DD0E1).withValues(alpha: 0.45 * rightLeafScale),
        ],
      ).createShader(bounds);
      canvas.drawPath(rightLeaf, fillPaint);
      canvas.drawPath(rightLeaf, strokePaint);

      final rightVein = Path();
      rightVein.moveTo(w * 0.55, h * 0.42);
      rightVein.quadraticBezierTo(w * 0.68, h * 0.28, w * 0.82, h * 0.17);

      final Paint veinPaint = Paint()
        ..shader = strokePaint.shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.028
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(rightVein, veinPaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant LeafYLogoPainter oldDelegate) => false;
}

// ── 富文本筆記解析器（支援 Markdown 標題、粗體、清單、橫條、[color=...] 顏色標籤） ──
TextSpan buildNoteRichTextSpan(
  BuildContext context,
  String rawText, {
  bool isDark = false,
  TextStyle? baseStyle,
}) {
  final List<TextSpan> spans = [];
  final lines = rawText.split('\n');

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    TextStyle lineStyle = baseStyle ??
        TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white70 : Colors.black87,
          height: 1.71,
        );
    String content = line;
    TextSpan? prefixSpan;

    final trimmed = line.trim();

    // A. 解析水平分隔線: "---", "***", "___" (橫條效果)
    if (trimmed.length >= 3 &&
        (trimmed.replaceAll('-', '').isEmpty ||
            trimmed.replaceAll('*', '').isEmpty ||
            trimmed.replaceAll('_', '').isEmpty)) {
      spans.add(TextSpan(
        text: '───────────────────────────',
        style: lineStyle.copyWith(
          fontSize: 12,
          letterSpacing: 2.0,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white24 : const Color(0xFFBCAAA4),
        ),
      ));
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
      continue;
    }

    // B. 解析標頭: "# ", "## ", "### ", "#### "
    if (line.startsWith('# ')) {
      lineStyle = lineStyle.copyWith(
        fontSize: 18.5,
        fontWeight: FontWeight.bold,
        color: isDark ? const Color(0xFFFFCC80) : const Color(0xFF3E2723),
      );
      content = line.substring(2);
    } else if (line.startsWith('## ')) {
      lineStyle = lineStyle.copyWith(
        fontSize: 16.5,
        fontWeight: FontWeight.bold,
        color: isDark ? const Color(0xFFCE93D8) : const Color(0xFF4A148C),
      );
      content = line.substring(3);
    } else if (line.startsWith('### ')) {
      lineStyle = lineStyle.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: isDark ? const Color(0xFFB39DDB) : const Color(0xFF5D4037),
      );
      content = line.substring(4);
    } else if (line.startsWith('#### ')) {
      lineStyle = lineStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? const Color(0xFFD7CCC8) : const Color(0xFF795548),
      );
      content = line.substring(5);
    } else if (line.startsWith('> ')) {
      // C. 引用塊
      prefixSpan = TextSpan(
        text: '▎ ',
        style: TextStyle(
          color: isDark ? const Color(0xFFB39DDB) : const Color(0xFF673AB7),
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );
      lineStyle = lineStyle.copyWith(
        color: isDark ? const Color(0xFFE1BEE7) : const Color(0xFF4A148C),
        fontStyle: FontStyle.italic,
      );
      content = line.substring(2);
    } else if (line.startsWith('- [ ] ') || line.startsWith('* [ ] ')) {
      // D. 待辦清單 (未完成)
      prefixSpan = TextSpan(
        text: '☐ ',
        style: lineStyle.copyWith(
          color: isDark ? const Color(0xFFBCAAA4) : const Color(0xFF8D6E63),
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );
      content = line.substring(6);
    } else if (line.startsWith('- [x] ') ||
        line.startsWith('- [X] ') ||
        line.startsWith('* [x] ') ||
        line.startsWith('* [X] ')) {
      // D. 待辦清單 (已完成)
      prefixSpan = TextSpan(
        text: '☑ ',
        style: lineStyle.copyWith(
          color: const Color(0xFF2E7D32),
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      );
      lineStyle = lineStyle.copyWith(
        color: Colors.grey.shade500,
        decoration: TextDecoration.lineThrough,
      );
      content = line.substring(6);
    } else if (line.startsWith('- ') ||
        line.startsWith('* ') ||
        line.startsWith('+ ') ||
        line.startsWith('• ')) {
      // E. 項目清單
      prefixSpan = TextSpan(
        text: '• ',
        style: lineStyle.copyWith(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        ),
      );
      content = line.substring(2);
    }

    if (prefixSpan != null) {
      spans.add(prefixSpan);
    }

    // F. 解析行內文字：**粗體**、~~刪除線~~、`行內代碼` 與 [color=0xFF...]...[/color]
    int index = 0;
    bool isBold = false;
    bool isStrike = false;
    bool isCode = false;
    final List<Color> colorStack = [];

    while (index < content.length) {
      final int nextBold = content.indexOf('**', index);
      final int nextStrike = content.indexOf('~~', index);
      final int nextCode = content.indexOf('`', index);
      final int nextColor = content.indexOf('[color=', index);
      final int nextColorEnd = content.indexOf('[/color]', index);

      // 尋找最近的標籤位置
      int minIndex = content.length;
      String tagType = '';
      if (nextBold != -1 && nextBold < minIndex) {
        minIndex = nextBold;
        tagType = 'bold';
      }
      if (nextStrike != -1 && nextStrike < minIndex) {
        minIndex = nextStrike;
        tagType = 'strike';
      }
      if (nextCode != -1 && nextCode < minIndex) {
        minIndex = nextCode;
        tagType = 'code';
      }
      if (nextColor != -1 && nextColor < minIndex) {
        minIndex = nextColor;
        tagType = 'color';
      }
      if (nextColorEnd != -1 && nextColorEnd < minIndex) {
        minIndex = nextColorEnd;
        tagType = 'colorEnd';
      }

      if (minIndex > index) {
        final String plainText = content.substring(index, minIndex);
        TextStyle currentStyle = lineStyle;
        if (isBold) {
          currentStyle = currentStyle.copyWith(fontWeight: FontWeight.bold);
        }
        if (isStrike) {
          currentStyle =
              currentStyle.copyWith(decoration: TextDecoration.lineThrough);
        }
        if (isCode) {
          currentStyle = currentStyle.copyWith(
            fontFamily: 'monospace',
            color: isDark ? const Color(0xFFCE93D8) : const Color(0xFF4A148C),
            backgroundColor:
                isDark ? const Color(0xFF3B2D54) : const Color(0xFFEDE7F6),
          );
        }
        if (colorStack.isNotEmpty) {
          currentStyle = currentStyle.copyWith(color: colorStack.last);
        }

        spans.add(TextSpan(text: plainText, style: currentStyle));
      }

      if (minIndex == content.length) break;

      // 處理標籤本身
      if (tagType == 'bold') {
        isBold = !isBold;
        index = minIndex + 2;
      } else if (tagType == 'strike') {
        isStrike = !isStrike;
        index = minIndex + 2;
      } else if (tagType == 'code') {
        isCode = !isCode;
        index = minIndex + 1;
      } else if (tagType == 'color') {
        final int closeBracket = content.indexOf(']', minIndex);
        if (closeBracket != -1) {
          final String colorHex = content.substring(minIndex + 7, closeBracket);
          int? colorVal;
          if (colorHex.startsWith('0x') || colorHex.startsWith('0X')) {
            colorVal = int.tryParse(colorHex);
          } else if (colorHex.startsWith('#')) {
            colorVal = int.tryParse(colorHex.substring(1), radix: 16);
            if (colorVal != null && colorHex.length <= 7) {
              colorVal = 0xFF000000 | colorVal;
            }
          } else {
            colorVal = int.tryParse(colorHex);
          }
          if (colorVal != null) {
            colorStack.add(Color(colorVal));
          }
          index = closeBracket + 1;
        } else {
          spans.add(TextSpan(text: '[color=', style: lineStyle));
          index = minIndex + 7;
        }
      } else if (tagType == 'colorEnd') {
        if (colorStack.isNotEmpty) colorStack.removeLast();
        index = minIndex + 8;
      }
    }

    if (i < lines.length - 1) {
      spans.add(const TextSpan(text: '\n'));
    }
  }

  return TextSpan(children: spans);
}

/// 筆記富文本呈現 Widget
class RichNoteContentView extends StatelessWidget {
  final String content;
  final bool isDark;
  final TextStyle? baseStyle;
  final bool selectable;

  const RichNoteContentView({
    super.key,
    required this.content,
    this.isDark = false,
    this.baseStyle,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) {
      return Text(
        '（此筆記尚無純文字記錄）',
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final span = buildNoteRichTextSpan(
      context,
      content,
      isDark: isDark,
      baseStyle: baseStyle,
    );

    if (selectable) {
      return SelectableText.rich(span);
    }
    return Text.rich(span);
  }
}

// ── 社群主題 (Community Topics) 資料模型與常量 ──
class CommunityTopic {
  final String id;
  final String name; // e.g. "📐 數理邏輯"
  final String title; // e.g. "數理邏輯"
  final String emoji; // e.g. "📐"
  final Color color;
  final String description;
  final int memberCount;
  final int postCount;

  const CommunityTopic({
    required this.id,
    required this.name,
    required this.title,
    required this.emoji,
    required this.color,
    required this.description,
    this.memberCount = 156,
    this.postCount = 42,
  });
}

const List<CommunityTopic> kCommunityTopics = [
  CommunityTopic(
    id: 'topic_math',
    name: '📐 數理邏輯',
    title: '數理邏輯',
    emoji: '📐',
    color: Color(0xFF1E88E5),
    description: '探討數學解題、理化實驗與邏輯思維技巧',
    memberCount: 238,
    postCount: 64,
  ),
  CommunityTopic(
    id: 'topic_science',
    name: '🔬 自然科學',
    title: '自然科學',
    emoji: '🔬',
    color: Color(0xFF00897B),
    description: '探索生物演化、地球科學與宇宙科普新知',
    memberCount: 185,
    postCount: 48,
  ),
  CommunityTopic(
    id: 'topic_literature',
    name: '📚 國文文學',
    title: '國文文學',
    emoji: '📚',
    color: Color(0xFF6D4C41),
    description: '古文賞析、現代文學閱讀心得與寫作技巧',
    memberCount: 192,
    postCount: 51,
  ),
  CommunityTopic(
    id: 'topic_social',
    name: '🌍 社會人文',
    title: '社會人文',
    emoji: '🌍',
    color: Color(0xFFE65100),
    description: '歷史脈絡梳理、地理人文與公民社會思辨',
    memberCount: 147,
    postCount: 39,
  ),
  CommunityTopic(
    id: 'topic_ai',
    name: '💡 AI 與科技',
    title: 'AI 與科技',
    emoji: '💡',
    color: Color(0xFF7B1FA2),
    description: '人工智慧輔助學習、程式設計與未來科技',
    memberCount: 312,
    postCount: 88,
  ),
  CommunityTopic(
    id: 'topic_english',
    name: '🇬🇧 英語外語',
    title: '英語外語',
    emoji: '🇬🇧',
    color: Color(0xFF0288D1),
    description: '單字文法、聽力口說練習與多益檢定衝刺',
    memberCount: 265,
    postCount: 73,
  ),
  CommunityTopic(
    id: 'topic_exam',
    name: '🎯 備考衝刺',
    title: '備考衝刺',
    emoji: '🎯',
    color: Color(0xFFC2185B),
    description: '學測分科會考倒數、歷屆試題與錯題複習筆記',
    memberCount: 290,
    postCount: 95,
  ),
  CommunityTopic(
    id: 'topic_daily',
    name: '☕ 學習日常',
    title: '學習日常',
    emoji: '☕',
    color: Color(0xFFF57C00),
    description: '讀書打卡、番茄鐘專注心得與學習心情交流',
    memberCount: 340,
    postCount: 110,
  ),
  CommunityTopic(
    id: 'topic_creative',
    name: '🎨 手寫圖文',
    title: '手寫圖文',
    emoji: '🎨',
    color: Color(0xFF512DA8),
    description: '手寫筆記排版、精美塗鴉與視覺化心智圖分享',
    memberCount: 215,
    postCount: 59,
  ),
];

CommunityTopic? getCommunityTopicById(String id) {
  try {
    return kCommunityTopics.firstWhere(
      (t) => t.id == id || t.name == id || t.title == id,
    );
  } catch (_) {
    return null;
  }
}
