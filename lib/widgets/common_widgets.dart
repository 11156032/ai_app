import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:typed_data';
import '../services/app_locale_service.dart';

// 預設插圖頭像（emoji 角色 + 背景色）
List<Map<String, dynamic>> get kPresetAvatars => [
  {'emoji': '😊', 'color': Color(0xFFA1887F), 'label': tr('avatar_happy')}, // 預設暖棕
  {'emoji': '🐱', 'color': Color(0xFFFFAB91), 'label': tr('avatar_cat')},
  {'emoji': '🐶', 'color': Color(0xFFA5D6A7), 'label': tr('avatar_dog')},
  {'emoji': '🦊', 'color': Color(0xFFFFCC80), 'label': tr('avatar_fox')},
  {'emoji': '🐼', 'color': Color(0xFF90A4AE), 'label': tr('avatar_panda')},
  {'emoji': '🦁', 'color': Color(0xFFFFF176), 'label': tr('avatar_lion')},
  {'emoji': '🐸', 'color': Color(0xFF80CBC4), 'label': tr('avatar_frog')},
  {'emoji': '🐧', 'color': Color(0xFF90CAF9), 'label': tr('avatar_penguin')},
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
    if (diff.inSeconds < 60) return tr('time_just_now');
    if (diff.inMinutes < 60) return tr('time_min_ago', [diff.inMinutes.toString()]);
    if (diff.inHours < 24) return tr('time_hour_ago', [diff.inHours.toString()]);
    if (diff.inDays < 30) return tr('time_day_ago', [diff.inDays.toString()]);
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

class YeBangAppLogo extends StatefulWidget {
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
  State<YeBangAppLogo> createState() => _YeBangAppLogoState();
}

class _YeBangAppLogoState extends State<YeBangAppLogo>
    with SingleTickerProviderStateMixin {
  AnimationController? _orbitController;

  @override
  void initState() {
    super.initState();
    final bool isInTest = WidgetsBinding.instance.runtimeType
        .toString()
        .toLowerCase()
        .contains('test');

    if (widget.showOrbitRings) {
      _orbitController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 8),
      );
      if (!isInTest) _orbitController!.repeat();
    }
  }

  @override
  void dispose() {
    _orbitController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringSize = widget.size * (widget.showOrbitRings ? 1.32 : 1.0);
    final coreSize = widget.size;
    final leafSize = widget.size * 0.70;

    Widget imageWidget = Image.asset(
      'assets/app_logo.png',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Center(
        child: Icon(
          Icons.eco_rounded,
          size: leafSize,
          color: const Color(0xFF9CCC65),
        ),
      ),
    );

    Widget core = Container(
      width: coreSize,
      height: coreSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.backgroundColor ?? Colors.white,
        boxShadow: widget.hasShadow
            ? [
                BoxShadow(
                  color: const Color(0xFF4DD0E1).withValues(alpha: 0.20),
                  blurRadius: widget.size * 0.22,
                  offset: Offset(0, widget.size * 0.06),
                ),
                BoxShadow(
                  color: const Color(0xFF9CCC65).withValues(alpha: 0.18),
                  blurRadius: widget.size * 0.14,
                  offset: Offset(0, widget.size * 0.03),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: imageWidget,
      ),
    );

    if (!widget.showOrbitRings) return core;

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 柔和外光暈
          Container(
            width: ringSize * 0.95,
            height: ringSize * 0.95,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF4DD0E1).withValues(alpha: 0.12),
                  const Color(0xFF9CCC65).withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // 旋轉外軌道環
          if (_orbitController != null)
            AnimatedBuilder(
              animation: _orbitController!,
              builder: (_, child) {
                return Transform.rotate(
                  angle: _orbitController!.value * 6.28318,
                  child: child,
                );
              },
              child: CustomPaint(
                size: Size(ringSize, ringSize),
                painter: const ArcRingPainter(),
              ),
            )
          else
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
      ..strokeWidth = (size.width * 0.026).clamp(2.0, 3.5)
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 弧段 1: 青藍色漸變
    paint.color = const Color(0xFF00E5FF).withValues(alpha: 0.85);
    canvas.drawArc(rect, 0, 1.9, false, paint);

    // 弧段 2: 嫩綠色漸變
    paint.color = const Color(0xFF76FF03).withValues(alpha: 0.75);
    canvas.drawArc(rect, 2.5, 1.3, false, paint);

    // 弧段 3: 藍綠色光點
    paint.color = const Color(0xFF00BFA5).withValues(alpha: 0.6);
    canvas.drawArc(rect, 4.3, 0.7, false, paint);
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

/// 筆記富文本呈現 Widget（完整支援 Markdown 表格、區塊標註、對比表與結構排版）
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
        tr('note_no_text'),
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final theme = Theme.of(context);
    final textColor = isDark ? Colors.white70 : const Color(0xFF2C2523);

    return MarkdownBody(
      data: content,
      selectable: selectable,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        h1: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF3E2723),
          height: 1.5,
        ),
        h2: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFB388FF) : const Color(0xFF4A148C),
          height: 1.5,
        ),
        h3: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFD7CCC8) : const Color(0xFF5D4037),
        ),
        p: TextStyle(
          fontSize: (baseStyle?.fontSize ?? 14.0),
          height: 1.65,
          color: textColor,
        ),
        tableHead: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF3E2723),
          fontSize: 13,
        ),
        tableBody: TextStyle(
          color: textColor,
          fontSize: 12.5,
        ),
        tableBorder: TableBorder.all(
          color: isDark ? Colors.white24 : const Color(0xFFD7CCC8),
          width: 1,
        ),
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        tableColumnWidth: const IntrinsicColumnWidth(),
        blockquoteDecoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF311B92).withValues(alpha: 0.3)
              : const Color(0xFFF3E5F5).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isDark ? const Color(0xFFB388FF) : const Color(0xFF673AB7),
              width: 3.5,
            ),
          ),
        ),
        codeblockDecoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFF2E2A27),
          borderRadius: BorderRadius.circular(8),
        ),
        code: TextStyle(
          backgroundColor: isDark
              ? const Color(0xFF4527A0).withValues(alpha: 0.3)
              : const Color(0xFFEDE7F6),
          color: isDark ? const Color(0xFFD1C4E9) : const Color(0xFF4A148C),
          fontSize: 12.5,
        ),
        listBullet: TextStyle(
          color: isDark ? const Color(0xFFB388FF) : const Color(0xFF4A148C),
        ),
      ),
    );
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
    this.memberCount = 0,
    this.postCount = 0,
  });
}

List<CommunityTopic> get kCommunityTopics => [
  CommunityTopic(
    id: 'topic_math',
    name: tr('topic_math_name'),
    title: tr('topic_math_title'),
    emoji: '📐',
    color: Color(0xFF1E88E5),
    description: tr('topic_math_desc'),
  ),
  CommunityTopic(
    id: 'topic_science',
    name: tr('topic_sci_name'),
    title: tr('topic_sci_title'),
    emoji: '🔬',
    color: Color(0xFF00897B),
    description: tr('topic_sci_desc'),
  ),
  CommunityTopic(
    id: 'topic_literature',
    name: tr('topic_lit_name'),
    title: tr('topic_lit_title'),
    emoji: '📚',
    color: Color(0xFF6D4C41),
    description: tr('topic_lit_desc'),
  ),
  CommunityTopic(
    id: 'topic_social',
    name: tr('topic_soc_name'),
    title: tr('topic_soc_title'),
    emoji: '🌍',
    color: Color(0xFFE65100),
    description: tr('topic_soc_desc'),
  ),
  CommunityTopic(
    id: 'topic_ai',
    name: tr('topic_ai_name'),
    title: tr('topic_ai_title'),
    emoji: '💡',
    color: Color(0xFF7B1FA2),
    description: tr('topic_ai_desc'),
  ),
  CommunityTopic(
    id: 'topic_english',
    name: tr('topic_en_name'),
    title: tr('topic_en_title'),
    emoji: '🇬🇧',
    color: Color(0xFF0288D1),
    description: tr('topic_en_desc'),
  ),
  CommunityTopic(
    id: 'topic_exam',
    name: tr('topic_exam_name'),
    title: tr('topic_exam_title'),
    emoji: '🎯',
    color: Color(0xFFC2185B),
    description: tr('topic_exam_desc'),
  ),
  CommunityTopic(
    id: 'topic_daily',
    name: tr('topic_daily_name'),
    title: tr('topic_daily_title'),
    emoji: '☕',
    color: Color(0xFFF57C00),
    description: tr('topic_daily_desc'),
  ),
  CommunityTopic(
    id: 'topic_creative',
    name: tr('topic_notes_name'),
    title: tr('topic_notes_title'),
    emoji: '📝',
    color: Color(0xFF512DA8),
    description: tr('topic_notes_desc'),
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

/// 將歡迎頁面向 ID 映射為標準 9 大社群 ID (防止 topic_coding 等不存在的 ID 出現於社群選單中)
String normalizeCommunityTopicId(String id) {
  switch (id) {
    case 'topic_physics':
    case 'topic_chemistry':
    case 'topic_biology':
    case 'topic_science':
      return 'topic_science';
    case 'topic_history':
    case 'topic_social':
      return 'topic_social';
    case 'topic_coding':
    case 'topic_tech':
    case 'topic_ai':
      return 'topic_ai';
    case 'topic_toeic':
    case 'topic_english':
      return 'topic_english';
    case 'topic_math':
      return 'topic_math';
    case 'topic_literature':
      return 'topic_literature';
    case 'topic_exam':
      return 'topic_exam';
    case 'topic_daily':
      return 'topic_daily';
    case 'topic_creative':
      return 'topic_creative';
    default:
      if (kCommunityTopics.any((t) => t.id == id)) return id;
      return 'topic_ai';
  }
}

/// 批次標準化社群 ID 列表並去重
List<String> normalizeCommunityTopicIds(Iterable<String> ids) {
  final normalized = <String>{};
  for (final id in ids) {
    normalized.add(normalizeCommunityTopicId(id));
  }
  return normalized.toList();
}

/// 全局輕量化快顯提示（確保收起速度靈敏，不阻塞畫面）
void showAppPrompt(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 1500),
  Color? backgroundColor,
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      backgroundColor: backgroundColor,
      action: action,
    ),
  );
}

extension FastPromptExtension on BuildContext {
  void showPrompt(
    String message, {
    Duration duration = const Duration(milliseconds: 1500),
    Color? backgroundColor,
    SnackBarAction? action,
  }) {
    showAppPrompt(
      this,
      message,
      duration: duration,
      backgroundColor: backgroundColor,
      action: action,
    );
  }
}
