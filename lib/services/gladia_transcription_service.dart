import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';

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
  final String provider; // 'gladia' or 'gemini_fallback'

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
/// 支援 Speaker Diarization、精確時間戳、中英混雜 Code-Switching 與 Gemini 2.5 Flash 自動備援
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

  /// 轉錄音訊檔案
  /// [onProgressStatus] 回傳即時進度狀態文字供 UI 顯示
  Future<GladiaTranscriptionResult> transcribeFile(
    File audioFile, {
    void Function(String statusMessage)? onProgressStatus,
  }) async {
    final apiKey = _kGladiaApiKey;

    if (apiKey.isEmpty) {
      debugPrint('GladiaTranscriptionService: 未設定 GLADIA_API_KEY，嘗試 Gemini 備援轉錄');
      return _transcribeWithGeminiFallback(audioFile, onProgressStatus);
    }

    try {
      onProgressStatus?.call('正在安全上傳音訊至 Gladia 雲端... ☁️');
      final audioUrl = await _uploadAudio(audioFile, apiKey);

      onProgressStatus?.call('Gladia 說話者分離與中英混雜語音辨識中... 🎙️');
      final resultUrl = await _createTranscriptionJob(audioUrl, apiKey);

      final result = await _pollTranscriptionResult(
        resultUrl,
        apiKey,
        onProgressStatus: onProgressStatus,
      );

      return result;
    } catch (e) {
      debugPrint('GladiaTranscriptionService error: $e, 啟動 Gemini 2.5 Flash 備援...');
      onProgressStatus?.call('Gladia 忙碌，切換高階 Gemini 語音辨識中... ⚡');
      return _transcribeWithGeminiFallback(audioFile, onProgressStatus);
    }
  }

  /// 1. 上傳音訊檔案至 Gladia
  Future<String> _uploadAudio(File audioFile, String apiKey) async {
    final uploadUri = Uri.parse('$_kGladiaBaseUrl/upload');
    final request = http.MultipartRequest('POST', uploadUri)
      ..headers['x-gladia-key'] = apiKey;

    request.files.add(await http.MultipartFile.fromPath(
      'audio',
      audioFile.path,
      filename: audioFile.path.split(RegExp(r'[\\/]')).last,
    ));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 45),
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
    const int maxAttempts = 75; // 最多等待 ~75 秒
    int attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;
      await Future.delayed(const Duration(seconds: 1));

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
                utterances.add(GladiaUtterance.fromJson(u));
              }
            }

            return GladiaTranscriptionResult(
              fullTranscript: fullTranscript.isNotEmpty
                  ? fullTranscript
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

  /// Gemini 備援語音轉錄 (當 Gladia 連線或額度耗盡時無縫切換)
  Future<GladiaTranscriptionResult> _transcribeWithGeminiFallback(
    File audioFile,
    void Function(String statusMessage)? onProgressStatus,
  ) async {
    final apiKey = _kGeminiApiKey;
    if (apiKey.isEmpty) {
      throw Exception('無法進行語音轉錄，請確認網路連線或 API 金鑰設定');
    }

    onProgressStatus?.call('使用 Gemini 高階語音引擎轉錄音訊中... ⚡');

    final audioBytes = await audioFile.readAsBytes();
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
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

    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart('audio/mp4', audioBytes),
      ]),
    ];

    final response = await model.generateContent(content);
    final text = response.text?.trim() ?? '';

    if (text.isEmpty) {
      throw Exception('Gemini 轉錄結果為空');
    }

    return GladiaTranscriptionResult(
      fullTranscript: text,
      utterances: [
        GladiaUtterance(
          speaker: 0,
          start: 0,
          end: 0,
          text: text,
        ),
      ],
      isDiarized: text.contains('說話者'),
      provider: 'gemini_fallback',
    );
  }
}
