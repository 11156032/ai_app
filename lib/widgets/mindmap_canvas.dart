import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'mindmap_node.dart';

// ============================================================
// 心智圖全螢幕橫向/直向檢視頁面 (FullscreenMindMapView)
// ============================================================
class FullscreenMindMapView extends StatefulWidget {
  final MindMapNode root;
  final String title;

  const FullscreenMindMapView({
    super.key,
    required this.root,
    this.title = '心智圖全螢幕檢視',
  });

  static Future<void> open(
    BuildContext context, {
    required MindMapNode root,
    String title = '心智圖全螢幕檢視',
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullscreenMindMapView(root: root, title: title),
      ),
    );
  }

  @override
  State<FullscreenMindMapView> createState() => _FullscreenMindMapViewState();
}

class _FullscreenMindMapViewState extends State<FullscreenMindMapView> {
  bool _isLandscapeForced = false;

  @override
  void initState() {
    super.initState();
    // 進入全螢幕時，全面解鎖四向旋轉（支援直接將手機轉為橫向瀏覽）
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // 離開全螢幕時，恢復預設直向模式
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  /// 一鍵切換橫向寬螢幕 / 直向模式
  void _toggleOrientation() {
    setState(() {
      _isLandscapeForced = !_isLandscapeForced;
      if (_isLandscapeForced) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeRight,
          DeviceOrientation.landscapeLeft,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F5),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF4A148C),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '關閉全螢幕',
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isLandscapeForced
                  ? Icons.stay_current_portrait_rounded
                  : Icons.stay_current_landscape_rounded,
            ),
            onPressed: _toggleOrientation,
            tooltip: _isLandscapeForced ? '切換為直向' : '切換為橫向寬螢幕',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: InteractiveMindMapView(
          root: widget.root,
          showRotateButton: true,
          onRotate: _toggleOrientation,
        ),
      ),
    );
  }
}

// ============================================================
// 心智圖互動畫布元件
// ============================================================
class InteractiveMindMapView extends StatefulWidget {
  final MindMapNode root;
  final bool showRotateButton;
  final VoidCallback? onRotate;

  const InteractiveMindMapView({
    super.key,
    required this.root,
    this.showRotateButton = false,
    this.onRotate,
  });

  @override
  State<InteractiveMindMapView> createState() => _InteractiveMindMapViewState();
}

class _InteractiveMindMapViewState extends State<InteractiveMindMapView> {
  final TransformationController _transformController = TransformationController();
  late MindMapNode _root;
  Size? _lastViewportSize;

  @override
  void initState() {
    super.initState();
    _root = widget.root;
  }

  @override
  void didUpdateWidget(InteractiveMindMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.root != widget.root) {
      setState(() => _root = widget.root);
      if (_lastViewportSize != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _lastViewportSize != null) {
            _centerView(_lastViewportSize!);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  /// 計算最適合目前可視區域（Viewport）的縮放與置中矩陣
  void _centerView(Size viewportSize) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return;

    // 計算心智圖在畫布中的整體幾何邊界
    final bounds = MindMapPainter.computeTreeBounds(
      _root,
      MindMapPainter.kStartX,
      MindMapPainter.kCanvasHeight / 2,
    );
    final treeWidth = bounds.width;
    final treeHeight = bounds.height;

    // 依可視區域大小計算最舒適的縮放比 (兼顧手機小螢幕與全螢幕檢視)
    final scaleX = (viewportSize.width - 48) / math.max(1.0, treeWidth);
    final scaleY = (viewportSize.height - 48) / math.max(1.0, treeHeight);
    final double scale = math.min(scaleX, scaleY).clamp(0.65, 1.05);

    double dx;
    // 若縮放後能完整納入視窗則水平置中，否則靠左預留 24px 邊距以利閱讀主節點
    if (treeWidth * scale <= viewportSize.width - 48) {
      dx = (viewportSize.width - (treeWidth * scale)) / 2 - (bounds.left * scale);
    } else {
      dx = 24.0 - (bounds.left * scale);
    }

    // 垂直精準置中
    final dy = (viewportSize.height / 2) - (bounds.center.dy * scale);

    _transformController.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0.0, 1.0)
      ..scaleByDouble(scale, scale, scale, 1.0);
  }

  /// 依視窗中心平滑縮放
  void _zoom(double factor) {
    if (_lastViewportSize == null) return;
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(0.3, 2.5);

    final center = Offset(_lastViewportSize!.width / 2, _lastViewportSize!.height / 2);
    final scenePoint = _transformController.toScene(center);

    final matrix = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0.0, 1.0)
      ..scaleByDouble(targetScale, targetScale, targetScale, 1.0)
      ..translateByDouble(-scenePoint.dx, -scenePoint.dy, 0.0, 1.0);

    _transformController.value = matrix;
  }

  void _onNodeTap(MindMapNode node) {
    if (node.children.isNotEmpty) {
      setState(() => node.isExpanded = !node.isExpanded);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final currentSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastViewportSize != currentSize &&
            currentSize.width > 0 &&
            currentSize.height > 0) {
          _lastViewportSize = currentSize;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _centerView(currentSize);
          });
        }

        return Stack(
          children: [
            // 主畫布
            InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.25,
              maxScale: 2.8,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(400),
              child: SizedBox(
                width: MindMapPainter.kCanvasWidth,
                height: MindMapPainter.kCanvasHeight,
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

            // 浮動工具欄 (右上或右下)
            Positioned(
              right: 12,
              bottom: 12,
              child: _buildToolbar(),
            ),
          ],
        );
      },
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
            onPressed: () => _zoom(1.2),
            tooltip: '放大',
            color: const Color(0xFF4A148C),
          ),
          Container(height: 1, color: Colors.grey.shade200),
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 20),
            onPressed: () => _zoom(0.8),
            tooltip: '縮小',
            color: const Color(0xFF4A148C),
          ),
          Container(height: 1, color: Colors.grey.shade200),
          IconButton(
            icon: const Icon(Icons.center_focus_strong_rounded, size: 20),
            onPressed: () {
              if (_lastViewportSize != null) {
                _centerView(_lastViewportSize!);
              }
            },
            tooltip: '回到中心',
            color: const Color(0xFF4A148C),
          ),
          if (widget.showRotateButton && widget.onRotate != null) ...[
            Container(height: 1, color: Colors.grey.shade200),
            IconButton(
              icon: const Icon(Icons.screen_rotation_rounded, size: 20),
              onPressed: widget.onRotate,
              tooltip: '旋轉螢幕 / 橫向檢視',
              color: const Color(0xFF4A148C),
            ),
          ],
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

  static const double kCanvasWidth = 1600.0;
  static const double kCanvasHeight = 1000.0;
  static const double kStartX = 40.0;
  static const double kNodeWidth = 136.0;
  static const double kNodeHeight = 44.0;
  static const double kHGap = 56.0;
  static const double kVGap = 18.0;

  MindMapPainter({required this.root, required this.onNodeTap});

  /// 靜態輔助：計算樹狀圖幾何包圍盒
  static Rect computeTreeBounds(MindMapNode root, double startX, double centerY) {
    _layoutSubtree(root, startX, centerY);
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    void traverse(MindMapNode node) {
      if (node.position.dx < minX) minX = node.position.dx;
      if (node.position.dy < minY) minY = node.position.dy;
      if (node.position.dx + kNodeWidth > maxX) maxX = node.position.dx + kNodeWidth;
      if (node.position.dy + kNodeHeight > maxY) maxY = node.position.dy + kNodeHeight;

      if (node.isExpanded) {
        for (final child in node.children) {
          traverse(child);
        }
      }
    }

    traverse(root);
    if (minX == double.infinity) {
      return Rect.fromLTWH(startX, centerY - kNodeHeight / 2, kNodeWidth, kNodeHeight);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static double _layoutSubtree(MindMapNode node, double x, double centerY) {
    node.position = Offset(x, centerY - kNodeHeight / 2);

    if (!node.isExpanded || node.children.isEmpty) {
      node.subtreeHeight = kNodeHeight;
      return kNodeHeight;
    }

    double totalChildrenHeight = 0;
    for (final child in node.children) {
      totalChildrenHeight += _estimateSubtreeHeight(child) + kVGap;
    }
    totalChildrenHeight -= kVGap;
    node.subtreeHeight = math.max(kNodeHeight, totalChildrenHeight);

    double childY = centerY - totalChildrenHeight / 2;
    for (final child in node.children) {
      final childH = _estimateSubtreeHeight(child);
      _layoutSubtree(child, x + kNodeWidth + kHGap, childY + childH / 2);
      childY += childH + kVGap;
    }
    return node.subtreeHeight;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _layoutSubtree(root, kStartX, size.height / 2);
    _drawConnections(canvas, root);
    _drawNodes(canvas, root);
  }

  static double _estimateSubtreeHeight(MindMapNode node) {
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
