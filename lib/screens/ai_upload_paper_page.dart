import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';
import '../utils/question_utils.dart';
import 'question_set_detail_page.dart';
import '../services/app_locale_service.dart';

enum UploadState { initial, analyzing, preview }

class AiUploadPaperPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final List<String> allSubjects;
  final Map<String, List<String>> subjectChapters;
  final int initialTab;

  const AiUploadPaperPage({
    super.key,
    required this.currentUser,
    required this.allSubjects,
    required this.subjectChapters,
    this.initialTab = 0,
  });

  @override
  State<AiUploadPaperPage> createState() => _AiUploadPaperPageState();
}

class _AiUploadPaperPageState extends State<AiUploadPaperPage> {
  UploadState _state = UploadState.initial;
  late int _activeTab; // 0: 上傳考卷解析, 1: 智慧主題命題出卷

  // File Upload State
  String? _selectedFilePath;
  String? _selectedFileName;
  Uint8List? _fileBytes;
  String? _mimeType;

  // Topic Generation State
  final TextEditingController _topicSubjectCtrl = TextEditingController();
  final TextEditingController _topicChapterCtrl = TextEditingController();
  final TextEditingController _topicCountCtrl = TextEditingController(text: '5');
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
    // 安全性：中繼站通行證不再寫死於程式碼
    return '';
  }

  // 內建系統 Gemini API Key (支援多模態視覺直連)
  static String get _kDefaultGeminiApiKey {
    try {
      final key = dotenv.env['GEMINI_API_KEY'];
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    // 安全性：不再內建任何真實金鑰
    return '';
  }

  // Loading Steps Simulation
  int _currentStep = 0;
  final List<String> _loadingSteps = [
    tr('up_step1'),
    tr('up_step2'),
    tr('up_step3'),
    tr('up_step4')
  ];

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _topicSubjectCtrl.text =
        widget.allSubjects.isNotEmpty ? widget.allSubjects.first : '數學';
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recoverLostCameraImage();
      });
    }
  }

  /// Android 系統相機開啟時若背景 Activity 被系統回收，透過 retrieveLostData 找回剛拍的照片
  Future<void> _recoverLostCameraImage() async {
    try {
      final picker = ImagePicker();
      final response = await picker.retrieveLostData();
      if (response.isEmpty) return;
      if (response.file != null) {
        await _processPickedXFile(response.file!);
      } else if (response.exception != null && mounted) {
        _handleImagePickException(response.exception!);
      }
    } catch (e) {
      debugPrint('AiUploadPaper: retrieveLostData 失敗: $e');
    }
  }

  @override
  void dispose() {
    _topicSubjectCtrl.dispose();
    _topicChapterCtrl.dispose();
    _topicCountCtrl.dispose();
    _paperNameCtrl.dispose();
    _subjectCtrl.dispose();
    _chapterCtrl.dispose();
    super.dispose();
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

  // 考卷辨識候選 Gemini API Keys（依序嘗試：使用者自訂 -> 考卷專用 -> 全域預設，自動去重）
  Future<List<String>> _getCandidatePaperApiKeys() async {
    final keys = <String>[];
    void addKey(String? k) {
      final trimmed = k?.trim() ?? '';
      if (trimmed.isNotEmpty && !keys.contains(trimmed)) {
        keys.add(trimmed);
      }
    }

    // 1. User custom api key in db
    try {
      final uid =
          (widget.currentUser['id'] ?? widget.currentUser['user_id'] ?? 'u1')
              .toString();
      final db = await DatabaseHelper.instance.database;
      final userRows =
          await db.query('users', where: 'id = ?', whereArgs: [uid]);
      if (userRows.isNotEmpty) {
        addKey(userRows.first['gemini_api_key'] as String?);
      }
    } catch (e) {
      debugPrint('Error getting user custom api key: $e');
    }

    // 2. Paper-specific key from dotenv / dart-define
    try {
      addKey(dotenv.env['GEMINI_PAPER_API_KEY']);
    } catch (_) {}
    const envPaperKey = String.fromEnvironment('GEMINI_PAPER_API_KEY');
    addKey(envPaperKey);

    // 3. General key fallback from dotenv / dart-define
    try {
      addKey(dotenv.env['GEMINI_API_KEY']);
    } catch (_) {}
    const envGeneralKey = String.fromEnvironment('GEMINI_API_KEY');
    addKey(envGeneralKey);

    return keys;
  }

  static const List<String> _kGeminiPaperModels = [
    'gemini-3-flash-preview',
    'gemini-3.1-flash-lite',
    'gemini-2.5-flash-lite',
    'gemini-flash-lite-latest',
    'gemini-3.5-flash',
    'gemini-2.5-flash',
    'gemini-3.5-flash-lite',
    'gemma-4-26b-a4b-it',
    'gemma-4-31b-it',
  ];

  /// 透過多組候選金鑰與多組可用 Gemini / Gemma 視覺模型進行直連解析（支援純文字與圖片/PDF 多模態）
  Future<({String? text, bool hitRateLimit})> _tryDirectGeminiWithKeys({
    required List<String> apiKeys,
    required String prompt,
    String? base64Data,
    String? mimeType,
    double? temperature,
    int timeoutSeconds = 40,
  }) async {
    bool hitRateLimit = false;
    for (final apiKey in apiKeys) {
      for (final modelName in _kGeminiPaperModels) {
        try {
          debugPrint('AiUploadPaper: 嘗試 Gemini REST API ($modelName)...');
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
          );
          final parts = <Map<String, dynamic>>[
            {'text': prompt},
            if (base64Data != null && mimeType != null)
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Data,
                }
              },
          ];
          final isGemma = modelName.startsWith('gemma-');
          final genConfig = <String, dynamic>{
            if (!isGemma) 'responseMimeType': 'application/json',
            if (temperature != null) 'temperature': temperature,
          };
          final res = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json; charset=utf-8'},
                body: jsonEncode({
                  'contents': [
                    {'parts': parts}
                  ],
                  'generationConfig': genConfig,
                }),
              )
              .timeout(Duration(seconds: timeoutSeconds));

          if (res.statusCode == 200) {
            final data = jsonDecode(utf8.decode(res.bodyBytes));
            final text = data['candidates']?[0]?['content']?['parts']?[0]
                ?['text'] as String?;
            if (text != null && text.trim().isNotEmpty) {
              debugPrint('AiUploadPaper: Gemini ($modelName) 辨識成功！');
              return (text: text, hitRateLimit: hitRateLimit);
            }
          } else {
            debugPrint(
                'AiUploadPaper: Gemini ($modelName) 錯誤 [${res.statusCode}]: ${res.body}');
            if (res.statusCode == 429) {
              hitRateLimit = true;
            } else if (res.statusCode == 401 || res.statusCode == 403) {
              // 金鑰無效或停用，直接跳換下一組金鑰
              break;
            }
          }
        } catch (e) {
          debugPrint('AiUploadPaper: Gemini ($modelName) 例外: $e');
        }
      }
    }
    return (text: null, hitRateLimit: hitRateLimit);
  }

  /// 從 PDF 檔案二進位中提取文字內容（原生支援數位考卷直接解析）
  static String _extractTextFromPdfBytes(Uint8List bytes) {
    final buffer = StringBuffer();
    try {
      final content = latin1.decode(bytes);
      final streamRegex =
          RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream', multiLine: true);
      final matches = streamRegex.allMatches(content);

      for (final m in matches) {
        final streamRaw = m.group(1);
        if (streamRaw == null || streamRaw.isEmpty) continue;

        Uint8List? decompressedBytes;
        try {
          final streamBytes = latin1.encode(streamRaw);
          decompressedBytes = Uint8List.fromList(zlib.decode(streamBytes));
        } catch (_) {}

        final streamText = decompressedBytes != null
            ? utf8.decode(decompressedBytes, allowMalformed: true)
            : streamRaw;

        // 提取 () Tj 與 [] TJ 標籤文字
        final tjRegex = RegExp(r'\(([\s\S]*?)\)\s*Tj');
        for (final tjMatch in tjRegex.allMatches(streamText)) {
          final t = tjMatch.group(1);
          if (t != null && t.trim().isNotEmpty) {
            buffer.writeln(t);
          }
        }

        final arrayTjRegex = RegExp(r'\[([\s\S]*?)\]\s*TJ');
        for (final atjMatch in arrayTjRegex.allMatches(streamText)) {
          final arrayContent = atjMatch.group(1);
          if (arrayContent != null) {
            final itemRegex = RegExp(r'\((.*?)\)');
            for (final itemMatch in itemRegex.allMatches(arrayContent)) {
              final t = itemMatch.group(1);
              if (t != null && t.trim().isNotEmpty) {
                buffer.write(t);
              }
            }
            buffer.writeln();
          }
        }
      }
    } catch (e) {
      debugPrint('PDF text extraction error: $e');
    }

    // 品質驗證：檢查提取的文字是否為可讀內容（而非 glyph ID 亂碼）
    final extracted = buffer.toString().trim();
    if (extracted.isNotEmpty && !_isReadableText(extracted)) {
      debugPrint('AiUploadPaper: PDF 提取文字品質不佳（可能為 glyph 編碼亂碼），捨棄並改用視覺辨識');
      return '';
    }

    if (extracted.length < 20) {
      final fallbackBuffer = StringBuffer();
      try {
        final utf8Text = utf8.decode(bytes, allowMalformed: true);
        final chineseOrAlpha =
            RegExp(r'[\u4e00-\u9fa5a-zA-Z0-9\s，。！？、（）()]{4,}');
        for (final match in chineseOrAlpha.allMatches(utf8Text)) {
          final str = match.group(0)?.trim();
          if (str != null &&
              str.length > 5 &&
              !str.startsWith('%PDF') &&
              !str.contains('endobj')) {
            fallbackBuffer.writeln(str);
          }
        }
      } catch (_) {}
      final fallbackText = fallbackBuffer.toString().trim();
      if (fallbackText.isNotEmpty && _isReadableText(fallbackText)) {
        return fallbackText;
      }
      return '';
    }

    return extracted;
  }

  /// 驗證文字是否為可讀內容（非 glyph ID 亂碼）
  /// 檢查可讀字元（中日韓、英文字母、數字、常見標點）的比例是否超過 40%
  static bool _isReadableText(String text) {
    if (text.isEmpty) return false;
    // 可讀字元：中日韓文字、英文字母、數字、常見中英文標點、空白
    final readableChars = RegExp(
      r'[\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff\uac00-\ud7afa-zA-Z0-9\s.,;:!?()\[\]{}\-+=]',
    );
    int readableCount = 0;
    for (int i = 0; i < text.length; i++) {
      if (readableChars.hasMatch(text[i])) {
        readableCount++;
      }
    }
    final ratio = readableCount / text.length;
    debugPrint('AiUploadPaper: 文字可讀性比例 = ${(ratio * 100).toStringAsFixed(1)}% ($readableCount/${text.length})');
    return ratio >= 0.4;
  }



  // 呼叫 Cloudflare 雲端中繼站 (支援 Gemini, Groq, OpenRouter 多模態)
  static Future<String?> _tryCloudflareProxy({
    required String provider,
    required String prompt,
    String? model,
    String? base64Data,
    String? mimeType,
    int timeoutSeconds = 30,
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
              if (base64Data != null) 'data': base64Data,
              if (mimeType != null) 'mime_type': mimeType,
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

  /// 依序嘗試多個 Gemini 模型透過 Cloudflare 中繼站辨識（避免預設模型達 429 限流時直接失敗）
  static Future<({String? text, bool hitRateLimit})>
      _tryCloudflareGeminiWithFallback({
    required String prompt,
    String? base64Data,
    String? mimeType,
    int timeoutSeconds = 30,
  }) async {
    const models = <String?>[
      'gemini-flash-latest',
      'gemini-3-flash-preview',
      'gemini-3.1-flash-lite',
      'gemini-2.5-flash-lite',
      'gemini-3.5-flash',
      'gemini-2.5-flash',
      'gemma-4-26b-a4b-it',
      'gemma-4-31b-it',
      null,
    ];
    bool hitRateLimit = false;
    for (final model in models) {
      try {
        final response = await http
            .post(
              Uri.parse(_kCloudflareProxyUrl),
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                _kAppSecretHeader: _kAppClientSecret,
              },
              body: jsonEncode({
                'provider': 'gemini',
                if (model != null) 'model': model,
                'prompt': prompt,
                if (base64Data != null) 'data': base64Data,
                if (mimeType != null) 'mime_type': mimeType,
              }),
            )
            .timeout(Duration(seconds: timeoutSeconds));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final rawText = data['candidates']?[0]?['content']?['parts']?[0]
              ?['text'] as String?;
          if (rawText != null && rawText.trim().isNotEmpty) {
            return (text: rawText, hitRateLimit: hitRateLimit);
          }
        } else {
          if (response.statusCode == 429) hitRateLimit = true;
          debugPrint(
              'Cloudflare Relay Error (${model ?? 'default'}) [${response.statusCode}]: ${response.body}');
        }
      } catch (e) {
        debugPrint('Cloudflare Relay Exception (${model ?? 'default'}): $e');
      }
    }
    return (text: null, hitRateLimit: hitRateLimit);
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
        Uint8List? bytes = file.bytes;
        if (bytes == null && file.path != null && !kIsWeb) {
          try {
            bytes = await File(file.path!).readAsBytes();
          } catch (_) {}
        }

        setState(() {
          _selectedFilePath = file.path;
          _selectedFileName = file.name;
          _fileBytes = bytes;
          _mimeType = 'application/pdf';
        });

        // Automatically start AI recognition
        _startAiRecognition();
      }
    } catch (e) {
      _showErrorSnackBar(tr('up_pick_pdf_failed', [e.toString()]));
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
        await _processPickedXFile(image);
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      _handleImagePickException(e);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(tr('image_pick_failed_e', [e.toString()]));
    }
  }

  Future<void> _processPickedXFile(XFile image) async {
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty) {
      _showErrorSnackBar('讀取相片失敗（檔案內容為空），請重新拍攝或從相簿選取。');
      return;
    }

    String mimeType = 'image/jpeg';
    final rawMime = image.mimeType?.toLowerCase() ?? '';
    if (rawMime == 'image/png' ||
        rawMime == 'image/webp' ||
        rawMime == 'image/jpeg') {
      mimeType = rawMime;
    } else {
      final ext = image.name.split('.').last.toLowerCase();
      if (ext == 'png') mimeType = 'image/png';
      if (ext == 'webp') mimeType = 'image/webp';
      if (ext == 'heic' || ext == 'heif') mimeType = 'image/jpeg';
    }

    setState(() {
      _selectedFilePath = image.path;
      _selectedFileName =
          image.name.isNotEmpty ? image.name : 'camera_exam.jpg';
      _fileBytes = bytes;
      _mimeType = mimeType;
    });

    // Automatically start AI recognition
    _startAiRecognition();
  }

  void _handleImagePickException(PlatformException e) {
    final code = e.code.toLowerCase();
    if (code.contains('camera_access_denied') || code.contains('permission')) {
      _showErrorDialog(
        '需要相機權限',
        '無法使用相機拍照，請前往裝置或瀏覽器的「權限設定」開啟相機存取權限，或改用「從相簿選取」。',
      );
    } else if (code.contains('no_available_camera')) {
      _showErrorDialog(
        '找不到可用相機',
        '目前裝置沒有可用的相機鏡頭，請改用「從相簿選取」上傳考卷照片。',
      );
    } else {
      _showErrorSnackBar(
          tr('image_pick_failed_e', [e.message ?? e.code]));
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
          child: SingleChildScrollView(
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
                    tr('up_photo_source'),
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
                    title: Text(tr('up_camera'),
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(tr('up_camera_sub'),
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
                    title: Text(tr('up_gallery'),
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(tr('up_gallery_sub'),
                        style: TextStyle(fontSize: 12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
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
        : tr('up_core_quiz');
    final subject = _topicSubjectCtrl.text.trim().isNotEmpty
        ? _topicSubjectCtrl.text.trim()
        : '綜合學科';
    final parsedCount =
        int.tryParse(_topicCountCtrl.text.trim()) ?? _topicQuestionCount;
    final count = parsedCount.clamp(1, 20);
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
請針對以下科目與單元，設計一份高鑑別度、精簡明瞭且具備關鍵解析的標準選擇題（單選題）題本：

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
      "text": "精煉題目敘述（30~80字以內，切入核心情境與條件）",
      "options": ["選項一", "選項二", "選項三", "選項四"],
      "answer": "0",
      "explanation": "極簡解析（30~60字以內，一兩句話說明解法關鍵即可）",
      "difficulty": "${diff == '基礎' ? '易' : (diff == '進階' ? '難' : '中')}"
    }
  ]
}

【重要品質與字數規範】
1. 嚴格字數限制：每題題幹 30~80 字內、每個選項 25 字內、解析 30~60 字內，觀念解析精簡扼要，一兩句話說明核心關鍵即可，切勿拖泥帶水。
2. 輸出語言：${AppLocaleService.getAiLanguageInstruction()}（題目、選項、單元、詳解皆適用；JSON 欄位名稱保持英文不變）
3. 選項純文字：選項陣列中的文字請去除 A. B. C. D. 或 (A) (B) 等前綴標籤。
4. 嚴禁 LaTeX 原始指令：嚴禁出現 \\frac, \\times, \\pm 等反斜線語法，請使用標準文字符號（例如 (a/b), ×, ±, √(x), x^2, +, -, *, /, =）。
5. 嚴禁出現 <think> 思考標籤或對話開場白。
6. 答案索引精確：answer 必須是 0-based 索引字串（"0", "1", "2", "3"）。
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

      // 順位 2：Cloudflare Groq 旗艦中繼引擎 (openai/gpt-oss-20b)
      if (responseText == null || responseText.trim().isEmpty) {
        debugPrint('AiUploadPaper: 切換 Cloudflare Groq 旗艦引擎 (openai/gpt-oss-20b)...');
        responseText = await _tryCloudflareProxy(
          provider: 'groq',
          model: 'openai/gpt-oss-20b',
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
            generationConfig: GenerationConfig(
              maxOutputTokens: (count * 350) + 300,
              temperature: 0.2,
            ),
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
      _showErrorDialog(tr('up_gen_failed'), e.toString());
    }
  }

  // --------------------------------------------------------------------------
  // 核心功能 2：上傳考卷文件/PDF/圖片辨識（支援無答案試卷自動運算推導與多模型備援）
  // --------------------------------------------------------------------------
  Future<void> _startAiRecognition() async {
    // 檢查檔案資料（Web 版不支援 dart:io File 讀取本地路徑）
    if (_fileBytes == null && _selectedFilePath != null && !kIsWeb) {
      try {
        _fileBytes = await File(_selectedFilePath!).readAsBytes();
      } catch (e) {
        _showErrorSnackBar(tr('up_read_failed', [e.toString()]));
        return;
      }
    }

    if (_fileBytes == null) {
      _showErrorSnackBar(tr('up_load_error'));
      return;
    }

    // 檔案大小偵測與日誌
    final fileSizeMB = _fileBytes!.length / (1024 * 1024);
    debugPrint('AiUploadPaper: 檔案大小 = ${fileSizeMB.toStringAsFixed(2)} MB, MIME = $_mimeType');
    if (fileSizeMB > 20) {
      _showErrorSnackBar('檔案過大（${fileSizeMB.toStringAsFixed(1)} MB），建議控制在 20MB 以內以確保辨識順利。');
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

    try {
      String? responseText;
      bool hitRateLimit = false;
      final candidateKeys = await _getCandidatePaperApiKeys();

      // ── 順位 1：若為 PDF 檔案，優先採用 PDF 內建文字萃取 ➔ Gemini / Groq 高速文字解析 ──
      if (_isPdf && _fileBytes != null) {
        debugPrint('AiUploadPaper: 正在從 PDF 提取文字內容 (檔案: $_selectedFileName)...');
        final pdfExtractedText = _extractTextFromPdfBytes(_fileBytes!);
        debugPrint('AiUploadPaper: PDF 文字提取結果長度 = ${pdfExtractedText.length} 字元');
        if (pdfExtractedText.length < 15) {
          debugPrint('AiUploadPaper: PDF 文字過少，將改用多模態視覺辨識...');
        }
        if (pdfExtractedText.length >= 15) {
          debugPrint(
              'AiUploadPaper: 成功從 PDF 提取文字 (長度: ${pdfExtractedText.length})，啟動高速 AI 解析引擎...');
          final pdfTextPrompt = '''
你是一個精通臺灣各級升學考試與學術測驗的「頂級試卷題庫解析與結構化大師」。
以下是從使用者上傳的考卷 PDF（檔名：$_selectedFileName）中完整提取的題目文字內容。請仔細分析所有試卷題目，並結構化為標準單選題題庫。

【最重要規則：絕對禁止自行編造題目！】
- 你必須且只能解析下方「考卷文字內容」中實際存在的題目
- 如果文字內容看起來是亂碼、不可讀、或無法辨識出任何試題，請回傳空的 questions 陣列：{"paper_name":"無法辨識","subject":"","chapter":"","questions":[]}
- 絕對不可自行捏造、虛構任何題目或答案
- subject 學科必須根據考卷實際內容判斷（如檔名或內容與英文相關就是英文，與數學相關就是數學）

【核心規則：無答案試卷自動演算解題】：
1. 若試卷中無提供答案，請由 AI 親自為每道題目深度推導演算出正確答案（填入 options 的 0-based 索引 "0", "1", "2" 或 "3"），並在 explanation 中提供詳盡清晰的步驟與觀念詳解！
2. 若試卷已有答案，請核對並採納該答案，並補齊詳解步驟。
3. 選項文字請去除 A. B. C. D. 等前綴標籤，保持純淨文字。
4. 題目與選項請保留考卷原文語言；explanation 詳解的輸出語言：${AppLocaleService.getAiLanguageInstruction()}

【考卷文字內容】
$pdfExtractedText

【嚴格輸出格式契約】
請絕對只回傳符合以下 JSON 格式的字串，嚴禁包裹 markdown 或其他多餘說明：
{
  "paper_name": "（依據考卷文字辨識出的題本名稱）",
  "subject": "（學科名稱，例如：數學、英文、國文、物理、化學、生物、歷史、地理、公民 等）",
  "chapter": "（單元或章節名稱）",
  "questions": [
    {
      "text": "完整題目敘述（包含情境與所有條件）",
      "options": ["選項一", "選項二", "選項三", "選項四"],
      "answer": "0",
      "explanation": "深度解題步驟與觀念詳解（無答案試卷將由 AI 自動推導演算）",
      "difficulty": "中"
    }
  ]
}
''';

          if (candidateKeys.isNotEmpty) {
            final directRes = await _tryDirectGeminiWithKeys(
              apiKeys: candidateKeys,
              prompt: pdfTextPrompt,
              temperature: 0.1,
              timeoutSeconds: 40,
            );
            responseText = directRes.text;
            hitRateLimit = hitRateLimit || directRes.hitRateLimit;
          }

          // 若直連失敗，優先嘗試 Cloudflare Gemini 中繼站 (依序切換可用模型)
          if (responseText == null || responseText.trim().isEmpty) {
            debugPrint('AiUploadPaper: Gemini 本地直連解析失敗，嘗試 Cloudflare Gemini 中繼...');
            final proxyRes = await _tryCloudflareGeminiWithFallback(
              prompt: pdfTextPrompt,
              timeoutSeconds: 25,
            );
            responseText = proxyRes.text;
            hitRateLimit = hitRateLimit || proxyRes.hitRateLimit;
          }
          // 次選 Cloudflare Groq 中繼 (15 秒超時)
          if (responseText == null || responseText.trim().isEmpty) {
            debugPrint('AiUploadPaper: Gemini 文字解析全部失敗，嘗試 Groq 中繼...');
            responseText = await _tryCloudflareProxy(
              provider: 'groq',
              model: 'openai/gpt-oss-20b',
              prompt: pdfTextPrompt,
              timeoutSeconds: 15,
            );
          }
        }
      }

      // ── 順位 2：多模態視覺模型（針對圖片/照片與純掃描圖檔 PDF）──
      if (responseText == null || responseText.trim().isEmpty) {
        final systemPrompt = '''
你是一個精通臺灣各級升學考試與學術測驗的「頂級試卷 OCR、題庫辨識與自動解題大師」。
請仔細檢視並深度解析使用者上傳的試卷文件（檔名：$_selectedFileName），提取出所有題目並結構化為標準單選題題庫。

【最重要規則：絕對禁止自行編造題目！】
- 你必須且只能辨識文件中實際存在的題目，不可自行捏造
- 如果檔案無法辨識或無法提取出任何試題，請回傳空的 questions 陣列：{"paper_name":"無法辨識","subject":"","chapter":"","questions":[]}
- subject 學科必須根據考卷實際內容判斷（如檔名或內容與英文相關就是英文，與數學相關就是數學）

【重要辨識、無答案自動推導與品質準則】
1. 忠實辨識原題：請精確辨識考卷中的真實題目文字、題幹條件、數值、選項與題意。
2. 【無答案試卷自動演算解題】：若試卷無附帶答案，請 AI 親自深度演算推導出正確答案（填入 options 的 0-based 索引 "0", "1", "2" 或 "3"），並在 explanation 中提供完整計算與推導步驟！
3. 語言：題目與選項請保留考卷原文語言；explanation 詳解的輸出語言：${AppLocaleService.getAiLanguageInstruction()}
4. 選項純淨化：選項陣列中的文字請移除 A. B. C. D. 或 ① ② ③ ④ 等標籤。
5. 答案索引：answer 欄位必須為 options 陣列的 0-based 索引字串（"0", "1", "2" 或 "3"）。

【嚴格輸出格式契約】
請絕對只回傳符合以下 JSON 格式的字串，嚴禁包裹 markdown 或其他多餘說明：
{
  "paper_name": "（依據考卷內容辨識出或生成的題本名稱）",
  "subject": "（學科名稱，例如：數學、英文、國文、物理、化學、生物、歷史、地理、公民 等）",
  "chapter": "（單元或章節名稱）",
  "questions": [
    {
      "text": "完整題目敘述",
      "options": ["選項一", "選項二", "選項三", "選項四"],
      "answer": "0",
      "explanation": "深度解題步驟與觀念詳解",
      "difficulty": "中"
    }
  ]
}
''';

        final base64Data = base64Encode(_fileBytes!);

        // 優先使用候選 Gemini API Keys 多模型直連（支援多模態圖片與掃描 PDF）
        if (candidateKeys.isNotEmpty) {
          final directRes = await _tryDirectGeminiWithKeys(
            apiKeys: candidateKeys,
            prompt: systemPrompt,
            base64Data: base64Data,
            mimeType: _mimeType ?? 'image/jpeg',
            timeoutSeconds: 45,
          );
          responseText = directRes.text;
          hitRateLimit = hitRateLimit || directRes.hitRateLimit;
        }

        // 嘗試 Cloudflare 雲端中繼站 (依序切換可用模型)
        if (responseText == null || responseText.trim().isEmpty) {
          debugPrint('AiUploadPaper: 切換 Cloudflare 雲端中繼站 (Gemini 多模態引擎)...');
          final proxyRes = await _tryCloudflareGeminiWithFallback(
            prompt: systemPrompt,
            base64Data: base64Data,
            mimeType: _mimeType ?? 'image/jpeg',
            timeoutSeconds: 50,
          );
          responseText = proxyRes.text;
          hitRateLimit = hitRateLimit || proxyRes.hitRateLimit;
        }
      }

      if (responseText == null || responseText.trim().isEmpty) {
        if (hitRateLimit) {
          throw Exception(
            '目前 AI 辨識服務請求人數較多（已達暫時上限），請稍候片刻再試一次。',
          );
        }
        throw Exception('無法完成考卷解析。請確認：\n1. 網路連線正常\n2. 檔案為選擇題格式\n3. 檔案字跡清晰且非加密 PDF\n若為掃描圖檔 PDF，建議截圖後以圖片方式上傳。');
      }

      stepTimer.cancel();
      _parseAndApplyQuestions(responseText);
    } catch (e) {
      stepTimer.cancel();
      setState(() {
        _state = UploadState.initial;
      });
      _showErrorDialog(tr('up_recog_failed'), e.toString().replaceAll('Exception: ', ''));
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
    // 標號後必須接標點，避免把「2 和 3」「a = 3」等選項內容的開頭誤刪
    opt = opt.replaceAll(
      RegExp(
          r'^(?:[A-Da-d][\.\、\:\)](?!\d)\s*|\([A-Da-d]\)\s*|\[[A-Da-d]\]\s*|[①②③④⑤]\s*|\d{1,2}[\、\:\)]\s*|\d{1,2}\.(?!\d)\s*)'),
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

    Map<String, dynamic> parsedData;
    try {
      parsedData = jsonDecode(cleanText.trim()) as Map<String, dynamic>;
    } catch (_) {
      // 修正 AI 回傳的 LaTeX 單反斜線（例如 \frac, \times）導致 JSON 解析失敗
      final repaired = cleanText
          .trim()
          .replaceAllMapped(RegExp(r'\\(?!["\\/bfnrtu])'), (_) => r'\\');
      parsedData = jsonDecode(repaired) as Map<String, dynamic>;
    }
    final String rawPaperName =
        (parsedData['paper_name'] ?? 'AI 智慧生成題本').toString();
    final String paperName = _cleanAiSymbols(rawPaperName);
    final String subject = _cleanAiSymbols(
        (parsedData['subject'] ?? _topicSubjectCtrl.text.trim()).toString());
    final String chapter =
        _cleanAiSymbols((parsedData['chapter'] ?? 'AI 核心單元').toString());
    final List<dynamic> qList = parsedData['questions'] ?? [];

    if (paperName.contains('無法辨識') || qList.isEmpty) {
      throw Exception(
          tr('up_no_valid_q'));
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
        options.add(tr('up_none_above'));
      }

      questions.add({
        'text': text,
        'options': options,
        'answerIndex': ansIndex,
        'explanation': _cleanAiSymbols((q['explanation'] ?? '').toString()),
        'difficulty': QuestionUtils.normalizeDifficulty(q['difficulty'], fallback: '中'),
      });
    }

    if (questions.isEmpty) {
      throw Exception('未能從上傳的文件/相片中提取出完整的題目結構，請重新拍攝或選取清晰的試卷。');
    }

    setState(() {
      _paperNameCtrl.text = paperName;
      _subjectCtrl.text =
          subject.isNotEmpty ? subject : _topicSubjectCtrl.text.trim();
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
      _showErrorSnackBar(tr('up_need_name'));
      return;
    }
    if (subject.isEmpty) {
      _showErrorSnackBar(tr('up_need_subject'));
      return;
    }
    if (_questions.isEmpty) {
      _showErrorSnackBar(tr('up_need_q'));
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
        final String difficulty = QuestionUtils.normalizeDifficulty(q['difficulty'], fallback: '中');

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
        ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
          SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, 
            content: Text(tr('up_created', [paperName.toString(), _questions.length.toString()])),
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
      _showErrorSnackBar(tr('up_save_failed', [e.toString()]));
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
      SnackBar(duration: const Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating, 
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
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('confirm')),
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
        title: Text(tr('up_title'),
            style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface)),
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        iconTheme: IconThemeData(color: cs.onSurface),
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
                            tr('up_tab_doc'),
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
                            tr('up_tab_topic'),
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
                    Text(tr('up_photo_title'),
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(tr('up_photo_sub'),
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
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('up_pdf_title'),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(tr('up_pdf_sub'),
                              style: TextStyle(
                                  fontSize: 11, color: cs.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
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
                      tr('up_tip'),
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
                  Text(tr('up_s1'),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _topicSubjectCtrl,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '可自由輸入或點選下方學科（例：數學、生物、日文、經濟學...）',
                      hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      prefixIcon: Icon(Icons.school_outlined, size: 20, color: cs.primary),
                      suffixIcon: _topicSubjectCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.cancel_rounded, size: 16),
                              onPressed: () {
                                setState(() {
                                  _topicSubjectCtrl.clear();
                                });
                              },
                            )
                          : null,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: cs.outline.withValues(alpha: 0.2)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...{
                          ...widget.allSubjects,
                          '數學',
                          '英文',
                          '國文',
                          '理化',
                          '生物',
                          '歷史',
                          '地理',
                          '公民',
                          '地球科學',
                          '資訊管理',
                        }.map((sub) {
                          final isSelected =
                              _topicSubjectCtrl.text.trim() == sub;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _topicSubjectCtrl.text = sub;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? cs.primary
                                      : cs.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? cs.primary
                                        : cs.primary.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  trv(sub),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.white
                                        : cs.primary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(tr('up_s2'),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _topicChapterCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: tr('up_s2_hint'),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        tr('up_s3'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        '可自由填寫 1 ~ 20 題',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _topicCountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: '輸入自訂題數 (例如 8 或 12)',
                      hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                      prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                      suffixText: '題',
                      suffixStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
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
                    onChanged: (val) {
                      final n = int.tryParse(val.trim());
                      if (n != null) {
                        setState(() => _topicQuestionCount = n);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [3, 5, 10, 15, 20].map((c) {
                        final isSel = _topicQuestionCount == c;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('$c 題'),
                            selected: isSel,
                            onSelected: (_) {
                              setState(() {
                                _topicQuestionCount = c;
                                _topicCountCtrl.text = c.toString();
                              });
                            },
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isSel ? FontWeight.bold : FontWeight.w500,
                              color: isSel ? cs.onPrimary : cs.onSurface,
                            ),
                            selectedColor: cs.primary,
                            backgroundColor: cs.surfaceContainerHighest
                                .withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSel
                                    ? cs.primary
                                    : cs.outline.withValues(alpha: 0.15),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 0),
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. 難易度
                  Text(
                    tr('up_s4'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDifficultyOption(cs, '基礎', tr('up_diff_basic')),
                      const SizedBox(width: 8),
                      _buildDifficultyOption(cs, '中等', tr('up_diff_mid')),
                      const SizedBox(width: 8),
                      _buildDifficultyOption(cs, '進階', tr('up_diff_adv')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.bolt_rounded, size: 20),
                      label: Text(tr('up_generate'),
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
              tr('up_recognizing'),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              tr('up_recognizing_sub'),
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
                  _selectedFileName ?? tr('up_file_loaded'),
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
                label: Text(tr('up_reupload'), style: TextStyle(fontSize: 12)),
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
                      Row(
                        children: [
                          Icon(Icons.assignment_ind_rounded,
                              color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text(tr('up_settings'),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _paperNameCtrl,
                        decoration: InputDecoration(
                          labelText: tr('wq_paper_name'),
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
                                labelText: tr('ql_subjects'),
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
                                labelText: tr('up_unit_name'),
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
                    tr('up_preview_n', [_questions.length.toString()]),
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
                          'difficulty': '中',
                        });
                      });
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(tr('up_add_q'), style: TextStyle(fontSize: 13)),
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
                        title: Text(tr('up_discard')),
                        content: Text(tr('up_discard_msg')),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(tr('btn_cancel'))),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _state = UploadState.initial;
                                _questions.clear();
                              });
                            },
                            child: Text(tr('up_confirm_discard'),
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
                  child: Text(tr('up_discard_btn')),
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
                  child: Text(tr('up_confirm_create'),
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
                    tr('qs_q_n', [(qIndex + 1).toString()]),
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
                      value: QuestionUtils.normalizeDifficulty(q['difficulty'], fallback: '中'),
                      items: [
                        DropdownMenuItem(
                            value: '易',
                            child: Text(tr('up_easy'), style: const TextStyle(fontSize: 12))),
                        DropdownMenuItem(
                            value: '中',
                            child: Text(tr('up_mid'), style: const TextStyle(fontSize: 12))),
                        DropdownMenuItem(
                            value: '難',
                            child: Text(tr('up_hard'), style: const TextStyle(fontSize: 12))),
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
                      tooltip: tr('up_delete_q'),
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 12),

            // Question Text Input
            Text(tr('up_q_desc'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 4),
            TextFormField(
              initialValue: q['text'],
              maxLines: null,
              decoration: InputDecoration(
                hintText: tr('up_q_desc_hint'),
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
            Text(tr('up_options'),
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
                          hintText: tr('up_option_n', [char.toString()]),
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
            Text(tr('up_explanation'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 4),
            TextFormField(
              initialValue: q['explanation'],
              maxLines: null,
              decoration: InputDecoration(
                hintText: tr('up_explanation_hint'),
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
