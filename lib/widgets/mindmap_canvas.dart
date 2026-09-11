import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'mindmap_node.dart';

// ============================================================
// 心智圖互動畫布元件
// ============================================================
class InteractiveMindMapView extends StatefulWidget {
  final MindMapNode root;

  const InteractiveMindMapView({super.key, required this.root});

  @override
  State<InteractiveMindMapView> createState() => _InteractiveMindMapViewState();
}

class _InteractiveMindMapViewState extends State<InteractiveMindMapView> {
  final TransformationController _transformController = TransformationController();
  late MindMapNode _root;

  @override
  void initState() {
    super.initState();
    _root = widget.root;
    // 預設縮放置中
    WidgetsBinding.instance.addPostFrameCallback((_) => _resetView());
  }

  @override
  void didUpdateWidget(InteractiveMindMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.root != widget.root) {
      setState(() => _root = widget.root);
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetView() {
    _transformController.value = Matrix4.identity()
      ..translateByDouble(40.0, 0.0, 0.0, 1.0);
  }

  void _onNodeTap(MindMapNode node) {
    if (node.children.isNotEmpty) {
      setState(() => node.isExpanded = !node.isExpanded);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 主畫布
        InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.3,
          maxScale: 2.5,
          constrained: false,
          child: SizedBox(
            width: 1400,
            height: 900,
            child: CustomPaint(
              painter: MindMapPainter(
                root: _root,
                onNodeTap: _onNodeTap,
              ),
              child: _MindMapGestureLayer(
                root: _root,
                transformController: _transformController,
                onNodeTap: _onNodeTap,
              ),
            ),
          ),
        ),

        // 浮動工具欄
        Positioned(
          right: 12,
          bottom: 12,
          child: _buildToolbar(),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 20),
            onPressed: () {
              final m = _transformController.value.clone();
              m.scaleByDouble(1.2, 1.2, 1.2, 1.0);
              _transformController.value = m;
            },
            tooltip: '放大',
            color: const Color(0xFF4A148C),
          ),
          Container(height: 1, color: Colors.grey.shade200),
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 20),
            onPressed: () {
              final m = _transformController.value.clone();
              m.scaleByDouble(0.8, 0.8, 0.8, 1.0);
              _transformController.value = m;
            },
            tooltip: '縮小',
            color: const Color(0xFF4A148C),
          ),
          Container(height: 1, color: Colors.grey.shade200),
          IconButton(
            icon: const Icon(Icons.center_focus_strong_rounded, size: 20),
            onPressed: _resetView,
            tooltip: '回到中心',
            color: const Color(0xFF4A148C),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 心智圖 CustomPainter
// ============================================================
class MindMapPainter extends CustomPainter {
  final MindMapNode root;
  final void Function(MindMapNode) onNodeTap;

  static const double kNodeWidth = 130.0;
  static const double kNodeHeight = 44.0;
  static const double kHGap = 60.0;
  static const double kVGap = 20.0;

  MindMapPainter({required this.root, required this.onNodeTap});

  @override
  void paint(Canvas canvas, Size size) {
    _computeLayout(root, 0, size.height / 2);
    _drawConnections(canvas, root);
    _drawNodes(canvas, root);
  }

  // ─── 計算節點佈局位置 ───
  double _computeLayout(MindMapNode node, double x, double centerY) {
    node.position = Offset(x, centerY - kNodeHeight / 2);

    if (!node.isExpanded || node.children.isEmpty) {
      node.subtreeHeight = kNodeHeight;
      return kNodeHeight;
    }

    double totalChildrenHeight = 0;
    for (final child in node.children) {
      totalChildrenHeight +=
          _estimateSubtreeHeight(child) + kVGap;
    }
    totalChildrenHeight -= kVGap;
    node.subtreeHeight = math.max(kNodeHeight, totalChildrenHeight);

    double childY = centerY - totalChildrenHeight / 2;
    for (final child in node.children) {
      final childH = _estimateSubtreeHeight(child);
      _computeLayout(child, x + kNodeWidth + kHGap, childY + childH / 2);
      childY += childH + kVGap;
    }
    return node.subtreeHeight;
  }

  double _estimateSubtreeHeight(MindMapNode node) {
    if (!node.isExpanded || node.children.isEmpty) return kNodeHeight;
    double total = 0;
    for (final c in node.children) {
      total += _estimateSubtreeHeight(c) + kVGap;
    }
    return math.max(kNodeHeight, total - kVGap);
  }

  // ─── 繪製連接線（S 型三次貝茲曲線） ───
  void _drawConnections(Canvas canvas, MindMapNode parent) {
    if (!parent.isExpanded) return;
    for (final child in parent.children) {
      final p1 = Offset(
        parent.position.dx + kNodeWidth,
        parent.position.dy + kNodeHeight / 2,
      );
      final p2 = Offset(
        child.position.dx,
        child.position.dy + kNodeHeight / 2,
      );
      final midX = (p1.dx + p2.dx) / 2;
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(midX, p1.dy, midX, p2.dy, p2.dx, p2.dy);

      canvas.drawPath(
        path,
        Paint()
          ..color = child.color.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );

      _drawConnections(canvas, child);
    }
  }

  // ─── 繪製節點 ───
  void _drawNodes(Canvas canvas, MindMapNode node) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          node.position.dx, node.position.dy, kNodeWidth, kNodeHeight),
      const Radius.circular(10),
    );

    // 白底 + 陰影
    canvas.drawRRect(
      rect,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = Colors.white,
    );

    // 左側彩色 accent bar
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(node.position.dx, node.position.dy, 4, kNodeHeight),
        topLeft: const Radius.circular(10),
        bottomLeft: const Radius.circular(10),
      ),
      Paint()..color = node.color,
    );

    // 文字
    final tp = TextPainter(
      text: TextSpan(
        text: node.label.length > 14
            ? '${node.label.substring(0, 13)}…'
            : node.label,
        style: TextStyle(
          color: const Color(0xFF2C2523),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: kNodeWidth - 14);
    tp.paint(
        canvas,
        Offset(node.position.dx + 10,
            node.position.dy + (kNodeHeight - tp.height) / 2));

    // 折疊/展開圓點（有子節點才顯示）
    if (node.children.isNotEmpty) {
      final dotCenter = Offset(
        node.position.dx + kNodeWidth - 10,
        node.position.dy + kNodeHeight / 2,
      );
      canvas.drawCircle(
        dotCenter,
        6,
        Paint()..color = node.color.withValues(alpha: 0.15),
      );
      canvas.drawCircle(
        dotCenter,
        6,
        Paint()
          ..color = node.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // + / - 符號
      final icon = node.isExpanded ? '−' : '+';
      final iconTp = TextPainter(
        text: TextSpan(
          text: icon,
          style: TextStyle(
              color: node.color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconTp.paint(canvas,
          dotCenter - Offset(iconTp.width / 2, iconTp.height / 2));
    }

    // 遞迴繪製子節點
    if (node.isExpanded) {
      for (final child in node.children) {
        _drawNodes(canvas, child);
      }
    }
  }

  @override
  bool shouldRepaint(MindMapPainter oldDelegate) => true;
}

// ============================================================
// 手勢層（處理節點點選）
// ============================================================
class _MindMapGestureLayer extends StatelessWidget {
  final MindMapNode root;
  final TransformationController transformController;
  final void Function(MindMapNode) onNodeTap;

  const _MindMapGestureLayer({
    required this.root,
    required this.transformController,
    required this.onNodeTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (details) {
        final local = transformController.toScene(details.localPosition);
        _hitTest(root, local);
      },
      child: const SizedBox.expand(),
    );
  }

  void _hitTest(MindMapNode node, Offset tap) {
    final rect = Rect.fromLTWH(
      node.position.dx,
      node.position.dy,
      MindMapPainter.kNodeWidth,
      MindMapPainter.kNodeHeight,
    );
    if (rect.contains(tap)) {
      onNodeTap(node);
      return;
    }
    if (node.isExpanded) {
      for (final child in node.children) {
        _hitTest(child, tap);
      }
    }
  }
}
