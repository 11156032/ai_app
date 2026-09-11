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
  meetingSummary,   // 會議摘要
  classKeyPoints,   // 課堂重點
  actionConclusion, // 代辦結論
  dailyJournal,     // 日常隨筆
}

extension VoiceNoteStyleExtension on VoiceNoteStyle {
  String get label {
    switch (this) {
      case VoiceNoteStyle.meetingSummary:
        return '會議摘要';
      case VoiceNoteStyle.classKeyPoints:
        return '課堂重點';
      case VoiceNoteStyle.actionConclusion:
        return '代辦結論';
      case VoiceNoteStyle.dailyJournal:
        return '日常隨筆';
    }
  }

  String get emoji {
    switch (this) {
      case VoiceNoteStyle.meetingSummary:
        return '📋';
      case VoiceNoteStyle.classKeyPoints:
        return '🎓';
      case VoiceNoteStyle.actionConclusion:
        return '✅';
      case VoiceNoteStyle.dailyJournal:
        return '📝';
    }
  }

  String get description {
    switch (this) {
      case VoiceNoteStyle.meetingSummary:
        return '提煉會議核心議題、討論重點與關鍵共識，條理清晰';
      case VoiceNoteStyle.classKeyPoints:
        return '提煉課堂核心觀念脈絡、章節重點與觀念解析';
      case VoiceNoteStyle.actionConclusion:
        return '整理重要結論、待確認項目與明確的行動代辦清單';
      case VoiceNoteStyle.dailyJournal:
        return '記錄日常隨想、生活心得與概念脈絡延伸';
    }
  }

  String get suggestedCategory {
    switch (this) {
      case VoiceNoteStyle.classKeyPoints:
        return '學習';
      case VoiceNoteStyle.meetingSummary:
      case VoiceNoteStyle.actionConclusion:
        return '工作';
      case VoiceNoteStyle.dailyJournal:
        return '生活';
    }
  }
}

// ============================================================
// 2. 待辦事項資料類別
// ============================================================
class ActionItem {
  final String task;
  final String owner;    // 負責人（無則 "未指定"）
  final String dueDate;  // 期限（無則 "無"）
  bool isCompleted;

  ActionItem({
    required this.task,
    this.owner = '未指定',
    this.dueDate = '無',
    this.isCompleted = false,
  });

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    return ActionItem(
      task: json['task'] as String? ?? '',
      owner: json['owner'] as String? ?? '未指定',
      dueDate: json['due_date'] as String? ?? '無',
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'task': task,
    'owner': owner,
    'due_date': dueDate,
    'is_completed': isCompleted,
  };
}

// ============================================================
// 3. 整理結果資料類別（向前相容升級）
// ============================================================
class VoiceNoteResult {
  // 原有欄位（保持不變）
  final String title;
  final String category;
  final String markdownContent;
  final List<String> tags;
  final String rawTranscript;
  final bool isAiGenerated;

  // 新增欄位（nullable，向前相容）
  final String? summary;                   // 核心摘要 1~2 句
  final List<String>? keyPoints;           // 條列重點
  final List<ActionItem>? actionItems;     // 待辦清單（含負責人/期限）
  final Map<String, dynamic>? mindmapJson; // 心智圖樹狀 JSON

  const VoiceNoteResult({
    required this.title,
    required this.category,
    required this.markdownContent,
    required this.tags,
    required this.rawTranscript,
    required this.isAiGenerated,
    this.summary,
    this.keyPoints,
    this.actionItems,
    this.mindmapJson,
  });

  VoiceNoteResult copyWith({
    String? title,
    String? category,
    String? markdownContent,
    List<String>? tags,
    String? rawTranscript,
    bool? isAiGenerated,
    String? summary,
    List<String>? keyPoints,
    List<ActionItem>? actionItems,
    Map<String, dynamic>? mindmapJson,
  }) {
    return VoiceNoteResult(
      title: title ?? this.title,
      category: category ?? this.category,
      markdownContent: markdownContent ?? this.markdownContent,
      tags: tags ?? this.tags,
      rawTranscript: rawTranscript ?? this.rawTranscript,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      summary: summary ?? this.summary,
      keyPoints: keyPoints ?? this.keyPoints,
      actionItems: actionItems ?? this.actionItems,
      mindmapJson: mindmapJson ?? this.mindmapJson,
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

    // 解析 AI 回傳的 JSON（支援新欄位：summary, key_points, action_items, mindmap）
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

        // ── 基礎欄位 ──
        final rawTitle = (decoded['title'] as String? ?? '').trim();
        final rawCategory = (decoded['category'] as String? ?? '').trim();
        final rawContent = (decoded['content'] as String? ?? '').trim();
        final rawTags = decoded['tags'];
        final tags = rawTags is List
            ? rawTags
                .map((e) => AiDiagnosisService.toTraditionalChinese(e.toString()))
                .toList()
            : <String>[];

        // ── 新增欄位：summary ──
        final rawSummary = decoded['summary'] as String?;
        final summary = rawSummary != null
            ? AiDiagnosisService.toTraditionalChinese(rawSummary.trim())
            : null;

        // ── 新增欄位：key_points ──
        final rawKeyPoints = decoded['key_points'];
        final keyPoints = rawKeyPoints is List
            ? rawKeyPoints
                .map((e) => AiDiagnosisService.toTraditionalChinese(e.toString()))
                .toList()
            : null;

        // ── 新增欄位：action_items ──
        final rawActionItems = decoded['action_items'];
        List<ActionItem>? actionItems;
        if (rawActionItems is List && rawActionItems.isNotEmpty) {
          actionItems = rawActionItems
              .whereType<Map<String, dynamic>>()
              .map((e) => ActionItem.fromJson(e))
              .where((a) => a.task.isNotEmpty)
              .toList();
        }

        // ── 新增欄位：mindmap ──
        final mindmapJson = decoded['mindmap'] as Map<String, dynamic>?;

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
          summary: summary,
          keyPoints: keyPoints,
          actionItems: actionItems,
          mindmapJson: mindmapJson,
        );
      } catch (e) {
        debugPrint('VoiceNoteService JSON parse error: $e\nRaw: $responseText');
      }
    }

    // 最終降級：本地規則式整理
    return _localFallback(transcript, style);
  }

  // ----------------------------------------------------------
  // 私有方法：情境感知 Prompt（移除硬編碼學術標籤）
  // ----------------------------------------------------------
  String _buildPrompt(String transcript, VoiceNoteStyle style) {
    final langInstruction = AppLocaleService.getAiLanguageInstruction();
    final styleInstruction = _getStyleInstruction(style);

    return '''
你是一位頂級的語音筆記整理助手，擅長把口語化的逐字稿轉換為自然、清晰、有條理的筆記。

【核心原則】
- 智慧去贅字：自動剔除「痾」「呃」「嗯」「那個」「就是說」「然後呢」等口語停頓詞
- 情境感知：根據內容的實際性質決定最合適的整理框架，不強套學術模板
- 自然表達：用精煉的書面語重新表達，而非逐字翻譯原文
- 語言：繁體中文（台灣習慣用語，避免大陸詞彙）

$styleInstruction

【JSON 輸出格式】
你必須只回傳一個 JSON 物件，不得包含任何 Markdown 代碼塊或前後文字：

{
  "title": "簡短精確的筆記標題（15字以內）",
  "category": "工作|學習|生活",
  "summary": "核心情境摘要（1~2句，讓人一眼看懂這是什麼內容）",
  "key_points": ["重點1", "重點2", "重點3"],
  "action_items": [
    { "task": "待辦事項描述", "owner": "負責人（無則填未指定）", "due_date": "期限（無則填無）", "is_completed": false }
  ],
  "mindmap": {
    "id": "root",
    "label": "主題名稱",
    "color": "#673AB7",
    "children": [
      { "id": "n1", "label": "子主題", "color": "#3F51B5",
        "children": [{ "id": "n1_1", "label": "細節", "color": "#2196F3", "children": [] }] }
    ]
  },
  "content": "完整的 Markdown 格式筆記（使用 # 標題、## 子標題、- 列點、**粗體**、> 引用、- [ ] 待辦）",
  "tags": ["關鍵字1", "關鍵字2", "關鍵字3"]
}

【語音逐字稿】：
$transcript

$langInstruction
''';
  }

  String _getStyleInstruction(VoiceNoteStyle style) {
    switch (style) {
      case VoiceNoteStyle.meetingSummary:
        return '''
【整理風格：會議摘要】
請將語音內容整理為結構嚴謹的會議摘要，重點如下：
- 提煉核心議題、主要討論過程與各方發言重點
- 清楚標記會議達成的關鍵共識與最終決議
- 重要結論與核心共識放入 key_points
- 若有提及待辦項目則放入 action_items
- 心智圖以「會議主旨」為根，各討論議題為子分支
''';
      case VoiceNoteStyle.classKeyPoints:
        return '''
【整理風格：課堂重點】
請根據課堂講述內容彈性整理，重點如下：
- 梳理課程核心概念、章節脈絡與邏輯架構，避免生硬固定框架
- 若有專有名詞或核心術語，用 **粗體** 標記並附上清晰精準的解析
- 若有步驟、流程或演算法，以數字清單條列說明
- key_points 填入 5~8 個最關鍵的課堂學習重點
- 心智圖以「課程主題」為根，核心章節觀念為子分支
''';
      case VoiceNoteStyle.actionConclusion:
        return '''
【整理風格：代辦結論】
請以行動導向整理內容，重點如下：
- 精煉各項討論產出的最終結論與決策重點
- 提取所有明確待辦行動、跟進事項、負責人與預計期限，完整填入 action_items 陣列
- 標明「已決議結論」與「待跟進/待確認項目」
- Markdown 內容中使用 - [ ] 格式的 Checkbox 列出待辦清單
- key_points 填入核心結論與行動要點
''';
      case VoiceNoteStyle.dailyJournal:
        return '''
【整理風格：日常隨筆】
請以生活隨想與心得記錄的角度整理，重點如下：
- 記錄日常生活隨筆、感悟心得與靈感發想，保留自然的思維流動
- 提煉核心心得與延伸觀念，結構輕盈不拘泥固定框架
- 允許補充延伸思考（用 > 引用塊標記）
- key_points 記錄 3~5 個重要隨想或心得
- 心智圖以「隨筆主題」為根，各心得感悟為子節點
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
      case VoiceNoteStyle.meetingSummary:
        buffer.writeln('# ${style.emoji} 會議摘要');
        buffer.writeln();
        buffer.writeln('**日期**：${DateTime.now().toString().substring(0, 10)}');
        buffer.writeln();
        buffer.writeln('## 📋 會議核心與討論重點');
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        buffer.writeln();
        buffer.writeln('## 🤝 關鍵共識與結論');
        buffer.writeln('- （請補充會議共識）');
        break;
      case VoiceNoteStyle.classKeyPoints:
        buffer.writeln('# ${style.emoji} 課堂重點筆記');
        buffer.writeln();
        buffer.writeln('## 🎓 核心觀念解析');
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        break;
      case VoiceNoteStyle.actionConclusion:
        buffer.writeln('# ${style.emoji} 代辦結論');
        buffer.writeln();
        buffer.writeln('**日期**：${DateTime.now().toString().substring(0, 10)}');
        buffer.writeln();
        buffer.writeln('## 💡 核心結論');
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        buffer.writeln();
        buffer.writeln('## ✅ 待辦與跟進行動');
        buffer.writeln('- [ ] 請補充待辦事項');
        break;
      case VoiceNoteStyle.dailyJournal:
        buffer.writeln('# ${style.emoji} 日常隨筆');
        buffer.writeln();
        buffer.writeln('## 📝 隨筆與生活心得');
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
