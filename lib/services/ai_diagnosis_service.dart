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

  /// Groq AI 預設使用的模型清單 (按優先順序排序)
  /// 【在這改 Groq 模型】
  static const List<String> _kGroqModels = [
    'openai/gpt-oss-120b', // Groq 官方新旗艦替代模型 (高速直出、無思考延遲)
    'gpt-oss-120b', // Groq 官方新旗艦 (相容無前綴 ID)
    'openai/gpt-oss-20b', // Groq 極速輕量直出模型 (~1000 T/s、毫秒反應)
    'gpt-oss-20b', // Groq 極速輕量 (相容無前綴 ID)
    'llama-3.1-8b-instant', // Groq 經典極速模型
    'qwen/qwen3.6-27b', // Qwen 深度推導模型 (思考模型置於最後備援)
    'qwen3.6-27b', // Qwen 相容 ID
  ];

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
      final response = await http
          .post(
            Uri.parse(_kCloudflareProxyUrl),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'provider': provider,
              if (model != null) 'model': model,
              'prompt': prompt,
            }),
          )
          .timeout(Duration(seconds: timeoutSeconds));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
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

  /// 自動將簡體字與大陸術語轉換為繁體中文與台灣慣用語
  static String toTraditionalChinese(String text) {
    if (text.isEmpty) return text;

    String result = text
        .replaceAll('笔记', '筆記')
        .replaceAll('关键词', '關鍵字')
        .replaceAll('检索', '檢索')
        .replaceAll('查找', '搜尋')
        .replaceAll('要点', '要點')
        .replaceAll('储存', '儲存')
        .replaceAll('存储', '儲存')
        .replaceAll('标签', '標籤')
        .replaceAll('错题', '錯題')
        .replaceAll('练习', '練習')
        .replaceAll('诊断', '診斷')
        .replaceAll('设置', '設定')
        .replaceAll('密码', '密碼')
        .replaceAll('登录', '登入')
        .replaceAll('计划', '計畫')
        .replaceAll('简介', '簡介')
        .replaceAll('个人', '個人')
        .replaceAll('档案', '檔案')
        .replaceAll('账号', '帳號')
        .replaceAll('页面', '頁面')
        .replaceAll('帮助', '幫助')
        .replaceAll('总结', '總結')
        .replaceAll('建议', '建議')
        .replaceAll('题目', '題目')
        .replaceAll('选项', '選項')
        .replaceAll('复习', '複習')
        .replaceAll('学习', '學習')
        .replaceAll('知识', '知識')
        .replaceAll('难度', '難度')
        .replaceAll('章节', '章節')
        .replaceAll('单元', '單元')
        .replaceAll('低代码', '低程式碼')
        .replaceAll('代码', '程式碼')
        .replaceAll('用户', '使用者')
        .replaceAll('界面', '介面')
        .replaceAll('网络', '網路')
        .replaceAll('项目', '項目')
        .replaceAll('点击', '點擊')
        .replaceAll('一键', '一鍵')
        .replaceAll('专员', '專員');

    const s2t = {
      '点': '點',
      '关': '關',
      '键': '鍵',
      '记': '記',
      '标': '標',
      '签': '籤',
      '错': '錯',
      '题': '題',
      '练': '練',
      '习': '習',
      '诊': '診',
      '断': '斷',
      '码': '碼',
      '录': '錄',
      '划': '劃',
      '简': '簡',
      '个': '個',
      '档': '檔',
      '账': '帳',
      '页': '頁',
      '帮': '幫',
      '总': '總',
      '结': '結',
      '议': '議',
      '难': '難',
      '单': '單',
      '库': '庫',
      '网': '網',
      '络': '絡',
      '专': '專',
      '业': '業',
      '门': '門',
      '开': '開',
      '发': '發',
      '统': '統',
      '计': '計',
      '实': '實',
      '现': '現',
      '创': '創',
      '减': '減',
      '杂': '雜',
      '时': '時',
      '间': '間',
      '构': '構',
      '选': '選',
      '择': '擇',
      '释': '釋',
      '观': '觀',
      '导': '導',
      '师': '師',
      '课': '課',
      '测': '測',
      '验': '驗',
      '试': '試',
      '卷': '卷',
      '准': '準',
      '备': '備',
      '查': '查',
      '询': '詢',
      '贴': '貼',
      '动': '動',
      '态': '態',
      '评': '評',
      '论': '論',
      '赞': '讚',
      '提': '提',
      '取': '取',
      '优': '優',
      '化': '化',
      '随': '隨',
      '与': '與',
      '给': '給',
      '为': '為',
      '这': '這',
      '么': '麼',
      '样': '樣',
      '里': '裡',
      '后': '後',
      '并': '並',
      '数': '數',
      '据': '據',
      '显': '顯',
      '示': '示',
      '输': '輸',
      '详': '詳',
      '细': '細',
      '步': '步',
      '骤': '驟',
      '图': '圖',
      '历': '歷',
      '程': '程',
      '待': '待',
      '办': '辦',
      '获': '獲',
      '得': '得',
      '连': '連',
      '线': '線',
      '轻': '輕',
      '松': '鬆',
      '进': '進',
      '行': '行',
      '快': '快',
      '速': '速',
      '重': '重',
      '类': '類',
      '型': '型',
    };

    final buffer = StringBuffer();
    for (int i = 0; i < result.length; i++) {
      final char = result[i];
      buffer.write(s2t[char] ?? char);
    }
    return buffer.toString();
  }

  /// 移除 AI 模型（包含 Reasoning/Thinking 模型）輸出的內部思考過程塊 <think>...</think>，過濾 ** 星號為美觀括號，並強制繁體中文
  static String cleanThinkingTags(String text) {
    if (text.isEmpty) return text;
    String cleaned = text
        .replaceAll(
            RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<think>[\s\S]*$', caseSensitive: false), '')
        .replaceAll(
            RegExp(r'^<think>.*$', caseSensitive: false, multiLine: true), '')
        .replaceAllMapped(
            RegExp(r'^\s*\*\*\s*([^*]+?)\s*\*\*\s*$', multiLine: true),
            (m) => '【${m.group(1)}】')
        .replaceAllMapped(
            RegExp(r'\*\*([^*]+?)\*\*'),
            (m) => '【${m.group(1)}】')
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^\s*[\*\-]\s+', multiLine: true), '• ')
        .replaceAll(RegExp(r'\[\$[0-9]+\]|【\$[0-9]+】|\$[0-9]+'), '');
    return toTraditionalChinese(cleaned.trim());
  }

  static String _cleanMarkdown(String text) {
    return cleanThinkingTags(text);
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
你是「YeBang 家教學習 APP」的個人智慧特助「代理人助理」。你是一位精練有禮、親切友好、直擊重點的學習好夥伴。

【回答核心原則：精簡扼要、直擊核心】
- 字數嚴格控制在【80 ~ 120 字以內】，精闢講重點，拒絕冗長鋪墊與廢話。
- 先用 1 句精華定義核心概念，再用 2~3 點簡短重點（• ）說明關鍵要素，讓使用者 10 秒內快速吸收。
- 語氣友好親切大方（稱呼「你」），使用台灣繁體中文習慣用語（例如：「低程式碼 (Low-Code)」）。
- 嚴禁在句首生硬堆疊「喔😊」等做作語氣詞，直接自然切入重點。

【功能操作引導】
當使用者詢問或想執行 APP 功能時，1~2 句簡要說明並提示觸發關鍵字：
1. 📓 個人筆記本（關鍵字：「新增筆記」、「查看筆記本」、「整理筆記」）
2. ⚙️ 個人設定（關鍵字：「修改密碼」、「修改暱稱」、「更換頭像」、「個人檔案」）
3. 📅 日曆與待辦（關鍵字：「新增行程」、「新增待辦」、「修改行程」）
4. 📚 題庫測驗（關鍵字：「練習題庫」、「做測驗」）
5. 💬 社群交流（關鍵字：「發貼文」、「看動態」）

【排版與語言】
- 永遠使用繁體中文（Traditional Chinese），絕不使用簡體字。
- 條列使用標準符號（• ），Emoji 適度點綴 1-2 個，保持版面清爽好讀。
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
      for (final gModel in _kGroqModels) {
        debugPrint('代理人助理：啟動 Groq 超高速引擎 ($gModel)...');
        try {
          bool hasYielded = false;
          await for (final chunk in _tryGroqModel(
            model: gModel,
            messages: messages,
            maxTokens: 250,
          )) {
            yield AssistantResponseChunk(chunk, 'groq');
            hasYielded = true;
          }
          if (hasYielded) return; // Groq 成功輸出，直接完成
        } catch (e) {
          final errStr = e.toString();
          if (errStr.contains('model_decommissioned') ||
              errStr.contains('model_not_found')) {
            debugPrint('⚠️ Groq 模型 $gModel 已下架/不可用，無縫秒切下一個備援模型...');
          } else {
            debugPrint('Groq 模型 $gModel 失敗/超時（$e），嘗試下一個 Groq 備援模型...');
          }
        }
      }
    }

    // 2. 嘗試本地 OpenRouter (僅在 Key 存在時調用，避免卡住)
    // 【在這改 OpenRouter 模型】
    bool openRouterSucceeded = false;
    Exception? lastError;

    if (_kOpenRouterApiKey.trim().isNotEmpty) {
      final fallbackModels = [
        if (customModel != null && customModel.isNotEmpty) customModel,
        'google/gemma-4-26b-a4b-it:free',
        'google/gemma-4-31b-it:free',
        'poolside/laguna-s-2.1:free',
        'openai/gpt-oss-20b:free',
        'nvidia/nemotron-3-ultra-550b-a55b:free',
        'nvidia/nemotron-3.5-lightning:free',
        'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free',
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
          model: 'gemini-2.0-flash',
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
- $langDirective（嚴禁出現「笔记」、「关键词」、「要点」等簡體字，一律使用繁體字「筆記」、「關鍵字」、「要點」）。
- 語氣親切溫暖、條理清晰（例如適度條列重點）。
- 重要名詞或步驟請以雙星號 (**) 標示（例如：**個人檔案** > **設定與安全**）。
- 內容精簡明瞭（約 80~150 字），直擊重點，避免冗長廢話。
''';

    await for (final chunk in generateOpenRouterGuideStream(
      userInput: userInput,
      history: history,
      customSystemPrompt: systemPrompt,
    )) {
      if (chunk.text.isNotEmpty) {
        yield toTraditionalChinese(chunk.text);
      }
    }
  }

  /// 內部輔助：向指定模型發送串流請求，每個 chunk 逐一 yield。
  static Stream<String> _tryOpenRouterModel({
    required String model,
    required List<Map<String, String>> messages,
    int maxTokens = 700,
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
      // 連線 Timeout：12 秒（給予模型充足的連線與排隊時間）
      final response = await client.send(request).timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw Exception('OpenRouter 請求逾時（12s）'),
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
          .timeout(const Duration(seconds: 20), onTimeout: (sink) {
        sink.addError(Exception('OpenRouter 串流讀取逾時（20s）'));
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
    int maxTokens = 700,
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
      'temperature': 0.7,
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
          .timeout(const Duration(seconds: 20), onTimeout: (sink) {
        sink.addError(Exception('Groq 串流讀取逾時（20s）'));
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
        for (final gModel in _kGroqModels) {
          try {
            bool hasYielded = false;
            await for (final chunk in _tryGroqModel(
                    model: gModel,
                    messages: [
                      {'role': 'user', 'content': prompt}
                    ],
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
        model: 'gemini-2.0-flash',
        apiKey: _kSystemGeminiApiKey,
      );
      final contentStream = model.generateContentStream([Content.text(prompt)]);
      await for (final chunk
          in contentStream.timeout(const Duration(seconds: 8))) {
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
你是一位專業的個人化 AI 補強教師。請根據學生在【$subjectLabel】的真實測驗錯題資料，直接精闢分析其盲點並給予關鍵補強建議。

學生錯題資料：
$wrongDetails

請嚴格依照以下兩大標題格式輸出（總字數約 120~180 字），禁止輸出任何引言、程式碼區塊或模板說明文字，請使用【關鍵詞】標示核心概念與考點：

[弱項摘要]
（請用 1-2 句話直接說明學生在【$subjectLabel】的主要弱點與盲點，例如：學生在【...】章節概念較不熟練...）

[觀念重點]
• 【核心考點】：（針對錯題觀念的精準剖析，約 40~60 字）
• 【解題思維】：（具體解題切入技巧或注意事項，約 40~60 字）

${AppLocaleService.getAiLanguageInstruction()}
''';
    } else {
      prompt = '''
你是一位專業的個人化 AI 學習導師。學生目前在【$subjectLabel】科目掌握度良好（暫無近期錯題），請為學生整理該科目的核心精華觀念與進階學習方向。

請嚴格依照以下兩大標題格式輸出（總字數約 120~180 字），禁止輸出任何引言、程式碼區塊或模板說明文字，請使用【關鍵詞】標示核心概念與考點：

[弱項摘要]
學生在【$subjectLabel】掌握度良好，暫無明顯錯題盲點。建議持續維持手感，著重在【核心概念】的融會貫通與【進階題型】挑戰。

[觀念重點]
• 【核心定理】：（精闢統整【$subjectLabel】最具代表性的高頻必考核心定理或觀念定義，約 40~60 字）
• 【進階思維】：（提供突破【$subjectLabel】進階應用題型的思維路徑與解題關鍵，約 40~60 字）

${AppLocaleService.getAiLanguageInstruction()}
''';
    }

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content':
            '你是一位專業的個人化 AI 補強教師，擅長根據學生在特定科目的弱點生成針對性學習建議。請直接給出分析重點，使用【關鍵詞】標示重點，嚴禁複製模板說明括號。'
      },
      {'role': 'user', 'content': prompt},
    ];

    // 1. 優先：嘗試速度最快且穩定的 Groq (0.3s)
    if (_kGroqApiKey.isNotEmpty) {
      debugPrint('學習建議：啟動 Groq 快速引擎...');
      for (final gModel in _kGroqModels) {
        try {
          bool hasYielded = false;
          await for (final chunk in _tryGroqModel(
                  model: gModel, messages: messages, maxTokens: 400)
              .timeout(const Duration(seconds: 8))) {
            yield chunk;
            hasYielded = true;
          }
          if (hasYielded) return;
        } catch (e) {
          debugPrint('學習建議 Groq 模型 $gModel 失敗: $e');
        }
      }
    }

    // 2. 備援：Cloudflare 雲端中繼站 (適合實體手機無本機 Key 時)
    try {
      debugPrint('學習建議：嘗試 Cloudflare 雲端中繼站 (Groq)...');
      String? proxyText = await _tryCloudflareProxy(
        provider: 'groq',
        model: 'llama-3.1-8b-instant',
        prompt: prompt,
        timeoutSeconds: 6,
      );
      if (proxyText == null || proxyText.trim().isEmpty) {
        debugPrint('學習建議：Groq 中繼站無回應，切換 Gemini 中繼站...');
        proxyText = await _tryCloudflareProxy(
          provider: 'gemini',
          prompt: prompt,
          timeoutSeconds: 6,
        );
      }
      if (proxyText == null || proxyText.trim().isEmpty) {
        debugPrint('學習建議：Gemini 中繼站無回應，切換 OpenRouter 中繼站...');
        proxyText = await _tryCloudflareProxy(
          provider: 'openrouter',
          model: 'google/gemma-4-26b-a4b-it:free',
          prompt: prompt,
          timeoutSeconds: 6,
        );
      }
      if (proxyText != null && proxyText.trim().isNotEmpty) {
        yield proxyText;
        return;
      }
    } catch (e) {
      debugPrint('學習建議 Cloudflare 中繼站例外: $e');
    }

    // 3. 備援：嘗試 Gemini 直連（Google 官方）
    final now = DateTime.now();
    if (_kSystemGeminiApiKey.isNotEmpty &&
        (nextAvailableTime == null || !nextAvailableTime!.isAfter(now))) {
      debugPrint('學習建議：嘗試 Gemini 備援...');
      try {
        final model = GenerativeModel(
            model: 'gemini-2.0-flash', apiKey: _kSystemGeminiApiKey);
        bool hasYielded = false;
        await for (final chunk in model.generateContentStream(
            [Content.text(prompt)]).timeout(const Duration(seconds: 8))) {
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

    // 4. 本地高階學科專屬智慧診斷庫（100% 依據科目深度客製，絕不千篇一律）
    debugPrint('學習建議：啟動本地高品質專屬學科診斷...');
    yield _generateSubjectSpecificRemedialMaterial(subject);
  }

  /// 本地高階學科專屬智慧診斷生成器（各學科專屬重點考點與解題思維）
  static String _generateSubjectSpecificRemedialMaterial(String subject) {
    final sub = subject.trim();
    if (sub.contains('國文') || sub.contains('語文')) {
      return '''
[弱項摘要]
針對【國文科】文言文閱讀、白話文意判讀與成語字詞理解進行深度解構，強化【篇章邏輯思維】與文本語感。

[觀念重點]
• 【核心考點】：文言文首重【文意脈絡】與詞性虛實詞辨析，白話文先抓作者核心主旨與轉折詞。
• 【解題思維】：題目問及主旨時，優先比對【結論句】與反駁段落，排除過度推論或以偏概全之干擾選項。
• 【精準突破】：平時累積【高頻成語典故】與形音義對比，培養語感並提升審題敏銳度。
''';
    } else if (sub.contains('英文') || sub.contains('英語')) {
      return '''
[弱項摘要]
針對【英文科】文法句構、克漏字時態與閱讀測驗長難句，加強【核心字彙與文法脈絡】之融會貫通。

[觀念重點]
• 【核心考點】：精確掌握主詞動詞一致性、時態語態，以及【關係代名詞】與連接詞之句型搭配。
• 【解題思維】：閱讀測驗先瀏覽題目【關鍵定位詞】（人名、年代、專有名詞），再回文精讀定位段落。
• 【精準突破】：系統化整理【易混淆同義字/片語】與固定介系詞搭配，每日維持閱讀手感與語感。
''';
    } else if (sub.contains('數學') || sub.contains('微積分')) {
      return '''
[弱項摘要]
針對【數學科】幾何定理、代數運算與函數圖像，協助釐清【核心公式推導】並建立嚴謹的【解題步驟邏輯】。

[觀念重點]
• 【核心考點】：審題時標示已知條件與未知數，畫出【幾何圖形/函數坐標圖】以輔助直觀幾何思考。
• 【解題思維】：由目標結論逆推所需定理，先列出關係式再簡化運算，避免盲目套用公式。
• 【精準突破】：嚴格注意【正負號與定義域限制】（如分母不為零、根號內非負），完成後代入特殊值檢驗。
''';
    } else if (sub.contains('物理')) {
      return '''
[弱項摘要]
針對【物理科】力學分析、電磁學與能量守恆定律，強化【物理模型建立】與向量運算能力。

[觀念重點]
• 【核心考點】：解力學題先畫出受力【自由體圖（Free Body Diagram）】，明確標註各作用力方向。
• 【解題思維】：判斷系統是否滿足【動量守恆】或【力學能守恆】，選取最簡便的參考系與狀態方程式。
• 【精準突破】：嚴格檢查【單位轉換】與向量正負號約定，加深對物理意義與物理圖表的直觀理解。
''';
    } else if (sub.contains('化學')) {
      return '''
[弱項摘要]
針對【化學科】化學計量、氧化還原、酸鹼平衡與反應速率，鞏固【微觀粒子與反應模型】。

[觀念重點]
• 【核心考點】：平衡化學方程式是計算基石，嚴格遵循【質量守恆與電荷守恆】原則。
• 【解題思維】：溶液與平衡問題利用【ICE 表格（初態、變化量、平衡態）】條理化分析濃度變化。
• 【精準突破】：熟記【常見沉澱表、氧化數規則與酸鹼強弱順序】，避免在多選判斷題失分。
''';
    } else if (sub.contains('生物')) {
      return '''
[弱項摘要]
針對【生物科】細胞構造、遺傳演化、生理調節與生態系，建立【生理機制與流程架構】。

[觀念重點]
• 【核心考點】：掌握核心生理反應之【發生場所與物質流向】（如光合作用、細胞呼吸作用）。
• 【解題思維】：遺傳題型多善用【棋盤方格法】分析基因型機率，實驗圖表題先看橫縱軸變數關係。
• 【精準突破】：以【心智圖/流程圖】串聯不同器官系統的調控機制，強化跨章節橫向整合記憶。
''';
    } else if (sub.contains('歷史')) {
      return '''
[弱項摘要]
針對【歷史科】時代分期、政經制度變遷與重大事件因果，強化【時空脈絡與歷史解釋】。

[觀念重點]
• 【核心考點】：掌握各時代的【核心政治體制與經濟重心移轉】，理清重大改革的時代背景與影響。
• 【解題思維】：史料題先辨識作者立場與發言年代，從文本中提取【關鍵時間與制度名詞】比對選項。
• 【精準突破】：按時間軸整理【重大事件對照表】，加強跨區域與跨文明的橫向連結與比較。
''';
    } else if (sub.contains('地理')) {
      return '''
[弱項摘要]
針對【地理科】自然環境（地形、氣候）、人文產業與地圖判讀，培養【空間分佈與人地互動】思維。

[觀念重點]
• 【核心考點】：掌握全球主要【氣候成因與洋流風帶】規律，理解地形對聚落、交通與水系的影響。
• 【解題思維】：等高線與等壓線圖先判斷數值增減與疏密程度，定位空間坐標與氣候特徵。
• 【精準突破】：結合【GIS 空間分析概念與專題地圖】，加強自然環境與人文發展的因果關聯。
''';
    } else if (sub.contains('公民')) {
      return '''
[弱項摘要]
針對【公民科】憲政民主、法律權利、市場經濟與社會文化，建立【法理邏輯與制度規範】。

[觀念重點]
• 【核心考點】：熟記五院職權分工、憲法保障基本權利與【民事、刑事、行政責任】之本質區別。
• 【解題思維】：經濟學考題善用【供需曲線圖】分析價格管制與市場均衡，釐清機會成本概念。
• 【精準突破】：注意日常時事新聞中的【法制改革與公共議題】，結合公民核心概念進行論證。
''';
    } else if (sub.contains('資訊') || sub.contains('計算機') || sub.contains('程式')) {
      return '''
[弱項摘要]
針對【$sub】核心系統架構、網路通訊與演算法概念，強化【技術架構與邏輯應用思維】。

[觀念重點]
• 【核心考點】：釐清資料庫關聯模型、正規化原則與網路【OSI 七層架構】之各層功能定位。
• 【解題思維】：系統分析題型先界定【輸入、處理、輸出與資料流向】，分析安全性與擴充性。
• 【精準突破】：熟記新興技術概念（雲端運算、AI 模型、資訊安全防護），強化跨章節綜合理解。
''';
    } else {
      return '''
[弱項摘要]
針對【$sub】核心觀念與常見題型進行深度解構，協助鞏固【核心知識架構】並建立嚴謹的【解題思維邏輯】。

[觀念重點]
• 【核心考點】：審題時先抓出【$sub】核心關鍵字與已知條件，釐清題意定義與核心概念。
• 【解題思維】：加強【高頻常考觀念】的縱向連結，理解解題步驟背後的邏輯意涵，多做同類型題目的觀念對比。
• 【精準突破】：針對容易混淆的【干擾選項】建立錯題筆記，定期複習以強化直覺反應力與解題精準度。
''';
    }
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
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_kSystemGeminiApiKey',
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
        model: 'gemini-2.0-flash',
        apiKey: _kSystemGeminiApiKey,
      );
      final contentStream = model.generateContentStream([Content.text(prompt)]);
      await for (final chunk
          in contentStream.timeout(const Duration(seconds: 8))) {
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
        (nextAvailableTime == null ||
            !nextAvailableTime!.isAfter(DateTime.now()))) {
      try {
        final model = GenerativeModel(
          model: 'gemini-2.0-flash',
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
        debugPrint(
            'Gemini clone stream error, switching to Cloudflare Proxy: $e');
        if (e.toString().contains('429') ||
            e.toString().contains('RESOURCE_EXHAUSTED')) {
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
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
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
    final cleaned = cleanThinkingTags(text);
    return cleaned
        .replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '')
        .replaceAllMapped(
            RegExp(r'^\s*[\*\-]\s*【([^*]+)】\s*:\s*', multiLine: true),
            (m) => '• 【${m.group(1)}】：')
        .replaceAllMapped(
            RegExp(r'^\s*[\*\-]\s*\*\*([^*]+)\*\*\s*:\s*', multiLine: true),
            (m) => '• 【${m.group(1)}】：')
        .replaceAll(RegExp(r'^\s*[\*\-]\s*', multiLine: true), '• ')
        .replaceAll('**', '')
        .replaceAll(RegExp(r'\[\$[0-9]+\]|【\$[0-9]+】|\$[0-9]+'), '')
        .trim();
  }

  static Stream<String> askQuestionExplanationStream({
    required String userId,
    required Map<String, dynamic> question,
    required int correctIndex,
    required int? chosenIndex,
  }) async* {
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
        options = rawOptions
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '')
            .split(',')
            .map((e) => e.trim())
            .toList();
      }
    }

    final correctOpt = (correctIndex >= 0 && correctIndex < options.length)
        ? options[correctIndex]
        : '未知';
    final chosenOpt = (chosenIndex != null &&
            chosenIndex >= 0 &&
            chosenIndex < options.length)
        ? options[chosenIndex]
        : '未作答';

    final correctOptLetter = String.fromCharCode(65 + correctIndex);
    final chosenOptLetter =
        chosenIndex != null ? String.fromCharCode(65 + chosenIndex) : '無';

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

    // 1. 優先：嘗試本地 Groq API (極速 ~300ms)
    if (_kGroqApiKey.isNotEmpty) {
      for (final gModel in _kGroqModels) {
        debugPrint('AI 解析：嘗試本地 Groq 引擎 ($gModel)...');
        try {
          bool hasYielded = false;
          await for (final chunk in _tryGroqModel(
                  model: gModel, messages: messages, maxTokens: 1024)
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
            model: 'gemini-2.0-flash', apiKey: _kSystemGeminiApiKey);
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

    // 5. 本地高質量結構化備援解析（保證永遠正常呈現）
    final localExplanation = '''
🎯 觀念精華：為什麼正確答案是 ($correctOptLetter)
• 正確解答為【$correctOpt】。核心關鍵在於準確掌握題幹定義與核心原理，透過標準觀念直接推導求得。

🔍 迷思快剖：${chosenIndex != null ? '選擇 ($chosenOptLetter) 的盲點' : '常見作答陷阱'}
• ${chosenIndex != null ? '選擇【$chosenOpt】時，容易忽略題目限制條件或誤判關鍵轉換步驟。' : '審題時須注意題目細節與名詞定義，避免落入典型干擾選項陷阱。'}

💡 一秒口訣：精闢記憶句
• 【精準審題抓關鍵，排除干擾選正解】。
''';

    yield localExplanation;
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
