import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'ai_diagnosis_service.dart';
import 'gladia_transcription_service.dart';

/// 語音錄製與轉錄服務 (搭載 Gladia V2 說話者分離、精確時間戳、中英混雜辨識與 Gemini 2.5 Flash 雙重引擎)
class GroqWhisperService {
  GroqWhisperService._();
  static final GroqWhisperService instance = GroqWhisperService._();

  final AudioRecorder _audioRecorder = AudioRecorder();

  // 錄音狀態
  bool _isRecording = false;
  bool _isPaused = false;
  String? _currentRecordingPath;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  double _maxAmplitudeSeen = -160.0;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  String? get currentRecordingPath => _currentRecordingPath;

  // ----------------------------------------------------------
  // 1. 錄音生命週期管理
  // ----------------------------------------------------------

  /// 開始錄製高品質音訊
  /// [onAmplitudeChange] 提供 0.0 ~ 10.0 的即時音量分貝數值供波形動畫使用
  Future<bool> startRecording({
    void Function(double level)? onAmplitudeChange,
  }) async {
    try {
      // 檢查並申請麥克風權限
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        debugPrint('GroqWhisperService: 未取得麥克風錄音權限');
        return false;
      }

      // 取得應用程式暫存路徑
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = p.join(tempDir.path, fileName);
      _currentRecordingPath = filePath;
      _maxAmplitudeSeen = -160.0;

      // 啟動 44.1kHz AAC-LC 標準高品質壓縮錄音 (最相容 iOS/Android 硬體麥克風，無破音或靜音)
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: filePath,
      );

      _isRecording = true;
      _isPaused = false;

      // 監聽即時音量分貝
      _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        final currentDb = amp.current;
        if (!currentDb.isInfinite && !currentDb.isNaN) {
          if (currentDb > _maxAmplitudeSeen) {
            _maxAmplitudeSeen = currentDb;
          }
        }
        if (onAmplitudeChange != null) {
          // amp.current 通常落在 -160.0 到 0.0 dBFS
          // 將 -60.0 dBFS ~ 0.0 dBFS 正規化至 0.0 ~ 10.0
          if (currentDb.isInfinite || currentDb.isNaN || currentDb <= -60.0) {
            onAmplitudeChange(0.0);
          } else {
            final normalized = ((currentDb + 60.0) / 60.0) * 10.0;
            onAmplitudeChange(normalized.clamp(0.0, 10.0));
          }
        }
      });

      debugPrint('GroqWhisperService: 錄音已啟動，路徑: $filePath');
      return true;
    } catch (e) {
      debugPrint('GroqWhisperService startRecording error: $e');
      _isRecording = false;
      _isPaused = false;
      return false;
    }
  }

  /// 暫停錄音
  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) return;
    try {
      await _audioRecorder.pause();
      _isPaused = true;
      debugPrint('GroqWhisperService: 錄音已暫停');
    } catch (e) {
      debugPrint('GroqWhisperService pauseRecording error: $e');
    }
  }

  /// 繼續錄音
  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return;
    try {
      await _audioRecorder.resume();
      _isPaused = false;
      debugPrint('GroqWhisperService: 錄音已繼續');
    } catch (e) {
      debugPrint('GroqWhisperService resumeRecording error: $e');
    }
  }

  /// 結束錄音並取得錄音檔路徑
  Future<String?> stopRecording() async {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    if (!_isRecording && !_isPaused) return null;

    try {
      final path = await _audioRecorder.stop();
      _isRecording = false;
      _isPaused = false;
      final resolvedPath = path ?? _currentRecordingPath;
      debugPrint(
          'GroqWhisperService: 錄音完成，檔案大小: ${resolvedPath != null ? File(resolvedPath).lengthSync() : 0} bytes, 最大振幅: $_maxAmplitudeSeen dBFS');
      return resolvedPath;
    } catch (e) {
      debugPrint('GroqWhisperService stopRecording error: $e');
      _isRecording = false;
      _isPaused = false;
      return null;
    }
  }

  /// 取消錄音並刪除暫存檔
  Future<void> cancelRecording() async {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    if (_isRecording || _isPaused) {
      try {
        final path = await _audioRecorder.stop();
        _isRecording = false;
        _isPaused = false;
        final targetPath = path ?? _currentRecordingPath;
        if (targetPath != null) {
          final file = File(targetPath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      } catch (e) {
        debugPrint('GroqWhisperService cancelRecording error: $e');
      }
    }
    _isRecording = false;
    _isPaused = false;
    _currentRecordingPath = null;
  }

  // ----------------------------------------------------------
  // 2. 雲端極速音訊轉錄 (Gladia V2 旗艦 ➔ Gemini 2.5 Flash ➔ Cloudflare Relay)
  // ----------------------------------------------------------

  /// 停止當前錄音並取得包含說話者分離與時間戳的轉錄成果
  Future<GladiaTranscriptionResult> stopAndTranscribeResult({
    void Function(String statusMessage)? onProgressStatus,
  }) async {
    final audioPath = await stopRecording();
    // 給予作業系統底層 I/O 緩衝區 200ms 確保 MP4/M4A moov header 完整寫入
    await Future.delayed(const Duration(milliseconds: 200));

    if (audioPath == null || audioPath.isEmpty) {
      throw Exception('未取得音訊錄音檔案，請確認已說話並重新錄音 🎙️');
    }

    final audioFile = File(audioPath);
    if (!await audioFile.exists() || audioFile.lengthSync() < 400) {
      throw Exception('錄音時間過短或無音訊數據，請點擊麥克風說話 🎙️');
    }

    try {
      final result = await GladiaTranscriptionService.instance.transcribeFile(
        audioFile,
        onProgressStatus: onProgressStatus,
      );
      return result;
    } finally {
      // 轉錄完成後自動清理暫存錄音檔
      try {
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      } catch (_) {}
      _currentRecordingPath = null;
    }
  }

  /// 停止當前錄音並轉錄為繁體中文文字 (含說話者與時間戳)
  Future<String> stopAndTranscribe({
    String? prompt,
    void Function(String statusMessage)? onProgressStatus,
  }) async {
    final result = await stopAndTranscribeResult(onProgressStatus: onProgressStatus);
    return result.toFormattedDiarizedText();
  }

  /// 將指定音訊檔案進行轉錄（優先 Gladia V2 ➔ 自動 Gemini 2.5 Flash 備援）
  Future<String> transcribeAudioFile(
    File audioFile, {
    String? prompt,
    String language = 'zh',
  }) async {
    try {
      final result =
          await GladiaTranscriptionService.instance.transcribeFile(audioFile);
      final formatted = result.toFormattedDiarizedText();
      if (formatted.isNotEmpty) return formatted;
    } catch (e) {
      debugPrint('GroqWhisperService transcribeAudioFile error: $e');
    }

    throw Exception('語音辨識服務暫時無法連線，請確認網路連線或直接在此輸入文字 📝');
  }

  /// 清理 Whisper 辨識結果（過濾幻覺字串、去重複循環、口語贅字與轉為繁體中文）
  static String cleanWhisperTranscript(String raw) {
    if (raw.trim().isEmpty) return '';

    var cleaned = raw.trim();

    // 1. 移除 Whisper 常見的幻覺字幕、片尾詞或提示詞回波
    final hallucinations = [
      RegExp(r'字幕由\s*.+?\s*提供', caseSensitive: false),
      RegExp(r'請訂閱\s*.+?(頻道|關注)?', caseSensitive: false),
      RegExp(r'點讚[、，\s]*訂閱[、，\s]*開啟小鈴鐺', caseSensitive: false),
      RegExp(r'Thank you for watching.*', caseSensitive: false),
      RegExp(r'Thanks for watching.*', caseSensitive: false),
      RegExp(r'Amara\.org', caseSensitive: false),
      RegExp(r'感謝您的?收看.*?[。！\n]?', caseSensitive: false),
      RegExp(r'謝謝大家(的)?收看.*?[。！\n]?', caseSensitive: false),
      RegExp(r'繁體中文[。！\n]?', caseSensitive: false),
      RegExp(r'臺灣慣用語[。！\n]?', caseSensitive: false),
      RegExp(r'標點符號[。！\n]?', caseSensitive: false),
      RegExp(r'以下為繁體中文語音筆記.*?[。！\n]?', caseSensitive: false),
      RegExp(r'請保留完整標點符號.*?[。！\n]?', caseSensitive: false),
      RegExp(r'專有名詞與中英夾雜.*?[。！\n]?', caseSensitive: false),
      RegExp(r'^[。，、？！\.\,\s]+$'),
    ];
    for (final h in hallucinations) {
      cleaned = cleaned.replaceAll(h, '');
    }

    // 2. 去除連續重複的句子或短語 (例如 "謝謝大家。謝謝大家。")
    final lines = cleaned.split('\n');
    final dedupedLines = <String>[];
    String? lastLine;
    for (final line in lines) {
      final t = line.trim();
      if (t.isNotEmpty && t != lastLine) {
        dedupedLines.add(t);
        lastLine = t;
      }
    }
    cleaned = dedupedLines.join('\n');

    return AiDiagnosisService.toTraditionalChinese(cleaned.trim());
  }

  /// 釋放資源
  Future<void> dispose() async {
    _amplitudeSubscription?.cancel();
    try {
      await _audioRecorder.dispose();
    } catch (_) {}
  }
}
