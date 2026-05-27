import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  factory DiagnosisResult.fromJson(Map<String, dynamic> json, {bool isAiGenerated = true}) {
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
  static const String _kSystemGeminiApiKey = 'AIzaSyCTkO0XLKss6oEELbB4rVpIX_XdshJKc8I';
  static DateTime? nextAvailableTime;

  /// Generate a learning diagnosis report.
  /// If the user is a registered user, it uses the system-wide Gemini API key.
  /// If the user is a guest (userId == 'u4'), it immediately falls back to a rule-based local diagnosis.
  static Future<DiagnosisResult> generate({
    required String userId,
    required List<Map<String, dynamic>> wrongQuestions,
    required List<Map<String, dynamic>> correctQuestions,
    required int score,
    required int total,
    required String subject,
  }) async {
    // 訪客帳戶權限限制：直接退回本地 Fallback
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

    // Fallback to local rule-based analysis if API call fails
    return _generateLocalFallback(
      wrongQuestions: wrongQuestions,
      correctQuestions: correctQuestions,
      score: score,
      total: total,
      subject: subject,
    );
  }

  /// Generate note summary and action items using Gemini API.
  /// Since guest is blocked at the UI/Intent layer, this is for registered users only.
  /// Returns a Map with keys: 'points' (List<String>) and 'actions' (List<String>)
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

      final response = await http.post(
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
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final resJson = jsonDecode(response.body);
        final text = resJson['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
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
        debugPrint('Gemini note summary error: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error calling Gemini for note summary: $e');
    }

    // Fallback to local extraction if API call fails
    return _generateLocalNoteSummaryMap(noteContent);
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
        // 本地備用摘要：依句號、問號、驚嘆號分割句尾，只取第一句完整的話，避免話沒講完就斷句
        List<String> sentences = pt.split(RegExp(r'[。！？]'));
        String firstSentence = sentences[0].trim();
        if (firstSentence.isNotEmpty) {
          // 若本句太長，保留整句但如果大於60字，則切斷，否則直接保留整句
          if (firstSentence.length > 60) {
            firstSentence = '${firstSentence.substring(0, 57)}...';
          } else {
            firstSentence = '$firstSentence。';
          }
          points.add('重點 $count：$firstSentence');
          count++;
        }
      }
      if (points.length >= 3) break; // 最多 3 點
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
      final correctAns = (opts != null && ansIdx != null && ansIdx >= 0 && ansIdx < opts.length)
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
  "strengths": ["強項 1", "強項 2", ...],
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

    final response = await http.post(
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
    ).timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final resJson = jsonDecode(response.body);
      final text = resJson['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text != null && text.trim().isNotEmpty) {
        final decoded = jsonDecode(text.trim());
        return DiagnosisResult.fromJson(decoded, isAiGenerated: true);
      }
    }

    if (response.statusCode == 429) {
      _updateNextAvailableTime(response.body);
    }

    throw Exception('Failed to get response from Gemini API: ${response.statusCode} - ${response.body}');
  }

  static DiagnosisResult _generateLocalFallback({
    required List<Map<String, dynamic>> wrongQuestions,
    required List<Map<String, dynamic>> correctQuestions,
    required int score,
    required int total,
    required String subject,
  }) {
    // 依據單元章節分類，分析強項與弱項
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

    final List<String> strengths = [];
    final List<String> weaknesses = [];

    // 強項：答對題數多，且沒答錯或答錯少的章節
    correctChapters.forEach((ch, count) {
      final wCount = wrongChapters[ch] ?? 0;
      if (wCount == 0 || (count / (count + wCount)) >= 0.7) {
        strengths.add('$ch (答對 $count 題)');
      }
    });

    // 弱項：有答錯的章節
    wrongChapters.forEach((ch, count) {
      final cCount = correctChapters[ch] ?? 0;
      if (cCount == 0 || (cCount / (cCount + count)) < 0.6) {
        weaknesses.add('$ch (答錯 $count 題)');
      }
    });

    // 預設填充
    if (strengths.isEmpty) {
      if (score >= 80) {
        strengths.add('$subject 基本觀念');
      } else if (correctQuestions.isNotEmpty) {
        final firstCh = correctQuestions.first['chapter'] as String?;
        strengths.add(firstCh != null && firstCh.isNotEmpty ? firstCh : '$subject 基礎題目');
      } else {
        strengths.add('尚未展現明顯強項，繼續加油！');
      }
    }

    if (weaknesses.isEmpty) {
      if (score < 100 && wrongQuestions.isNotEmpty) {
        final firstCh = wrongQuestions.first['chapter'] as String?;
        weaknesses.add(firstCh != null && firstCh.isNotEmpty ? firstCh : '$subject 錯題觀念');
      } else {
        weaknesses.add('本次測驗無明顯弱項，表現完美！');
      }
    }

    // 生成摘要與學習建議
    String summary;
    String suggestion;
    String encouragement;

    if (score == 100) {
      summary = '太棒了！本次「$subject」測驗獲得滿分，展現出極高的熟練度。';
      suggestion = '目前在此科目表現優異。建議可以挑戰更高難度的進階試題，或是協助同學解題以加深思考。';
      encouragement = '優秀的表現源於你的努力，繼續保持這股頂尖的學習狀態！';
    } else if (score >= 80) {
      summary = '本次「$subject」測驗表現亮眼，正確率達 $score%，已掌握大部分核心概念。';
      suggestion = '主要強項在於 ${strengths.take(2).join('、')}。建議針對答錯的弱項觀念進行微調複習，並加強錯題的細節觀念。';
      encouragement = '距離完美只差一步，細心檢視錯題，你一定能突破極限！';
    } else if (score >= 60) {
      summary = '本次「$subject」測驗表現尚可，正確率為 $score%，基本概念已具備但仍不夠穩定。';
      suggestion = '你在 ${strengths.take(1).join()} 表現不錯，但 ${weaknesses.take(1).join()} 稍顯薄弱。建議針對弱項章節的教科書/講義重新閱讀，並進行專題練習。';
      encouragement = '及格是個起點，持之以恆地複習弱項，分數一定會穩步上升！';
    } else {
      summary = '本次「$subject」測驗挑戰性較高，正確率為 $score%，有較多核心概念需要重溫。';
      suggestion = '目前 ${weaknesses.take(2).join('與')} 是需要首要加強的單元。建議從最基礎的課堂例題重新學起，並建立專屬的錯題本反覆練習。';
      encouragement = '挫折是學習的養分，找出不會的地方就是進步的機會，我們一起加油！';
    }

    return DiagnosisResult(
      summary: summary,
      strengths: strengths,
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
              nextAvailableTime = DateTime.now().add(Duration(seconds: seconds));
              return;
            }
          }
        }
      }
      // default if 429 but failed to parse specific delay
      nextAvailableTime = DateTime.now().add(const Duration(seconds: 60));
    } catch (_) {
      nextAvailableTime = DateTime.now().add(const Duration(seconds: 60));
    }
  }
}
