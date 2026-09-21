import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_diagnosis_service.dart';
import 'voice_recognition_service.dart';

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

  /// 輸出標準說話者+時間戳格式文字 (提供給 LLM 進行結構化提煉，並自動優化單一說話者與連續說話體驗)
  String toFormattedDiarizedText() {
    if (utterances.isEmpty) {
      return VoiceRecognitionService.ensureChinesePunctuation(fullTranscript.trim());
    }

    // 統計不同的說話者數量
    final validUtterances =
        utterances.where((u) => u.text.trim().isNotEmpty).toList();
    if (validUtterances.isEmpty) {
      return VoiceRecognitionService.ensureChinesePunctuation(fullTranscript.trim());
    }

    final uniqueSpeakers = validUtterances.map((u) => u.speaker).toSet();

    // 1. 若只有一位說話者 (單人錄音)：直接輸出乾淨流暢的逐字稿，不重複添加「說話者 1」
    if (uniqueSpeakers.length <= 1) {
      if (fullTranscript.trim().isNotEmpty) {
        return VoiceRecognitionService.ensureChinesePunctuation(fullTranscript.trim());
      }
      final concatenated = validUtterances.map((u) => u.text.trim()).join(' ');
      return VoiceRecognitionService.ensureChinesePunctuation(concatenated);
    }

    // 2. 若有多位說話者 (雙人/多人對話)：合併同一說話者的連續發言，僅在說話者輪替時標註
    final buffer = StringBuffer();
    int? currentSpeaker;

    for (final u in validUtterances) {
      final cleanText = VoiceRecognitionService.cleanFillerWords(u.text.trim());
      if (cleanText.isEmpty) continue;

      if (currentSpeaker != u.speaker) {
        if (buffer.isNotEmpty) buffer.writeln();
        buffer.write('[${u.formattedStartTime}] ${u.speakerDisplayName}：$cleanText');
        currentSpeaker = u.speaker;
      } else {
        // 同一說話者連續發言，自然串接
        final punctuated = VoiceRecognitionService.ensureChinesePunctuation(cleanText);
        buffer.write(' $punctuated');
      }
    }

    final resultStr = buffer.toString().trim();
    return VoiceRecognitionService.ensureChinesePunctuation(resultStr);
  }
}

/// Gladia V2 旗艦語音轉錄服務
/// 支援 Speaker Diarization、精確時間戳、中英混雜 Code-Switching，並搭載 Groq Whisper 與 Gemini 2.5 Flash 雙重高可靠備援
class GladiaTranscriptionService {
  GladiaTranscriptionService._();
  static final GladiaTranscriptionService instance =
      GladiaTranscriptionService._();

  static const String _kGladiaRelayUrl =
      'https://ai-app-proxy.adenlee36.workers.dev/gladia';
  static const String _kGladiaDirectBaseUrl = 'https://api.gladia.io/v2';

  // 讀取 App 訪問 Cloudflare Worker 的金鑰通行證
  static String get _kAppClientSecret {
    try {
      final secret = dotenv.env['APP_CLIENT_SECRET'];
      if (secret != null && secret.isNotEmpty) return secret;
    } catch (_) {}
    const envSecret = String.fromEnvironment('APP_CLIENT_SECRET');
    if (envSecret.isNotEmpty) return envSecret;
    return 'K/Qk9-gt2P.E9qa';
  }

  // 讀取 Gladia API 金鑰 (作為備援直連使用)
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
    try {
      return utf8.decode(base64Decode('QVEuQWI4Uk42SXg2NEUtQWdKQm51dm9DM1Vxcmh6QkUtM004TWRRR1NPYXZBcGdLMG1VOEE='));
    } catch (_) {
      return '';
    }
  }

  /// 轉錄音訊檔案（自動串接 Cloudflare Gladia 中繼 ➔ Gladia 直連 ➔ Groq Whisper ➔ Gemini 2.5 Flash 四重備援）
  /// [onProgressStatus] 回傳即時進度狀態文字供 UI 顯示
  Future<GladiaTranscriptionResult> transcribeFile(
    File audioFile, {
    void Function(String statusMessage)? onProgressStatus,
  }) async {
    if (!await audioFile.exists() || audioFile.lengthSync() < 200) {
      throw Exception('未取得有效音訊資料，請靠近麥克風說話 🎙️');
    }

    final List<String> errorLogs = [];

    // ----------------------------------------------------
    // 順位 1：Cloudflare 中繼站 Gladia V2 旗艦轉錄 (不暴露 API Key，含說話者分離)
    // ----------------------------------------------------
    try {
      onProgressStatus?.call('安全傳送音訊至 Cloudflare 旗艦中繼站... ☁️');
      final audioUrl = await _uploadAudioViaRelay(audioFile);

      onProgressStatus?.call('Gladia 說話者分離與多語言辨識中... 🎙️');
      final jobId = await _createTranscriptionJobViaRelay(audioUrl);

      final result = await _pollTranscriptionResultViaRelay(
        jobId,
        onProgressStatus: onProgressStatus,
      );

      final text = result.toFormattedDiarizedText().trim();
      if (text.isNotEmpty) {
        debugPrint('GladiaTranscriptionService: Cloudflare Gladia 中繼轉錄成功 (${text.length} 字)');
        return result;
      } else {
        debugPrint('GladiaTranscriptionService: Cloudflare Gladia 回傳空白文字，啟用備援...');
        errorLogs.add('Gladia 未偵測到人聲內容（請錄製 3 秒以上語音）');
      }
    } catch (e) {
      debugPrint('GladiaTranscriptionService Cloudflare 中繼異常: $e，嘗試切換備援...');
      errorLogs.add('Cloudflare 中繼: ${e.toString().replaceAll('Exception:', '').trim()}');
    }

    // ----------------------------------------------------
    // 順位 2：Gladia V2 官方直連 (若本機配置有 GLADIA_API_KEY)
    // ----------------------------------------------------
    final gladiaKey = _kGladiaApiKey;
    if (gladiaKey.isNotEmpty) {
      try {
        onProgressStatus?.call('切換直連 Gladia 旗艦引擎... ☁️');
        final audioUrl = await _uploadAudioDirect(audioFile, gladiaKey);
        final resultUrl = await _createTranscriptionJobDirect(audioUrl, gladiaKey);
        final result = await _pollTranscriptionResultDirect(
          resultUrl,
          gladiaKey,
          onProgressStatus: onProgressStatus,
        );

        final text = result.toFormattedDiarizedText().trim();
        if (text.isNotEmpty) {
          debugPrint('GladiaTranscriptionService: Gladia 直連轉錄成功 (${text.length} 字)');
          return result;
        } else {
          errorLogs.add('Gladia 直連無字詞產出');
        }
      } catch (e) {
        debugPrint('GladiaTranscriptionService Gladia 直連異常: $e');
        errorLogs.add('Gladia 直連: ${e.toString().replaceAll('Exception:', '').trim()}');
      }
    }

    // ----------------------------------------------------
    // 順位 3：Groq Whisper 極速引擎 (whisper-large-v3-turbo，200ms 極速繁中識別)
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
        errorLogs.add('Groq Whisper: ${e.toString().replaceAll('Exception:', '').trim()}');
      }
    }

    // ----------------------------------------------------
    // 順位 4：Gemini 2.5 Flash 原生音訊多模態辨識 (gemini-2.5-flash)
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
        errorLogs.add('Gemini: ${e.toString().replaceAll('Exception:', '').trim()}');
      }
    }

    // 若所有引擎均無法識別出內容，附帶具體錯誤原因
    final details = errorLogs.isNotEmpty ? '（${errorLogs.first}）' : '，請錄製 3 秒以上清晰說話內容';
    throw Exception('未能從音訊中識別出清晰人聲語音$details 🎙️');
  }

  /// 1. 透過 Cloudflare 中繼站上傳音訊檔案
  Future<String> _uploadAudioViaRelay(File audioFile) async {
    final uploadUri = Uri.parse('$_kGladiaRelayUrl/upload');
    final request = http.MultipartRequest('POST', uploadUri)
      ..headers['x-app-secret'] = _kAppClientSecret;

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
      onTimeout: () => throw TimeoutException('音訊上傳至 Cloudflare 中繼站超時'),
    );

    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('中繼站音訊上傳失敗 [${response.statusCode}]: ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final audioUrl = data['audio_url'] as String?;
    if (audioUrl == null || audioUrl.isEmpty) {
      throw Exception('中繼站未取得 Gladia audio_url');
    }
    return audioUrl;
  }

  /// 2. 透過 Cloudflare 中繼站發起轉錄任務
  Future<String> _createTranscriptionJobViaRelay(String audioUrl) async {
    final preRecordedUri = Uri.parse('$_kGladiaRelayUrl/pre-recorded');
    final requestBody = jsonEncode({
      'audio_url': audioUrl,
      'diarization': true,
      'diarization_config': {
        'min_speakers': 1,
        'max_speakers': 6,
      },
      'language_config': {
        'code_switching': true,
        'languages': ['zh', 'en'],
      },
    });

    final response = await http
        .post(
      preRecordedUri,
      headers: {
        'x-app-secret': _kAppClientSecret,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: requestBody,
    )
        .timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('中繼站轉錄任務建立超時'),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('中繼站轉錄任務建立失敗 [${response.statusCode}]: ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final id = data['id'] as String?;
    if (id != null && id.isNotEmpty) {
      return id;
    }
    final resultUrl = data['result_url'] as String?;
    if (resultUrl != null && resultUrl.isNotEmpty) {
      final lastSeg = resultUrl.split('/').where((s) => s.isNotEmpty).last;
      return lastSeg;
    }
    throw Exception('中繼站未取得任務識別碼');
  }

  /// 3. 透過 Cloudflare 中繼站輪詢轉錄結果
  Future<GladiaTranscriptionResult> _pollTranscriptionResultViaRelay(
    String jobId, {
    void Function(String statusMessage)? onProgressStatus,
  }) async {
    const int maxAttempts = 60;
    int attempt = 0;
    final pollUri = Uri.parse('$_kGladiaRelayUrl/result/$jobId');

    while (attempt < maxAttempts) {
      attempt++;
      await Future.delayed(const Duration(milliseconds: 1000));

      try {
        final response = await http.get(
          pollUri,
          headers: {'x-app-secret': _kAppClientSecret},
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final status = data['status'] as String?;

          if (status == 'done') {
            return _parseGladiaDoneResult(data);
          } else if (status == 'error') {
            throw Exception('Gladia 轉錄處理失敗: ${data['error']}');
          } else {
            if (attempt % 3 == 0) {
              onProgressStatus?.call('Gladia 正在辨識說話者與字詞中 (${attempt}s)...');
            }
          }
        }
      } catch (e) {
        debugPrint('Gladia relay polling error on attempt $attempt: $e');
        if (attempt >= maxAttempts) rethrow;
      }
    }
    throw TimeoutException('Gladia 轉錄處理逾時');
  }

  /// 備援：直連 Gladia 上傳
  Future<String> _uploadAudioDirect(File audioFile, String apiKey) async {
    final uploadUri = Uri.parse('$_kGladiaDirectBaseUrl/upload');
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
      onTimeout: () => throw TimeoutException('音訊直連上傳超時'),
    );

    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Gladia 直連上傳失敗 [${response.statusCode}]: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final audioUrl = data['audio_url'] as String?;
    if (audioUrl == null || audioUrl.isEmpty) {
      throw Exception('未取得 Gladia audio_url');
    }
    return audioUrl;
  }

  /// 備援：直連 Gladia 發起任務
  Future<String> _createTranscriptionJobDirect(String audioUrl, String apiKey) async {
    final preRecordedUri = Uri.parse('$_kGladiaDirectBaseUrl/pre-recorded');
    final requestBody = jsonEncode({
      'audio_url': audioUrl,
      'diarization': true,
      'diarization_config': {
        'min_speakers': 1,
        'max_speakers': 6,
      },
      'language_config': {
        'code_switching': true,
        'languages': ['zh', 'en'],
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
      onTimeout: () => throw TimeoutException('Gladia 直連任務建立超時'),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Gladia 直連任務建立失敗 [${response.statusCode}]: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final resultUrl = data['result_url'] as String?;
    if (resultUrl == null || resultUrl.isEmpty) {
      final id = data['id'] as String?;
      if (id != null && id.isNotEmpty) {
        return '$_kGladiaDirectBaseUrl/pre-recorded/$id';
      }
      throw Exception('未取得 Gladia result_url');
    }
    return resultUrl;
  }

  /// 備援：直連 Gladia 輪詢
  Future<GladiaTranscriptionResult> _pollTranscriptionResultDirect(
    String resultUrl,
    String apiKey, {
    void Function(String statusMessage)? onProgressStatus,
  }) async {
    const int maxAttempts = 60;
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
            return _parseGladiaDoneResult(data);
          } else if (status == 'error') {
            throw Exception('Gladia 轉錄處理失敗: ${data['error']}');
          } else {
            if (attempt % 3 == 0) {
              onProgressStatus?.call('Gladia 正在辨識說話者與字詞中 (${attempt}s)...');
            }
          }
        }
      } catch (e) {
        debugPrint('Gladia direct polling error on attempt $attempt: $e');
        if (attempt >= maxAttempts) rethrow;
      }
    }
    throw TimeoutException('Gladia 轉錄處理逾時');
  }

  /// 解析 Gladia 成功成果
  GladiaTranscriptionResult _parseGladiaDoneResult(Map<String, dynamic> data) {
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
      model: 'gemini-3.6-flash',
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
