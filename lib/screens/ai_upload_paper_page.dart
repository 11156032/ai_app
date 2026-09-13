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

  // 內建系統 Gemini API Key (支援多模態視覺直連)
  static String get _kDefaultGeminiApiKey {
    try {
      final key = dotenv.env['GEMINI_API_KEY'];
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    return '';
  }

  // Loading Steps Simulation
  int _currentStep = 0;
  final List<String> _loadingSteps = [
    '正在連接高精準 AI 視覺辨識模型...',
    '正在深度解析試卷題目、題幹與圖文條件...',
    'AI 正在提取與結構化選項、標準答案與解題步驟...',
    '正在整理試卷預覽與題目驗證，請稍候...'
  ];

  @override
  void initState() {
    super.initState();
    _selectedTopicSubject =
        widget.allSubjects.isNotEmpty ? widget.allSubjects.first : '數學';
  }

  // For displaying file preview
  bool get _isImage => _mimeType?.startsWith('image/') ?? false;
  bool get _isPdf => _mimeType == 'application/pdf';

  Future<String> _getApiKey() async {
    // 1. Check user custom api key in db
    try {
      final uid =
          (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1')
              .toString();
      final db = await DatabaseHelper.instance.database;
      final userRows =
          await db.query('users', where: 'id = ?', whereArgs: [uid]);
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

    // 4. 內建系統 Gemini API Key
    return _kDefaultGeminiApiKey;
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

  // Pick Image (支援相簿與拍照，並進行尺寸最佳化確保辨識穩定)
  Future<void> _pickImage([ImageSource source = ImageSource.gallery]) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final ext = image.name.split('.').last.toLowerCase();
        String mimeType = 'image/jpeg';
        if (ext == 'png') mimeType = 'image/png';
        if (ext == 'webp') mimeType = 'image/webp';
        if (ext == 'heic' || ext == 'heif') mimeType = 'image/jpeg';

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

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  '選擇考卷相片來源',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.camera_alt_rounded, color: cs.primary),
                  ),
                  title: const Text('拍照辨識',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('即時拍攝實體考卷或試題講義',
                      style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.photo_library_rounded, color: cs.primary),
                  ),
                  title: const Text('相簿選取',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('從手機相簿選取已保存的考卷照片',
                      style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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

    final stepTimer = Stream.periodic(const Duration(seconds: 2), (i) => i + 1)
        .listen((step) {
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
      "options": ["選項一", "選項二", "選項三", "選項四"],
      "answer": "0",
      "explanation": "完整詳細的計算流程、觀念詳解與陷阱提示",
      "difficulty": "${diff == '基礎' ? 'easy' : (diff == '進階' ? 'hard' : 'medium')}"
    }
  ]
}

【重要品質與標點規範】
1. 繁體中文：全部內容（題目、選項、單元、詳解）必須為臺灣正體繁體中文。
2. 選項乾淨純文字：選項陣列中的文字請去除 A. B. C. D.、(A) (B) 或 ① ② 等前綴標籤，保持純文字。
3. 嚴禁奇怪符號與 LaTeX 原始指令：嚴禁出現 \\frac, \\times, \\pm, \\text 等 LaTeX 反斜線代碼。數學算式請用常規標準符號（例如寫 (a/b) 而非 \\frac{a}{b}；寫 × 而非 \\times；寫 ± 而非 \\pm；寫 √(x) 而非 \\sqrt{x}；寫 x^2、+、-、*、/、= 等）。
4. 嚴禁出現 <think> 思考標籤或對話開場白。
5. 答案索引精確：answer 必須是 0-based 索引字串（"0", "1", "2", "3"）。
6. 專業詳解：每題務必提供富有教育價值的深度詳解與步驟。
''';

    try {
      String? responseText;

      // 順位 1：Cloudflare Gemini 旗艦中繼站
      debugPrint('AiUploadPaper: 優先調用 Cloudflare 雲端中繼站 (Gemini 旗艦引擎)...');
      responseText = await _tryCloudflareProxy(
        provider: 'gemini',
        prompt: prompt,
        timeoutSeconds: 25,
      );

      // 順位 2：Cloudflare Groq 旗艦中繼引擎 (groq/compound)
      if (responseText == null || responseText.trim().isEmpty) {
        debugPrint('AiUploadPaper: 切換 Cloudflare Groq 旗艦引擎 (groq/compound)...');
        responseText = await _tryCloudflareProxy(
          provider: 'groq',
          model: 'groq/compound',
          prompt: prompt,
          timeoutSeconds: 20,
        );
      }

      // 順位 3：Cloudflare Groq 深度引擎 (openai/gpt-oss-120b)
      if (responseText == null || responseText.trim().isEmpty) {
        debugPrint(
            'AiUploadPaper: 切換 Cloudflare Groq 深度引擎 (openai/gpt-oss-120b)...');
        responseText = await _tryCloudflareProxy(
          provider: 'groq',
          model: 'openai/gpt-oss-120b',
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
  // 核心功能 2：上傳考卷文件/圖片辨識（高精準多模態視覺模型串接）
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

    final stepTimer = Stream.periodic(const Duration(seconds: 2), (i) => i + 1)
        .listen((step) {
      if (step < _loadingSteps.length && mounted) {
        setState(() {
          _currentStep = step;
        });
      }
    });

    final systemPrompt = '''
你是一個精通臺灣各級升學考試與學校測驗的「專業試卷 OCR 與解析大師」。
請仔細辨識檢視使用者上傳的試卷文件（圖片或 PDF），提取並解析出所有的選擇題（單選題）。

【重要辨識與品質準則】
1. 忠實辨識原題：請精確辨識圖片中的真實題目文字、題幹條件、選項與數值，絕不可憑空捏造或杜撰與圖片無關的題目！
2. 題型支援：優先提取試卷上的單選題。若試卷上有其他題型（如是非題、填空題、簡答題、計算題），請依據該題目的原始題幹與內容，合理轉化為具備 4 個選項、正確答案與步驟詳解的單選題。
3. 繁體中文：所有題目內容、選項、單元名稱與詳解必須全部使用臺灣正體繁體中文。
4. 選項純淨化：選項陣列中的文字請移除 A. B. C. D. 或 ① ② ③ ④ 等前綴標籤，保持乾淨純文字。
5. 答案索引：answer 欄位必須為 options 陣列的 0-based 索引字串（"0", "1", "2" 或 "3"）。
6. 深度詳解：請為每一題提供清晰步驟、觀念推理與計算詳解。
7. 【防偽與無關圖片守則】：若圖片完全模糊不清、過度反光導致無法閱讀，或該圖片根本不是任何考卷、試題、筆記或作業（例如純風景照、生活照、雜物或黑畫面），請在 paper_name 填入 "無法辨識題目"，並將 questions 設為空陣列 []，絕對切勿憑空捏造毫不相干的題目！

【嚴格輸出格式契約】
請絕對只回傳符合以下 JSON 格式的字串，嚴禁包裹 markdown 或其他多餘說明：
{
  "paper_name": "（依據考卷內容辨識出或生成的題本名稱，若無法辨識請填 "無法辨識題目"）",
  "subject": "（學科名稱，例如：數學、英文、國文、物理、化學、生物、歷史、地理、公民 等）",
  "chapter": "（單元或章節名稱）",
  "questions": [
    {
      "text": "完整題目敘述（包含題目情境與所有條件）",
      "options": ["選項一", "選項二", "選項三", "選項四"],
      "answer": "0",
      "explanation": "深度解題步驟與觀念詳解",
      "difficulty": "medium"
    }
  ]
}
''';

    try {
      String? responseText;
      final apiKey = await _getApiKey();
      final modelsToTry = [
        'gemini-2.5-flash',
        'gemini-2.0-flash',
        'gemini-1.5-flash'
      ];

      // 順位 1：透過 Gemini SDK 多模型依序嘗試多模態視覺辨識
      if (apiKey.isNotEmpty) {
        for (final modelName in modelsToTry) {
          try {
            debugPrint('AiUploadPaper: 啟動 Gemini SDK 多模態視覺辨識 ($modelName)...');
            final model = GenerativeModel(
              model: modelName,
              apiKey: apiKey,
              safetySettings: [
                SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
                SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
                SafetySetting(
                    HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
                SafetySetting(
                    HarmCategory.dangerousContent, HarmBlockThreshold.none),
              ],
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
            if (response.text != null && response.text!.trim().isNotEmpty) {
              responseText = response.text;
              debugPrint('AiUploadPaper: Gemini SDK ($modelName) 多模態辨識成功！');
              break;
            }
          } catch (sdkErr) {
            debugPrint('Gemini SDK ($modelName) 多模態解析例外: $sdkErr');
          }
        }
      }

      // 順位 2：若 SDK 因網路代理或平台問題失敗，使用直接 Google REST API 直連多模態
      if ((responseText == null || responseText.trim().isEmpty) &&
          apiKey.isNotEmpty) {
        final base64Data = base64Encode(_fileBytes!);
        for (final modelName in modelsToTry) {
          try {
            debugPrint(
                'AiUploadPaper: 嘗試 Gemini 原生 REST API 多模態直連 ($modelName)...');
            final url = Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
            );
            final res = await http
                .post(
                  url,
                  headers: {'Content-Type': 'application/json; charset=utf-8'},
                  body: jsonEncode({
                    'contents': [
                      {
                        'parts': [
                          {'text': systemPrompt},
                          {
                            'inline_data': {
                              'mime_type': _mimeType!,
                              'data': base64Data,
                            }
                          }
                        ]
                      }
                    ],
                    'safetySettings': [
                      {
                        'category': 'HARM_CATEGORY_HARASSMENT',
                        'threshold': 'BLOCK_NONE'
                      },
                      {
                        'category': 'HARM_CATEGORY_HATE_SPEECH',
                        'threshold': 'BLOCK_NONE'
                      },
                      {
                        'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
                        'threshold': 'BLOCK_NONE'
                      },
                      {
                        'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                        'threshold': 'BLOCK_NONE'
                      },
                    ],
                    'generationConfig': {
                      'responseMimeType': 'application/json',
                    },
                  }),
                )
                .timeout(const Duration(seconds: 35));

            if (res.statusCode == 200) {
              final data = jsonDecode(utf8.decode(res.bodyBytes));
              final text = data['candidates']?[0]?['content']?['parts']?[0]
                  ?['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                responseText = text;
                debugPrint('AiUploadPaper: Gemini REST API ($modelName) 辨識成功！');
                break;
              }
            } else {
              debugPrint(
                  'AiUploadPaper: Gemini REST API ($modelName) 回應失敗 [${res.statusCode}]: ${res.body}');
            }
          } catch (restErr) {
            debugPrint(
                'AiUploadPaper: Gemini REST API ($modelName) 例外: $restErr');
          }
        }
      }

      if (responseText == null || responseText.trim().isEmpty) {
        throw Exception('無法完成考卷圖片辨識，請確保圖片文字清晰、光線充足，並檢查網路連線後重試。');
      }

      stepTimer.cancel();
      _parseAndApplyQuestions(responseText);
    } catch (e) {
      stepTimer.cancel();
      setState(() {
        _state = UploadState.initial;
      });
      _showErrorDialog('辨識失敗', e.toString().replaceAll('Exception: ', ''));
    }
  }

  // --------------------------------------------------------------------------
  // AI 符號與特殊標籤純淨化（過濾 <think>、LaTeX 反斜線、奇怪符號與重複選項標號）
  // --------------------------------------------------------------------------
  static String _cleanAiSymbols(String raw) {
    if (raw.isEmpty) return raw;
    String text = raw;

    // 1. 移除模型思考鏈標籤 (如 <think>...</think> 或單獨標籤)
    text = text.replaceAll(
        RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'</?think>', caseSensitive: false), '');

    // 2. 移除 LaTeX 數學定界符 ($$...$$, $...$, \(...\), \[...\])
    text = text.replaceAllMapped(
        RegExp(r'\$\$(.*?)\$\$', dotAll: true), (m) => m.group(1) ?? '');
    text = text.replaceAllMapped(RegExp(r'\$(.*?)\$'), (m) => m.group(1) ?? '');
    text = text.replaceAll(r'\(', '').replaceAll(r'\)', '');
    text = text.replaceAll(r'\[', '').replaceAll(r'\]', '');

    // 3. 轉換常見 LaTeX 分數、根號等語法為標準易讀符號
    text = text.replaceAllMapped(RegExp(r'\\frac\{([^}]+)\}\{([^}]+)\}'), (m) {
      return '(${m.group(1)}/${m.group(2)})';
    });
    text = text.replaceAllMapped(RegExp(r'\\sqrt\{([^}]+)\}'), (m) {
      return '√(${m.group(1)})';
    });
    text = text.replaceAllMapped(RegExp(r'\\sqrt\[([^\]]+)\]\{([^}]+)\}'), (m) {
      return '${m.group(1)}√(${m.group(2)})';
    });

    const mathReplacements = {
      r'\times': '×',
      r'\div': '÷',
      r'\pm': '±',
      r'\mp': '∓',
      r'\approx': '≈',
      r'\neq': '≠',
      r'\leq': '≤',
      r'\geq': '≥',
      r'\le': '≤',
      r'\ge': '≥',
      r'\cdot': '·',
      r'\circ': '°',
      r'\degree': '°',
      r'\pi': 'π',
      r'\theta': 'θ',
      r'\alpha': 'α',
      r'\beta': 'β',
      r'\gamma': 'γ',
      r'\delta': 'δ',
      r'\Delta': 'Δ',
      r'\in': '∈',
      r'\notin': '∉',
      r'\subset': '⊂',
      r'\supset': '⊃',
      r'\cap': '∩',
      r'\cup': '∪',
      r'\infty': '∞',
      r'\angle': '∠',
      r'\triangle': '△',
      r'\perp': '⊥',
      r'\parallel': '∥',
      r'\to': '→',
      r'\rightarrow': '→',
      r'\Rightarrow': '⇒',
      r'\iff': '⇔',
      r'\therefore': '∴',
      r'\because': '∵',
    };

    mathReplacements.forEach((k, v) {
      text = text.replaceAll(k, v);
    });

    // 移除 \text{...}, \mathbf{...}, \mathit{...} 等指令包裹
    text = text.replaceAllMapped(
        RegExp(r'\\(?:text|mathbf|mathit|mathrm|mathbb)\{([^}]+)\}'), (m) {
      return m.group(1) ?? '';
    });

    // 4. 清理 Markdown 粗體、斜體殘留星號
    text = text.replaceAllMapped(
        RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1) ?? '');
    text =
        text.replaceAllMapped(RegExp(r'__([^_]+)__'), (m) => m.group(1) ?? '');

    // 5. 移除不可見特殊字元、零寬字符與控制符
    text = text.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF\u00A0]'), ' ');

    // 6. 整理多餘空白與連續反斜線
    text = text.replaceAll(r'\\', r'\');
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');

    return text.trim();
  }

  static String _cleanOptionText(String raw) {
    String opt = _cleanAiSymbols(raw);
    // 移除選項開頭重複的 A. B. C. D.、(A) (B)、[A] [B]、① ② 或 1. 2. 標號
    opt = opt.replaceAll(
      RegExp(
          r'^(?:[A-Da-d][\.\、\:\)\s\-]+|\([A-Da-d]\)\s*|\[[A-Da-d]\]\s*|[①②③④⑤]\s*|\d+[\.\、\:\)\s\-]+)'),
      '',
    );
    return opt.trim();
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
        cleanText = match.group(1)?.trim() ?? cleanText;
      }
    }

    final firstBrace = cleanText.indexOf('{');
    final lastBrace = cleanText.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      cleanText = cleanText.substring(firstBrace, lastBrace + 1);
    }

    final Map<String, dynamic> parsedData = jsonDecode(cleanText.trim());
    final String rawPaperName =
        (parsedData['paper_name'] ?? 'AI 智慧生成題本').toString();
    final String paperName = _cleanAiSymbols(rawPaperName);
    final String subject = _cleanAiSymbols(
        (parsedData['subject'] ?? _selectedTopicSubject).toString());
    final String chapter =
        _cleanAiSymbols((parsedData['chapter'] ?? 'AI 核心單元').toString());
    final List<dynamic> qList = parsedData['questions'] ?? [];

    if (paperName.contains('無法辨識') || qList.isEmpty) {
      throw Exception(
          '未能從上傳的文件/相片中辨識出有效的考卷題目。請確保上傳的試卷清晰無反光、文字清楚端正，且確實包含考卷題目內容。');
    }

    List<Map<String, dynamic>> questions = [];
    for (final q in qList) {
      final rawOptions = q['options'] as List<dynamic>? ?? [];
      final options = rawOptions
          .map((e) => _cleanOptionText(e.toString()))
          .where((opt) => opt.isNotEmpty)
          .toList();
      final rawAns = q['answer'] ?? '0';
      int ansIndex = int.tryParse(rawAns.toString()) ?? 0;
      if (ansIndex < 0 || ansIndex >= options.length) ansIndex = 0;

      final text = _cleanAiSymbols((q['text'] ?? '').toString());
      if (text.isEmpty) continue;

      // 若選項不足 4 個，適當補齊以符合單選題架構
      while (options.length < 4) {
        options.add('以上皆非');
      }

      questions.add({
        'text': text,
        'options': options,
        'answerIndex': ansIndex,
        'explanation': _cleanAiSymbols((q['explanation'] ?? '').toString()),
        'difficulty': (q['difficulty'] ?? 'medium').toString(),
      });
    }

    if (questions.isEmpty) {
      throw Exception('未能從上傳的文件/相片中提取出完整的題目結構，請重新拍攝或選取清晰的試卷。');
    }

    setState(() {
      _paperNameCtrl.text = paperName;
      _subjectCtrl.text = subject.isNotEmpty ? subject : _selectedTopicSubject;
      _chapterCtrl.text = chapter.isNotEmpty ? chapter : '考卷解析單元';
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
      final String userId =
          (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1')
              .toString();

      // 1. Insert Chapter/Tag if not exists
      int tagId;
      final tagRows =
          await db.query('tags', where: 'name = ?', whereArgs: [chapter]);
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
      final paperId = await DatabaseHelper.instance
          .createPaper(userId, paperName, questionIds);

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
            const Icon(Icons.error_outline_rounded,
                color: Colors.red, size: 28),
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
        title: const Text('AI 智慧匯入題本',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                        color:
                            _activeTab == 0 ? cs.primary : Colors.transparent,
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
                            color: _activeTab == 0
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '考卷文件辨識',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: _activeTab == 0
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _activeTab == 0
                                  ? cs.onPrimary
                                  : cs.onSurfaceVariant,
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
                        color:
                            _activeTab == 1 ? cs.primary : Colors.transparent,
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
                            color: _activeTab == 1
                                ? cs.onPrimary
                                : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '智慧主題命題',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: _activeTab == 1
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: _activeTab == 1
                                  ? cs.onPrimary
                                  : cs.onSurfaceVariant,
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
          const SizedBox(height: 16),

          if (_activeTab == 0) ...[
            // Tab 0: 考卷/講義檔案上傳
            GestureDetector(
              onTap: _showImageSourcePicker,
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
                    Icon(Icons.image_search_rounded,
                        size: 44, color: cs.primary),
                    const SizedBox(height: 10),
                    const Text('拍照或上傳考卷相片',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('支援相機即時拍照、相簿選取（PNG, JPG, WebP）',
                        style: TextStyle(
                            fontSize: 11.5, color: cs.onSurfaceVariant)),
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
                  border: Border.all(
                      color: cs.outline.withValues(alpha: 0.2), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.picture_as_pdf_rounded,
                        size: 34, color: Colors.redAccent.shade200),
                    const SizedBox(width: 14),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('上傳 PDF 考卷檔案',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14.5)),
                        const SizedBox(height: 2),
                        Text('適合掃描版或電子試卷文件',
                            style: TextStyle(
                                fontSize: 11, color: cs.onSurfaceVariant)),
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
                      style: TextStyle(
                          fontSize: 11.5,
                          color: cs.onSurfaceVariant,
                          height: 1.4),
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
                  Text('1. 選擇考試學科',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: cs.outline.withValues(alpha: 0.2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value:
                            widget.allSubjects.contains(_selectedTopicSubject)
                                ? _selectedTopicSubject
                                : (widget.allSubjects.isNotEmpty
                                    ? widget.allSubjects.first
                                    : '數學'),
                        items: (widget.allSubjects.isNotEmpty
                                ? widget.allSubjects
                                : ['數學', '英文', '國文', '理化', '歷史', '地理', '資訊管理'])
                            .map((sub) => DropdownMenuItem(
                                  value: sub,
                                  child: Text(sub,
                                      style: const TextStyle(fontSize: 14)),
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

                  Text('2. 單元或考科主題',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _topicChapterCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '例如：空間幾何、牛頓運動定律、一元二次方程式…',
                      hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: cs.outline.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: cs.outline.withValues(alpha: 0.2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. 命題數量
                  Text(
                    '3. 命題數量',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildCountOption(cs, 3, '3 題'),
                      const SizedBox(width: 8),
                      _buildCountOption(cs, 5, '5 題'),
                      const SizedBox(width: 8),
                      _buildCountOption(cs, 10, '10 題'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. 難易度
                  Text(
                    '4. 難易度設定',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDifficultyOption(cs, '基礎', '🌱 基礎'),
                      const SizedBox(width: 8),
                      _buildDifficultyOption(cs, '中等', '⚡ 中等'),
                      const SizedBox(width: 8),
                      _buildDifficultyOption(cs, '進階', '🔥 進階'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.bolt_rounded, size: 20),
                      label: const Text('開始 AI 智慧命題生成題本',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
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

  Widget _buildCountOption(ColorScheme cs, int count, String title) {
    final isSel = _topicQuestionCount == count;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _topicQuestionCount = count),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          decoration: BoxDecoration(
            color: isSel
                ? cs.primary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSel ? cs.primary : cs.outline.withValues(alpha: 0.18),
              width: isSel ? 1.8 : 1.0,
            ),
            boxShadow: isSel
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                color: isSel ? cs.onPrimary : cs.onSurface,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyOption(ColorScheme cs, String value, String label) {
    final isSel = _topicDifficulty == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _topicDifficulty = value),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          decoration: BoxDecoration(
            color: isSel
                ? cs.primary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSel ? cs.primary : cs.outline.withValues(alpha: 0.18),
              width: isSel ? 1.8 : 1.0,
            ),
            boxShadow: isSel
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                color: isSel ? cs.onPrimary : cs.onSurface,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
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
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface),
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
                  Widget icon = Icon(Icons.circle_outlined,
                      size: 16, color: cs.outline.withValues(alpha: 0.5));

                  if (isActive) {
                    itemColor = cs.primary;
                    icon = SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.primary),
                    );
                  } else if (isDone) {
                    itemColor = Colors.green;
                    icon = const Icon(Icons.check_circle,
                        size: 16, color: Colors.green);
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
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.bold),
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
                          Icon(Icons.assignment_ind_rounded,
                              color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text('題本與科目設定',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _paperNameCtrl,
                        decoration: InputDecoration(
                          labelText: '題本名稱',
                          prefixIcon: const Icon(Icons.assignment_rounded),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
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
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
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
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
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
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface),
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
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('取消')),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _state = UploadState.initial;
                                _questions.clear();
                              });
                            },
                            child: const Text('確認放棄',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('確認建立題本',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Question Card Editor
  Widget _buildQuestionEditorCard(
      int qIndex, Map<String, dynamic> q, ColorScheme cs) {
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '第 ${qIndex + 1} 題',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                        fontSize: 13),
                  ),
                ),
                Row(
                  children: [
                    // Difficulty Selector
                    DropdownButton<String>(
                      value: q['difficulty'],
                      items: const [
                        DropdownMenuItem(
                            value: 'easy',
                            child: Text('簡單', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(
                            value: 'medium',
                            child: Text('中等', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(
                            value: 'hard',
                            child: Text('困難', style: TextStyle(fontSize: 12))),
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
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 20),
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
            const Text('題目描述',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 4),
            TextFormField(
              initialValue: q['text'],
              maxLines: null,
              decoration: InputDecoration(
                hintText: '請輸入題目敘述',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (val) {
                q['text'] = val;
              },
            ),
            const SizedBox(height: 16),

            // Options list
            const Text('選項與正解 (點擊選取正確答案)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
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
                          border: Border.all(
                              color: isCorrect ? Colors.green : cs.outline),
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
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          focusedBorder: isCorrect
                              ? const OutlineInputBorder(
                                  borderSide: BorderSide(
                                      color: Colors.green, width: 1.5),
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
            const Text('題目解析',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 4),
            TextFormField(
              initialValue: q['explanation'],
              maxLines: null,
              decoration: InputDecoration(
                hintText: '請輸入題目詳細解析（選填）',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
