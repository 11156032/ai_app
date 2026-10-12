import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/app_locale_service.dart';

/// 全螢幕 QR Code 掃描器頁面
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  bool _hasScanned = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _hasScanned = true;
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(value.trim());
        break;
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      final capture = await _controller.analyzeImage(file.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final barcode in capture.barcodes) {
          final value = barcode.rawValue;
          if (value != null && value.trim().isNotEmpty) {
            _hasScanned = true;
            HapticFeedback.mediumImpact();
            if (mounted) {
              Navigator.of(context).pop(value.trim());
            }
            return;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('qr_not_found_in_image')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('讀取圖片失敗: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (_) {}
  }

  void _switchCamera() async {
    try {
      await _controller.switchCamera();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scanWindowSize = MediaQuery.of(context).size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── 相機預覽畫面 ──
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        '${tr('qr_camera_failed')}: ${error.errorCode.name}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('qr_camera_perm_hint'),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(Icons.photo_library_rounded),
                        label: Text(tr('qr_gallery_pick')),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── 半透明遮罩與掃描框 ──
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.65),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  width: double.infinity,
                  height: double.infinity,
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: scanWindowSize,
                    height: scanWindowSize,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 掃描框邊角裝飾與掃描線 ──
          Center(
            child: SizedBox(
              width: scanWindowSize,
              height: scanWindowSize,
              child: Stack(
                children: [
                  // 四個角圓弧框
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                  ),
                  // 動態掃描雷射光
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Positioned(
                        top: (scanWindowSize - 20) * _animController.value,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFF64B5F6),
                                Color(0xFF42A5F5),
                                Color(0xFF64B5F6),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF42A5F5).withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── 頂部導覽欄 ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  Text(
                    tr('qr_scanner_title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // 平衡返回按鈕寬度
                ],
              ),
            ),
          ),

          // ── 底部控制按鈕區 ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('qr_scanner_hint'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 手電筒
                      _buildCircleButton(
                        icon: _isTorchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        label: _isTorchOn ? tr('qr_torch_on') : tr('qr_torch_off'),
                        isActive: _isTorchOn,
                        onTap: _toggleTorch,
                      ),
                      // 相簿選取
                      _buildCircleButton(
                        icon: Icons.photo_library_rounded,
                        label: tr('qr_gallery_pick'),
                        isActive: false,
                        onTap: _pickImageFromGallery,
                      ),
                      // 切換鏡頭
                      _buildCircleButton(
                        icon: Icons.flip_camera_ios_rounded,
                        label: tr('qr_flip_camera'),
                        isActive: false,
                        onTap: _switchCamera,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.black87 : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
