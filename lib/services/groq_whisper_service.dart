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
  double _maxAmplitudeSeen = -160.0;

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
    // 給予作業系統底層 I/O 緩衝區 250ms 確保 MP4/M4A moov header 完整寫入
    await Future.delayed(const Duration(milliseconds: 250));

    if (audioPath == null || audioPath.isEmpty) {
      throw Exception('未取得音訊錄音檔案，請確認已說話並重新錄音 🎙️');
    }

    final audioFile = File(audioPath);
    // 實測空白 M4A 標頭約為 800~1500 bytes，小於 2500 bytes 代表未錄進任何有效音軌數據
    if (!await audioFile.exists() || audioFile.lengthSync() < 2500) {
      throw Exception('錄音時間過短或音訊無聲音，請長按或點擊麥克風說話 🎙️');
    }

    // 若全程音量振幅皆為極低靜音（例如麥克風被系統靜音）
    if (_maxAmplitudeSeen < -58.0) {
      debugPrint(
          'GroqWhisperService: 錄音全程音量過低 (maxAmp: $_maxAmplitudeSeen dBFS)');
      throw Exception('未偵測到清晰語音，請靠近麥克風並確認已開口說話 🎙️');
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
    // 預設提示詞保持極簡，避免 Whisper 觸發自回歸前文續寫幻覺
    const defaultPrompt = '繁體中文。';
    final effectivePrompt = (prompt != null && prompt.trim().isNotEmpty)
        ? prompt.trim()
        : defaultPrompt;

    // 引擎 1: Groq Whisper (Turbo ➔ V3)
    final groqKey = _kGroqApiKey;
    if (groqKey.isNotEmpty) {
      for (final model in _kWhisperModels) {
        try {
          debugPrint('GroqWhisperService: 正在發送音檔至 Groq Whisper ($model)...');
          final stopwatch = Stopwatch()..start();

          final uri =
              Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
          final request = http.MultipartRequest('POST', uri)
            ..headers['Authorization'] = 'Bearer $groqKey'
            ..fields['model'] = model
            ..fields['response_format'] = 'verbose_json'
            ..fields['temperature'] = '0.0'
            ..fields['language'] = language
            ..fields['prompt'] = effectivePrompt
            ..files.add(
              await http.MultipartFile.fromPath(
                'file',
                audioFile.path,
                filename: 'recording.m4a',
              ),
            );

          final streamedResponse = await request.send().timeout(
                const Duration(seconds: 25),
                onTimeout: () =>
                    throw TimeoutException('Groq Whisper 轉錄超時（25s）'),
              );

          final response = await http.Response.fromStream(streamedResponse);
          stopwatch.stop();
          debugPrint(
              'GroqWhisperService: [$model] 轉錄完成，耗時 ${stopwatch.elapsedMilliseconds}ms, Status: ${response.statusCode}');

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes))
                as Map<String, dynamic>;

            // 檢查是否為靜音無聲幻覺 (no_speech_prob)
            final segments = data['segments'] as List<dynamic>?;
            double noSpeechProb = 0.0;
            if (segments != null && segments.isNotEmpty) {
              double sumProb = 0.0;
              for (final s in segments) {
                if (s is Map<String, dynamic>) {
                  sumProb += (s['no_speech_prob'] as num?)?.toDouble() ?? 0.0;
                }
              }
              noSpeechProb = sumProb / segments.length;
            } else if (data['no_speech_prob'] != null) {
              noSpeechProb =
                  (data['no_speech_prob'] as num?)?.toDouble() ?? 0.0;
            }

            if (noSpeechProb > 0.72) {
              debugPrint(
                  'GroqWhisperService: [$model] 判定為無聲或噪音 (no_speech_prob: $noSpeechProb)，攔截幻覺');
              throw Exception('未偵測到清晰語音，請靠近麥克風說話 🎙️');
            }

            final rawText = (data['text'] as String? ?? '').trim();

            if (rawText.isNotEmpty) {
              final cleaned = cleanWhisperTranscript(rawText);
              if (cleaned.isNotEmpty) {
                return cleaned;
              }
            }
          } else {
            debugPrint(
                'Groq Whisper API [$model] 回應 ${response.statusCode}: ${utf8.decode(response.bodyBytes)}');
          }
        } catch (e) {
          if (e.toString().contains('未偵測到清晰語音')) rethrow;
          debugPrint('Groq Whisper [$model] 轉錄異常: $e，嘗試備援引擎...');
        }
      }
    }

    // 引擎 2: Google Gemini 1.5 Flash 多模態音訊直接轉錄
    final geminiKey = _kGeminiApiKey;
    if (geminiKey.isNotEmpty) {
      try {
        debugPrint(
            'GroqWhisperService: 切換至備援引擎 Google Gemini 1.5 Flash 音訊轉錄...');
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
                '4. 若音訊為純靜音或無法辨識之背景噪音，請輸出空字串。\n'
                '5. 直接輸出純文字逐字稿內容，絕對不要加任何引言、前綴、標記或註解。',
              ),
            ]),
          ];

          final response = await model.generateContent(content).timeout(
                const Duration(seconds: 25),
              );
          final text = response.text?.trim() ?? '';
          if (text.isNotEmpty) {
            debugPrint(
                'GroqWhisperService: Gemini 1.5 Flash 音訊轉錄成功 (${text.length} 字)');
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
                'prompt': '請精準轉錄這段音訊為繁體中文，保留標點，去除贅字，若無人聲請直接輸出空字串：',
                'audioBase64': base64Audio,
                'mimeType': 'audio/m4a',
              }),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
              as String?;
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
