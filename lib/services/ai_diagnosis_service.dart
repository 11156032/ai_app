import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';

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

  factory DiagnosisResult.fromJson(Map<String, dynamic> json,
      {bool isAiGenerated = true}) {
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
  static const String _kSystemGeminiApiKey =
      'AQ.Ab8RN6IKYCJChp7vSzpJovc-SnuoM2tvq-2AAXXC-UtS0nWFwQ';
  static DateTime? nextAvailableTime;

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
      final model = GenerativeModel(
        model: 'gemini-3.5-flash',
        apiKey: _kSystemGeminiApiKey,
      );
      final contentStream = model.generateContentStream([Content.text(prompt)]);
      await for (final chunk in contentStream) {
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
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$_kSystemGeminiApiKey',
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
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'responseMimeType': 'application/json',
              }
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final text = resJson['candidates']?[0]?['content']?['parts']?[0]
            ?['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          final decoded = jsonDecode(text.trim());
          final List<String> points =
              List<String>.from(decoded['points'] ?? []);
          final List<String> actions =
              List<String>.from(decoded['actions'] ?? []);
          return {
            'points': points,
            'actions': actions,
            'isAiGenerated': true,
          };
        }
      } else {
        if (response.statusCode == 429) {
          _updateNextAvailableTime(response.body);
        }
        debugPrint(
            'Gemini note summary error: ${response.statusCode} ${response.body}');
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

請以繁體中文 (Traditional Chinese) 回答。
''';

    try {
      final model = GenerativeModel(
        model: 'gemini-3.5-flash',
        apiKey: _kSystemGeminiApiKey,
      );
      final contentStream = model.generateContentStream([Content.text(prompt)]);
      await for (final chunk in contentStream) {
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
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$apiKey',
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
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
            }
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
        'Failed to get response from Gemini API: ${response.statusCode} - ${response.body}');
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
            firstCh != null && firstCh.isNotEmpty ? firstCh : '$subject 錯題觀念');
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
              nextAvailableTime =
                  DateTime.now().add(Duration(seconds: seconds));
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
