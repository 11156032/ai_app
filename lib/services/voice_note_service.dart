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
        return '精簡';
      case VoiceNoteDetailLevel.detailed:
        return '詳盡';
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
        return '極速提煉核心結論與關鍵要點，去蕪存菁';
      case VoiceNoteDetailLevel.detailed:
        return '完整梳理邏輯脈絡、深度解析與推導過程';
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
        return '課堂研討';
      case VoiceNoteStyle.agileMeeting:
        return '商務會議';
      case VoiceNoteStyle.speedSummary:
        return '速讀摘要';
      case VoiceNoteStyle.structureMindmap:
        return '架構心智圖';
      case VoiceNoteStyle.inspirationJournal:
        return '靈感隨筆';
    }
  }

  String get fullName {
    switch (this) {
      case VoiceNoteStyle.academicLecture:
        return '課堂與學術研討';
      case VoiceNoteStyle.agileMeeting:
        return '敏捷商務會議';
      case VoiceNoteStyle.speedSummary:
        return '極速速讀摘要';
      case VoiceNoteStyle.structureMindmap:
        return '架構拆解與心智圖';
      case VoiceNoteStyle.inspirationJournal:
        return '靈感閃念與隨筆';
    }
  }

  String get subtitle {
    switch (this) {
      case VoiceNoteStyle.academicLecture:
        return '知識吸收・考證與複習';
      case VoiceNoteStyle.agileMeeting:
        return '決策・進度與執行對齊';
      case VoiceNoteStyle.speedSummary:
        return '快速掌握長文／長語音核心';
      case VoiceNoteStyle.structureMindmap:
        return '複雜知識拓撲與系統規劃';
      case VoiceNoteStyle.inspirationJournal:
        return '捕捉點子・生活感悟';
    }
  }

  String get badgeTag {
    switch (this) {
      case VoiceNoteStyle.academicLecture:
        return '康乃爾分層';
      case VoiceNoteStyle.agileMeeting:
        return '決策+待辦';
      case VoiceNoteStyle.speedSummary:
        return '極致降噪';
      case VoiceNoteStyle.structureMindmap:
        return '純層級視覺';
      case VoiceNoteStyle.inspirationJournal:
        return '思維原味';
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
        return '康乃爾分層架構：核心名詞解析（Bold + 繁中定義）、脈絡邏輯筆記與 3~5 題自我檢測 QA（Active Recall）';
      case VoiceNoteStyle.agileMeeting:
        return '決策與落地導向：一話決策（Executive TL;DR）、核心共識結論與可勾選待辦清單（動作 + 負責人 + 預計時程）';
      case VoiceNoteStyle.speedSummary:
        return '極致降噪：30 秒吸收重點（3 條具體數據金句）與正反觀點／核心論點對比 Markdown 表格';
      case VoiceNoteStyle.structureMindmap:
        return '純層級視覺：多層級結構大綱（最多三層）＋ 內嵌 Mermaid 思維導圖語法與原生互動心智圖';
      case VoiceNoteStyle.inspirationJournal:
        return '保留思維原味：核心亮點提取（> 引用塊）與延伸思考方向聯想標籤（Chips 格式）';
    }
  }

  List<String> get featureHighlights {
    switch (this) {
      case VoiceNoteStyle.academicLecture:
        return [
          '核心名詞與觀念解析（Bold + 繁中定義）',
          '章節脈絡邏輯筆記與考點梳理',
          '3～5 題主動回憶自我檢測 QA (Active Recall)',
        ];
      case VoiceNoteStyle.agileMeeting:
        return [
          '一話決策（Executive TL;DR 速報）',
          '核心共識與各議程決議事項',
          '可勾選待辦清單（- [ ] 動作 + 負責人 + 期限）',
        ];
      case VoiceNoteStyle.speedSummary:
        return [
          '30 秒極速吸收（3 條具體事實數據金句）',
          '正反觀點／核心論點對比（強制 Markdown 表格）',
          '直擊精要，極致剔除口語贅字',
        ];
      case VoiceNoteStyle.structureMindmap:
        return [
          '多層級結構大綱（嚴格依賴 #、##、###，最多三層）',
          '內嵌 Mermaid 思維導圖代碼塊',
          '同步生成可全螢幕探索之互動樹狀心智圖',
        ];
      case VoiceNoteStyle.inspirationJournal:
        return [
          '核心亮點提取（> 引用塊醒目標註）',
          '生活感悟、靈感火花與真實思考流動',
          '延伸思考方向與聯想標籤（Chips 格式）',
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
        title: '空白語音筆記',
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
   - 標點符號完整化：強制為所有語句補充正確全角繁體中文標點符號（句號「。」、逗號「，」、問號「？」、驚嘆號「！」），嚴禁輸出完全無標點符號的連續文字。
   - 精確校正中英文專有名詞、專業術語、同音錯字（例如將「摸豆」校正為「Model」、「API」、「Flutter」等），並剔除口語贅字（如「呃、啊、那個」）。
2. 台灣繁體中文（正體中文）術語強制規範：
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
   - 嚴禁通靈未在語音中提及的人名、日期或數據。若未提及負責人標註「[未指定]」，未提及期限標註「[待定]」。
   - 若語音中完全無待辦事項，action_items 必須回傳空陣列 []，嚴禁生成「無」、「無待辦」等佔位文字。
4. $lengthHint
5. $detailHint

$styleInstruction

【JSON 輸出格式規範】
你必須只回傳一個乾淨、標準的 JSON 物件，不得包含任何 Markdown 代碼塊（```json）前後包裝，直接以 { 開頭以 } 結尾：

{
  "title": "簡短精確的筆記標題（15字以內，繁體中文）",
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
- **[術語名]**：以台灣繁體中文給予清晰白話之定義與核心概念。
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
        buffer.writeln('# ${style.emoji} 課堂與學術研討筆記');
        buffer.writeln();
        buffer.writeln('## 📖 核心名詞與觀念解析');
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        buffer.writeln();
        buffer.writeln('## ❓ 主動回憶自我檢測 (Active Recall)');
        buffer.writeln('- **Q1**：此主題的核心意涵為何？');
        buffer.writeln('  - **A**：請根據筆記要點回想並自我解答。');
        break;
      case VoiceNoteStyle.agileMeeting:
        buffer.writeln('# ${style.emoji} 敏捷商務會議摘要');
        buffer.writeln();
        buffer.writeln('**記錄日期**：${DateTime.now().toString().substring(0, 10)}');
        buffer.writeln();
        buffer.writeln('## ⚡ 一話決策 (TL;DR)');
        buffer.writeln('> 本次會議針對核心推進方向達成共識。');
        buffer.writeln();
        buffer.writeln('## 🤝 議程討論與決議事項');
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        buffer.writeln();
        buffer.writeln('## ✅ 待辦行動清單');
        buffer.writeln('- [ ] 確認後續跟進步驟 (負責人: [待指派] | 預計時程: [待定])');
        break;
      case VoiceNoteStyle.speedSummary:
        buffer.writeln('# ${style.emoji} 極速速讀摘要');
        buffer.writeln();
        buffer.writeln('## 🎯 30秒核心金句');
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        buffer.writeln();
        buffer.writeln('## 📊 核心論點對比表');
        buffer.writeln('| 分析維度 | 核心要點 | 考量重點 |');
        buffer.writeln('| :--- | :--- | :--- |');
        buffer.writeln('| 核心議題 | 詳見上方重點整理 | 需持續評估跟進 |');
        break;
      case VoiceNoteStyle.structureMindmap:
        buffer.writeln('# ${style.emoji} 架構拆解與心智圖');
        buffer.writeln();
        buffer.writeln('## 🌳 階層化知識大綱');
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        buffer.writeln();
        buffer.writeln('## 🗺️ Mermaid 思維導圖');
        buffer.writeln('```mermaid');
        buffer.writeln('mindmap');
        buffer.writeln('  root((${style.label}))');
        buffer.writeln('    核心要點');
        buffer.writeln('      重點細節');
        buffer.writeln('```');
        break;
      case VoiceNoteStyle.inspirationJournal:
        buffer.writeln('# ${style.emoji} 靈感閃念與隨筆');
        buffer.writeln();
        buffer.writeln('## 🌟 核心閃念亮點');
        buffer.writeln('> 捕捉生活與思維的靈感火花。');
        buffer.writeln();
        buffer.writeln('## 💭 心得感悟與靈感流動');
        buffer.writeln();
        _appendParagraphs(buffer, transcript);
        buffer.writeln();
        buffer.writeln('## 🏷️ 延伸聯想與思考方向');
        buffer.writeln('- #靈感延伸 探索應用可能性');
        break;
    }

    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('*⚠️ 此為語音原始記錄（離線整理），可手動編輯調整。*');
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
