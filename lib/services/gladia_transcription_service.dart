import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_diagnosis_service.dart';

/// 單句說話者轉錄分段
class GladiaUtterance {
  final int speaker;
  final double start; // 秒數
  final double end; // 秒數
  final String text;
  final String? language;

  GladiaUtterance({
    required this.speaker,
    required this.start,
    required this.end,
    required this.text,
    this.language,
  });

  /// 格式化起始時間 (例如 "01:23")
  String get formattedStartTime {
    final m = (start ~/ 60).toString().padLeft(2, '0');
    final s = (start.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// 格式化時間區間 (例如 "01:23 - 01:45")
  String get formattedTimeRange {
    final sm = (start ~/ 60).toString().padLeft(2, '0');
    final ss = (start.toInt() % 60).toString().padLeft(2, '0');
    final em = (end ~/ 60).toString().padLeft(2, '0');
    final es = (end.toInt() % 60).toString().padLeft(2, '0');
    return '$sm:$ss - $em:$es';
  }

  /// 說話者顯示名稱 (例如 "說話者 1")
  String get speakerDisplayName => '說話者 ${speaker + 1}';

  Map<String, dynamic> toJson() => {
        'speaker': speaker,
        'start': start,
        'end': end,
        'text': text,
        'language': language,
      };

  factory GladiaUtterance.fromJson(Map<String, dynamic> json) {
    return GladiaUtterance(
      speaker: json['speaker'] is int ? json['speaker'] as int : 0,
      start: (json['start'] as num?)?.toDouble() ?? 0.0,
      end: (json['end'] as num?)?.toDouble() ?? 0.0,
      text: (json['text'] as String?)?.trim() ?? '',
      language: json['language'] as String?,
    );
  }
}

/// Gladia 轉錄完整成果
class GladiaTranscriptionResult {
  final String fullTranscript;
  final List<GladiaUtterance> utterances;
  final bool isDiarized;
  final String provider; // 'gladia', 'groq_whisper', or 'gemini_fallback'

  GladiaTranscriptionResult({
    required this.fullTranscript,
    required this.utterances,
    this.isDiarized = true,
    this.provider = 'gladia',
  });

  /// 輸出標準說話者+時間戳格式文字 (提供給 LLM 進行結構化提煉)
  String toFormattedDiarizedText() {
    if (utterances.isEmpty) {
      return fullTranscript;
    }
    return utterances.map((u) {
      return '[${u.formattedStartTime}] ${u.speakerDisplayName}: ${u.text}';
    }).join('\n');
  }
}

/// Gladia V2 旗艦語音轉錄服務
/// 支援 Speaker Diarization、精確時間戳、中英混雜 Code-Switching，並搭載 Groq Whisper 與 Gemini 2.5 Flash 雙重高可靠備援
class GladiaTranscriptionService {
  GladiaTranscriptionService._();
  static final GladiaTranscriptionService instance =
      GladiaTranscriptionService._();

  static const String _kGladiaBaseUrl = 'https://api.gladia.io/v2';

  // 讀取 Gladia API 金鑰
  static String get _kGladiaApiKey {
    try {
      final key = dotenv.env['GLADIA_API_KEY'];
      if (key != null && key.trim().isNotEmpty) return key.trim();
    } catch (_) {}
    const envKey = String.fromEnvironment('GLADIA_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    return '';
  }

  // 讀取 Groq API 金鑰
  static String get _kGroqApiKey {
    try {
      final key = dotenv.env['GROQ_API_KEY'];
      if (key != null && key.trim().isNotEmpty) return key.trim();
    } catch (_) {}
    const envKey = String.fromEnvironment('GROQ_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    return '';
  }

  // 讀取 Gemini API 金鑰 (作為備援)
  static String get _kGeminiApiKey {
    try {
      final key = dotenv.env['GEMINI_API_KEY'];
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    return '';
  }

  /// 轉錄音訊檔案（自動串接 Gladia V2 旗艦 ➔ Groq Whisper ➔ Gemini 2.5 Flash 備援）
  /// [onProgressStatus] 回傳即時進度狀態文字供 UI 顯示
  Future<GladiaTranscriptionResult> transcribeFile(
    File audioFile, {
    void Function(String statusMessage)? onProgressStatus,
  }) async {
    if (!await audioFile.exists() || audioFile.lengthSync() < 200) {
      throw Exception('未取得有效音訊資料，請靠近麥克風說話 🎙️');
    }

    // ----------------------------------------------------
    // 順位 1：Gladia V2 旗艦轉錄 (含說話者分離與多語言 Code-Switching)
    // ----------------------------------------------------
    final gladiaKey = _kGladiaApiKey;
    if (gladiaKey.isNotEmpty) {
      try {
        onProgressStatus?.call('正在安全傳送音訊至 Gladia 旗艦引擎... ☁️');
        final audioUrl = await _uploadAudio(audioFile, gladiaKey);

        onProgressStatus?.call('Gladia 說話者分離與多語言辨識中... 🎙️');
        final resultUrl = await _createTranscriptionJob(audioUrl, gladiaKey);

        final result = await _pollTranscriptionResult(
          resultUrl,
          gladiaKey,
          onProgressStatus: onProgressStatus,
        );

        final text = result.toFormattedDiarizedText().trim();
        if (text.isNotEmpty) {
          debugPrint('GladiaTranscriptionService: Gladia V2 轉錄成功 (${text.length} 字)');
          return result;
        } else {
          debugPrint('GladiaTranscriptionService: Gladia 回傳空白文字，立即啟用備援轉錄引擎...');
        }
      } catch (e) {
        debugPrint('GladiaTranscriptionService Gladia 引擎異常: $e，立即切換備援引擎...');
      }
    }

    // ----------------------------------------------------
    // 順位 2：Groq Whisper 極速引擎 (whisper-large-v3-turbo，200ms 極速繁中識別)
    // ----------------------------------------------------
    final groqKey = _kGroqApiKey;
    if (groqKey.isNotEmpty) {
      try {
        onProgressStatus?.call('啟動 Groq Whisper 極速語音引擎... ⚡');
        final groqResult = await _transcribeWithGroqWhisper(audioFile);
        final text = groqResult.fullTranscript.trim();
        if (text.isNotEmpty) {
          debugPrint('GladiaTranscriptionService: Groq Whisper 轉錄成功 (${text.length} 字)');
          return groqResult;
        }
      } catch (e) {
        debugPrint('GladiaTranscriptionService Groq Whisper 引擎異常: $e');
      }
    }

    // ----------------------------------------------------
    // 順位 3：Gemini 2.5 Flash 原生音訊多模態辨識 (gemini-2.5-flash)
    // ----------------------------------------------------
    final geminiKey = _kGeminiApiKey;
    if (geminiKey.isNotEmpty) {
      try {
        onProgressStatus?.call('啟動 Gemini 2.5 高階語音多模態辨識... ⚡');
        final geminiResult = await _transcribeWithGemini25(audioFile);
        final text = geminiResult.fullTranscript.trim();
        if (text.isNotEmpty) {
          debugPrint('GladiaTranscriptionService: Gemini 2.5 轉錄成功 (${text.length} 字)');
          return geminiResult;
        }
      } catch (e) {
        debugPrint('GladiaTranscriptionService Gemini 2.5 異常: $e');
      }
    }

    // 若所有引擎均無法識別出內容
    throw Exception('未能從音訊中識別出清晰人聲語音，請靠近麥克風並確保音量清晰後重試 🎙️');
  }

  /// 1. 上傳音訊檔案至 Gladia
  Future<String> _uploadAudio(File audioFile, String apiKey) async {
    final uploadUri = Uri.parse('$_kGladiaBaseUrl/upload');
    final request = http.MultipartRequest('POST', uploadUri)
      ..headers['x-gladia-key'] = apiKey;

    final filename = audioFile.path.split(RegExp(r'[\\/]')).last;
    final ext = filename.split('.').last.toLowerCase();
    final mediaType = (ext == 'm4a' || ext == 'mp4' || ext == 'aac')
        ? MediaType('audio', 'mp4')
        : (ext == 'wav'
            ? MediaType('audio', 'wav')
            : MediaType('application', 'octet-stream'));

    request.files.add(await http.MultipartFile.fromPath(
      'audio',
      audioFile.path,
      filename: filename,
      contentType: mediaType,
    ));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 40),
      onTimeout: () => throw TimeoutException('音訊上傳至 Gladia 超時'),
    );

    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Gladia 音訊上傳失敗 [${response.statusCode}]: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final audioUrl = data['audio_url'] as String?;
    if (audioUrl == null || audioUrl.isEmpty) {
      throw Exception('未取得 Gladia audio_url');
    }
    return audioUrl;
  }

  /// 2. 發起轉錄任務 (開啟 Diarization 說話者分離與 Code-Switching)
  Future<String> _createTranscriptionJob(String audioUrl, String apiKey) async {
    final preRecordedUri = Uri.parse('$_kGladiaBaseUrl/pre-recorded');
    final requestBody = jsonEncode({
      'audio_url': audioUrl,
      'diarization': true,
      'diarization_config': {
        'min_speakers': 1,
        'max_speakers': 6,
      },
      'language_config': {
        'code_switching': true, // 支援中英混雜語音
        'languages': ['zh', 'en'], // 明確設定以繁體中文與英語為主
      },
    });

    final response = await http
        .post(
      preRecordedUri,
      headers: {
        'x-gladia-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: requestBody,
    )
        .timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Gladia 任務建立請求超時'),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Gladia 轉錄任務發起失敗 [${response.statusCode}]: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final resultUrl = data['result_url'] as String?;
    if (resultUrl == null || resultUrl.isEmpty) {
      final id = data['id'] as String?;
      if (id != null && id.isNotEmpty) {
        return '$_kGladiaBaseUrl/pre-recorded/$id';
      }
      throw Exception('未取得 Gladia result_url');
    }
    return resultUrl;
  }

  /// 3. 輪詢結果
  Future<GladiaTranscriptionResult> _pollTranscriptionResult(
    String resultUrl,
    String apiKey, {
    void Function(String statusMessage)? onProgressStatus,
  }) async {
    const int maxAttempts = 60; // 最多等待 ~60 秒
    int attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;
      await Future.delayed(const Duration(milliseconds: 1000));

      try {
        final response = await http.get(
          Uri.parse(resultUrl),
          headers: {'x-gladia-key': apiKey},
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final status = data['status'] as String?;

          if (status == 'done') {
            final result = data['result'] as Map<String, dynamic>?;
            final transcription =
                result?['transcription'] as Map<String, dynamic>?;

            final fullTranscript =
                (transcription?['full_transcript'] as String?)?.trim() ?? '';
            final rawUtterances =
                transcription?['utterances'] as List<dynamic>? ?? [];

            final utterances = <GladiaUtterance>[];
            for (final u in rawUtterances) {
              if (u is Map<String, dynamic>) {
                final text = (u['text'] as String?)?.trim() ?? '';
                if (text.isNotEmpty) {
                  utterances.add(GladiaUtterance(
                    speaker: u['speaker'] is int ? u['speaker'] as int : 0,
                    start: (u['start'] as num?)?.toDouble() ?? 0.0,
                    end: (u['end'] as num?)?.toDouble() ?? 0.0,
                    text: AiDiagnosisService.toTraditionalChinese(text),
                    language: u['language'] as String?,
                  ));
                }
              }
            }

            final traditionalFull =
                AiDiagnosisService.toTraditionalChinese(fullTranscript);

            return GladiaTranscriptionResult(
              fullTranscript: traditionalFull.isNotEmpty
                  ? traditionalFull
                  : utterances.map((u) => u.text).join(' '),
              utterances: utterances,
              isDiarized: utterances.isNotEmpty,
              provider: 'gladia',
            );
          } else if (status == 'error') {
            throw Exception('Gladia 轉錄處理失敗: ${data['error']}');
          } else {
            // queued or processing
            if (attempt % 3 == 0) {
              onProgressStatus?.call('Gladia 正在辨識說話者與字詞中 (${attempt}s)...');
            }
          }
        }
      } catch (e) {
        debugPrint('Gladia polling error on attempt $attempt: $e');
        if (attempt >= maxAttempts) rethrow;
      }
    }

    throw TimeoutException('Gladia 轉錄處理逾時');
  }

  /// Groq Whisper 極速轉錄 (whisper-large-v3-turbo, 200ms 反應速度)
  Future<GladiaTranscriptionResult> _transcribeWithGroqWhisper(
    File audioFile,
  ) async {
    final apiKey = _kGroqApiKey;
    if (apiKey.isEmpty) {
      throw Exception('未設定 GROQ_API_KEY');
    }

    final uri = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
      ..fields['model'] = 'whisper-large-v3-turbo'
      ..fields['response_format'] = 'json'
      ..fields['temperature'] = '0.0'
      ..fields['language'] = 'zh'
      ..fields['prompt'] = '以下為繁體中文語音筆記內容，請保留完整標點符號、專有名詞與中英夾雜精準拼寫。';

    final filename = audioFile.path.split(RegExp(r'[\\/]')).last;
    final ext = filename.split('.').last.toLowerCase();
    final mediaType = (ext == 'm4a' || ext == 'mp4' || ext == 'aac')
        ? MediaType('audio', 'mp4')
        : (ext == 'wav'
            ? MediaType('audio', 'wav')
            : MediaType('application', 'octet-stream'));

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      audioFile.path,
      filename: filename,
      contentType: mediaType,
    ));

    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 25),
          onTimeout: () => throw TimeoutException('Groq Whisper 轉錄超時'),
        );

    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final rawText = (data['text'] as String? ?? '').trim();
      if (rawText.isNotEmpty) {
        final traditional = AiDiagnosisService.toTraditionalChinese(rawText);
        return GladiaTranscriptionResult(
          fullTranscript: traditional,
          utterances: [
            GladiaUtterance(
              speaker: 0,
              start: 0,
              end: 0,
              text: traditional,
            ),
          ],
          isDiarized: false,
          provider: 'groq_whisper',
        );
      }
    }
    throw Exception('Groq Whisper 回傳空白轉錄或錯誤 [${response.statusCode}]');
  }

  /// Gemini 2.5 Flash 原生音訊多模態語音轉錄 (gemini-2.5-flash)
  Future<GladiaTranscriptionResult> _transcribeWithGemini25(
    File audioFile,
  ) async {
    final apiKey = _kGeminiApiKey;
    if (apiKey.isEmpty) {
      throw Exception('未設定 GEMINI_API_KEY');
    }

    final audioBytes = await audioFile.readAsBytes();
    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
    );

    const prompt = '''
請將這段錄音精確轉錄為繁體中文（台灣習慣用語）與英文中英混雜的逐字稿。
要求：
1. 自動識別不同的說話者（例如：說話者 1、說話者 2）。
2. 每段話前標註時間或說話者，例如：[說話者 1]: 內容...
3. 嚴格校正專有名詞與同音錯字，中英夾雜時英文單字正確拼寫。
4. 僅回傳轉錄逐字稿內容，不要包含額外前言或寒暄。
''';

    final ext = audioFile.path.split('.').last.toLowerCase();
    final mimeType = (ext == 'wav') ? 'audio/wav' : 'audio/mp4';

    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart(mimeType, audioBytes),
      ]),
    ];

    final response = await model.generateContent(content).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException('Gemini 2.5 轉錄超時'),
        );
    final text = response.text?.trim() ?? '';

    if (text.isEmpty) {
      throw Exception('Gemini 轉錄結果為空');
    }

    final traditional = AiDiagnosisService.toTraditionalChinese(text);

    return GladiaTranscriptionResult(
      fullTranscript: traditional,
      utterances: [
        GladiaUtterance(
          speaker: 0,
          start: 0,
          end: 0,
          text: traditional,
        ),
      ],
      isDiarized: traditional.contains('說話者'),
      provider: 'gemini_fallback',
    );
  }
}
