import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../database/database_helper.dart';

class AIPaperSpec {
  final String title;
  final List<String> targetChapters;
  final String difficulty; // 'all', 'easy', 'medium', 'hard'
  final int count;
  final List<String> keywords;

  AIPaperSpec({
    required this.title,
    this.targetChapters = const [],
    this.difficulty = 'all',
    this.count = 10,
    this.keywords = const [],
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'targetChapters': targetChapters,
        'difficulty': difficulty,
        'count': count,
        'keywords': keywords,
      };
}

class AIPaperGeneratorService {
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

  static String get _kDefaultGeminiApiKey {
    try {
      final key = dotenv.env['GEMINI_API_KEY'];
      if (key != null && key.isNotEmpty) return key;
    } catch (_) {}
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    try {
      return utf8.decode(base64Decode(
          'QVEuQWI4Uk42S3hsa2Z2QlJaenFXSGpXamNlZmFtVzlEeEx6UjdZOWliX2c4aXZHRWRJNUE='));
    } catch (_) {
      return '';
    }
  }

  /// 根據使用者需求描述，解析出篩選規格 (Spec)
  static Future<AIPaperSpec> parseUserPrompt({
    required String subject,
    required List<String> availableChapters,
    required String userPrompt,
  }) async {
    final cleanPrompt = userPrompt.trim();
    if (cleanPrompt.isEmpty) {
      return AIPaperSpec(
        title: '$subject 綜合練習卷',
        count: 10,
        difficulty: 'all',
      );
    }

    // 1. 嘗試透過 AI 解析
    try {
      final spec = await _parseWithAI(subject, availableChapters, cleanPrompt);
      if (spec != null) return spec;
    } catch (e) {
      debugPrint('AIPaperGeneratorService AI 解析異常，切換規則引擎: $e');
    }

    // 2. 本地規則引擎解析 (高可靠備援，完全離線可用)
    return _parseWithRules(subject, availableChapters, cleanPrompt);
  }

  static Future<AIPaperSpec?> _parseWithAI(
    String subject,
    List<String> availableChapters,
    String userPrompt,
  ) async {
    final chaptersStr = availableChapters.join('、');
    final systemPrompt = '''
你是一位考卷規劃專家。請根據使用者的出卷需求，將其轉換為題目庫抽題規格。
學科: $subject
可用章節列表: [$chaptersStr]
使用者需求: "$userPrompt"

請一律輸出 JSON 格式，不要包含 markdown 標籤或任何其他文字：
{
  "title": "建議考卷名稱 (例如: 國文 - 基礎觀念快掃卷)",
  "targetChapters": ["精確符合可用章節列表中的名稱，若無指定或為全冊則留空陣列 []"],
  "difficulty": "easy 或 medium 或 hard 或 all",
  "count": 10 (題數，預設 10，數字),
  "keywords": ["相關關鍵字"]
}
''';

    String? responseText;

    // 順位 1：Cloudflare Proxy
    try {
      final res = await http.post(
        Uri.parse(_kCloudflareProxyUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          _kAppSecretHeader: _kAppClientSecret,
        },
        body: jsonEncode({
          'provider': 'gemini',
          'model': 'gemini-2.5-flash',
          'prompt': systemPrompt,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        responseText = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      }
    } catch (e) {
      debugPrint('Cloudflare proxy ai paper error: $e');
    }

    // 順位 2：本地 Gemini SDK 直連
    if (responseText == null || responseText.trim().isEmpty) {
      final apiKey = _kDefaultGeminiApiKey;
      if (apiKey.isNotEmpty) {
        final model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(temperature: 0.1),
        );
        final res = await model.generateContent([Content.text(systemPrompt)]);
        responseText = res.text;
      }
    }

    if (responseText != null && responseText.trim().isNotEmpty) {
      final cleaned = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;

      final title = decoded['title']?.toString() ?? '$subject 專屬測驗卷';
      final chapters = (decoded['targetChapters'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((e) => availableChapters.contains(e))
          .toList();
      final diff = decoded['difficulty']?.toString() ?? 'all';
      final count = int.tryParse(decoded['count']?.toString() ?? '10') ?? 10;
      final keywords = (decoded['keywords'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      return AIPaperSpec(
        title: title,
        targetChapters: chapters,
        difficulty: diff,
        count: count.clamp(3, 50),
        keywords: keywords,
      );
    }

    return null;
  }

  /// 本地離線規則解析引擎
  static AIPaperSpec _parseWithRules(
    String subject,
    List<String> availableChapters,
    String prompt,
  ) {
    // 1. 題數解析 (找數字 + 題)
    int count = 10;
    final countMatch = RegExp(r'(\d+)\s*題').firstMatch(prompt);
    if (countMatch != null) {
      count = int.tryParse(countMatch.group(1) ?? '10') ?? 10;
    } else {
      final numMatch = RegExp(r'\b(\d+)\b').firstMatch(prompt);
      if (numMatch != null) {
        final parsed = int.tryParse(numMatch.group(1) ?? '10') ?? 10;
        if (parsed >= 3 && parsed <= 50) count = parsed;
      }
    }
    count = count.clamp(3, 50);

    // 2. 難度解析
    String difficulty = 'all';
    if (prompt.contains('難') || prompt.contains('進階') || prompt.contains('拔高') || prompt.contains('挑戰') || prompt.contains('易錯')) {
      difficulty = 'hard';
    } else if (prompt.contains('易') || prompt.contains('簡單') || prompt.contains('基礎') || prompt.contains('入門')) {
      difficulty = 'easy';
    } else if (prompt.contains('中等') || prompt.contains('一般')) {
      difficulty = 'medium';
    }

    // 3. 章節比對
    final matchedChapters = <String>[];
    for (final ch in availableChapters) {
      if (prompt.contains(ch)) {
        matchedChapters.add(ch);
      }
    }

    // 如果沒有精確匹配完整名稱，嘗試比對「第X單元」、「第X章」
    if (matchedChapters.isEmpty) {
      final unitMatches = RegExp(r'第\s*([0-9一二三四五六七八九十]+)\s*[單元|章|課]').allMatches(prompt);
      for (final m in unitMatches) {
        final numStr = m.group(1) ?? '';
        for (final ch in availableChapters) {
          if (ch.contains(numStr) || ch.contains(m.group(0)!)) {
            if (!matchedChapters.contains(ch)) matchedChapters.add(ch);
          }
        }
      }
    }

    // 4. 自動標題
    String title = '$subject ';
    if (matchedChapters.isNotEmpty) {
      title += matchedChapters.join('、');
      title += ' 特訓卷';
    } else if (difficulty == 'hard') {
      title += '進階攻堅突破卷';
    } else if (difficulty == 'easy') {
      title += '基礎觀念精練卷';
    } else {
      title += '綜合模擬測驗卷';
    }

    return AIPaperSpec(
      title: title,
      targetChapters: matchedChapters,
      difficulty: difficulty,
      count: count,
    );
  }

  /// 從 SQLite 題庫中，根據 AIPaperSpec 智慧抓取題目
  static Future<List<Map<String, dynamic>>> fetchQuestionsForSpec({
    required String subject,
    required AIPaperSpec spec,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // 建立查詢 SQL
    final whereConditions = <String>['q.subject = ?', 'q.is_public = 1'];
    final whereArgs = <dynamic>[subject];

    // 難度過濾
    if (spec.difficulty == 'easy') {
      whereConditions.add("q.difficulty IN ('易', '簡單', '基礎')");
    } else if (spec.difficulty == 'medium') {
      whereConditions.add("q.difficulty IN ('中', '中等', '一般')");
    } else if (spec.difficulty == 'hard') {
      whereConditions.add("q.difficulty IN ('難', '進階', '困難', '拔高')");
    }

    // 章節過濾 (若指定了章節)
    String joinClause = '';
    if (spec.targetChapters.isNotEmpty) {
      joinClause = '''
        JOIN question_tag_map qm ON q.id = qm.question_id
        JOIN tags t ON t.id = qm.tag_id
      ''';
      final placeholders = List.filled(spec.targetChapters.length, '?').join(',');
      whereConditions.add('t.name IN ($placeholders)');
      whereArgs.addAll(spec.targetChapters);
    }

    // 關鍵字過濾
    if (spec.keywords.isNotEmpty) {
      final kwOrs = <String>[];
      for (final kw in spec.keywords) {
        if (kw.trim().isNotEmpty) {
          kwOrs.add('q.text LIKE ?');
          whereArgs.add('%${kw.trim()}%');
        }
      }
      if (kwOrs.isNotEmpty) {
        whereConditions.add('(${kwOrs.join(' OR ')})');
      }
    }

    final sql = '''
      SELECT DISTINCT q.*, u.display_name as author
      FROM questions q
      $joinClause
      LEFT JOIN users u ON q.user_id = u.id
      WHERE ${whereConditions.join(' AND ')}
      ORDER BY RANDOM()
      LIMIT ?
    ''';

    var rows = await db.rawQuery(sql, [...whereArgs, spec.count]);

    // 若嚴格條件下題目不足，進行優雅降級（放寬難度或關鍵字限制，確保使用者有題可練）
    if (rows.length < spec.count) {
      final needed = spec.count - rows.length;
      final existingIds = rows.map((r) => r['id']).toList();

      final fallbackWhere = ['q.subject = ?', 'q.is_public = 1'];
      final fallbackArgs = <dynamic>[subject];
      if (existingIds.isNotEmpty) {
        fallbackWhere.add('q.id NOT IN (${List.filled(existingIds.length, '?').join(',')})');
        fallbackArgs.addAll(existingIds);
      }

      final fallbackSql = '''
        SELECT q.*, u.display_name as author
        FROM questions q
        LEFT JOIN users u ON q.user_id = u.id
        WHERE ${fallbackWhere.join(' AND ')}
        ORDER BY RANDOM()
        LIMIT ?
      ''';
      final fallbackRows = await db.rawQuery(fallbackSql, [...fallbackArgs, needed]);
      rows = [...rows, ...fallbackRows];
    }

    // 轉換成 QuestionPracticePage 相容格式
    return rows.map((row) {
      final id = int.tryParse(row['id'].toString()) ?? -1;
      final rawOptions = row['options'];
      final decodedOptions = rawOptions is String
          ? jsonDecode(rawOptions) as List<dynamic>
          : (rawOptions as List<dynamic>? ?? []);

      return {
        'id': id,
        'subject': row['subject'] ?? subject,
        'chapter': row['chapter'] ?? (spec.targetChapters.isNotEmpty ? spec.targetChapters.first : '綜合'),
        'difficulty': row['difficulty'] ?? '中',
        'type': row['type'] ?? '單選題',
        'question': row['text'] ?? '',
        'options': decodedOptions,
        'answerIndex': int.tryParse((row['answer'] ?? '0').toString()) ?? 0,
        'explanation': row['explanation'] ?? '',
        'isFavorite': (row['bookmarked'] as int? ?? 0) == 1,
        'isPublic': (row['is_public'] as int? ?? 0) == 1,
        'author': row['author'] ?? row['user_id'] ?? '',
        'user_id': row['user_id'] ?? '',
        'created_at': row['created_at'],
      };
    }).toList();
  }
}
