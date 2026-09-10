import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'ai_diagnosis_service.dart';
import 'app_locale_service.dart';

// ============================================================
// 1. 整理風格列舉
// ============================================================
enum VoiceNoteStyle {
  studyOutline,    // 📌 學習重點大綱
  examReview,      // 🎯 考試複習考點
  meetingMinutes,  // 📋 會議/課堂紀錄
  ideaOrganize,    // 💡 靈感整理
}

extension VoiceNoteStyleExtension on VoiceNoteStyle {
  String get label {
    switch (this) {
      case VoiceNoteStyle.studyOutline:
        return '學習重點大綱';
      case VoiceNoteStyle.examReview:
        return '考試複習考點';
      case VoiceNoteStyle.meetingMinutes:
        return '會議課堂紀錄';
      case VoiceNoteStyle.ideaOrganize:
        return '靈感整理';
    }
  }

  String get emoji {
    switch (this) {
      case VoiceNoteStyle.studyOutline:
        return '📌';
      case VoiceNoteStyle.examReview:
        return '🎯';
      case VoiceNoteStyle.meetingMinutes:
        return '📋';
      case VoiceNoteStyle.ideaOrganize:
        return '💡';
    }
  }

  String get description {
    switch (this) {
      case VoiceNoteStyle.studyOutline:
        return '提煉核心主題、層級清晰的條列重點與觀念摘要';
      case VoiceNoteStyle.examReview:
        return '整理關鍵定義、核心考點標籤與易混淆辨析';
      case VoiceNoteStyle.meetingMinutes:
        return '記錄議題、結論與待辦 TODO 行動清單';
      case VoiceNoteStyle.ideaOrganize:
        return '聚類相關概念、延伸脈絡、靈感激發';
    }
  }

  String get suggestedCategory {
    switch (this) {
      case VoiceNoteStyle.studyOutline:
      case VoiceNoteStyle.examReview:
        return '學習';
      case VoiceNoteStyle.meetingMinutes:
        return '工作';
      case VoiceNoteStyle.ideaOrganize:
        return '生活';
    }
  }
}

// ============================================================
// 2. 整理結果資料類別
// ============================================================
class VoiceNoteResult {
  final String title;
  final String category;
  final String markdownContent;
  final List<String> tags;
  final String rawTranscript;
  final bool isAiGenerated;

  const VoiceNoteResult({
    required this.title,
    required this.category,
    required this.markdownContent,
    required this.tags,
    required this.rawTranscript,
    required this.isAiGenerated,
  });

  VoiceNoteResult copyWith({
    String? title,
    String? category,
    String? markdownContent,
    List<String>? tags,
    String? rawTranscript,
    bool? isAiGenerated,
  }) {
    return VoiceNoteResult(
      title: title ?? this.title,
      category: category ?? this.category,
      markdownContent: markdownContent ?? this.markdownContent,
      tags: tags ?? this.tags,
      rawTranscript: rawTranscript ?? this.rawTranscript,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
    );
  }
}

// ============================================================
// 3. 語音筆記整理服務
// ============================================================
class VoiceNoteService {
  VoiceNoteService._();
  static final VoiceNoteService instance = VoiceNoteService._();

  static const String _kCloudflareProxyUrl =
      'https://ai-app-proxy.adenlee36.workers.dev';

  static const String _kAppSecretHeader = 'x-app-secret';
  static String get _kAppClientSecret {
    try {
      final secret = dotenv.env['APP_CLIENT_SECRET'];
      if (secret != null && secret.isNotEmpty) return secret;
    } catch (_) {}
    const envSecret = String.fromEnvironment('APP_CLIENT_SECRET');
    if (envSecret.isNotEmpty) return envSecret;
    return 'K/Qk9-gt2P.E9qa';
  }

  static String get _kGeminiApiKey {
    try {
      final key = dotenv.env['GEMINI_API_KEY'];
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    return '';
  }

  // ----------------------------------------------------------
  // 公開主方法：整理語音逐字稿
  // ----------------------------------------------------------
  Future<VoiceNoteResult> organizeTranscript({
    required String transcript,
    required VoiceNoteStyle style,
    String? userId,
  }) async {
    if (transcript.trim().isEmpty) {
      return VoiceNoteResult(
        title: '空白語音筆記',
        category: style.suggestedCategory,
        markdownContent: '',
        tags: [],
        rawTranscript: transcript,
        isAiGenerated: false,
      );
    }

    final prompt = _buildPrompt(transcript, style);

    // ============================================================
    // 優先使用 Cloudflare 雲端中繼站 (Gemini 優先 -> Groq -> OpenRouter)
    // ============================================================
    // 順位 1：Cloudflare Gemini 旗艦引擎 (中繼站優先)
    debugPrint('VoiceNoteService: 優先啟動 Cloudflare 雲端中繼站 (Gemini 引擎)...');
    String? responseText = await _tryCloudflareProxy(
      provider: 'gemini',
      prompt: prompt,
      timeoutSeconds: 15,
    );

    // 順位 2-A：Cloudflare Groq 快速引擎 (compound-beta)
    if (responseText == null || responseText.trim().isEmpty) {
      debugPrint('VoiceNoteService: 切換 Cloudflare Groq 極速引擎 (compound-beta)...');
      responseText = await _tryCloudflareProxy(
        provider: 'groq',
        model: 'compound-beta',
        prompt: prompt,
        timeoutSeconds: 15,
      );
    }

    // 順位 2-B：Cloudflare Groq 深度引擎 (qwen/qwen3.6-27b)
    if (responseText == null || responseText.trim().isEmpty) {
      debugPrint('VoiceNoteService: 切換 Cloudflare Groq 深度模型 (qwen/qwen3.6-27b)...');
      responseText = await _tryCloudflareProxy(
        provider: 'groq',
        model: 'qwen/qwen3.6-27b',
        prompt: prompt,
        timeoutSeconds: 25,
      );
    }

    // 順位 3：Cloudflare OpenRouter 引擎
    if (responseText == null || responseText.trim().isEmpty) {
      debugPrint('VoiceNoteService: 切換 Cloudflare OpenRouter 引擎中繼...');
      responseText = await _tryCloudflareProxy(
        provider: 'openrouter',
        prompt: prompt,
        timeoutSeconds: 10,
      );
    }

    // 順位 4：全部中繼站失敗時，降級直連 Gemini API
    if ((responseText == null || responseText.trim().isEmpty) && _kGeminiApiKey.isNotEmpty) {
      debugPrint('VoiceNoteService: 中繼站無回應，降級直連 Gemini API...');
      responseText = await _tryDirectGemini(prompt);
    }

    // 解析 AI 回傳的 JSON
    if (responseText != null && responseText.trim().isNotEmpty) {
      try {
        // 清理思考標籤與 markdown 程式碼區塊
        String cleanedResponse = AiDiagnosisService.cleanThinkingTags(responseText).trim();
        if (cleanedResponse.startsWith('```')) {
          cleanedResponse = cleanedResponse
              .replaceFirst(RegExp(r'^```[a-z]*\n?'), '')
              .replaceFirst(RegExp(r'\n?```$'), '')
              .trim();
        }

        final decoded = jsonDecode(cleanedResponse) as Map<String, dynamic>;
        final rawTitle = (decoded['title'] as String? ?? '').trim();
        final rawCategory = (decoded['category'] as String? ?? '').trim();
        final rawContent = (decoded['content'] as String? ?? '').trim();
        final rawTags = decoded['tags'];
        final tags = rawTags is List
            ? rawTags
                .map((e) => AiDiagnosisService.toTraditionalChinese(e.toString()))
                .toList()
            : <String>[];

        final title = AiDiagnosisService.toTraditionalChinese(rawTitle);
        final markdownContent = AiDiagnosisService.toTraditionalChinese(rawContent);

        return VoiceNoteResult(
          title: title.isEmpty ? _generateFallbackTitle(transcript, style) : title,
          category: _validateCategory(rawCategory, style),
          markdownContent: markdownContent.isEmpty
              ? _buildFallbackContent(transcript, style)
              : markdownContent,
          tags: tags,
          rawTranscript: transcript,
          isAiGenerated: true,
        );
      } catch (e) {
        debugPrint('VoiceNoteService JSON parse error: $e\nRaw: $responseText');
      }
    }

    // 最終降級：本地規則式整理
    return _localFallback(transcript, style);
  }

  // ----------------------------------------------------------
  // 私有方法：建立 Prompt
  // ----------------------------------------------------------
  String _buildPrompt(String transcript, VoiceNoteStyle style) {
    final langInstruction = AppLocaleService.getAiLanguageInstruction();
    final styleInstruction = _getStyleInstruction(style);

    return '''
你是一位專業的學習筆記整理助手。請閱讀以下語音辨識逐字稿，並以「${style.label}」風格將其整理為高品質的結構化筆記。

$styleInstruction

【重要格式規定】
- 輸出語言：繁體中文（台灣習慣用語，避免大陸詞彙）
- 【智慧去贅字】：自動剔除逐字稿中的口頭禪、語助詞與贅字（例如：「痾」、「呃」、「嗯」、「那個」、「就是說」、「然後呢」等口語停頓詞與重複口吃），轉化為乾淨俐落的專業書面筆記。
- 不得照抄原文，需用精煉句子重新表達核心意思
- Markdown 格式：使用 # 標題、## 子標題、- 列點、**粗體**關鍵字、> 引用、- [ ] 待辦事項
- 你必須只回傳一個 JSON 物件，格式如下，且不得包含任何 Markdown 代碼塊（如 ```json）或前後文字：

{
  "title": "簡短精確的筆記標題（15字以內）",
  "category": "學習|工作|生活",
  "content": "完整的 Markdown 格式筆記內容",
  "tags": ["關鍵字1", "關鍵字2", "關鍵字3"]
}

【語音逐字稿】：
$transcript

$langInstruction
''';
  }

  String _getStyleInstruction(VoiceNoteStyle style) {
    switch (style) {
      case VoiceNoteStyle.studyOutline:
        return '''
【整理風格：學習重點大綱】
請識別逐字稿中所有知識性內容，整理為：
1. 用 # 標題說明主題領域
2. 每個核心概念用 ## 子標題區分
3. 每個概念包含【定義是什麼】、【為何重要】、【如何應用】（若有提到）
4. 底部加上 ## 📝 重點摘要，用3-5個 - 列點總結最重要的學習收穫
''';
      case VoiceNoteStyle.examReview:
        return '''
【整理風格：考試複習考點】
請從逐字稿中識別所有考試重點，整理為：
1. 用 ## 🔑 核心考點 列出所有重要名詞定義（用 **粗體** 標記）
2. 用 ## ⚠️ 易混淆點 列出容易搞混的概念對比（格式：**A** vs **B**：差異說明）
3. 用 ## 📊 重點公式/原則 列出需要記憶的規則或公式（若有）
4. 用 ## 💪 考前提醒 列出2-3個最需要注意的考點
注意：請為重要關鍵字加上 **粗體** 格式，讓複習時一眼識別。
''';
      case VoiceNoteStyle.meetingMinutes:
        return '''
【整理風格：會議課堂紀錄】
請將逐字稿整理為正式的會議/課堂紀錄格式：
1. 用 ## 📋 主要議題 列出本次討論的核心主題（2-5點）
2. 用 ## 💬 重要討論與結論 記錄關鍵決策與達成共識的事項
3. 用 ## ✅ 待辦事項 將需要後續執行的事項以 - [ ] 格式列出（若有提到負責人或期限請附上）
4. 用 ## 📌 下次跟進 記錄需要繼續追蹤的事項（若有）
注意：待辦事項格式必須為 Markdown checkbox：- [ ] 待辦內容
''';
      case VoiceNoteStyle.ideaOrganize:
        return '''
【整理風格：靈感整理】
請以「靈感孵化」的視角整理逐字稿：
1. 用 ## 💡 核心靈感 提煉最核心的想法或洞察（1-3個）
2. 用 ## 🌱 延伸思考 從核心靈感出發，列出可以進一步探索的方向
3. 用 ## 🔗 關聯概念 找出想法之間的連結與脈絡
4. 用 ## 🎯 下一步行動 列出將靈感轉化為行動的具體步驟（若有）
注意：此模式允許適度補充 AI 的延伸洞察（用 > 引用塊標記），幫助發展想法。
''';
    }
  }

  // ----------------------------------------------------------
  // 私有方法：呼叫 Cloudflare 中繼站
  // ----------------------------------------------------------
  Future<String?> _tryCloudflareProxy({
    required String provider,
    String? model,
    required String prompt,
    int timeoutSeconds = 15,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_kCloudflareProxyUrl),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              _kAppSecretHeader: _kAppClientSecret,
            },
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
        return rawText;
      }
      debugPrint('VoiceNoteService Cloudflare [$provider] ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
      return null;
    } catch (e) {
      debugPrint('VoiceNoteService Cloudflare [$provider] exception: $e');
      return null;
    }
  }

  // ----------------------------------------------------------
  // 私有方法：直連 Gemini API
  // ----------------------------------------------------------
  Future<String?> _tryDirectGemini(String prompt) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _kGeminiApiKey,
      );
      final response = await model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 25));
      return response.text;
    } on GenerativeAIException catch (e) {
      debugPrint('VoiceNoteService Gemini direct error: $e');
      return null;
    } catch (e) {
      debugPrint('VoiceNoteService Gemini direct exception: $e');
      return null;
    }
  }

  // ----------------------------------------------------------
  // 私有方法：本地降級整理
  // ----------------------------------------------------------
  VoiceNoteResult _localFallback(String transcript, VoiceNoteStyle style) {
    debugPrint('VoiceNoteService: All AI APIs failed, using local fallback.');
    final title = _generateFallbackTitle(transcript, style);
    final content = _buildFallbackContent(transcript, style);

    return VoiceNoteResult(
      title: title,
      category: style.suggestedCategory,
      markdownContent: content,
      tags: [],
      rawTranscript: transcript,
      isAiGenerated: false,
    );
  }

  String _generateFallbackTitle(String transcript, VoiceNoteStyle style) {
    final words = transcript.trim().split(RegExp(r'\s+'));
    final preview =
        words.take(8).join('').replaceAll(RegExp(r'[^\u4e00-\u9fff\w]'), '');
    final truncated = preview.length > 12 ? '${preview.substring(0, 12)}...' : preview;
    if (truncated.isEmpty) return '${style.emoji} ${style.label}';
    return '${style.emoji} $truncated';
  }

  String _buildFallbackContent(String transcript, VoiceNoteStyle style) {
    final buffer = StringBuffer();

    switch (style) {
      case VoiceNoteStyle.studyOutline:
        buffer.writeln('# ${style.emoji} 學習筆記');
        buffer.writeln();
        buffer.writeln('## 📝 語音內容（待整理）');
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        break;
      case VoiceNoteStyle.examReview:
        buffer.writeln('# ${style.emoji} 考試複習');
        buffer.writeln();
        buffer.writeln('## 🔑 核心考點');
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        break;
      case VoiceNoteStyle.meetingMinutes:
        buffer.writeln('# ${style.emoji} 會議紀錄');
        buffer.writeln();
        buffer.writeln('**日期**：${DateTime.now().toString().substring(0, 10)}');
        buffer.writeln();
        buffer.writeln('## 📋 討論內容');
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        buffer.writeln();
        buffer.writeln('## ✅ 待辦事項');
        buffer.writeln('- [ ] 請補充待辦事項');
        break;
      case VoiceNoteStyle.ideaOrganize:
        buffer.writeln('# ${style.emoji} 靈感紀錄');
        buffer.writeln();
        buffer.writeln('## 💡 靈感內容');
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        break;
    }

    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('*⚠️ 此為語音原始記錄（離線整理），可手動編輯調整。*');
    return buffer.toString();
  }

  void _appendParagraphs(StringBuffer buffer, String transcript) {
    // 依照中文句號、逗號、換行分段
    final sentences = transcript
        .split(RegExp(r'[。！？\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    for (final sentence in sentences) {
      buffer.writeln('- $sentence');
    }
  }

  String _validateCategory(String aiCategory, VoiceNoteStyle style) {
    const validCategories = ['學習', '工作', '生活', '未分類'];
    if (validCategories.contains(aiCategory)) return aiCategory;
    return style.suggestedCategory;
  }
}
