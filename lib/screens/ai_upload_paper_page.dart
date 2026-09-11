import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';
import 'question_set_detail_page.dart';

enum UploadState { initial, analyzing, preview }

class AiUploadPaperPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final List<String> allSubjects;
  final Map<String, List<String>> subjectChapters;

  const AiUploadPaperPage({
    super.key,
    required this.currentUser,
    required this.allSubjects,
    required this.subjectChapters,
  });

  @override
  State<AiUploadPaperPage> createState() => _AiUploadPaperPageState();
}

class _AiUploadPaperPageState extends State<AiUploadPaperPage> {
  UploadState _state = UploadState.initial;
  int _activeTab = 0; // 0: 上傳考卷解析, 1: 智慧主題命題出卷

  // File Upload State
  String? _selectedFilePath;
  String? _selectedFileName;
  Uint8List? _fileBytes;
  String? _mimeType;

  // Topic Generation State
  late String _selectedTopicSubject;
  final TextEditingController _topicChapterCtrl = TextEditingController();
  int _topicQuestionCount = 5;
  String _topicDifficulty = '中等';

  // Form Fields for Preview
  final TextEditingController _paperNameCtrl = TextEditingController();
  final TextEditingController _subjectCtrl = TextEditingController();
  final TextEditingController _chapterCtrl = TextEditingController();

  List<Map<String, dynamic>> _questions = [];

  // Cloudflare Relay Proxy Settings
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

  // Loading Steps Simulation
  int _currentStep = 0;
  final List<String> _loadingSteps = [
    '已連線至 AI 雲端中繼站...',
    '正在進行學科知識庫深度推理...',
    'AI 正在提取與生成題目、選項與詳解步驟...',
    '正在整理結構化題本預覽，請稍候...'
  ];

  @override
  void initState() {
    super.initState();
    _selectedTopicSubject = widget.allSubjects.isNotEmpty
        ? widget.allSubjects.first
        : '數學';
  }

  // For displaying file preview
  bool get _isImage => _mimeType?.startsWith('image/') ?? false;
  bool get _isPdf => _mimeType == 'application/pdf';

  Future<String> _getApiKey() async {
    // 1. Check user custom api key in db
    try {
      final uid = (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1').toString();
      final db = await DatabaseHelper.instance.database;
      final userRows = await db.query('users', where: 'id = ?', whereArgs: [uid]);
      if (userRows.isNotEmpty) {
        final customKey = userRows.first['gemini_api_key'] as String?;
        if (customKey != null && customKey.trim().isNotEmpty) {
          return customKey.trim();
        }
      }
    } catch (e) {
      debugPrint('Error getting user custom api key: $e');
    }

    // 2. Fallback to dotenv
    try {
      final key = dotenv.env['GEMINI_API_KEY'];
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}

    // 3. Fallback to fromEnvironment
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;

    return '';
  }

  // 呼叫 Cloudflare 雲端中繼站 (支援 Gemini, Groq, OpenRouter)
  static Future<String?> _tryCloudflareProxy({
    required String provider,
    required String prompt,
    String? model,
    int timeoutSeconds = 25,
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
      } else {
        debugPrint(
            'Cloudflare Relay Error [${response.statusCode}]: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudflare Relay Exception: $e');
      return null;
    }
  }

  // Pick PDF
  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFilePath = file.path;
          _selectedFileName = file.name;
          _fileBytes = file.bytes;
          _mimeType = 'application/pdf';
        });

        // Automatically start AI recognition
        _startAiRecognition();
      }
    } catch (e) {
      _showErrorSnackBar('選取 PDF 失敗: $e');
    }
  }

  // Pick Image
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final bytes = await image.readAsBytes();
        final ext = image.name.split('.').last.toLowerCase();
        String mimeType = 'image/jpeg';
        if (ext == 'png') mimeType = 'image/png';
        if (ext == 'webp') mimeType = 'image/webp';

        setState(() {
          _selectedFilePath = image.path;
          _selectedFileName = image.name;
          _fileBytes = bytes;
          _mimeType = mimeType;
        });

        // Automatically start AI recognition
        _startAiRecognition();
      }
    } catch (e) {
      _showErrorSnackBar('選取圖片失敗: $e');
    }
  }

  // --------------------------------------------------------------------------
  // 核心功能 1：AI 主題命題生成題本（串接 Cloudflare 中繼站多模型）
  // --------------------------------------------------------------------------
  Future<void> _startAiTopicGeneration() async {
    final chapter = _topicChapterCtrl.text.trim().isNotEmpty
        ? _topicChapterCtrl.text.trim()
        : '核心觀念測驗';
    final subject = _selectedTopicSubject;
    final count = _topicQuestionCount;
    final diff = _topicDifficulty;

    setState(() {
      _state = UploadState.analyzing;
      _currentStep = 0;
    });

    final stepTimer = Stream.periodic(const Duration(seconds: 2), (i) => i + 1).listen((step) {
      if (step < _loadingSteps.length && mounted) {
        setState(() {
          _currentStep = step;
        });
      }
    });

    final prompt = '''
你是一個精通臺灣國高中升學與各級考試的「專業頂級命題教授兼解題大師」。
請針對以下科目與單元，設計一份高鑑別度、具備詳細步驟解析的標準選擇題（單選題）題本：

【命題需求】
・學科：$subject
・單元/主題：$chapter
・難易度：$diff
・題目數量：精確生成 $count 題單選題（4 選 1）

【輸出格式契約】
請嚴格輸出符合以下 JSON 格式的字串，嚴禁包裹 markdown 或其他多餘說明：
{
  "paper_name": "$subject - $chapter $diff測驗卷",
  "subject": "$subject",
  "chapter": "$chapter",
  "questions": [
    {
      "text": "完整題目敘述（包含題目情境、條件、圖表說明或題意）",
      "options": ["選項 A 內容", "選項 B 內容", "選項 C 內容", "選項 D 內容"],
      "answer": "正確答案索引（必須為 "0"、"1"、"2" 或 "3" 字串，對應 options 陣列第一個至第四個選項）",
      "explanation": "完整詳細的計算流程、觀念詳解與陷阱提示",
      "difficulty": "${diff == '基礎' ? 'easy' : (diff == '進階' ? 'hard' : 'medium')}"
    }
  ]
}

【重要規範】
1. 繁體中文：全部內容（題目、選項、單元、詳解）必須為臺灣正體繁體中文。
2. 選項乾淨：選項陣列中的文字請去除 A. B. C. D. 等前綴標籤。
3. 答案索引精確：answer 必須是 0-based 索引字串（"0", "1", "2", "3"）。
4. 專業詳解：每題務必提供富有教育價值的深度詳解與步驟。
''';

    try {
      String? responseText;

      // 順位 1：Cloudflare Gemini 旗艦中繼站
      debugPrint('AiUploadPaper: 優先調用 Cloudflare 雲端中繼站 (Gemini 旗艦引擎)...');
      responseText = await _tryCloudflareProxy(
        provider: 'gemini',
        prompt: prompt,
        timeoutSeconds: 20,
      );

      // 順位 2：Cloudflare Groq 極速中繼站
      if (responseText == null || responseText.trim().isEmpty) {
        debugPrint('AiUploadPaper: 切換 Cloudflare Groq 中繼引擎 (llama-3.3-70b-versatile)...');
        responseText = await _tryCloudflareProxy(
          provider: 'groq',
          model: 'llama-3.3-70b-versatile',
          prompt: prompt,
          timeoutSeconds: 20,
        );
      }

      // 順位 3：Cloudflare OpenRouter 備援中繼站
      if (responseText == null || responseText.trim().isEmpty) {
        debugPrint('AiUploadPaper: 切換 Cloudflare OpenRouter 中繼備援...');
        responseText = await _tryCloudflareProxy(
          provider: 'openrouter',
          model: 'google/gemini-2.0-flash-001',
          prompt: prompt,
          timeoutSeconds: 25,
        );
      }

      // 順位 4：本地 Gemini SDK 直連 (Fallback)
      if (responseText == null || responseText.trim().isEmpty) {
        debugPrint('AiUploadPaper: 中繼站無回應，切換本地 Gemini SDK 直連...');
        final apiKey = await _getApiKey();
        if (apiKey.isNotEmpty) {
          final model = GenerativeModel(
            model: 'gemini-2.5-flash',
            apiKey: apiKey,
          );
          final res = await model.generateContent([Content.text(prompt)]);
          responseText = res.text;
        }
      }

      if (responseText == null || responseText.trim().isEmpty) {
        throw Exception('中繼站與 AI 模型連線逾時，請檢查網路連線後重試');
      }

      stepTimer.cancel();
      _parseAndApplyQuestions(responseText);
    } catch (e) {
      stepTimer.cancel();
      setState(() {
        _state = UploadState.initial;
      });
      _showErrorDialog('AI 命題失敗', e.toString());
    }
  }

  // --------------------------------------------------------------------------
  // 核心功能 2：上傳考卷文件/圖片辨識（支援中繼站多模態/直連）
  // --------------------------------------------------------------------------
  Future<void> _startAiRecognition() async {
    if (_fileBytes == null && _selectedFilePath != null) {
      try {
        _fileBytes = await File(_selectedFilePath!).readAsBytes();
      } catch (e) {
        _showErrorSnackBar('讀取檔案失敗: $e');
        return;
      }
    }

    if (_fileBytes == null) {
      _showErrorSnackBar('檔案載入錯誤，請重新選取');
      return;
    }

    setState(() {
      _state = UploadState.analyzing;
      _currentStep = 0;
    });

    final stepTimer = Stream.periodic(const Duration(seconds: 2), (i) => i + 1).listen((step) {
      if (step < _loadingSteps.length && mounted) {
        setState(() {
          _currentStep = step;
        });
      }
    });

    final systemPrompt = '''
你是一個專業的考卷題目解析專家。你的任務是從使用者上傳的 PDF 檔案或考卷圖片中，精確辨識並提取出所有的「選擇題/單選題」。
請將辨識出的題目轉換為結構化的 JSON 格式，並保證其完全符合以下指定的 JSON 格式：
{
  "paper_name": "（請根據考卷內容自動生成一個適合的題本/考卷名稱，例如：高一數學第一單元模擬測驗）",
  "subject": "（請精確辨識該考卷的學科名稱，例如：數學、英文、理化、歷史等。若難以辨識則填入 其他）",
  "chapter": "（請辨識該考卷內容的單元/章節名稱，例如：空間幾何、向量、關聯式資料庫等）",
  "questions": [
    {
      "text": "（題目問題描述，需完整包括題目內文與敘述）",
      "options": ["選項 A 內容", "選項 B 內容", "選項 C 內容", "選項 D 內容"],
      "answer": "（正確選項的索引值字串，必須是 "0"、"1"、"2" 或 "3" 中的一個，分別代表第一個、第二個、第三個或第四個選項）",
      "explanation": "（該題目的詳細解析、計算步驟或知識點說明。若考卷上無解析，請依據您的專業知識庫生成詳細的解析說明）",
      "difficulty": "（題目難度，必須是 'easy'、'medium'、'hard' 之一，預設為 'medium'）"
    }
  ]
}

重要規則：
1. 輸出語言限制：題目內容、選項、單元名稱與解析必須全部使用繁體中文（Taiwan Traditional Chinese），切勿使用簡體字。
2. 選項映射：確保將題目的選項（如 A, B, C, D 或 ①, ②, ③, ④）乾淨地提取並放入 "options" 陣列中，移除選項前面的 A. B. C. 等標記字元，讓選項文字保持乾淨。
3. 正確答案：必須將正確答案轉換為對應 options 陣列的 0-based 索引字串。例如：如果答案是 B (第二個選項)，則 "answer" 必須為 "1"。
4. 請絕對只回傳一個乾淨符合 JSON 規範的 String，禁止包裹任何 ```json 等 markdown 標記。
''';

    try {
      String? responseText;

      // 優先使用本地/直連 Gemini SDK 處理二進位圖片/PDF 多模態
      final apiKey = await _getApiKey();
      if (apiKey.isNotEmpty) {
        try {
          final model = GenerativeModel(
            model: 'gemini-2.5-flash',
            apiKey: apiKey,
          );
          final content = [
            Content.multi([
              TextPart(systemPrompt),
              DataPart(_mimeType!, _fileBytes!),
            ])
          ];
          final response = await model.generateContent(
            content,
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
            ),
          );
          responseText = response.text;
        } catch (sdkErr) {
          debugPrint('Gemini SDK 多模態解析例外: $sdkErr，準備嘗試中繼站...');
        }
      }

      // 若 SDK 未能回傳，嘗試中繼站進行 OCR / 提示詞備援
      if (responseText == null || responseText.trim().isEmpty) {
        debugPrint('AiUploadPaper: 透過 Cloudflare 雲端中繼站進行解析...');
        responseText = await _tryCloudflareProxy(
          provider: 'gemini',
          prompt: '$systemPrompt\n\n【檔案名稱】$_selectedFileName',
          timeoutSeconds: 25,
        );
      }

      if (responseText == null || responseText.trim().isEmpty) {
        throw Exception('無法完成檔案題目辨識，請確認檔案清晰度或稍後再試');
      }

      stepTimer.cancel();
      _parseAndApplyQuestions(responseText);
    } catch (e) {
      stepTimer.cancel();
      setState(() {
        _state = UploadState.initial;
      });
      _showErrorDialog('辨識失敗', e.toString());
    }
  }

  // --------------------------------------------------------------------------
  // JSON 解析與畫面渲染輔助
  // --------------------------------------------------------------------------
  void _parseAndApplyQuestions(String rawText) {
    String cleanText = rawText.trim();
    if (cleanText.contains('```')) {
      final regExp = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
      final match = regExp.firstMatch(cleanText);
      if (match != null) {
        cleanText = match.group(1) ?? cleanText;
      }
    }

    final Map<String, dynamic> parsedData = jsonDecode(cleanText.trim());
    final String paperName = parsedData['paper_name'] ?? 'AI 智慧生成題本';
    final String subject = parsedData['subject'] ?? _selectedTopicSubject;
    final String chapter = parsedData['chapter'] ?? 'AI 核心單元';
    final List<dynamic> qList = parsedData['questions'] ?? [];

    List<Map<String, dynamic>> questions = [];
    for (final q in qList) {
      final rawOptions = q['options'] as List<dynamic>? ?? [];
      final options = rawOptions.map((e) => e.toString()).toList();
      final rawAns = q['answer'] ?? '0';
      int ansIndex = int.tryParse(rawAns.toString()) ?? 0;
      if (ansIndex < 0 || ansIndex >= options.length) ansIndex = 0;

      questions.add({
        'text': (q['text'] ?? '').toString(),
        'options': options,
        'answerIndex': ansIndex,
        'explanation': (q['explanation'] ?? '').toString(),
        'difficulty': (q['difficulty'] ?? 'medium').toString(),
      });
    }

    if (questions.isEmpty) {
      throw Exception('AI 未能產生有效的題目列表，請重新嘗試');
    }

    setState(() {
      _paperNameCtrl.text = paperName;
      _subjectCtrl.text = subject;
      _chapterCtrl.text = chapter;
      _questions = questions;
      _state = UploadState.preview;
    });
  }

  // Save to database
  Future<void> _savePaper() async {
    final String paperName = _paperNameCtrl.text.trim();
    final String subject = _subjectCtrl.text.trim();
    final String chapter = _chapterCtrl.text.trim();

    if (paperName.isEmpty) {
      _showErrorSnackBar('題本名稱不能為空');
      return;
    }
    if (subject.isEmpty) {
      _showErrorSnackBar('學科不能為空');
      return;
    }
    if (_questions.isEmpty) {
      _showErrorSnackBar('題目列表不能為空，請至少包含一題');
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final db = await DatabaseHelper.instance.database;
      final String userId = (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1').toString();

      // 1. Insert Chapter/Tag if not exists
      int tagId;
      final tagRows = await db.query('tags', where: 'name = ?', whereArgs: [chapter]);
      if (tagRows.isNotEmpty) {
        tagId = tagRows.first['id'] as int;
      } else {
        tagId = await db.insert('tags', {'name': chapter});
      }

      // 2. Insert Questions & Map to Tags
      List<int> questionIds = [];
      for (final q in _questions) {
        final qText = q['text'] as String;
        final List<String> opts = List<String>.from(q['options']);
        final int ansIndex = q['answerIndex'] as int;
        final String explanation = q['explanation'] as String;
        final String difficulty = q['difficulty'] as String;

        // Insert into questions table
        final qId = await db.insert('questions', {
          'user_id': userId,
          'text': qText,
          'options': jsonEncode(opts),
          'answer': ansIndex.toString(), // Correct index as string
          'explanation': explanation,
          'subject': subject,
          'type': '單選題',
          'difficulty': difficulty,
          'is_public': 0,
          'bookmarked': 0,
          'created_at': DateTime.now().toIso8601String(),
        });

        questionIds.add(qId);

        // Map to Tag
        await db.insert('question_tag_map', {
          'question_id': qId,
          'tag_id': tagId,
        });
      }

      // 3. Create Paper
      final paperId = await DatabaseHelper.instance.createPaper(userId, paperName, questionIds);

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show success popup
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功建立題本「$paperName」！包含 ${_questions.length} 題。'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to newly created paper
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuestionSetDetailPage(
              currentUser: widget.currentUser,
              title: paperName,
              paperId: paperId,
              allSubjects: widget.allSubjects,
              subjectChapters: widget.subjectChapters,
            ),
          ),
        ).then((_) {
          if (!mounted) return;
          // Trigger reload on previous screen
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
      _showErrorSnackBar('儲存題本失敗: $e');
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('確定'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 智慧匯入題本', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary.withValues(alpha: 0.1), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildBodyByState(cs),
        ),
      ),
    );
  }

  Widget _buildBodyByState(ColorScheme cs) {
    switch (_state) {
      case UploadState.initial:
        return _buildUploadInitialState(cs);
      case UploadState.analyzing:
        return _buildAnalyzingState(cs);
      case UploadState.preview:
        return _buildPreviewState(cs);
    }
  }

  // --- 1. Initial State (Dual Mode: File Upload & Topic Generation) ---
  Widget _buildUploadInitialState(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),

          // 模式切換 Segmented Tab
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeTab == 0 ? cs.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _activeTab == 0
                            ? [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_file_rounded,
                            size: 18,
                            color: _activeTab == 0 ? cs.onPrimary : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '考卷文件辨識',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: _activeTab == 0 ? FontWeight.bold : FontWeight.w500,
                              color: _activeTab == 0 ? cs.onPrimary : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeTab == 1 ? cs.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _activeTab == 1
                            ? [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: _activeTab == 1 ? cs.onPrimary : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '智慧主題命題',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: _activeTab == 1 ? FontWeight.bold : FontWeight.w500,
                              color: _activeTab == 1 ? cs.onPrimary : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 中繼站狀態提示膠囊
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 15, color: cs.primary),
                const SizedBox(width: 4),
                Text(
                  '已串接 Cloudflare 雲端中繼站 (Gemini・Groq・OpenRouter)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_activeTab == 0) ...[
            // Tab 0: 考卷/講義檔案上傳
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.3),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_search_rounded, size: 44, color: cs.primary),
                    const SizedBox(height: 10),
                    const Text('上傳考卷或講義相片', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('支援 PNG, JPG, WebP 格式相片', style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _pickPdf,
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.2), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, size: 34, color: Colors.redAccent.shade200),
                    const SizedBox(width: 14),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('上傳 PDF 考卷檔案', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                        const SizedBox(height: 2),
                        Text('適合掃描版或電子試卷文件', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      ],
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.primary.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: cs.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '小叮嚀：相片請保持光線充足且文字清晰，AI 將自動辨識題目並生成詳解！',
                      style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Tab 1: 智慧主題命題出題
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. 選擇考試學科', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: widget.allSubjects.contains(_selectedTopicSubject)
                            ? _selectedTopicSubject
                            : (widget.allSubjects.isNotEmpty ? widget.allSubjects.first : '數學'),
                        items: (widget.allSubjects.isNotEmpty
                                ? widget.allSubjects
                                : ['數學', '英文', '國文', '理化', '歷史', '地理', '資訊管理'])
                            .map((sub) => DropdownMenuItem(
                                  value: sub,
                                  child: Text(sub, style: const TextStyle(fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedTopicSubject = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text('2. 單元或考科主題', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _topicChapterCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '例如：空間幾何、牛頓運動定律、一元二次方程式…',
                      hintStyle: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('3. 命題數量', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurface)),
                            const SizedBox(height: 8),
                            Row(
                              children: [3, 5, 10].map((c) {
                                final isSel = _topicQuestionCount == c;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Center(child: Text('$c 題', style: const TextStyle(fontSize: 12))),
                                      selected: isSel,
                                      selectedColor: cs.primary,
                                      labelStyle: TextStyle(
                                        color: isSel ? cs.onPrimary : cs.onSurface,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      onSelected: (_) => setState(() => _topicQuestionCount = c),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('4. 難易度', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurface)),
                            const SizedBox(height: 8),
                            Row(
                              children: ['基礎', '中等', '進階'].map((d) {
                                final isSel = _topicDifficulty == d;
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: ChoiceChip(
                                      label: Center(child: Text(d, style: const TextStyle(fontSize: 11.5))),
                                      selected: isSel,
                                      selectedColor: cs.primary,
                                      labelStyle: TextStyle(
                                        color: isSel ? cs.onPrimary : cs.onSurface,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      onSelected: (_) => setState(() => _topicDifficulty = d),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.bolt_rounded, size: 20),
                      label: const Text('開始 AI 智慧命題生成題本', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                      ),
                      onPressed: _startAiTopicGeneration,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- 2. Loading / Analyzing State ---
  Widget _buildAnalyzingState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // AI Ripple effect
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(strokeWidth: 4),
                ),
                Icon(Icons.auto_awesome_rounded, size: 32, color: cs.primary),
              ],
            ),
            const SizedBox(height: 40),
            Text(
              'AI 正在辨識您的檔案',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              '這通常需要 5-15 秒，請勿關閉此畫面',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),

            // Steps Progress
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: cs.surfaceContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: List.generate(_loadingSteps.length, (index) {
                  final isActive = index == _currentStep;
                  final isDone = index < _currentStep;

                  Color itemColor = cs.onSurfaceVariant;
                  Widget icon = Icon(Icons.circle_outlined, size: 16, color: cs.outline.withValues(alpha: 0.5));

                  if (isActive) {
                    itemColor = cs.primary;
                    icon = SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                    );
                  } else if (isDone) {
                    itemColor = Colors.green;
                    icon = const Icon(Icons.check_circle, size: 16, color: Colors.green);
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        icon,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _loadingSteps[index],
                            style: TextStyle(
                              fontSize: 13.5,
                              color: itemColor,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. Preview & Edit Form State ---
  Widget _buildPreviewState(ColorScheme cs) {
    return Column(
      children: [
        // 頂部靜態檔案資訊列
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
          child: Row(
            children: [
              Icon(
                _isImage ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
                color: _isPdf ? Colors.redAccent : cs.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedFileName ?? '已載入檔案',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _state = UploadState.initial;
                    _questions.clear();
                    _selectedFilePath = null;
                    _selectedFileName = null;
                    _fileBytes = null;
                    _mimeType = null;
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('重新上傳', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),

        // 主要編輯與題目預覽區域
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Metadata Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: cs.outline.withValues(alpha: 0.15)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.assignment_ind_rounded, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text('題本與科目設定', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _paperNameCtrl,
                        decoration: InputDecoration(
                          labelText: '題本名稱',
                          prefixIcon: const Icon(Icons.assignment_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _subjectCtrl,
                              decoration: InputDecoration(
                                labelText: '學科分類',
                                prefixIcon: const Icon(Icons.school_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _chapterCtrl,
                              decoration: InputDecoration(
                                labelText: '單元名稱',
                                prefixIcon: const Icon(Icons.tag_rounded),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title containing count of questions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AI 提取題目預覽 (${_questions.length} 題)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _questions.add({
                          'text': '請輸入題目描述',
                          'options': ['選項 A', '選項 B', '選項 C', '選項 D'],
                          'answerIndex': 0,
                          'explanation': '請輸入解析',
                          'difficulty': 'medium',
                        });
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('新增一題', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Questions List
              ...List.generate(_questions.length, (index) {
                final q = _questions[index];
                return _buildQuestionEditorCard(index, q, cs);
              }),

              const SizedBox(height: 100), // padding for floating action button
            ],
          ),
        ),

        // Bottom floating save bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              )
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // Cancel dialog
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('放棄辨識'),
                        content: const Text('確定要放棄目前辨識出來的題目並返回上傳畫面嗎？'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _state = UploadState.initial;
                                _questions.clear();
                              });
                            },
                            child: const Text('確認放棄', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('放棄'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _savePaper,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('確認建立題本', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Question Card Editor
  Widget _buildQuestionEditorCard(int qIndex, Map<String, dynamic> q, ColorScheme cs) {
    final List<String> options = List<String>.from(q['options']);
    final int ansIndex = q['answerIndex'] as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with number and delete button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '第 ${qIndex + 1} 題',
                    style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 13),
                  ),
                ),
                Row(
                  children: [
                    // Difficulty Selector
                    DropdownButton<String>(
                      value: q['difficulty'],
                      items: const [
                        DropdownMenuItem(value: 'easy', child: Text('簡單', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'medium', child: Text('中等', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'hard', child: Text('困難', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            q['difficulty'] = val;
                          });
                        }
                      },
                      underline: const SizedBox(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () {
                        setState(() {
                          _questions.removeAt(qIndex);
                        });
                      },
                      tooltip: '刪除此題',
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 12),

            // Question Text Input
            const Text('題目描述', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 4),
            TextFormField(
              initialValue: q['text'],
              maxLines: null,
              decoration: InputDecoration(
                hintText: '請輸入題目敘述',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (val) {
                q['text'] = val;
              },
            ),
            const SizedBox(height: 16),

            // Options list
            const Text('選項與正解 (點擊選取正確答案)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            ...List.generate(options.length, (oIdx) {
              final isCorrect = oIdx == ansIndex;
              final char = String.fromCharCode(65 + oIdx);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    // Correct indicator clickable
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          q['answerIndex'] = oIdx;
                        });
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isCorrect ? Colors.green : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: isCorrect ? Colors.green : cs.outline),
                        ),
                        child: Center(
                          child: Text(
                            char,
                            style: TextStyle(
                              color: isCorrect ? Colors.white : cs.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Option Text Field
                    Expanded(
                      child: TextFormField(
                        initialValue: options[oIdx],
                        decoration: InputDecoration(
                          hintText: '選項 $char',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          focusedBorder: isCorrect
                              ? const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.green, width: 1.5),
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          options[oIdx] = val;
                          q['options'] = options;
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),

            // Explanation Input
            const Text('題目解析', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 4),
            TextFormField(
              initialValue: q['explanation'],
              maxLines: null,
              decoration: InputDecoration(
                hintText: '請輸入題目詳細解析（選填）',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (val) {
                q['explanation'] = val;
              },
            ),
          ],
        ),
      ),
    );
  }
}
