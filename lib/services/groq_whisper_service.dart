import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
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

  // 讀取 Gemini API 金鑰
  static String get _kGeminiApiKey {
    try {
      final key = dotenv.env['GEMINI_API_KEY'];
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    return '';
  }

  static const String _kCloudflareProxyUrl =
      'https://ai-app-proxy.adenlee36.workers.dev';
  static const String _kAppClientSecret = 'K/Qk9-gt2P.E9qa';
  static const String _kAppSecretHeader = 'X-App-Secret';

  // ----------------------------------------------------------
  // 2. 雲端極速音訊轉錄 (Groq Whisper ➔ Gemini 1.5 Flash ➔ Cloudflare Relay)
  // ----------------------------------------------------------

  /// 停止當前錄音並轉錄為繁體中文文字
  Future<String> stopAndTranscribe({String? prompt}) async {
    final audioPath = await stopRecording();
    // 給予作業系統 I/O 緩衝區 200ms 刷新寫入
    await Future.delayed(const Duration(milliseconds: 200));

    if (audioPath == null || audioPath.isEmpty) {
      throw Exception('未取得音訊錄音檔案，請確認已說話並重新錄音 🎙️');
    }

    final audioFile = File(audioPath);
    if (!await audioFile.exists() || audioFile.lengthSync() < 300) {
      throw Exception('錄音時間過短或音訊無聲音，請長按或點擊麥克風說話 🎙️');
    }

    try {
      final transcript = await transcribeAudioFile(audioFile, prompt: prompt);
      return transcript;
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

  /// 將指定音訊檔案進行轉錄（自動多重引擎輪詢降級）
  Future<String> transcribeAudioFile(
    File audioFile, {
    String? prompt,
    String language = 'zh',
  }) async {
    const defaultPrompt = '以下為繁體中文語音筆記內容，請保留完整標點符號（逗號、句號、問號）、專有名詞與中英夾雜精準拼寫。';
    final effectivePrompt = prompt ?? defaultPrompt;

    // 引擎 1: Groq Whisper (Turbo ➔ V3)
    final groqKey = _kGroqApiKey;
    if (groqKey.isNotEmpty) {
      for (final model in _kWhisperModels) {
        try {
          debugPrint('GroqWhisperService: 正在發送音檔至 Groq Whisper ($model)...');
          final stopwatch = Stopwatch()..start();

          final uri = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
          final request = http.MultipartRequest('POST', uri)
            ..headers['Authorization'] = 'Bearer $groqKey'
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
                const Duration(seconds: 25),
                onTimeout: () => throw TimeoutException('Groq Whisper 轉錄超時（25s）'),
              );

          final response = await http.Response.fromStream(streamedResponse);
          stopwatch.stop();
          debugPrint('GroqWhisperService: [$model] 轉錄完成，耗時 ${stopwatch.elapsedMilliseconds}ms, Status: ${response.statusCode}');

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
            final rawText = (data['text'] as String? ?? '').trim();

            if (rawText.isNotEmpty) {
              return AiDiagnosisService.toTraditionalChinese(rawText);
            }
          } else {
            debugPrint('Groq Whisper API [$model] 回應 ${response.statusCode}: ${utf8.decode(response.bodyBytes)}');
          }
        } catch (e) {
          debugPrint('Groq Whisper [$model] 轉錄異常: $e，嘗試備援引擎...');
        }
      }
    }

    // 引擎 2: Google Gemini 1.5 Flash 多模態音訊直接轉錄
    final geminiKey = _kGeminiApiKey;
    if (geminiKey.isNotEmpty) {
      try {
        debugPrint('GroqWhisperService: 切換至備援引擎 Google Gemini 1.5 Flash 音訊轉錄...');
        final audioBytes = await audioFile.readAsBytes();
        if (audioBytes.isNotEmpty) {
          final model = GenerativeModel(
            model: 'gemini-1.5-flash',
            apiKey: geminiKey,
            generationConfig: GenerationConfig(temperature: 0.1),
          );

          final content = [
            Content.multi([
              DataPart('audio/m4a', audioBytes),
              TextPart(
                '你是一個頂級的高精準繁體中文語音轉文字助手。\n'
                '請將這段音訊錄音完整精確轉錄為繁體中文逐字稿，要求：\n'
                '1. 保留正確且完整的標點符號（逗號、句號、問號、頓號等）。\n'
                '2. 去除語意無關的「呃、啊、嗯、那個」等停頓口吃詞。\n'
                '3. 保留專有名詞、數字與英文縮寫。\n'
                '4. 直接輸出純文字逐字稿內容，絕對不要加任何引言、前綴、標記或註解。',
              ),
            ]),
          ];

          final response = await model.generateContent(content).timeout(
                const Duration(seconds: 25),
              );
          final text = response.text?.trim() ?? '';
          if (text.isNotEmpty) {
            debugPrint('GroqWhisperService: Gemini 1.5 Flash 音訊轉錄成功 (${text.length} 字)');
            return AiDiagnosisService.toTraditionalChinese(text);
          }
        }
      } catch (e) {
        debugPrint('GroqWhisperService Gemini 音訊轉錄異常: $e');
      }
    }

    // 引擎 3: Cloudflare 雲端中繼站音訊轉錄
    try {
      debugPrint('GroqWhisperService: 嘗試透過 Cloudflare 中繼站進行轉錄...');
      final audioBytes = await audioFile.readAsBytes();
      if (audioBytes.isNotEmpty) {
        final base64Audio = base64Encode(audioBytes);
        final response = await http
            .post(
              Uri.parse(_kCloudflareProxyUrl),
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                _kAppSecretHeader: _kAppClientSecret,
              },
              body: jsonEncode({
                'provider': 'gemini',
                'model': 'gemini-1.5-flash',
                'prompt': '請精準轉錄這段音訊為繁體中文，保留標點，去除贅字，直接輸出逐字稿：',
                'audioBase64': base64Audio,
                'mimeType': 'audio/m4a',
              }),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
          if (text != null && text.trim().isNotEmpty) {
            return AiDiagnosisService.toTraditionalChinese(text.trim());
          }
        }
      }
    } catch (e) {
      debugPrint('GroqWhisperService Cloudflare 音訊中繼轉錄異常: $e');
    }

    throw Exception('語音辨識服務暫時無法連線，請確認網路連線或直接在此輸入文字 📝');
  }

  /// 釋放資源
  Future<void> dispose() async {
    _amplitudeSubscription?.cancel();
    try {
      await _audioRecorder.dispose();
    } catch (_) {}
  }
}
