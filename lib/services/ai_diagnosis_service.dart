import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'app_locale_service.dart';

class AssistantResponseChunk {
  final String text;
  final String model; // 'gemini' or 'openrouter'
  AssistantResponseChunk(this.text, this.model);
}

class DiagnosisResult {
  final String summary;
  final List<String> strengths;
  final List<String> weaknesses;
  final String suggestion;
  final String encouragement;
  final bool isAiGenerated;

  DiagnosisResult({
    required this.summary,
    required this.strengths,
    required this.weaknesses,
    required this.suggestion,
    required this.encouragement,
    required this.isAiGenerated,
  });

  factory DiagnosisResult.fromJson(
    Map<String, dynamic> json, {
    bool isAiGenerated = true,
  }) {
    return DiagnosisResult(
      summary: json['summary'] ?? '',
      strengths: List<String>.from(json['strengths'] ?? []),
      weaknesses: List<String>.from(json['weaknesses'] ?? []),
      suggestion: json['suggestion'] ?? '',
      encouragement: json['encouragement'] ?? '',
      isAiGenerated: isAiGenerated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'strengths': strengths,
      'weaknesses': weaknesses,
      'suggestion': suggestion,
      'encouragement': encouragement,
      'isAiGenerated': isAiGenerated,
    };
  }
}

class AiDiagnosisService {
  static String get _kSystemGeminiApiKey {
    try {
      final key = dotenv.env['GEMINI_API_KEY'];
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    return '';
  }

  static String get _kOpenRouterApiKey {
    try {
      final key = dotenv.env['OPENROUTER_API_KEY'];
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    const envKey = String.fromEnvironment('OPENROUTER_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    return '';
  }

  static String get _kGroqApiKey {
    try {
      final key = dotenv.env['GROQ_API_KEY'];
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    const envKey = String.fromEnvironment('GROQ_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    return '';
  }

  static DateTime? nextAvailableTime;

  static const String _kCloudflareProxyUrl =
      'https://ai-app-proxy.adenlee36.workers.dev';

  /// 呼叫 Cloudflare 雲端中繼站 (支援 Groq, OpenRouter, Gemini)
  static Future<String?> _tryCloudflareProxy({
    required String provider,
    required String prompt,
    String? model,
    int timeoutSeconds = 15,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_kCloudflareProxyUrl),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'provider': provider,
          if (model != null) 'model': model,
          'prompt': prompt,
        }),
      ).timeout(Duration(seconds: timeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String? rawText;
        if (provider == 'groq' || provider == 'openrouter') {
          rawText = data['choices']?[0]?['message']?['content'] as String?;
        } else {
          rawText = data['candidates']?[0]?['content']?['parts']?[0]?['text']
              as String?;
        }
        if (rawText != null) {
          return _cleanMarkdown(rawText);
        }
        return null;
      } else {
        debugPrint(
            'Cloudflare Proxy Error [${response.statusCode}]: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudflare Proxy Exception: $e');
      return null;
    }
  }

  static String _cleanMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'\1')
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^\s*\*\s+', multiLine: true), '• ')
        .trim();
  }

  /// 呼叫 AI 進行 APP 導覽與對答 (優先使用 Groq 超高速零成本引擎，失敗退至 OpenRouter / Gemini)
  static Stream<AssistantResponseChunk> generateOpenRouterGuideStream({
    required String userInput,
    required List<Map<String, dynamic>> history,
    String? customSystemPrompt,
    String? customModel,
  }) async* {
    // 系統提示詞：定義導覽員的角色與對答規則
    final systemInstruction = customSystemPrompt ??
        '''
你是「代理人助理」，這款學習 APP 專屬的個人智慧特助。

【雙重職責與回答原則】
1. 💡 協助 APP 功能操作：
   - 當使用者想執行功能（如新增行程、發貼文、測驗診斷、筆記管理、修改設定）或詢問 APP 功能時，請以【條理分明、簡潔點列】的方式引導，並提示具體觸發關鍵字（例如：直接說「新增行程」）。
2. 💬 日常對問與生活關懷：
   - 當使用者進行日常寒暄、心情抒發、學科常識問答或讀書鼓勵時，請以【溫暖口語、親切自然】的方式回答（約 2-3 句），可適時結合 APP 功能給予貼心關懷。

【本 APP 支援的功能與對應觸發關鍵字】
1. 📅 日曆行程與待辦：管理個人行程與任務（直接輸入「新增行程」、「新增待辦」、「修改行程」、「修改待辦」）。
2. 💬 社群交流：發布學習貼文、心得與互動（直接輸入「發貼文」）。
3. 📚 題庫與 AI 診斷：進行測驗並分析個人弱項（直接輸入「練習題庫」）。
4. 📓 個人筆記本：紀錄筆記與 AI 摘要整理（直接輸入「查看筆記本」、「新增筆記」、「整理筆記」）。
5. ⚙️ 個人設定：直接提示精確關鍵字，例如「修改密碼」、「修改暱稱」、「更換頭像」、「修改簡介」、「切換主題」、「字體大小」、「個人檔案」。

【排版與視覺規範】
- 語言：永遠使用繁體中文（Traditional Chinese），絕不使用簡體字。
- 字數控制：文字務必【精簡流暢】（整體控制在 80~120 字以內），避免長篇大論。
- 條列規範：列舉項目時請使用標準條列（• 或 1. 2.），Emoji 符號僅在重點處適度點綴 1-2 個（嚴禁過度堆疊）。
- 符號禁忌：絕對不使用任何類似星星的符號（如 ✨、⭐、🌟 等）。
''';

    // 組建對話訊息
    final messages = <Map<String, String>>[];
    messages.add({'role': 'system', 'content': systemInstruction});
    for (var msg in history.take(6)) {
      final isAi = msg['isAI'] == true;
      final text = msg['text'] as String? ?? '';
      if (text.isNotEmpty &&
          text != '⏳ 正在查詢中...' &&
          text != '⏳ 正在思考中...' &&
          msg['widgetType'] == null) {
        messages.add({'role': isAi ? 'assistant' : 'user', 'content': text});
      }
    }
    messages.add({'role': 'user', 'content': userInput});

    // 0. 若本地無設定 Key（例如實體手機 / 打包 APK），直接優先使用 Cloudflare 雲端中繼站 (避免空 Key 逾時卡住)
    if (_kGroqApiKey.trim().isEmpty &&
        _kOpenRouterApiKey.trim().isEmpty &&
        _kSystemGeminiApiKey.trim().isEmpty) {
      debugPrint('代理人助理：未偵測到本地 Key，直接優先使用 Cloudflare 雲端中繼站...');
      final fullPrompt = '$systemInstruction\n\n【使用者對話歷史與提問】\n$userInput';
      try {
        String? proxyText = await _tryCloudflareProxy(
          provider: 'groq',
          prompt: fullPrompt,
        );
        if (proxyText == null || proxyText.trim().isEmpty) {
          debugPrint('代理人助理：Groq 中繼失敗，切換 Gemini 中繼...');
          proxyText = await _tryCloudflareProxy(
            provider: 'gemini',
            prompt: fullPrompt,
          );
        }
        if (proxyText != null && proxyText.trim().isNotEmpty) {
          debugPrint('代理人助理：成功取得 Cloudflare 回應');
          yield AssistantResponseChunk(proxyText, 'proxy');
          return;
        }
      } catch (e) {
        debugPrint('Cloudflare 雲端中繼站直連失敗: $e');
      }
    }

    // 1. 嘗試本地 Groq (具備雙模型備援)
    if (_kGroqApiKey.trim().isNotEmpty) {
      final groqModels = [
        'llama-3.3-70b-versatile', // 旗艦高品質模型
        'llama-3.1-8b-instant', // 極速備援模型（幾無併發延遲）
      ];
      for (final gModel in groqModels) {
        debugPrint('代理人助理：啟動 Groq 超高速引擎 ($gModel)...');
        try {
          bool hasYielded = false;
          await for (final chunk in _tryGroqModel(
            model: gModel,
            messages: messages,
          )) {
            yield AssistantResponseChunk(chunk, 'groq');
            hasYielded = true;
          }
          if (hasYielded) return; // Groq 成功輸出，直接完成
        } catch (e) {
          debugPrint('Groq 模型 $gModel 失敗/超時（$e），嘗試下一個 Groq 備援模型...');
        }
      }
    }

    // 2. 嘗試本地 OpenRouter (僅在 Key 存在時調用，避免卡住)
    bool openRouterSucceeded = false;
    Exception? lastError;

    if (_kOpenRouterApiKey.trim().isNotEmpty) {
      final fallbackModels = [
        if (customModel != null && customModel.isNotEmpty) customModel,
        'google/gemma-4-26b-a4b-it:free',
        'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free',
        'nvidia/nemotron-3-ultra-550b-a55b:free',
        'poolside/laguna-s-2.1:free',
      ];

      for (final model in fallbackModels) {
        debugPrint('代理人助理：使用 OpenRouter 模型 $model');
        try {
          bool hasYielded = false;
          await for (final chunk in _tryOpenRouterModel(
            model: model,
            messages: messages,
          )) {
            yield AssistantResponseChunk(chunk, 'openrouter');
            hasYielded = true;
          }
          if (hasYielded) {
            openRouterSucceeded = true;
            break;
          }
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          debugPrint('OpenRouter 模型 $model 失敗（$e）...');
        }
      }
    }

    if (openRouterSucceeded) return;

    // 2. 備援救援機制：若 OpenRouter 免費模型均無回應或失敗，才調用官方 Gemini 2.5 Flash 救援
    final now = DateTime.now();
    bool useGemini = true;
    if (nextAvailableTime != null && nextAvailableTime!.isAfter(now)) {
      useGemini = false;
    }

    if (useGemini && _kSystemGeminiApiKey.isNotEmpty) {
      debugPrint('代理人助理：OpenRouter 免費模型均失敗，啟動官方 Gemini 2.5 Flash 進行救援');
      try {
        final model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: _kSystemGeminiApiKey,
          systemInstruction: Content.system(systemInstruction),
        );

        final geminiContents = <Content>[];
        for (var msg in history.take(6)) {
          final isAi = msg['isAI'] == true;
          final text = msg['text'] as String? ?? '';
          if (text.isNotEmpty &&
              text != '⏳ 正在查詢中...' &&
              text != '⏳ 正在思考中...' &&
              msg['widgetType'] == null) {
            geminiContents.add(
              isAi ? Content.model([TextPart(text)]) : Content.text(text),
            );
          }
        }
        geminiContents.add(Content.text(userInput));

        final responseStream = model
            .generateContentStream(geminiContents)
            .timeout(
              const Duration(seconds: 20),
              onTimeout: (sink) => sink.addError(Exception('Gemini 回應逾時（20s）')),
            );
        bool hasYielded = false;
        await for (final chunk in responseStream) {
          final text = chunk.text;
          if (text != null && text.isNotEmpty) {
            yield AssistantResponseChunk(text, 'gemini');
            hasYielded = true;
          }
        }
        if (hasYielded) return;
      } catch (e) {
        debugPrint('官方 Gemini 救援失敗（$e）');
        lastError = e is Exception ? e : Exception(e.toString());
        if (e.toString().contains('429') ||
            e.toString().contains('RESOURCE_EXHAUSTED')) {
          nextAvailableTime = DateTime.now().add(const Duration(seconds: 30));
        }
      }
    }

    // 最終防護線：嘗試 Cloudflare 雲端中繼站 (支援 Groq 與 Gemini 雙重備援)
    try {
      debugPrint('代理人助理：嘗試 Cloudflare 雲端中繼站 (Groq)...');
      final fullPrompt = '$systemInstruction\n\n【使用者問題】\n$userInput';
      String? proxyText = await _tryCloudflareProxy(
        provider: 'groq',
        prompt: fullPrompt,
      );
      if (proxyText == null || proxyText.isEmpty) {
        debugPrint('代理人助理：Groq 中繼失敗，嘗試 Cloudflare 雲端中繼站 (Gemini)...');
        proxyText = await _tryCloudflareProxy(
          provider: 'gemini',
          prompt: fullPrompt,
        );
      }
      if (proxyText != null && proxyText.isNotEmpty) {
        yield AssistantResponseChunk(proxyText, 'proxy');
        return;
      }
    } catch (e) {
      debugPrint('Cloudflare 中繼站失敗: $e');
    }

    throw lastError ?? Exception('所有 AI 助理模型均無法使用');
  }

  /// 呼叫 24H 智慧線上客服（專門解答 APP 操作、題庫測驗、AI 診斷、個人筆記與帳號設定等問題）
  static Stream<String> generateCustomerSupportStream({
    required String userInput,
    required List<Map<String, dynamic>> history,
  }) async* {
    final langDirective = AppLocaleService.getAiLanguageInstruction();
    final systemPrompt = '''
你是「YeBang 家教 APP」的專業 24 小時智慧線上客服專員（YeBang Support Agent）。
你的職責是親切、有條理地解答使用者在 APP 操作、功能使用、題庫練習、AI 診斷、個人筆記、行事曆排程與帳號設定等各方面的疑問。

【本 APP 核心功能知識庫】
1. 📚 題庫練習與測驗：
   - 支援國高中各學科練習與模擬試卷，作答完成後自動匯入「錯題本」。
   - 每道題目附有解析，並可點擊「AI 詳解」獲取深入的步驟剖析與觀念釐清。
2. 📊 AI 學習診斷與個人化建議：
   - 「個人檔案」頁面提供知識掌握度矩陣圖與能力雷達圖。
   - 點擊矩陣圓點或「一鍵 AI 生成學習建議」，即可生成針對學生弱項的客製化補強教材。
3. 📓 個人筆記本：
   - 可建立筆記、標籤分類、搜尋，並支援「一鍵 AI 摘要整理」提取重點。
   - 測驗後的錯題也可一鍵同步為筆記。
4. 📅 智慧行事曆與待辦：
   - 可建立讀書計畫、新增與修改待辦事項，支援推播提醒。
5. 💬 社群交流：
   - 提供學生互相分享讀書心得、發布貼文與互動討論。
6. ⚙️ 個人設定與帳號安全：
   - 支援修改暱稱、頭像、個人簡介、切換深色/淺色主題、字體大小、通知開關。
   - 帳號綁定 Email 為主要登入識別，密碼可在「設定與安全」修改。
   - 若遇到無法解決的技術問題或需人工協助，可引導使用者至「客服與意見回饋」填寫表單。

【回答規範】
- $langDirective
- 語氣親切溫暖、條理清晰（例如適度條列重點）。
- 重要名詞或步驟請以雙星號 (**) 標示（例如：**個人檔案** > **設定與安全**）。
- 內容精簡明瞭（約 100~200 字），避免冗長廢話。
''';

    await for (final chunk in generateOpenRouterGuideStream(
      userInput: userInput,
      history: history,
      customSystemPrompt: systemPrompt,
    )) {
      if (chunk.text.isNotEmpty) {
        yield chunk.text;
      }
    }
  }

  /// 內部輔助：向指定模型發送串流請求，每個 chunk 逐一 yield。
  static Stream<String> _tryOpenRouterModel({
    required String model,
    required List<Map<String, String>> messages,
    int maxTokens = 300,
  }) async* {
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    final client = http.Client();
    final request = http.Request('POST', url);
    request.headers.addAll({
      'Authorization': 'Bearer $_kOpenRouterApiKey',
      'Content-Type': 'application/json; charset=utf-8',
      'HTTP-Referer': 'https://hihi-app.local',
      'X-Title': 'HiHi Assistant',
    });
    request.bodyBytes = utf8.encode(jsonEncode({
      'model': model,
      'stream': true,
      'messages': messages,
      'max_tokens': maxTokens,
      'temperature': 0.7,
    }));

    try {
      // 連線 Timeout：8 秒（快速失敗，讓外層可在 45s 內嘗試多個模型）
      final response = await client.send(request).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw Exception('OpenRouter 請求逾時（8s）'),
          );

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        throw Exception(
          'OpenRouter API 錯誤 [${response.statusCode}]: $errorBody',
        );
      }

      final byteStream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 12), onTimeout: (sink) {
        sink.addError(Exception('OpenRouter 串流讀取逾時（12s）'));
      });

      int chunkCount = 0;
      await for (final line in byteStream) {
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6).trim();
          if (dataStr == '[DONE]') break;

          try {
            final json = jsonDecode(dataStr);
            final content =
                json['choices']?[0]?['delta']?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
              chunkCount++;
            }
          } catch (_) {
            // 忽略個別行解析錯誤，不中斷串流
          }
        }
      }

      if (chunkCount == 0) {
        throw Exception('OpenRouter 模型 $model 回傳 0 個文字區塊');
      }
    } catch (e) {
      debugPrint('_tryOpenRouterModel ($model) error: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  /// 內部輔助：向 Groq 發送極速串流請求
  static Stream<String> _tryGroqModel({
    required String model,
    required List<Map<String, String>> messages,
    int maxTokens = 220,
  }) async* {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final client = http.Client();
    final request = http.Request('POST', url);
    request.headers.addAll({
      'Authorization': 'Bearer $_kGroqApiKey',
      'Content-Type': 'application/json; charset=utf-8',
    });
    request.bodyBytes = utf8.encode(jsonEncode({
      'model': model,
      'stream': true,
      'messages': messages,
      'max_tokens': maxTokens,
      'temperature': 0.5,
    }));

    try {
      final response = await client.send(request).timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw Exception('Groq 請求逾時（12s）'),
          );

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        throw Exception(
          'Groq API 錯誤 [${response.statusCode}]: $errorBody',
        );
      }

      final byteStream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 12), onTimeout: (sink) {
        sink.addError(Exception('Groq 串流讀取逾時（12s）'));
      });

      int chunkCount = 0;
      await for (final line in byteStream) {
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6).trim();
          if (dataStr == '[DONE]') break;

          try {
            final json = jsonDecode(dataStr);
            final content =
                json['choices']?[0]?['delta']?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
              chunkCount++;
            }
          } catch (_) {}
        }
      }

      if (chunkCount == 0) {
        throw Exception('Groq 模型 $model 回傳 0 個文字區塊');
      }
    } catch (e) {
      debugPrint('_tryGroqModel ($model) error: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 原有非串流版本（保留 fallback 用）
  // ─────────────────────────────────────────────────────────────────────────

  static Future<DiagnosisResult> generate({
    required String userId,
    required List<Map<String, dynamic>> wrongQuestions,
    required List<Map<String, dynamic>> correctQuestions,
    required int score,
    required int total,
    required String subject,
  }) async {
    if (userId == 'u4') {
      debugPrint('Guest user u4 detected. Falling back to local diagnosis.');
      return _generateLocalFallback(
        wrongQuestions: wrongQuestions,
        correctQuestions: correctQuestions,
        score: score,
        total: total,
        subject: subject,
      );
    }

    try {
      return await _callGeminiApi(
        apiKey: _kSystemGeminiApiKey,
        wrongQuestions: wrongQuestions,
        correctQuestions: correctQuestions,
        score: score,
        total: total,
        subject: subject,
      );
    } catch (e) {
      debugPrint('Error generating AI diagnosis: $e');
    }

    return _generateLocalFallback(
      wrongQuestions: wrongQuestions,
      correctQuestions: correctQuestions,
      score: score,
      total: total,
      subject: subject,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 新：串流版本（使用官方 google_generative_ai SDK）
  // ─────────────────────────────────────────────────────────────────────────

  /// 串流生成學習診斷報告，每個文字 chunk 逐一 yield。
  /// 訪客帳號直接 return 空串流。
  static Stream<String> generateStream({
    required String userId,
    required List<Map<String, dynamic>> wrongQuestions,
    required List<Map<String, dynamic>> correctQuestions,
    required int score,
    required int total,
    required String subject,
  }) async* {
    if (userId == 'u4') return;

    final wrongDetails = wrongQuestions.map((q) {
      final opts = q['options'] as List?;
      final ansIdx = q['answerIndex'] as int?;
      final correctAns = (opts != null &&
              ansIdx != null &&
              ansIdx >= 0 &&
              ansIdx < opts.length)
          ? opts[ansIdx]
          : '未知';
      return ' - 題目: ${q['question']}\n   單元/章節: ${q['chapter'] ?? '預設單元'}\n   難度: ${q['difficulty'] ?? '中'}\n   正確解答: $correctAns\n   解析: ${q['explanation'] ?? '無'}';
    }).join('\n');

    final correctDetails = correctQuestions.map((q) {
      return ' - 題目: ${q['question']}\n   單元/章節: ${q['chapter'] ?? '預設單元'}\n   難度: ${q['difficulty'] ?? '中'}';
    }).join('\n');

    // 使用固定段落標籤格式，方便串流後解析
    final prompt = '''
你是一個專業的 AI 學習診斷導師。請根據使用者的測驗結果，生成一份學習診斷報告。
請嚴格依照以下固定段落格式輸出純文字報告（禁止使用 JSON 或 Markdown 語法，禁止使用 ``` 代碼塊）：

[摘要]
（本次測驗整體表現摘要，1-2 句）

[弱項]
• 弱項描述1
• 弱項描述2

[建議]
（下一步具體可行的學習建議，2-3 句）

[鼓勵]
（一句充滿正面能量的激勵話語）

測驗資料如下：
- 科目：$subject
- 總題數：$total 題
- 答對題數：${correctQuestions.length} 題
- 答錯題數：${wrongQuestions.length} 題
- 分數：$score 分

答錯題目詳情：
$wrongDetails

答對題目詳情：
$correctDetails

請以繁體中文 (Traditional Chinese) 回答，切勿使用簡體字。
''';

    try {
      // 1. 本地 Groq (若有金鑰)
      if (_kGroqApiKey.isNotEmpty) {
        final groqModels = ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant'];
        for (final gModel in groqModels) {
          try {
            bool hasYielded = false;
            await for (final chunk in _tryGroqModel(
                    model: gModel,
                    messages: [{'role': 'user', 'content': prompt}],
                    maxTokens: 1024)
                .timeout(const Duration(seconds: 6))) {
              yield chunk;
              hasYielded = true;
            }
            if (hasYielded) return;
          } catch (_) {}
        }
      }

      // 2. Cloudflare Groq 中繼站
      try {
        final proxyText = await _tryCloudflareProxy(
          provider: 'groq',
          prompt: prompt,
          timeoutSeconds: 8,
        );
        if (proxyText != null && proxyText.isNotEmpty) {
          yield proxyText;
          return;
        }
      } catch (_) {}

      // 3. Gemini 直連
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _kSystemGeminiApiKey,
      );
      final contentStream = model.generateContentStream([Content.text(prompt)]);
      await for (final chunk in contentStream.timeout(const Duration(seconds: 8))) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }
    } on GenerativeAIException catch (e) {
      debugPrint('Gemini stream error: $e');
      // 若是 429，更新冷卻時間
      if (e.message.contains('429') ||
          e.message.contains('RESOURCE_EXHAUSTED')) {
        nextAvailableTime = DateTime.now().add(const Duration(seconds: 60));
      }
      rethrow;
    } catch (e) {
      debugPrint('Unexpected stream error: $e');
      rethrow;
    }
  }

  /// 將串流結束後的完整純文字解析成 DiagnosisResult。
  static DiagnosisResult parseStreamedText(String fullText) {
    String extract(String tag) {
      final start = fullText.indexOf('[$tag]');
      if (start == -1) return '';
      final contentStart = start + tag.length + 2; // 跳過 [tag]\n
      // 找下一個標籤
      final tagPattern = RegExp(r'\[.+?\]');
      final match = tagPattern.firstMatch(fullText.substring(contentStart));
      final end = match != null ? contentStart + match.start : fullText.length;
      return fullText.substring(contentStart, end).trim();
    }

    List<String> extractList(String tag) {
      final raw = extract(tag);
      if (raw.isEmpty) return [];
      return raw
          .split('\n')
          .map((l) => l.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim())
          .where((l) => l.isNotEmpty)
          .toList();
    }

    final summary = extract('摘要');
    final weaknesses = extractList('弱項');
    final suggestion = extract('建議');
    final encouragement = extract('鼓勵');

    // 若解析完全失敗，回傳原始文字作為摘要
    if (summary.isEmpty && weaknesses.isEmpty) {
      return DiagnosisResult(
        summary: fullText.trim().isNotEmpty ? fullText.trim() : '診斷完成，請參考上方內容。',
        strengths: const [],
        weaknesses: const [],
        suggestion: '',
        encouragement: '',
        isAiGenerated: true,
      );
    }

    return DiagnosisResult(
      summary: summary,
      strengths: const [],
      weaknesses: weaknesses,
      suggestion: suggestion,
      encouragement: encouragement,
      isAiGenerated: true,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 學習建議：串流生成個人化學習建議
  // ─────────────────────────────────────────────────────────────────────────

  /// 串流生成 AI 學習建議（根據錯題資料或掌握度，生成個人化弱項摘要、觀念重點與練習題目）
  static Stream<String> generateRemedialMaterialStream({
    required String userId,
    required String subject,
    required List<Map<String, dynamic>> wrongQuestions,
    bool hasRealMistakes = true,
    bool isComprehensive = false,
  }) async* {
    final subjectLabel = '$subject${isComprehensive ? '（全科盲點彙整）' : ''}';

    String prompt;
    if (hasRealMistakes && wrongQuestions.isNotEmpty) {
      final wrongDetails = wrongQuestions.take(5).map((q) {
        final optsRaw = q['options'];
        List? opts;
        if (optsRaw is String) {
          try {
            opts = jsonDecode(optsRaw) as List;
          } catch (_) {}
        } else if (optsRaw is List) {
          opts = optsRaw;
        }
        final ansIdx = q['answerIndex'] as int?;
        final correctAns = (opts != null &&
                ansIdx != null &&
                ansIdx >= 0 &&
                ansIdx < opts.length)
            ? opts[ansIdx].toString()
            : (q['answer'] as String? ?? '未知');
        return '• 題目：${q['question'] ?? q['text'] ?? ''}\n  章節：${q['chapter'] ?? '未知'}\n  難度：${q['difficulty'] ?? '中'}\n  正確答案：$correctAns\n  解析提示：${q['explanation'] ?? '無'}';
      }).join('\n\n');

      prompt = '''
你是一位專業的 AI 補強教師。請根據以下學生在【$subjectLabel】的真實測驗錯題資料，精確分析學生的盲點並給予關鍵補強建議。

學生錯題資料：
$wrongDetails

請嚴格依照以下固定格式輸出，內容務必精練（總字數控制在 250 字內）。禁止使用 JSON 或 Markdown 程式碼區塊，但請務必使用雙星號 (**) 來標示重點關鍵字（例如：**關鍵觀念**）：

[弱項摘要]
（根據錯題資料，用 1-2 句話精確概括學生的主要弱點與盲點）

[觀念重點]
• 重點一（針對錯題核心觀念的解題補強與觀念解析）
• 重點二

${AppLocaleService.getAiLanguageInstruction()}
''';
    } else {
      prompt = '''
你是一位專業的 AI 學習導師。學生目前在【$subjectLabel】科目掌握度良好（測驗表現優異或無近期錯題），請為學生整理該科目的核心精華觀念與進階學習方向。

請嚴格依照以下固定格式輸出，內容務必精練（總字數控制在 250 字內）。禁止使用 JSON 或 Markdown 程式碼區塊，但請務必使用雙星號 (**) 來標示重點關鍵字（例如：**核心考點**）：

[弱項摘要]
學生目前在該科目掌握度優異，暫無明顯錯題盲點。建議持續保持手感，著重在核心概念的融會貫通與進階難題挑戰。

[觀念重點]
• 重點一（該科目的必考核心精華觀念與常見題型突破點）
• 重點二

${AppLocaleService.getAiLanguageInstruction()}
''';
    }

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': '你是一位專業的個人化 AI 補強教師，擅長根據學生弱點生成針對性學習建議。請嚴格遵守輸出格式。'
      },
      {'role': 'user', 'content': prompt},
    ];

    // 1. 優先嘗試 Gemini（Google 官方，品質穩定）- 15秒超時
    final now = DateTime.now();
    if (_kSystemGeminiApiKey.isNotEmpty &&
        (nextAvailableTime == null || !nextAvailableTime!.isAfter(now))) {
      debugPrint('學習建議：啟動 Gemini...');
      try {
        final model = GenerativeModel(
            model: 'gemini-2.5-flash', apiKey: _kSystemGeminiApiKey);
        bool hasYielded = false;
        await for (final chunk in model.generateContentStream(
            [Content.text(prompt)]).timeout(const Duration(seconds: 15))) {
          final text = chunk.text;
          if (text != null && text.isNotEmpty) {
            yield text;
            hasYielded = true;
          }
        }
        if (hasYielded) return;
      } catch (e) {
        debugPrint('學習建議 Gemini 失敗: $e');
      }
    }

    // 2. 備援：嘗試速度最快的 Groq（15秒超時）
    if (_kGroqApiKey.isNotEmpty) {
      debugPrint('學習建議：嘗試 Groq 備援...');
      try {
        bool hasYielded = false;
        await for (final chunk in _tryGroqModel(
                model: 'llama-3.3-70b-versatile',
                messages: messages,
                maxTokens: 550)
            .timeout(const Duration(seconds: 15))) {
          yield chunk;
          hasYielded = true;
        }
        if (hasYielded) return;
      } catch (e) {
        debugPrint('學習建議 Groq 失敗: $e');
      }
    }

    // 3. 雲端中繼站備援 (適合實體手機無本機 Key 時)
    try {
      debugPrint('學習建議：嘗試 Cloudflare 雲端中繼站...');
      final proxyText = await _tryCloudflareProxy(
        provider: 'groq',
        prompt: prompt,
      );
      if (proxyText != null && proxyText.isNotEmpty) {
        yield proxyText;
        return;
      }
    } catch (e) {
      debugPrint('學習建議 Cloudflare 中繼站失敗: $e');
    }

    // 4. 本地高品質智能備援教材（100% 成功保證，絕不受連線限制）
    debugPrint('學習建議：啟動本地高品質備援生成...');
    final localMaterial = '''
[弱項摘要]
針對 $subject 核心觀念與常見題型進行強化解構，協助鞏固基礎定理並建立正確的解題思維邏輯。

[觀念重點]
• 重點一：審題時先抓出核心關鍵字與已知條件，避免盲目帶入公式。
• 重點二：理解解題步驟背後的邏輯意涵，多做同類型題目的觀念對比。
''';

    yield localMaterial;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 筆記整理：保留原有版本 + 新增串流版本
  // ─────────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> generateNoteSummary({
    required String userId,
    required String noteTitle,
    required String noteContent,
  }) async {
    if (userId == 'u4') {
      return {
        'points': ['訪客帳戶無法使用 AI 整理功能，請登入正式帳戶。'],
        'actions': [],
        'isAiGenerated': false,
      };
    }

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_kSystemGeminiApiKey',
      );

      final prompt = '''
你是一個專業的學習筆記整理小助手。請閱讀使用者的筆記內容，並將其整理為一份簡短、精煉且結構分明的重點大綱。
你不需要進行強制字元裁切，但請以你的專業判斷，用最精簡、通順且完整的句子來陳述核心要點，並避免照抄原文的大段落。
重點摘要（points）建議控制在 3-4 點，行動建議（actions）建議控制在 2-3 點。

你必須只回傳一個 JSON 物件，格式如下，且不得包含額外的 Markdown 標籤（如 ```json）或任何前導/後續文字：
{
  "points": [
    "重點摘要 1",
    "重點摘要 2",
    "重點摘要 3"
  ],
  "actions": [
    "行動建議 1",
    "行動建議 2"
  ]
}

筆記標題：$noteTitle
筆記內容：
$noteContent

${AppLocaleService.getAiLanguageInstruction()}
''';

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {'responseMimeType': 'application/json'},
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final text = resJson['candidates']?[0]?['content']?['parts']?[0]
            ?['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          final decoded = jsonDecode(text.trim());
          final List<String> points = List<String>.from(
            decoded['points'] ?? [],
          );
          final List<String> actions = List<String>.from(
            decoded['actions'] ?? [],
          );
          return {'points': points, 'actions': actions, 'isAiGenerated': true};
        }
      } else {
        if (response.statusCode == 429) {
          _updateNextAvailableTime(response.body);
        }
        debugPrint(
          'Gemini note summary error: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error calling Gemini for note summary: $e');
    }

    return _generateLocalNoteSummaryMap(noteContent);
  }

  /// 串流版筆記整理：逐字 yield 純文字，完成後由呼叫方解析。
  static Stream<String> generateNoteSummaryStream({
    required String userId,
    required String noteTitle,
    required String noteContent,
  }) async* {
    if (userId == 'u4') return;

    final prompt = '''
你是一個專業的學習筆記整理小助手。請閱讀使用者的筆記內容，生成重點摘要與行動建議。
請嚴格依照以下段落格式輸出（禁止使用 JSON 或 Markdown）：

[重點摘要]
• 摘要1
• 摘要2
• 摘要3

[行動建議]
• 建議1
• 建議2

筆記標題：$noteTitle
筆記內容：
$noteContent

${AppLocaleService.getAiLanguageInstruction()}
''';

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _kSystemGeminiApiKey,
      );
      final contentStream = model.generateContentStream([Content.text(prompt)]);
      await for (final chunk in contentStream.timeout(const Duration(seconds: 8))) {
        final text = chunk.text;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }
    } on GenerativeAIException catch (e) {
      debugPrint('Gemini note stream error: $e');
      if (e.message.contains('429') ||
          e.message.contains('RESOURCE_EXHAUSTED')) {
        nextAvailableTime = DateTime.now().add(const Duration(seconds: 60));
      }
      rethrow;
    } catch (e) {
      debugPrint('Unexpected note stream error: $e');
      rethrow;
    }
  }

  /// 解析串流筆記整理結果 → points / actions
  static Map<String, dynamic> parseStreamedNoteSummary(String fullText) {
    String extract(String tag) {
      final start = fullText.indexOf('[$tag]');
      if (start == -1) return '';
      final contentStart = start + tag.length + 2;
      final tagPattern = RegExp(r'\[.+?\]');
      final match = tagPattern.firstMatch(fullText.substring(contentStart));
      final end = match != null ? contentStart + match.start : fullText.length;
      return fullText.substring(contentStart, end).trim();
    }

    List<String> extractList(String tag) {
      final raw = extract(tag);
      if (raw.isEmpty) return [];
      return raw
          .split('\n')
          .map((l) => l.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim())
          .where((l) => l.isNotEmpty)
          .toList();
    }

    final points = extractList('重點摘要');
    final actions = extractList('行動建議');

    return {
      'points': points.isEmpty ? ['整理完成，請查看上方內容。'] : points,
      'actions': actions,
      'isAiGenerated': true,
    };
  }

  /// 分身對話串流：支援 Gemini SDK 及 Cloudflare 雲端中繼站備援（實體機無 Key 自動降級）
  static Stream<String> generateCloneStream({
    required String systemPrompt,
    required String userInput,
    required List<Map<String, dynamic>> history,
  }) async* {
    final String apiKey = _kSystemGeminiApiKey.trim();
    bool geminiSuccess = false;

    // 1. 若本地有 API Key，優先嘗試 Gemini SDK
    if (apiKey.isNotEmpty &&
        (nextAvailableTime == null || !nextAvailableTime!.isAfter(DateTime.now()))) {
      try {
        final model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
          systemInstruction: Content.system(systemPrompt),
        );

        final List<Content> contents = [];
        for (final msg in history) {
          final text = (msg['text'] as String? ?? '').trim();
          if (text.isEmpty) continue;
          final role = (msg['isAI'] as bool? ?? false) ? 'model' : 'user';
          contents.add(Content(role, [TextPart(text)]));
        }
        contents.add(Content.text(userInput));

        final contentStream = model.generateContentStream(contents).timeout(
              const Duration(seconds: 15),
              onTimeout: (sink) => sink.addError(Exception('Gemini 回應逾時（15s）')),
            );

        await for (final chunk in contentStream) {
          final text = chunk.text;
          if (text != null && text.isNotEmpty) {
            geminiSuccess = true;
            yield text;
          }
        }
        if (geminiSuccess) return;
      } catch (e) {
        debugPrint('Gemini clone stream error, switching to Cloudflare Proxy: $e');
        if (e.toString().contains('429') || e.toString().contains('RESOURCE_EXHAUSTED')) {
          nextAvailableTime = DateTime.now().add(const Duration(seconds: 60));
        }
      }
    }

    // 2. 本地無 Key 或 Gemini 連線失敗，自動無縫切換 Cloudflare 雲端中繼站 (Gemini / Groq)
    debugPrint('召喚分身：無本地 Key 或 Gemini 失敗，使用 Cloudflare 雲端中繼站...');

    final StringBuffer fullPrompt = StringBuffer();
    fullPrompt.writeln(systemPrompt);
    fullPrompt.writeln('\n【對話歷史與使用者提問】');
    for (final msg in history) {
      final text = (msg['text'] as String? ?? '').trim();
      if (text.isEmpty) continue;
      final role = (msg['isAI'] as bool? ?? false) ? '作者' : '使用者';
      fullPrompt.writeln('$role: $text');
    }
    fullPrompt.writeln('使用者: $userInput');
    fullPrompt.writeln('作者:');

    // 優先嘗試 Cloudflare Gemini
    String? responseText = await _tryCloudflareProxy(
      provider: 'gemini',
      prompt: fullPrompt.toString(),
    );

    // 備援：若 Cloudflare Gemini 失敗，嘗試 Cloudflare Groq
    responseText ??= await _tryCloudflareProxy(
      provider: 'groq',
      prompt: fullPrompt.toString(),
    );

    if (responseText != null && responseText.isNotEmpty) {
      yield responseText;
      return;
    }

    throw Exception('所有 AI 分身服務均無法回應，請檢查網路連線。');
  }

  static Map<String, dynamic> _generateLocalNoteSummaryMap(String content) {
    String cleanContent = content
        .replaceAll(RegExp(r'[#\*_\-\[\]]'), '')
        .replaceAll(RegExp(r'color=0x[0-9A-Fa-f]+'), '')
        .replaceAll(RegExp(r'\/color'), '')
        .trim();
    List<String> lines = cleanContent
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.length > 2)
        .toList();

    List<String> points = [];
    int count = 1;
    for (var line in lines) {
      String pt = line.replaceAll(RegExp(r'[#\n\r\-\*]'), '').trim();
      if (pt.isNotEmpty) {
        List<String> sentences = pt.split(RegExp(r'[。！？]'));
        String firstSentence = sentences[0].trim();
        if (firstSentence.isNotEmpty) {
          if (firstSentence.length > 60) {
            firstSentence = '${firstSentence.substring(0, 57)}...';
          } else {
            firstSentence = '$firstSentence。';
          }
          points.add('重點 $count：$firstSentence');
          count++;
        }
      }
      if (points.length >= 3) break;
    }

    if (points.isEmpty) {
      points.add('此筆記為空白內容，請補充細節。');
    }

    return {
      'points': points,
      'actions': ['複習筆記的核心概念，並進行相關的測驗練習。', '嘗試將重點整理成自己的文字，加深記憶。'],
      'isAiGenerated': false,
    };
  }

  static Future<DiagnosisResult> _callGeminiApi({
    required String apiKey,
    required List<Map<String, dynamic>> wrongQuestions,
    required List<Map<String, dynamic>> correctQuestions,
    required int score,
    required int total,
    required String subject,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    final wrongDetails = wrongQuestions.map((q) {
      final opts = q['options'] as List?;
      final ansIdx = q['answerIndex'] as int?;
      final correctAns = (opts != null &&
              ansIdx != null &&
              ansIdx >= 0 &&
              ansIdx < opts.length)
          ? opts[ansIdx]
          : '未知';
      return ' - 題目: ${q['question']}\n   單元/章節: ${q['chapter'] ?? '預設單元'}\n   難度: ${q['difficulty'] ?? '中'}\n   正確解答: $correctAns\n   解析: ${q['explanation'] ?? '無'}';
    }).join('\n');

    final correctDetails = correctQuestions.map((q) {
      return ' - 題目: ${q['question']}\n   單元/章節: ${q['chapter'] ?? '預設單元'}\n   難度: ${q['difficulty'] ?? '中'}';
    }).join('\n');

    final prompt = '''
你是一個專業的 AI 學習診斷導師。請根據使用者的測驗結果，生成一份結構化的學習診斷報告。
你必須只回傳一個 JSON 物件，格式如下，且不得包含額外的 Markdown 標籤（如 ```json）或任何前導/後續文字：
{
  "summary": "本次測驗整體表現摘要，描述本次測驗的精準表現（1-2 句）",
  "weaknesses": ["弱項 1", "弱項 2", ...],
  "suggestion": "下一步具體可行的學習建議，例如複習哪些觀念、加強哪類題目（2-3 句）",
  "encouragement": "一句充滿正面能量、溫暖且具體的激勵話語（1 句）"
}

測驗資料如下：
- 科目：$subject
- 總題數：$total 題
- 答對題數：${correctQuestions.length} 題
- 答錯題數：${wrongQuestions.length} 題
- 分數：$score 分

答錯題目詳情：
$wrongDetails

答對題目詳情：
$correctDetails

請以繁體中文 (Traditional Chinese) 回答，切勿使用簡體字。
''';

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {'responseMimeType': 'application/json'},
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final resJson = jsonDecode(response.body);
      final text = resJson['candidates']?[0]?['content']?['parts']?[0]?['text']
          as String?;
      if (text != null && text.trim().isNotEmpty) {
        final decoded = jsonDecode(text.trim());
        return DiagnosisResult.fromJson(decoded, isAiGenerated: true);
      }
    }

    if (response.statusCode == 429) {
      _updateNextAvailableTime(response.body);
    }

    throw Exception(
      'Failed to get response from Gemini API: ${response.statusCode} - ${response.body}',
    );
  }

  static DiagnosisResult _generateLocalFallback({
    required List<Map<String, dynamic>> wrongQuestions,
    required List<Map<String, dynamic>> correctQuestions,
    required int score,
    required int total,
    required String subject,
  }) {
    final Map<String, int> correctChapters = {};
    final Map<String, int> wrongChapters = {};

    for (var q in correctQuestions) {
      final ch = (q['chapter'] as String?)?.trim();
      if (ch != null && ch.isNotEmpty) {
        correctChapters[ch] = (correctChapters[ch] ?? 0) + 1;
      }
    }

    for (var q in wrongQuestions) {
      final ch = (q['chapter'] as String?)?.trim();
      if (ch != null && ch.isNotEmpty) {
        wrongChapters[ch] = (wrongChapters[ch] ?? 0) + 1;
      }
    }

    final List<String> weaknesses = [];

    wrongChapters.forEach((ch, count) {
      final cCount = correctChapters[ch] ?? 0;
      if (cCount == 0 || (cCount / (cCount + count)) < 0.6) {
        weaknesses.add('$ch (答錯 $count 題)');
      }
    });

    if (weaknesses.isEmpty) {
      if (score < 100 && wrongQuestions.isNotEmpty) {
        final firstCh = wrongQuestions.first['chapter'] as String?;
        weaknesses.add(
          firstCh != null && firstCh.isNotEmpty ? firstCh : '$subject 錯題觀念',
        );
      } else {
        weaknesses.add('本次測驗無明顯弱項，表現完美！');
      }
    }

    String summary;
    String suggestion;
    String encouragement;

    if (score == 100) {
      summary = '太棒了！本次「$subject」測驗獲得滿分，展現出極高的熟練度。';
      suggestion = '目前在此科目表現優異。建議可以挑戰更高難度的進階試題，或是協助同學解題以加深思考。';
      encouragement = '優秀的表現源於你的努力，繼續保持這股頂尖的學習狀態！';
    } else if (score >= 80) {
      summary = '本次「$subject」測驗表現亮眼，正確率達 $score%，已掌握大部分核心概念。';
      suggestion = '建議針對答錯的弱項觀念進行微調複習，並加強錯題的細節觀念。';
      encouragement = '距離完美只差一步，細心檢視錯題，你一定能突破極限！';
    } else if (score >= 60) {
      summary = '本次「$subject」測驗表現尚可，正確率為 $score%，基本概念已具備但仍不夠穩定。';
      suggestion =
          '你在部分單元表現稍顯薄弱，特別是 ${weaknesses.take(1).join()}。建議針對弱項章節的教科書/講義重新閱讀，並進行專題練習。';
      encouragement = '及格是個起點，持之以恆地複習弱項，分數一定會穩步上升！';
    } else {
      summary = '本次「$subject」測驗挑戰性較高，正確率為 $score%，有較多核心概念需要重溫。';
      suggestion =
          '目前 ${weaknesses.take(2).join('與')} 是需要首要加強的單元。建議從最基礎的課堂例題重新學起，並建立專屬的錯題本反覆練習。';
      encouragement = '挫折是學習的養分，找出不會的地方就是進步的機會，我們一起加油！';
    }

    return DiagnosisResult(
      summary: summary,
      strengths: const [],
      weaknesses: weaknesses,
      suggestion: suggestion,
      encouragement: encouragement,
      isAiGenerated: false,
    );
  }

  static String cleanAiExplanationText(String text) {
    return text
        .replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[\*\-]\s*\*\*([^*]+)\*\*\s*:\s*', multiLine: true), r'• 【$1】：')
        .replaceAll(RegExp(r'^\s*[\*\-]\s*', multiLine: true), '• ')
        .replaceAll('**', '')
        .trim();
  }

  static Stream<String> askQuestionExplanationStream({
    required String userId,
    required Map<String, dynamic> question,
    required int correctIndex,
    required int? chosenIndex,
  }) async* {
    if (userId == 'u4') {
      yield '訪客帳戶無法使用 AI 專屬解題功能，請登入正式帳戶以獲得完整解析。';
      return;
    }

    final qText = question['question'] ?? question['text'] ?? '';
    final rawOptions = question['options'];
    List<String> options = [];
    if (rawOptions is List) {
      options = rawOptions.map((e) => e.toString()).toList();
    } else if (rawOptions is String) {
      try {
        final decoded = jsonDecode(rawOptions);
        if (decoded is List) {
          options = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        options = rawOptions.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(',').map((e) => e.trim()).toList();
      }
    }
    
    final correctOpt = (correctIndex >= 0 && correctIndex < options.length) ? options[correctIndex] : '未知';
    final chosenOpt = (chosenIndex != null && chosenIndex >= 0 && chosenIndex < options.length) ? options[chosenIndex] : '未作答';

    final correctOptLetter = String.fromCharCode(65 + correctIndex);
    final chosenOptLetter = chosenIndex != null ? String.fromCharCode(65 + chosenIndex) : '無';

    final prompt = '''
你是一位極緻精煉、直擊考點的台灣 AI 考題導師。學生在練習選擇題時，需要「10 秒內能看完的精華觀念摘要」。

【精簡原則 - 嚴禁長篇大論與冗長贅述】
- 全文總字數請控制在 150 ~ 200 字以內，極致精華，直擊核心！
- 每一區塊只需 1~2 句簡短重點，絕對不講廢話。

【語言規範】
- ${AppLocaleService.getAiLanguageInstruction()}

【結構規範 - 請輸出以下 3 個精華區塊標題】
🎯 觀念精華：為什麼正確答案是 ($correctOptLetter)
• 1句話說明正確答案的【核心公式】或【原理觀念】。

🔍 迷思快剖：${chosenIndex != null ? '選擇 ($chosenOptLetter) 的盲點' : '常見作答陷阱'}
• 1~2點點出選錯原因或【常見混淆觀念】。

💡 一秒口訣：精闢記憶句
• 1句最精簡的【記憶口訣】或【高頻考點金句】。

【重點標籤規範】
- 僅在【核心觀念】或【公式名詞】使用【】粗括號標記，每區塊最多標記 1~2 個關鍵字。
- 條列請統一使用「• 」。

題目：$qText
選項：
${options.asMap().entries.map((e) => '${String.fromCharCode(65 + e.key)}. ${e.value}').join('\n')}

正確答案：$correctOptLetter. $correctOpt
學生作答：${chosenIndex != null ? '$chosenOptLetter. $chosenOpt' : '未作答'}

請直接開始精煉解析：
''';

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content':
            '你是一位專粹精煉的 AI 考題導師。${AppLocaleService.getAiLanguageInstruction()} 你說話極致精簡、只給精華幹貨，全文控制在 180 字內，用 🎯 觀念精華、🔍 迷思快剖、💡 一秒口訣 3 個卡片回答，絕不寫廢話長文。'
      },
      {'role': 'user', 'content': prompt},
    ];

    // 1. 優先：嘗試本地 Groq API
    if (_kGroqApiKey.isNotEmpty) {
      final groqModels = [
        'llama-3.3-70b-versatile',
        'llama-3.1-8b-instant',
      ];
      for (final gModel in groqModels) {
        debugPrint('AI 解析：嘗試本地 Groq 引擎 ($gModel)...');
        try {
          bool hasYielded = false;
          await for (final chunk in _tryGroqModel(
                  model: gModel,
                  messages: messages,
                  maxTokens: 1024)
              .timeout(const Duration(seconds: 4))) {
            yield chunk;
            hasYielded = true;
          }
          if (hasYielded) return;
        } catch (e) {
          debugPrint('AI 解析 Groq 模型 $gModel 失敗/逾時: $e');
        }
      }
    }

    // 2. 備援：發起 Cloudflare 雲端中繼站 (Groq 引擎)
    try {
      debugPrint('AI 解析：嘗試 Cloudflare 雲端中繼站 (Groq)...');
      final proxyText = await _tryCloudflareProxy(
        provider: 'groq',
        prompt: prompt,
        timeoutSeconds: 8,
      );
      if (proxyText != null && proxyText.isNotEmpty) {
        yield proxyText;
        return;
      }
    } catch (e) {
      debugPrint('AI 解析 Cloudflare Groq 中繼站失敗: $e');
    }

    // 3. 備援：嘗試 Gemini 直連
    final now = DateTime.now();
    if (_kSystemGeminiApiKey.isNotEmpty &&
        (nextAvailableTime == null || !nextAvailableTime!.isAfter(now))) {
      debugPrint('AI 解析：切換 Gemini 備援...');
      try {
        final model = GenerativeModel(
            model: 'gemini-2.5-flash', apiKey: _kSystemGeminiApiKey);
        bool hasYielded = false;
        await for (final chunk in model.generateContentStream(
            [Content.text(prompt)]).timeout(const Duration(seconds: 6))) {
          final text = chunk.text;
          if (text != null && text.isNotEmpty) {
            yield text;
            hasYielded = true;
          }
        }
        if (hasYielded) return;
      } catch (e) {
        debugPrint('AI 解析 Gemini 失敗: $e');
      }
    }

    // 4. 最終備援：Cloudflare Gemini 中繼站
    try {
      debugPrint('AI 解析：嘗試 Cloudflare 雲端中繼站 (Gemini)...');
      final proxyText = await _tryCloudflareProxy(
        provider: 'gemini',
        prompt: prompt,
        timeoutSeconds: 8,
      );
      if (proxyText != null && proxyText.isNotEmpty) {
        yield proxyText;
        return;
      }
    } catch (e) {
      debugPrint('AI 解析 Cloudflare Gemini 中繼站失敗: $e');
    }

    yield '目前 AI 助手似乎有點累了，無法連線為您解答。請檢查您的網路，稍後再試一次！';
  }

  static void _updateNextAvailableTime(String responseBody) {
    try {
      final json = jsonDecode(responseBody);
      final details = json['error']?['details'] as List?;
      if (details != null) {
        for (var detail in details) {
          if (detail['@type'] == 'type.googleapis.com/google.rpc.RetryInfo') {
            final delayStr = detail['retryDelay'] as String?;
            if (delayStr != null && delayStr.endsWith('s')) {
              final secondsStr = delayStr.substring(0, delayStr.length - 1);
              final seconds = double.tryParse(secondsStr)?.ceil() ?? 60;
              nextAvailableTime = DateTime.now().add(
                Duration(seconds: seconds),
              );
              return;
            }
          }
        }
      }
      nextAvailableTime = DateTime.now().add(const Duration(seconds: 60));
    } catch (_) {
      nextAvailableTime = DateTime.now().add(const Duration(seconds: 60));
    }
  }
}
