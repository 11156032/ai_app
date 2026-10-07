import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'ai_diagnosis_service.dart';
import 'app_locale_service.dart';
import 'voice_recognition_service.dart';

// ============================================================
// ============================================================
// 1. 整理風格與細緻度列舉 (比照業界頂級 AI 筆記應用規格)
// ============================================================

/// 筆記深度微調層級 (Concise 精簡 vs. Detailed 詳盡)
enum VoiceNoteDetailLevel {
  concise, // 精簡
  detailed, // 詳盡
}

extension VoiceNoteDetailLevelExtension on VoiceNoteDetailLevel {
  String get label {
    switch (this) {
      case VoiceNoteDetailLevel.concise:
        return tr('vs_concise');
      case VoiceNoteDetailLevel.detailed:
        return tr('vs_detailed');
    }
  }

  String get emoji {
    switch (this) {
      case VoiceNoteDetailLevel.concise:
        return '⚡';
      case VoiceNoteDetailLevel.detailed:
        return '📚';
    }
  }

  String get subtitle {
    switch (this) {
      case VoiceNoteDetailLevel.concise:
        return tr('vs_concise_d');
      case VoiceNoteDetailLevel.detailed:
        return tr('vs_detailed_d');
    }
  }
}

/// 5 大專用整理風格
enum VoiceNoteStyle {
  academicLecture, // 課堂與學術研討 (原課堂重點)
  agileMeeting, // 敏捷商務會議 (整合會議+代辦)
  speedSummary, // 極速速讀摘要 (原精華摘要)
  structureMindmap, // 架構拆解與心智圖 (原結構大綱)
  inspirationJournal, // 靈感閃念與隨筆 (原日常隨筆)
}

extension VoiceNoteStyleExtension on VoiceNoteStyle {
  String get label {
    switch (this) {
      case VoiceNoteStyle.academicLecture:
        return tr('vs_style_lecture');
      case VoiceNoteStyle.agileMeeting:
        return tr('vs_style_meeting');
      case VoiceNoteStyle.speedSummary:
        return tr('vs_style_speed');
      case VoiceNoteStyle.structureMindmap:
        return tr('vs_style_mindmap');
      case VoiceNoteStyle.inspirationJournal:
        return tr('vs_style_journal');
    }
  }

  String get fullName {
    switch (this) {
      case VoiceNoteStyle.academicLecture:
        return tr('vs_full_lecture');
      case VoiceNoteStyle.agileMeeting:
        return tr('vs_full_meeting');
      case VoiceNoteStyle.speedSummary:
        return tr('vs_full_speed');
      case VoiceNoteStyle.structureMindmap:
        return tr('vs_full_mindmap');
      case VoiceNoteStyle.inspirationJournal:
        return tr('vs_full_journal');
    }
  }

  String get subtitle {
    switch (this) {
      case VoiceNoteStyle.academicLecture:
        return tr('vs_use_lecture');
      case VoiceNoteStyle.agileMeeting:
        return tr('vs_use_meeting');
      case VoiceNoteStyle.speedSummary:
        return tr('vs_use_speed');
      case VoiceNoteStyle.structureMindmap:
        return tr('vs_use_mindmap');
      case VoiceNoteStyle.inspirationJournal:
        return tr('vs_use_journal');
    }
  }

  String get badgeTag {
    switch (this) {
      case VoiceNoteStyle.academicLecture:
        return tr('vs_tag_lecture');
      case VoiceNoteStyle.agileMeeting:
        return tr('vs_tag_meeting');
      case VoiceNoteStyle.speedSummary:
        return tr('vs_tag_speed');
      case VoiceNoteStyle.structureMindmap:
        return tr('vs_tag_mindmap');
      case VoiceNoteStyle.inspirationJournal:
        return tr('vs_tag_journal');
    }
  }

  String get emoji {
    switch (this) {
      case VoiceNoteStyle.academicLecture:
        return '🎓';
      case VoiceNoteStyle.agileMeeting:
        return '💼';
      case VoiceNoteStyle.speedSummary:
        return '⚡';
      case VoiceNoteStyle.structureMindmap:
        return '🧠';
      case VoiceNoteStyle.inspirationJournal:
        return '💡';
    }
  }

  String get description {
    switch (this) {
      case VoiceNoteStyle.academicLecture:
        return tr('vs_spec_lecture');
      case VoiceNoteStyle.agileMeeting:
        return tr('vs_spec_meeting');
      case VoiceNoteStyle.speedSummary:
        return tr('vs_spec_speed');
      case VoiceNoteStyle.structureMindmap:
        return tr('vs_spec_mindmap');
      case VoiceNoteStyle.inspirationJournal:
        return tr('vs_spec_journal');
    }
  }

  List<String> get featureHighlights {
    switch (this) {
      case VoiceNoteStyle.academicLecture:
        return [
          tr('vs_out_lecture_1'),
          tr('vs_out_lecture_2'),
          tr('vs_out_lecture_3'),
        ];
      case VoiceNoteStyle.agileMeeting:
        return [
          tr('vs_out_meeting_1'),
          tr('vs_out_meeting_2'),
          tr('vs_out_meeting_3'),
        ];
      case VoiceNoteStyle.speedSummary:
        return [
          tr('vs_out_speed_1'),
          tr('vs_out_speed_2'),
          tr('vs_out_speed_3'),
        ];
      case VoiceNoteStyle.structureMindmap:
        return [
          tr('vs_out_mindmap_1'),
          tr('vs_out_mindmap_2'),
          tr('vs_out_mindmap_3'),
        ];
      case VoiceNoteStyle.inspirationJournal:
        return [
          tr('vs_out_journal_1'),
          tr('vs_out_journal_2'),
          tr('vs_out_journal_3'),
        ];
    }
  }

  String get suggestedCategory {
    switch (this) {
      case VoiceNoteStyle.academicLecture:
        return '學習';
      case VoiceNoteStyle.agileMeeting:
        return '工作';
      case VoiceNoteStyle.speedSummary:
        return '工作';
      case VoiceNoteStyle.structureMindmap:
        return '學習';
      case VoiceNoteStyle.inspirationJournal:
        return '生活';
    }
  }

  /// 靜態反序列化（具備向前相容）
  static VoiceNoteStyle fromString(String? name) {
    if (name == null) return VoiceNoteStyle.academicLecture;
    switch (name) {
      case 'academicLecture':
      case 'classKeyPoints':
        return VoiceNoteStyle.academicLecture;
      case 'agileMeeting':
      case 'meetingSummary':
      case 'actionConclusion':
        return VoiceNoteStyle.agileMeeting;
      case 'speedSummary':
      case 'executiveSummary':
        return VoiceNoteStyle.speedSummary;
      case 'structureMindmap':
      case 'outlineMindmap':
        return VoiceNoteStyle.structureMindmap;
      case 'inspirationJournal':
      case 'dailyJournal':
        return VoiceNoteStyle.inspirationJournal;
      default:
        return VoiceNoteStyle.academicLecture;
    }
  }
}

// ============================================================
// 2. 待辦事項資料類別
// ============================================================
class ActionItem {
  final String task;
  final String owner; // 負責人（無則 "未指定"）
  final String dueDate; // 期限（無則 "無"）
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
  final String? summary; // 核心摘要 1~2 句
  final List<String>? keyPoints; // 條列重點
  final List<ActionItem>? actionItems; // 待辦清單（含負責人/期限）
  final Map<String, dynamic>? mindmapJson; // 心智圖樹狀 JSON
  final String? correctedTranscript; // 語意與中英混雜校正後的逐字稿（含說話者與時間戳）

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
    this.correctedTranscript,
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
    String? correctedTranscript,
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
      correctedTranscript: correctedTranscript ?? this.correctedTranscript,
    );
  }
}

// ============================================================
// 3. 語音筆記整理服務
// ============================================================
class VoiceNoteService {
  VoiceNoteService._();
  static final VoiceNoteService instance = VoiceNoteService._();

  /// 移除 AI 偶爾包覆在外的 ```markdown 或 ``` 區塊標籤
  static String cleanRawMarkdown(String raw) {
    var content = raw.trim();
    if (content.startsWith('```markdown')) {
      content = content.replaceFirst(RegExp(r'^```markdown\s*'), '');
      if (content.endsWith('```')) {
        content = content.replaceFirst(RegExp(r'\s*```$'), '');
      }
    } else if (content.startsWith('```md')) {
      content = content.replaceFirst(RegExp(r'^```md\s*'), '');
      if (content.endsWith('```')) {
        content = content.replaceFirst(RegExp(r'\s*```$'), '');
      }
    } else if (content.startsWith('```') && content.endsWith('```')) {
      content = content.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      content = content.replaceFirst(RegExp(r'\s*```$'), '');
    }
    return content.trim();
  }

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
    try {
      return utf8.decode(base64Decode('QVEuQWI4Uk42SXg2NEUtQWdKQm51dm9DM1Vxcmh6QkUtM004TWRRR1NPYXZBcGdLMG1VOEE='));
    } catch (_) {
      return '';
    }
  }

  // ----------------------------------------------------------
  // 公開主方法：整理語音轉文字稿
  // ----------------------------------------------------------
  Future<VoiceNoteResult> organizeTranscript({
    required String transcript,
    required VoiceNoteStyle style,
    VoiceNoteDetailLevel detailLevel = VoiceNoteDetailLevel.detailed,
    String? userId,
  }) async {
    if (transcript.trim().isEmpty) {
      return VoiceNoteResult(
        title: tr('vs_blank_note'),
        category: style.suggestedCategory,
        markdownContent: '',
        tags: [],
        rawTranscript: transcript,
        isAiGenerated: false,
      );
    }

    final prompt = _buildPrompt(transcript, style, detailLevel);

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

    // 順位 2-A：Cloudflare Groq 快速引擎 (groq/compound)
    if (responseText == null || responseText.trim().isEmpty) {
      debugPrint(
          'VoiceNoteService: 切換 Cloudflare Groq 極速引擎 (groq/compound)...');
      responseText = await _tryCloudflareProxy(
        provider: 'groq',
        model: 'groq/compound',
        prompt: prompt,
        timeoutSeconds: 15,
      );
    }

    // 順位 2-B：Cloudflare Groq 深度引擎 (openai/gpt-oss-120b)
    if (responseText == null || responseText.trim().isEmpty) {
      debugPrint(
          'VoiceNoteService: 切換 Cloudflare Groq 深度模型 (openai/gpt-oss-120b)...');
      responseText = await _tryCloudflareProxy(
        provider: 'groq',
        model: 'openai/gpt-oss-120b',
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
    if ((responseText == null || responseText.trim().isEmpty) &&
        _kGeminiApiKey.isNotEmpty) {
      debugPrint('VoiceNoteService: 中繼站無回應，降級直連 Gemini API...');
      responseText = await _tryDirectGemini(prompt);
    }

    // 解析 AI 回傳的 JSON（支援新欄位：summary, key_points, action_items, mindmap）
    if (responseText != null && responseText.trim().isNotEmpty) {
      try {
        // 清理思考標籤與 markdown 程式碼區塊
        String cleanedResponse =
            AiDiagnosisService.cleanThinkingTags(responseText).trim();
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
                .map((e) =>
                    AiDiagnosisService.toTraditionalChinese(e.toString()))
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
                .map((e) =>
                    AiDiagnosisService.toTraditionalChinese(e.toString()))
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

        // ── 新增欄位：corrected_transcript (語意校正後之逐字稿) ──
        final rawCorrected = decoded['corrected_transcript'] as String?;
        final correctedTranscript = rawCorrected != null && rawCorrected.trim().isNotEmpty
            ? AiDiagnosisService.toTraditionalChinese(rawCorrected.trim())
            : null;

        final title = AiDiagnosisService.toTraditionalChinese(rawTitle);
        final cleanedContent = cleanRawMarkdown(rawContent);
        final markdownContent =
            AiDiagnosisService.toTraditionalChinese(cleanedContent);

        return VoiceNoteResult(
          title:
              title.isEmpty ? _generateFallbackTitle(transcript, style) : title,
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
          correctedTranscript: correctedTranscript,
        );
      } catch (e) {
        debugPrint('VoiceNoteService JSON parse error: $e\nRaw: $responseText');
      }
    }

    // 最終降級：本地規則式整理
    return _localFallback(transcript, style);
  }

  // ----------------------------------------------------------
  // 私有方法：情境感知 Prompt（五大專業風格 + 繁中在地化 + 細緻度控制）
  // ----------------------------------------------------------
  String _buildPrompt(
    String transcript,
    VoiceNoteStyle style,
    VoiceNoteDetailLevel detailLevel,
  ) {
    final langInstruction = AppLocaleService.getAiLanguageInstruction();
    final styleInstruction = _getStyleInstruction(style, detailLevel);
    final transcriptLen = transcript.length;

    // 長度動態適配引導
    String lengthHint;
    if (transcriptLen < 300) {
      lengthHint = '【長度適配】：輸入音訊內容較短（< 300字），請進行極致精煉，提煉最具價值的要點，避免強行注水擴寫。';
    } else if (transcriptLen > 3000) {
      lengthHint = '【長度適配】：輸入音訊內容較長（> 3000字），請嚴密進行章節分段，善用多層級標題歸納，避免遺漏核心細節。';
    } else {
      lengthHint = '【長度適配】：請依據內容長度適當展開，條理清晰、重點分明。';
    }

    final detailHint = detailLevel == VoiceNoteDetailLevel.concise
        ? '【微調層級：⚡ 精簡 (Concise)】：極速提煉核心結論與關鍵要點，去蕪存菁，省略次要細節與背景贅述。'
        : '【微調層級：📚 詳盡 (Detailed)】：完整梳理邏輯脈絡、推導過程、論述細節與因果關係，結構豐富完備。';

    return '''
你是一位頂級的語音筆記整理與逐字稿語意校正專家，擅長把口語化、中英夾雜的逐字稿進行專業校正，並轉換為自然、清晰、有條理的專業結構化筆記。

【核心原則】
1. 說話者分離 (Diarization) 與標點符號完整校正：
   - 說話者辨識 (Diarization)：若輸入語音逐字稿含有多位說話者或時間戳（例如 [00:15] 說話者 1: ... 或對話語境），請在 "corrected_transcript" 與 "content" 中明確保留與區分「說話者 1」、「說話者 2」或角色名稱。
   - 標點符號完整化：強制為所有語句補充輸出語言對應的正確標點符號，嚴禁輸出完全無標點符號的連續文字。
   - 精確校正中英文專有名詞、專業術語、同音錯字（例如將「摸豆」校正為「Model」、「API」、「Flutter」等），並剔除口語贅字（如「呃、啊、那個」）。
2. 術語規範（僅在輸出語言為繁體中文時適用）：
   - 專案（嚴禁使用「項目」稱呼 Project）
   - 使用者（嚴禁使用「用戶」）
   - 資料庫（嚴禁使用「數據庫」）
   - 程式碼（嚴禁使用「代碼」）
   - 伺服器（嚴禁使用「服務器」）
   - 支援（嚴禁使用「支持」表示功能支援）
   - 透過（嚴禁使用「通過」表示手段途徑）
   - 資訊（嚴禁使用「信息」指稱 Data/Info）
   - 預設（嚴禁使用「默認」）
   - 即時（嚴禁使用「實時」）
   - 最佳化（嚴禁使用「優化」）
   - 雲端（嚴禁使用「雲」）
3. 防通靈與防空標籤規範：
   - 嚴禁通靈未在語音中提及的人名、日期或數據。若未提及負責人標註「[未指定]」，未提及期限標註「[待定]」（這兩個佔位詞請原樣保留不翻譯）。
   - 若語音中完全無待辦事項，action_items 必須回傳空陣列 []，嚴禁生成「無」、「無待辦」等佔位文字。
4. $lengthHint
5. $detailHint

$styleInstruction

【JSON 輸出格式規範】
你必須只回傳一個乾淨、標準的 JSON 物件，不得包含任何 Markdown 代碼塊（```json）前後包裝，直接以 { 開頭以 } 結尾：

{
  "title": "簡短精確的筆記標題（15字以內）",
  "category": "${style.suggestedCategory}",
  "summary": "核心情境摘要（1~2句，讓人一眼看懂這是什麼內容）",
  "key_points": ["關鍵重點1", "關鍵重點2", "關鍵重點3"],
  "action_items": [
    { "task": "動作描述", "owner": "負責人（無則填未指定）", "due_date": "期限（無則填待定）", "is_completed": false }
  ],
  "mindmap": {
    "id": "root",
    "label": "核心主題",
    "color": "#673AB7",
    "children": [
      { "id": "n1", "label": "核心要點", "color": "#3F51B5",
        "children": [{ "id": "n1_1", "label": "細節解析", "color": "#2196F3", "children": [] }] }
    ]
  },
  "content": "完整的 Markdown 筆記內容（請嚴格依照風格指示排版）",
  "corrected_transcript": "校正後的逐字稿（保留說話者標籤與時間戳格式，若無時間戳則輸出校正後文稿）",
  "tags": ["關鍵標籤1", "關鍵標籤2", "關鍵標籤3"]
}

【原始語音轉文字稿】：
$transcript

$langInstruction
''';
  }

  String _getStyleInstruction(VoiceNoteStyle style, VoiceNoteDetailLevel detailLevel) {
    switch (style) {
      case VoiceNoteStyle.academicLecture:
        return '''
【整理風格：🎓 課堂與學術研討】
架構依據康乃爾分層筆記法，請在 content 中輸出以下結構：
# 🎓 [主題名稱]
## 📖 核心名詞與術語解析
- **[術語名]**：以指定的輸出語言給予清晰白話之定義與核心概念。
## 🧠 課堂脈絡與考點梳理
梳理課程觀念、推導因果與重要關聯點。
## ❓ 自我檢測問答 (Active Recall)
提供 3~5 題幫助主動回憶的問答題：
- **Q1**：[關鍵問題？]
  - **A**：[核心解答提示與解析]
''';

      case VoiceNoteStyle.agileMeeting:
        return '''
【整理風格：💼 敏捷商務會議】
以決策導向與行動落實為核心，請在 content 中輸出以下結構：
# 💼 [會議主題名稱]
## ⚡ 一話決策 (Executive TL;DR)
> 1 句話精準概括本次會議最重大之核心結論或推進決策。
## 🤝 議程共識與決議
條列說明各項討論達成的明確共識。
## ✅ 待辦行動清單
使用可勾選清單，格式嚴格遵循：
- [ ] [具體動作] (負責人: [姓名或未指定] | 預計時程: [日期或待定])
（同時將上述各項待辦填入 JSON 的 action_items 陣列）
''';

      case VoiceNoteStyle.speedSummary:
        return '''
【整理風格：⚡ 極速速讀摘要】
以極致降噪、快速決策為核心，請在 content 中輸出以下結構：
# ⚡ [精華速讀標題]
## 🎯 30秒核心金句（3 條具體數據／關鍵事實）
1. [具體事實／數據 1]
2. [具體事實／數據 2]
3. [具體事實／數據 3]
## 📊 核心論點與觀點對比表
強制使用 Markdown 表格進行梳理：
| 分析維度 | 核心觀點／現況 | 考量點／潛在挑戰 |
| :--- | :--- | :--- |
| [維度 1] | [內容描述] | [考量點] |
| [維度 2] | [內容描述] | [考量點] |
''';

      case VoiceNoteStyle.structureMindmap:
        return '''
【整理風格：🧠 架構拆解與心智圖】
以層級結構化拓撲為核心，請在 content 中輸出階層大綱與 Mermaid 思維導圖語法：
# 🧠 [核心架構主題]
## 🌳 階層化知識大綱
嚴格使用最多三層之標題與符號：
- # 一級架構
  - ## 二級子模組
    - ### 三級要點解析
## 🗺️ Mermaid 思維導圖
```mermaid
mindmap
  root(([主題名稱]))
    分支一
      子點1
      子點2
    分支二
      子點3
```
（同時將樹狀階層結構完整填入 JSON 的 mindmap 欄位，供 App 互動式心智圖畫布展示）
''';

      case VoiceNoteStyle.inspirationJournal:
        return '''
【整理風格：💡 靈感閃念與隨筆】
保留思維原味與心流，請在 content 中輸出以下結構：
# 💡 [靈感隨筆主題]
## 🌟 核心閃念亮點
> [提取最具啟發性的 1~2 句思維火花金句]
## 💭 心得感悟與靈感流動
輕盈自然的隨想流動記錄。
## 🏷️ 延伸聯想與思考方向
- #思考延伸 [方向1]
- #未來應用 [方向2]
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
      debugPrint(
          'VoiceNoteService Cloudflare [$provider] ${response.statusCode}: ${response.body.substring(0, response.body.length.clamp(0, 200))}');
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
        model: 'gemini-3.6-flash',
        apiKey: _kGeminiApiKey,
      );
      final response = await model.generateContent(
          [Content.text(prompt)]).timeout(const Duration(seconds: 25));
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
    final truncated =
        preview.length > 12 ? '${preview.substring(0, 12)}...' : preview;
    if (truncated.isEmpty) return '${style.emoji} ${style.label}';
    return '${style.emoji} $truncated';
  }

  String _buildFallbackContent(String transcript, VoiceNoteStyle style) {
    final buffer = StringBuffer();

    switch (style) {
      case VoiceNoteStyle.academicLecture:
        buffer.writeln(tr('vs_off_lecture_h', [style.emoji.toString()]));
        buffer.writeln();
        buffer.writeln(tr('vs_off_terms'));
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        buffer.writeln();
        buffer.writeln(tr('vs_off_recall'));
        buffer.writeln(tr('vs_off_q1'));
        buffer.writeln('  - **A**：請根據筆記要點回想並自我解答。');
        break;
      case VoiceNoteStyle.agileMeeting:
        buffer.writeln(tr('vs_off_meeting_h', [style.emoji.toString()]));
        buffer.writeln();
        buffer.writeln(tr('vs_off_date', [(DateTime.now().toString().substring(0, 10)).toString()]));
        buffer.writeln();
        buffer.writeln(tr('vs_off_tldr'));
        buffer.writeln(tr('vs_off_tldr_body'));
        buffer.writeln();
        buffer.writeln(tr('vs_off_agenda'));
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        buffer.writeln();
        buffer.writeln(tr('vs_off_todos'));
        buffer.writeln(tr('vs_off_todo1'));
        break;
      case VoiceNoteStyle.speedSummary:
        buffer.writeln(tr('vs_off_speed_h', [style.emoji.toString()]));
        buffer.writeln();
        buffer.writeln(tr('vs_off_30s'));
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        buffer.writeln();
        buffer.writeln(tr('vs_off_table_h'));
        buffer.writeln(tr('vs_off_table_cols'));
        buffer.writeln('| :--- | :--- | :--- |');
        buffer.writeln(tr('vs_off_table_row'));
        break;
      case VoiceNoteStyle.structureMindmap:
        buffer.writeln(tr('vs_off_mindmap_h', [style.emoji.toString()]));
        buffer.writeln();
        buffer.writeln(tr('vs_off_outline'));
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        buffer.writeln();
        buffer.writeln(tr('vs_off_mermaid'));
        buffer.writeln('```mermaid');
        buffer.writeln('mindmap');
        buffer.writeln('  root((${style.label}))');
        buffer.writeln('    核心要點');
        buffer.writeln('      重點細節');
        buffer.writeln('```');
        break;
      case VoiceNoteStyle.inspirationJournal:
        buffer.writeln(tr('vs_off_journal_h', [style.emoji.toString()]));
        buffer.writeln();
        buffer.writeln(tr('vs_off_spark'));
        buffer.writeln(tr('vs_off_spark_body'));
        buffer.writeln();
        buffer.writeln(tr('vs_off_feel'));
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        buffer.writeln();
        buffer.writeln(tr('vs_off_extend'));
        buffer.writeln(tr('vs_off_extend_1'));
        break;
    }

    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln(tr('vs_off_footer'));
    return buffer.toString();
  }

  void _appendParagraphs(StringBuffer buffer, String transcript) {
    // 依照中文句號、逗號、換行分段，並自動補齊合適之繁體中文標點符號
    final punctuated = VoiceRecognitionService.ensureChinesePunctuation(transcript);
    final sentences = punctuated
        .split(RegExp(r'\n+'))
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
