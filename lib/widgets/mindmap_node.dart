import 'package:flutter/material.dart';

// ============================================================
// 心智圖節點資料模型
// ============================================================
class MindMapNode {
  final String id;
  final String label;
  final Color color;
  final List<MindMapNode> children;
  bool isExpanded;

  // 佈局計算（由 MindMapPainter 填入）
  Offset position = Offset.zero;
  Size size = const Size(140, 46);
  double subtreeHeight = 0;

  MindMapNode({
    required this.id,
    required this.label,
    required this.color,
    List<MindMapNode>? children,
    this.isExpanded = true,
  }) : children = children ?? [];

  // ─── JSON 解析 ───
  factory MindMapNode.fromJson(Map<String, dynamic> json) {
    final colorHex = (json['color'] as String?) ?? '#673AB7';
    final children = (json['children'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((c) => MindMapNode.fromJson(c))
            .toList() ??
        [];
    return MindMapNode(
      id: json['id'] as String? ?? 'node_${json.hashCode}',
      label: json['label'] as String? ?? '',
      color: _parseColor(colorHex),
      children: children,
    );
  }

  // ─── 從 key_points 自動生成兩層心智圖（降級顯示用）───
  static MindMapNode fromKeyPoints(String rootLabel, List<String> keyPoints) {
    final palette = [
      const Color(0xFF673AB7),
      const Color(0xFF3F51B5),
      const Color(0xFF2196F3),
      const Color(0xFF009688),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF795548),
    ];
    final children = keyPoints.asMap().entries.map((e) {
      return MindMapNode(
        id: 'kp_${e.key}',
        label: e.value,
        color: palette[e.key % palette.length],
      );
    }).toList();
    return MindMapNode(
      id: 'root',
      label: rootLabel,
      color: const Color(0xFF673AB7),
      children: children,
    );
  }

  // ─── 輔助：解析 hex color ───
  static Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '').trim();
    try {
      if (cleaned.length == 6) {
        return Color(int.parse('FF$cleaned', radix: 16));
      } else if (cleaned.length == 8) {
        return Color(int.parse(cleaned, radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF673AB7);
  }

  // ─── 遞迴收集所有可見節點 ───
  List<MindMapNode> get allVisibleNodes {
    final result = <MindMapNode>[this];
    if (isExpanded) {
      for (final child in children) {
        result.addAll(child.allVisibleNodes);
      }
    }
    return result;
  }
}
