import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_app/database/database_helper.dart';
import 'package:ai_app/services/ai_diagnosis_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.setTestDbPath(':memory:');
  });

  test('Test AiDiagnosisService guest blocking and local fallback', () async {
    final db = await DatabaseHelper.instance.database;

    // Verify database schema has gemini_api_key column (maintained for schema integrity)
    final userCols = await db.rawQuery('PRAGMA table_info(users)');
    final hasApiKeyCol = userCols.any((c) => c['name'] == 'gemini_api_key');
    expect(hasApiKeyCol, isTrue);

    // Create mock quiz results details
    final List<Map<String, dynamic>> wrongQuestions = [
      {
        'id': 'q1',
        'question': 'What is the capital of France?',
        'chapter': 'Geography Basics',
        'difficulty': 'easy',
        'subject': 'Geography',
        'explanation': 'Paris is the capital.',
        'options': ['London', 'Berlin', 'Paris', 'Rome'],
        'answerIndex': 2,
      }
    ];

    final List<Map<String, dynamic>> correctQuestions = [
      {
        'id': 'q2',
        'question': 'What is 2+2?',
        'chapter': 'Arithmetic',
        'difficulty': 'easy',
        'subject': 'Math',
        'explanation': '2+2 is 4.',
        'options': ['3', '4', '5', '6'],
        'answerIndex': 1,
      }
    ];

    // 1. Verify guest user ('u4') gets local fallback
    final reportGuest = await AiDiagnosisService.generate(
      userId: 'u4',
      wrongQuestions: wrongQuestions,
      correctQuestions: correctQuestions,
      score: 50,
      total: 2,
      subject: 'General Knowledge',
    );

    expect(reportGuest.isAiGenerated, isFalse);
    expect(reportGuest.summary, contains('General Knowledge'));
    expect(reportGuest.strengths, isNotEmpty);
    expect(reportGuest.weaknesses, isNotEmpty);
    expect(reportGuest.weaknesses.first, contains('Geography Basics'));

    // 2. Test generateNoteSummary guest blocking
    final guestSummary = await AiDiagnosisService.generateNoteSummary(
      userId: 'u4',
      noteTitle: 'Geography Note',
      noteContent: 'France is in Europe. Paris is the capital.',
    );
    expect(guestSummary['points'].first, contains('訪客帳戶無法使用 AI 整理功能'));

    // 3. Test generateNoteSummary local fallback logic
    final registeredSummary = await AiDiagnosisService.generateNoteSummary(
      userId: 'u1',
      noteTitle: 'Math Note',
      noteContent: 'Algebra is useful.\nLinear equations are straight lines.\nCalculus is hard.',
    );
    expect(registeredSummary['points'], isNotEmpty);
    if (registeredSummary['isAiGenerated'] == true) {
      expect(registeredSummary['actions'], isNotEmpty);
    } else {
      expect(registeredSummary['points'].any((pt) => pt.toString().contains('Algebra is useful')), isTrue);
      expect(registeredSummary['actions'], isNotEmpty);
    }

    await db.close();
  });
}
