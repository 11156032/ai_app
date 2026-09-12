import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'ai_diagnosis_service.dart';

/// Groq Whisper 語音轉錄服務
/// 結合本機高品質音訊錄製（零斷字、零漏句）與 Groq Whisper 旗艦極速轉錄（1~2 秒完成）
class GroqWhisperService {
  GroqWhisperService._();
  static final GroqWhisperService instance = GroqWhisperService._();

  final AudioRecorder _audioRecorder = AudioRecorder();

  // 錄音狀態
  bool _isRecording = false;
  bool _isPaused = false;
  String? _currentRecordingPath;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  String? get currentRecordingPath => _currentRecordingPath;

  // 讀取 Groq API 金鑰
  static String get _kGroqApiKey {
    try {
      final key = dotenv.env['GROQ_API_KEY'];
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    const envKey = String.fromEnvironment('GROQ_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    return '';
  }

  // 支援的 Whisper 模型（優先使用 whisper-large-v3-turbo 極速旗艦模型）
  static const List<String> _kWhisperModels = [
    'whisper-large-v3-turbo',
    'whisper-large-v3',
  ];

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
      final fileName = 'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final filePath = p.join(tempDir.path, fileName);
      _currentRecordingPath = filePath;

      // 啟動 AAC-LC 高品質壓縮錄音 (相容性與 Whisper 辨識率最高)
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
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
        if (onAmplitudeChange != null) {
          // amp.current 通常落在 -160.0 到 0.0 dBFS
          // 將 -60.0 dBFS ~ 0.0 dBFS 正規化至 0.0 ~ 10.0
          final currentDb = amp.current;
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
      debugPrint('GroqWhisperService: 錄音完成，檔案大小: ${resolvedPath != null ? File(resolvedPath).lengthSync() : 0} bytes');
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
  // 2. Groq Whisper 雲端極速音訊轉錄
  // ----------------------------------------------------------

  /// 停止當前錄音並直接呼叫 Groq Whisper 轉錄為文字
  /// [prompt] 可選提示詞（用於加強特定專有名詞或繁中排版習慣）
  Future<String> stopAndTranscribe({String? prompt}) async {
    final audioPath = await stopRecording();
    if (audioPath == null || audioPath.isEmpty) {
      throw Exception('未取得有效的音訊錄音檔案');
    }

    final audioFile = File(audioPath);
    if (!await audioFile.exists() || audioFile.lengthSync() == 0) {
      throw Exception('錄音檔案為空或不存在');
    }

    try {
      final transcript = await transcribeAudioFile(audioFile, prompt: prompt);
      return transcript;
    } finally {
      // 轉錄完成後自動刪除本機暫存檔，確保不浪費使用者儲存空間
      try {
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      } catch (_) {}
      _currentRecordingPath = null;
    }
  }

  /// 將指定本機音訊檔案傳送至 Groq Whisper 進行轉錄
  Future<String> transcribeAudioFile(
    File audioFile, {
    String? prompt,
    String language = 'zh',
  }) async {
    final apiKey = _kGroqApiKey;
    if (apiKey.isEmpty) {
      throw Exception('未設定 GROQ_API_KEY，請確認 assets/keys.env 配置');
    }

    const defaultPrompt = '以下為繁體中文語音筆記內容，請保留完整標點符號（逗號、句號、問號）、專有名詞與中英夾雜精準拼寫。';
    final effectivePrompt = prompt ?? defaultPrompt;

    Exception? lastError;

    // 依序嘗試 Whisper 模型（whisper-large-v3-turbo -> whisper-large-v3）
    for (final model in _kWhisperModels) {
      try {
        debugPrint('GroqWhisperService: 正在發送音檔至 Groq Whisper ($model)...');
        final stopwatch = Stopwatch()..start();

        final uri = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
        final request = http.MultipartRequest('POST', uri)
          ..headers['Authorization'] = 'Bearer $apiKey'
          ..fields['model'] = model
          ..fields['response_format'] = 'json'
          ..fields['temperature'] = '0.0'
          ..fields['language'] = language
          ..fields['prompt'] = effectivePrompt
          ..files.add(
            await http.MultipartFile.fromPath(
              'file',
              audioFile.path,
            ),
          );

        final streamedResponse = await request.send().timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException('Groq Whisper 轉錄請求超時（30s）'),
            );

        final response = await http.Response.fromStream(streamedResponse);
        stopwatch.stop();
        debugPrint('GroqWhisperService: [$model] 轉錄完成，耗時 ${stopwatch.elapsedMilliseconds}ms, Status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final rawText = (data['text'] as String? ?? '').trim();

          if (rawText.isNotEmpty) {
            // 轉換為標準繁體中文並返回
            final traditionalText = AiDiagnosisService.toTraditionalChinese(rawText);
            return traditionalText;
          } else {
            throw Exception('Groq Whisper 回傳空白轉錄文字');
          }
        } else {
          final errorBody = utf8.decode(response.bodyBytes);
          debugPrint('Groq Whisper API 錯誤 [$model] (${response.statusCode}): $errorBody');
          throw Exception('Groq Whisper API [${response.statusCode}]: $errorBody');
        }
      } catch (e) {
        debugPrint('Groq Whisper [$model] 發生異常: $e，嘗試下一個備援模型...');
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }

    throw lastError ?? Exception('Groq Whisper 轉錄失敗，所有模型均不可用');
  }

  /// 釋放資源
  Future<void> dispose() async {
    _amplitudeSubscription?.cancel();
    try {
      await _audioRecorder.dispose();
    } catch (_) {}
  }
}
