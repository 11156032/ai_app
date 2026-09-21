import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../utils/image_enhancer.dart';

// ─── 個人頭像裁切範圍選擇器對話框 ──────────────────────────────────────
class AvatarCropDialog extends StatefulWidget {
  final Uint8List rawBytes;
  const AvatarCropDialog({super.key, required this.rawBytes});

  @override
  State<AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<AvatarCropDialog> {
  double _zoom = 1.0;
  double _offsetX = 0.0;
  double _offsetY = 0.0;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '調整頭像可視範圍',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              '拖曳滑桿或調整縮放與位置，確定最佳發布預覽範圍',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            // 裁切預覽圓框區
            Center(
              child: ClipOval(
                child: Container(
                  width: 160,
                  height: 160,
                  color: Colors.black12,
                  child: Transform.translate(
                    offset: Offset(_offsetX, _offsetY),
                    child: Transform.scale(
                      scale: _zoom,
                      child: Image.memory(
                        widget.rawBytes,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 縮放控制
            Row(
              children: [
                const Icon(Icons.zoom_out, size: 18, color: Colors.grey),
                Expanded(
                  child: Slider(
                    value: _zoom,
                    min: 1.0,
                    max: 2.5,
                    divisions: 15,
                    label: '${_zoom.toStringAsFixed(1)}x',
                    onChanged: (val) => setState(() => _zoom = val),
                  ),
                ),
                const Icon(Icons.zoom_in, size: 18, color: Colors.grey),
              ],
            ),
            // 水平位置控制
            Row(
              children: [
                const Text('左右',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                Expanded(
                  child: Slider(
                    value: _offsetX,
                    min: -60.0,
                    max: 60.0,
                    onChanged: (val) => setState(() => _offsetX = val),
                  ),
                ),
              ],
            ),
            // 垂直位置控制
            Row(
              children: [
                const Text('上下',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                Expanded(
                  child: Slider(
                    value: _offsetY,
                    min: -60.0,
                    max: 60.0,
                    onChanged: (val) => setState(() => _offsetY = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _cropAndFinish,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('套用頭像範圍'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cropAndFinish() async {
    setState(() => _isProcessing = true);
    try {
      final codec = await instantiateImageCodec(widget.rawBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const canvasSize = 256.0;

      // 畫白底
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, canvasSize, canvasSize),
        Paint()..color = Colors.white,
      );

      // 計算轉換
      final double srcW = image.width.toDouble();
      final double srcH = image.height.toDouble();
      final double scale = (canvasSize / math.min(srcW, srcH)) * _zoom;

      final double dx = (canvasSize - srcW * scale) / 2 + _offsetX * 2;
      final double dy = (canvasSize - srcH * scale) / 2 + _offsetY * 2;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.scale(scale);
      canvas.drawImage(
          image, Offset.zero, Paint()..filterQuality = FilterQuality.high);
      canvas.restore();

      final picture = recorder.endRecording();
      final img = await picture.toImage(256, 256);
      final byteData = await img.toByteData(format: ImageByteFormat.png);

      if (mounted) {
        Navigator.pop(context, byteData?.buffer.asUint8List());
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context, widget.rawBytes);
      }
    }
  }
}

// ─── 社群貼文圖片 AI 畫質掃描修復底部面板 ──────────────────────────────────
class ImageQualityEnhanceSheet extends StatefulWidget {
  final Uint8List rawBytes;
  final XFile originalXFile;

  const ImageQualityEnhanceSheet({
    super.key,
    required this.rawBytes,
    required this.originalXFile,
  });

  @override
  State<ImageQualityEnhanceSheet> createState() =>
      _ImageQualityEnhanceSheetState();
}

class _ImageQualityEnhanceSheetState extends State<ImageQualityEnhanceSheet>
    with TickerProviderStateMixin {
  _ScanPhase _phase = _ScanPhase.scanning;

  late AnimationController _scanLineCtrl;
  late Animation<double> _scanLineAnim;
  late AnimationController _flashCtrl;
  late Animation<double> _flashAnim;

  ImageQualityReport? _report;
  Uint8List? _enhancedBytes;
  final List<DetectItem> _detectedItems = [];
  int _visibleItemCount = 0;

  @override
  void initState() {
    super.initState();
    _scanLineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _scanLineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut),
    );
    _flashCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _flashAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut),
    );
    _startScan();
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    _scanLineCtrl.repeat();
    final report = await ImageEnhancer.analyzeQuality(widget.rawBytes);
    _scanLineCtrl.stop();

    final items = [
      DetectItem(
          '銳利度', report.sharpnessScore, report.isBlurry ? '偵測到模糊' : '清晰'),
      DetectItem(
          '亮度',
          report.brightnessScore,
          report.isDark
              ? '偵測到偏暗'
              : report.isOverExposed
                  ? '偵測到過曝'
                  : '正常'),
      DetectItem(
          '對比度', report.contrastScore, report.isLowContrast ? '偵測到低對比' : '正常'),
    ];

    for (int i = 0; i < items.length; i++) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() {
        _detectedItems.add(items[i]);
        _visibleItemCount = _detectedItems.length;
      });
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (!report.needsRepair) {
      setState(() => _report = report);
      Navigator.pop(context, widget.originalXFile);
      return;
    }

    setState(() {
      _report = report;
      _phase = _ScanPhase.repairing;
    });

    final enhanced = await ImageEnhancer.enhanceImage(widget.rawBytes, report);
    if (!mounted) return;

    _flashCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));

    setState(() {
      _enhancedBytes = enhanced;
      _phase = _ScanPhase.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          Row(
            children: [
              const Icon(Icons.auto_fix_high,
                  color: Color(0xFF7C6AFF), size: 22),
              const SizedBox(width: 8),
              Text(
                _phase == _ScanPhase.scanning
                    ? 'AI 畫質掃描中...'
                    : _phase == _ScanPhase.repairing
                        ? 'AI 自動修復中...'
                        : '✨ 修復完成',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Image.memory(
                      (_phase == _ScanPhase.done && _enhancedBytes != null)
                          ? _enhancedBytes!
                          : widget.rawBytes,
                      key: ValueKey(_phase),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  if (_phase == _ScanPhase.scanning)
                    AnimatedBuilder(
                      animation: _scanLineAnim,
                      builder: (_, __) {
                        final top =
                            (_scanLineAnim.value * 200).clamp(0.0, 197.0);
                        return Stack(
                          children: [
                            Positioned(
                              top: top,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 3,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    Colors.transparent,
                                    Color(0xFF7C6AFF),
                                    Color(0xFF00E5FF),
                                    Color(0xFF7C6AFF),
                                    Colors.transparent,
                                  ]),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Color(0x887C6AFF),
                                        blurRadius: 12,
                                        spreadRadius: 4)
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: top + 3,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFF7C6AFF)
                                          .withValues(alpha: 0.15),
                                      Colors.transparent
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  AnimatedBuilder(
                    animation: _flashAnim,
                    builder: (_, __) => Opacity(
                      opacity: (_phase == _ScanPhase.repairing
                              ? 0.5 * (1 - _flashAnim.value)
                              : 0.0)
                          .clamp(0.0, 1.0),
                      child: Container(color: const Color(0xFF7C6AFF)),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.45)
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                const Color(0xFF7C6AFF).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_phase != _ScanPhase.done)
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor:
                                    AlwaysStoppedAnimation(Color(0xFF7C6AFF)),
                              ),
                            )
                          else
                            const Icon(Icons.auto_fix_high,
                                color: Color(0xFF7C6AFF), size: 12),
                          const SizedBox(width: 6),
                          Text(
                            _phase == _ScanPhase.scanning
                                ? '掃描中...'
                                : _phase == _ScanPhase.repairing
                                    ? '修復中...'
                                    : '已修復',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ..._detectedItems
              .take(_visibleItemCount)
              .map((item) => _buildDetectRow(item)),
          if (_phase == _ScanPhase.done && _report != null) ...[
            const SizedBox(height: 12),
            _buildScoreBar(_report!),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(context, widget.originalXFile),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white60,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('保留原圖'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      final enhanced = _enhancedBytes;
                      if (enhanced != null) {
                        Navigator.pop(context,
                            XFile.fromData(enhanced, name: 'ai_enhanced.png'));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C6AFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_fix_high, size: 16),
                        SizedBox(width: 6),
                        Text('套用 AI 修復',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_phase != _ScanPhase.done) const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDetectRow(DetectItem item) {
    final hasIssue = item.desc != '清晰' && item.desc != '正常';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            hasIssue ? Icons.warning_amber_rounded : Icons.check_circle,
            size: 16,
            color: hasIssue ? Colors.amber : Colors.greenAccent,
          ),
          const SizedBox(width: 8),
          Text(item.name,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Text(item.desc,
              style: TextStyle(
                color: hasIssue ? Colors.amber : Colors.greenAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.score / 100,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation(
                    hasIssue ? Colors.amber : const Color(0xFF7C6AFF)),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBar(ImageQualityReport report) {
    final score = report.overallScore.round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF7C6AFF).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: Color(0xFF7C6AFF), size: 20),
          const SizedBox(width: 10),
          const Text('修復後品質評分',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Text('$score / 100',
              style: const TextStyle(
                  color: Color(0xFF7C6AFF),
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

enum _ScanPhase { scanning, repairing, done }

class DetectItem {
  final String name;
  final double score;
  final String desc;
  const DetectItem(this.name, this.score, this.desc);
}

// ─── 社群貼文圖片視圖焦點 (Alignment) 選擇器對話框 ──────────────────────────────────
class ImageFocalPointDialog extends StatefulWidget {
  final Uint8List rawBytes;
  final double initialAlignX;
  final double initialAlignY;

  const ImageFocalPointDialog({
    super.key,
    required this.rawBytes,
    this.initialAlignX = 0.0,
    this.initialAlignY = 0.0,
  });

  @override
  State<ImageFocalPointDialog> createState() => _ImageFocalPointDialogState();
}

class _ImageFocalPointDialogState extends State<ImageFocalPointDialog> {
  late double _alignX;
  late double _alignY;

  @override
  void initState() {
    super.initState();
    _alignX = widget.initialAlignX;
    _alignY = widget.initialAlignY;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Alignment currentAlignment = Alignment(_alignX, _alignY);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF14141F) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.center_focus_strong,
                    color: Theme.of(context).primaryColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  '調整社群視圖顯示焦點',
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close,
                      color: isDark ? Colors.white54 : Colors.grey, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '可放大縮小預覽框，並手動拖曳對齊方位，決定最佳展示焦點',
              style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                  fontSize: 12),
            ),
            const SizedBox(height: 16),
            InteractiveViewer(
              clipBehavior: Clip.none,
              maxScale: 4.0,
              minScale: 1.0,
              panEnabled:
                  false, // Let GestureDetector handle 1-finger panning for alignment
              child: GestureDetector(
                onPanUpdate: (details) {
                  const double sens = 0.006;
                  setState(() {
                    _alignX =
                        (_alignX + details.delta.dx * sens).clamp(-1.0, 1.0);
                    _alignY =
                        (_alignY + details.delta.dy * sens).clamp(-1.0, 1.0);
                  });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black
                          : Colors.black.withValues(alpha: 0.05),
                      border: Border.all(
                          color: isDark
                              ? Theme.of(context)
                                  .primaryColor
                                  .withValues(alpha: 0.5)
                              : Colors.grey.shade300,
                          width: 1.5),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.memory(
                            widget.rawBytes,
                            fit: BoxFit.cover,
                            alignment: currentAlignment,
                          ),
                        ),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.touch_app,
                                    color: Colors.white70, size: 14),
                                SizedBox(width: 4),
                                Text('按住滑動微調，雙指可縮放預覽',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white60 : Colors.black54,
                      side: BorderSide(
                          color:
                              isDark ? Colors.white24 : Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pop(context, Offset(_alignX, _alignY)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('套用顯示焦點',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
