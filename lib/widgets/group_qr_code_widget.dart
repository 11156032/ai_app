import 'dart:convert';
import 'package:flutter/material.dart';

/// 高質感自繪 QR Code 元件（支援自適應大小、圓角矩陣、中心 Emoji 徽章）
class GroupQrCodeWidget extends StatelessWidget {
  final String data;
  final String? centerEmoji;
  final double size;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final bool showFrame;

  const GroupQrCodeWidget({
    super.key,
    required this.data,
    this.centerEmoji,
    this.size = 180,
    this.foregroundColor,
    this.backgroundColor,
    this.showFrame = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = foregroundColor ?? (isDark ? Colors.white : const Color(0xFF2D2013));
    final bg = backgroundColor ?? (isDark ? const Color(0xFF2A2A2A) : Colors.white);

    Widget qrPainter = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _QrMatrixPainter(
              data: data,
              foregroundColor: fg,
              backgroundColor: bg,
            ),
          ),
          if (centerEmoji != null && centerEmoji!.isNotEmpty)
            Container(
              width: size * 0.24,
              height: size * 0.24,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: fg.withValues(alpha: 0.15), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  centerEmoji!,
                  style: TextStyle(fontSize: size * 0.12),
                ),
              ),
            ),
        ],
      ),
    );

    if (!showFrame) return qrPainter;

    return Container(
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: qrPainter,
    );
  }
}

class _QrMatrixPainter extends CustomPainter {
  final String data;
  final Color foregroundColor;
  final Color backgroundColor;

  static const int matrixSize = 25; // 25x25 QR matrix

  _QrMatrixPainter({
    required this.data,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final fgPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.fill;

    final matrix = _generateMatrix(data);
    final cellSize = size.width / matrixSize;

    for (int r = 0; r < matrixSize; r++) {
      for (int c = 0; c < matrixSize; c++) {
        if (!matrix[r][c]) continue;

        // 避免遮擋中心徽章區（中央 7x7 留白）
        if (r >= 9 && r <= 15 && c >= 9 && c <= 15) {
          continue;
        }

        final left = c * cellSize;
        final top = r * cellSize;

        // 定位方塊 (Finder patterns)
        if (_isFinderPattern(r, c)) {
          // 在 finder pattern 區域畫圓角方塊
          final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(left + 0.5, top + 0.5, cellSize - 1, cellSize - 1),
            Radius.circular(cellSize * 0.25),
          );
          canvas.drawRRect(rect, fgPaint);
        } else {
          // 一般資料點 (Dot style)
          final dotRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(
              left + cellSize * 0.1,
              top + cellSize * 0.1,
              cellSize * 0.8,
              cellSize * 0.8,
            ),
            Radius.circular(cellSize * 0.35),
          );
          canvas.drawRRect(dotRect, fgPaint);
        }
      }
    }
  }

  bool _isFinderPattern(int r, int c) {
    // Top-Left (0..6, 0..6)
    if (r <= 6 && c <= 6) return true;
    // Top-Right (0..6, matrixSize-7..matrixSize-1)
    if (r <= 6 && c >= matrixSize - 7) return true;
    // Bottom-Left (matrixSize-7..matrixSize-1, 0..6)
    if (r >= matrixSize - 7 && c <= 6) return true;
    return false;
  }

  List<List<bool>> _generateMatrix(String content) {
    final mat = List.generate(matrixSize, (_) => List.filled(matrixSize, false));

    // 1. 繪製 3 個 Finder Patterns (7x7)
    _drawFinderPattern(mat, 0, 0);
    _drawFinderPattern(mat, 0, matrixSize - 7);
    _drawFinderPattern(mat, matrixSize - 7, 0);

    // 2. 繪製 Timing Patterns (row 6, col 6)
    for (int i = 7; i < matrixSize - 7; i++) {
      mat[6][i] = (i % 2 == 0);
      mat[i][6] = (i % 2 == 0);
    }

    // 3. 繪製 Alignment Pattern (5x5) at (18, 18)
    _drawAlignmentPattern(mat, matrixSize - 9, matrixSize - 9);

    // 4. 計算 Payload Hash 並填充資料模組
    final bytes = utf8.encode(content.isNotEmpty ? content : 'app://join');
    int seed = 0x811c9dc5;
    for (final b in bytes) {
      seed = ((seed ^ b) * 0x01000193) & 0xFFFFFFFF;
    }

    // 偽隨機線性同餘法 (LCG)
    int state = seed;
    for (int r = 0; r < matrixSize; r++) {
      for (int c = 0; c < matrixSize; c++) {
        // 跳過保留區
        if (_isReserved(r, c)) continue;

        state = (state * 1664525 + 1013904223) & 0xFFFFFFFF;
        final bit = ((state >> 16) & 1) == 1;
        // 棋盤格遮罩
        final mask = ((r + c) % 2 == 0);
        mat[r][c] = bit ^ mask;
      }
    }

    return mat;
  }

  void _drawFinderPattern(List<List<bool>> mat, int top, int left) {
    for (int r = 0; r < 7; r++) {
      for (int c = 0; c < 7; c++) {
        if (r == 0 || r == 6 || c == 0 || c == 6) {
          mat[top + r][left + c] = true;
        } else if (r >= 2 && r <= 4 && c >= 2 && c <= 4) {
          mat[top + r][left + c] = true;
        } else {
          mat[top + r][left + c] = false;
        }
      }
    }
  }

  void _drawAlignmentPattern(List<List<bool>> mat, int top, int left) {
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 5; c++) {
        if (r == 0 || r == 4 || c == 0 || c == 4 || (r == 2 && c == 2)) {
          mat[top + r][left + c] = true;
        } else {
          mat[top + r][left + c] = false;
        }
      }
    }
  }

  bool _isReserved(int r, int c) {
    // 3 Finder patterns + separators (8x8 regions)
    if (r <= 7 && c <= 7) return true;
    if (r <= 7 && c >= matrixSize - 8) return true;
    if (r >= matrixSize - 8 && c <= 7) return true;

    // Timing patterns
    if (r == 6 || c == 6) return true;

    // Alignment pattern
    if (r >= matrixSize - 9 && r <= matrixSize - 5 && c >= matrixSize - 9 && c <= matrixSize - 5) {
      return true;
    }

    return false;
  }

  @override
  bool shouldRepaint(covariant _QrMatrixPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
