import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// 圖片品質分析報告
class ImageQualityReport {
  final double sharpnessScore;
  final double brightnessScore;
  final double contrastScore;
  final double overallScore;
  final bool isBlurry;
  final bool isDark;
  final bool isOverExposed;
  final bool isLowContrast;
  final bool needsRepair;

  const ImageQualityReport({
    required this.sharpnessScore,
    required this.brightnessScore,
    required this.contrastScore,
    required this.overallScore,
    required this.isBlurry,
    required this.isDark,
    required this.isOverExposed,
    required this.isLowContrast,
    required this.needsRepair,
  });

  List<String> get issues {
    final list = <String>[];
    if (isBlurry) list.add('模糊');
    if (isDark) list.add('偏暗');
    if (isOverExposed) list.add('過曝');
    if (isLowContrast) list.add('低對比');
    return list;
  }
}

class ImageEnhancer {
  static Future<ImageQualityReport> analyzeQuality(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256, targetHeight: 256);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      return const ImageQualityReport(
        sharpnessScore: 100, brightnessScore: 100, contrastScore: 100,
        overallScore: 100, isBlurry: false, isDark: false,
        isOverExposed: false, isLowContrast: false, needsRepair: false,
      );
    }
    final pixels = byteData.buffer.asUint8List();
    final w = image.width;
    final h = image.height;

    double sumLuma = 0;
    double sumLumaSq = 0;
    for (int i = 0; i < pixels.length; i += 4) {
      final luma = 0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2];
      sumLuma += luma;
      sumLumaSq += luma * luma;
    }
    final n = (pixels.length ~/ 4).toDouble();
    final meanLuma = sumLuma / n;
    final variance = (sumLumaSq / n) - (meanLuma * meanLuma);
    final stdDev = math.sqrt(variance.clamp(0, double.infinity));

    double laplacianSum = 0;
    int laplacianCount = 0;
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final idx = (y * w + x) * 4;
        final center = _luma(pixels, idx);
        final top = _luma(pixels, ((y - 1) * w + x) * 4);
        final bottom = _luma(pixels, ((y + 1) * w + x) * 4);
        final left = _luma(pixels, (y * w + (x - 1)) * 4);
        final right = _luma(pixels, (y * w + (x + 1)) * 4);
        final lap = (4 * center - top - bottom - left - right).abs();
        laplacianSum += lap * lap;
        laplacianCount++;
      }
    }
    final laplacianVariance = laplacianCount > 0 ? laplacianSum / laplacianCount : 0.0;
    final sharpnessScore = (math.log(laplacianVariance + 1) / math.log(500) * 100).clamp(0.0, 100.0);

    double brightnessScore;
    if (meanLuma < 50) {
      brightnessScore = (meanLuma / 50 * 60).clamp(0.0, 100.0);
    } else if (meanLuma > 210) {
      brightnessScore = ((255 - meanLuma) / 45 * 60).clamp(0.0, 100.0);
    } else {
      brightnessScore = 100.0;
    }
    final contrastScore = (stdDev / 60 * 100).clamp(0.0, 100.0);
    final overallScore = (sharpnessScore * 0.5 + brightnessScore * 0.3 + contrastScore * 0.2).clamp(0.0, 100.0);

    return ImageQualityReport(
      sharpnessScore: sharpnessScore,
      brightnessScore: brightnessScore,
      contrastScore: contrastScore,
      overallScore: overallScore,
      isBlurry: sharpnessScore < 45,
      isDark: meanLuma < 50,
      isOverExposed: meanLuma > 210,
      isLowContrast: contrastScore < 30,
      needsRepair: overallScore < 70,
    );
  }

  static double _luma(Uint8List pixels, int idx) {
    if (idx + 2 >= pixels.length) return 0;
    return 0.299 * pixels[idx] + 0.587 * pixels[idx + 1] + 0.114 * pixels[idx + 2];
  }

  static Future<Uint8List> enhanceImage(Uint8List bytes, ImageQualityReport report) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final srcImage = frame.image;
    final w = srcImage.width;
    final h = srcImage.height;
    final byteData = await srcImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return bytes;

    final src = byteData.buffer.asUint8List();

    double brightnessAdj = 0.0;
    double contrastAdj = 1.0;
    double gammaAdj = 1.0;
    if (report.isDark) { brightnessAdj = 35.0; gammaAdj = 0.75; }
    else if (report.isOverExposed) { brightnessAdj = -30.0; contrastAdj = 0.85; }
    if (report.isLowContrast) contrastAdj = math.max(contrastAdj, 1.3);

    final lut = List<int>.generate(256, (i) {
      double v = i.toDouble();
      v = (v + brightnessAdj).clamp(0, 255);
      if (gammaAdj != 1.0) v = math.pow(v / 255.0, gammaAdj).toDouble() * 255.0;
      v = ((v - 128) * contrastAdj + 128).clamp(0, 255);
      return v.round().clamp(0, 255);
    });

    final adjusted = Uint8List.fromList(src);
    for (int i = 0; i < adjusted.length; i += 4) {
      adjusted[i] = lut[adjusted[i]];
      adjusted[i + 1] = lut[adjusted[i + 1]];
      adjusted[i + 2] = lut[adjusted[i + 2]];
    }

    Uint8List sharpened = adjusted;
    if (report.isBlurry) sharpened = _applyUnsharpMask(adjusted, w, h, strength: 1.4);

    final finalPixels = _boostSaturation(sharpened, 1.15);

    final buffer = await ui.ImmutableBuffer.fromUint8List(finalPixels);
    final descriptor = ui.ImageDescriptor.raw(buffer, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
    final enhancedCodec = await descriptor.instantiateCodec();
    final enhanced = (await enhancedCodec.getNextFrame()).image;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImage(enhanced, ui.Offset.zero, ui.Paint()..filterQuality = ui.FilterQuality.high);
    final picture = recorder.endRecording();
    final outImage = await picture.toImage(w, h);
    final outData = await outImage.toByteData(format: ui.ImageByteFormat.png);
    return outData?.buffer.asUint8List() ?? bytes;
  }

  static Uint8List _applyUnsharpMask(Uint8List src, int w, int h, {double strength = 1.2}) {
    final out = Uint8List.fromList(src);
    const kernel = [[1, 2, 1], [2, 4, 2], [1, 2, 1]];
    const kSum = 16.0;
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        for (int c = 0; c < 3; c++) {
          double blurred = 0;
          for (int ky = -1; ky <= 1; ky++) {
            for (int kx = -1; kx <= 1; kx++) {
              blurred += src[((y + ky) * w + (x + kx)) * 4 + c] * kernel[ky + 1][kx + 1];
            }
          }
          blurred /= kSum;
          final origIdx = (y * w + x) * 4 + c;
          final sharpened = src[origIdx] + strength * (src[origIdx] - blurred);
          out[origIdx] = sharpened.round().clamp(0, 255);
        }
      }
    }
    return out;
  }

  static Uint8List _boostSaturation(Uint8List src, double factor) {
    final out = Uint8List.fromList(src);
    for (int i = 0; i < src.length; i += 4) {
      final r = src[i].toDouble();
      final g = src[i + 1].toDouble();
      final b = src[i + 2].toDouble();
      final gray = 0.299 * r + 0.587 * g + 0.114 * b;
      out[i] = ((r - gray) * factor + gray).round().clamp(0, 255);
      out[i + 1] = ((g - gray) * factor + gray).round().clamp(0, 255);
      out[i + 2] = ((b - gray) * factor + gray).round().clamp(0, 255);
    }
    return out;
  }
}
