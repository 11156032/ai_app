import 'dart:convert';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_app/database/database_helper.dart';
import 'package:ai_app/screens/notes_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.setTestDbPath(':memory:');
  });

  test('Test Note Sharing and One-Click Importing', () async {
    final db = await DatabaseHelper.instance.database;

    // 1. 準備使用者 A 的筆記
    final originalNote = Note(
      id: 'test_note_123',
      userId: 'u1',
      title: '社群測試筆記',
      content: '這是測試筆記的內容。',
      category: '學習',
      strokes: [
        Stroke(points: [], color: const Color(0xFF000000), strokeWidth: 2.0)
      ],
      updatedAt: DateTime.now(),
    );

    // 2. 模擬分享筆記至貼文資料表
    final strokesJson = jsonEncode(originalNote.strokes.map((s) => s.toJson()).toList());
    final attachedData = {
      'shared_type': 'note',
      'title': originalNote.title,
      'content': originalNote.content,
      'category': originalNote.category,
      'strokes': strokesJson,
    };

    final postId = await db.insert('posts', {
      'user_id': 'u1',
      'content': '我分享了我的學習筆記《${originalNote.title}》',
      'type': 'note',
      'attached_data': jsonEncode(attachedData),
      'created_at': DateTime.now().toIso8601String(),
    });

    // 驗證貼文正確寫入
    final postRows = await db.query('posts', where: 'id = ?', whereArgs: [postId]);
    expect(postRows.length, 1);
    final post = postRows.first;
    expect(post['type'], 'note');

    // 3. 模擬使用者 B (u2) 一鍵匯入筆記
    final attachedFromDb = jsonDecode(post['attached_data'] as String) as Map<String, dynamic>;
    expect(attachedFromDb['shared_type'], 'note');

    final String title = attachedFromDb['title'] ?? '無標題筆記';
    final String content = attachedFromDb['content'] ?? '';
    final String category = attachedFromDb['category'] ?? '學習';
    
    final List<Stroke> strokes = [];
    final String? strokesJsonDb = attachedFromDb['strokes'];
    if (strokesJsonDb != null && strokesJsonDb.isNotEmpty) {
      final decoded = jsonDecode(strokesJsonDb) as List;
      for (var s in decoded) {
        strokes.add(Stroke.fromJson(s as Map<String, dynamic>));
      }
    }

    final newNote = Note(
      id: 'note_imported_123',
      userId: 'u2',
      title: '$title (社群匯入)',
      content: content,
      category: category,
      strokes: strokes,
      updatedAt: DateTime.now(),
    );

    NotesDatabase.notes.insert(0, newNote);

    // 驗證匯入的筆記資料正確性
    final imported = NotesDatabase.notes.firstWhere((n) => n.id == 'note_imported_123');
    expect(imported.title, '社群測試筆記 (社群匯入)');
    expect(imported.userId, 'u2');
    expect(imported.strokes.length, 1);
    expect(imported.strokes.first.strokeWidth, 2.0);

    // 清理測試資料
    NotesDatabase.notes.remove(newNote);
    await db.delete('posts', where: 'id = ?', whereArgs: [postId]);
  });

  test('Test Question Sharing and One-Click Importing', () async {
    final db = await DatabaseHelper.instance.database;

    // 1. 在資料庫中準備一道題目
    final questionId = await db.insert('questions', {
      'user_id': 'u1',
      'text': '何者不是 OOP 的特性？',
      'options': jsonEncode(['封裝', '繼承', '多型', '指標']),
      'answer': '3',
      'explanation': '指標是 C 語言特性，非 OOP 核心三大特性。',
      'subject': '程式設計',
      'difficulty': '易',
      'is_public': 0,
      'bookmarked': 0,
    });

    // 驗證題目已寫入
    final questionRows = await db.query('questions', where: 'id = ?', whereArgs: [questionId]);
    expect(questionRows.length, 1);
    final question = questionRows.first;

    // 2. 模擬分享該題目至社群貼文
    final attachedData = {
      'shared_type': 'question',
      'text': question['text'],
      'options': jsonDecode(question['options'] as String),
      'answer': question['answer'],
      'explanation': question['explanation'],
      'subject': question['subject'],
      'difficulty': question['difficulty'],
    };

    final postId = await db.insert('posts', {
      'user_id': 'u1',
      'content': '我分享了一道題目',
      'type': 'doc',
      'attached_data': jsonEncode(attachedData),
      'created_at': DateTime.now().toIso8601String(),
    });

    // 3. 模擬使用者 B (u2) 一鍵收藏該題目
    final postRows = await db.query('posts', where: 'id = ?', whereArgs: [postId]);
    final post = postRows.first;
    final attachedFromDb = jsonDecode(post['attached_data'] as String) as Map<String, dynamic>;

    final importedQuestionId = await db.insert('questions', {
      'user_id': 'u2',
      'text': attachedFromDb['text'],
      'options': jsonEncode(attachedFromDb['options']),
      'answer': attachedFromDb['answer'],
      'explanation': attachedFromDb['explanation'],
      'subject': attachedFromDb['subject'],
      'difficulty': attachedFromDb['difficulty'],
      'is_public': 0,
      'bookmarked': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    // 驗證使用者 B 題庫中的匯入題目
    final importedRows = await db.query('questions', where: 'id = ?', whereArgs: [importedQuestionId]);
    expect(importedRows.length, 1);
    final imported = importedRows.first;
    expect(imported['user_id'], 'u2');
    expect(imported['text'], '何者不是 OOP 的特性？');
    expect(jsonDecode(imported['options'] as String)[3], '指標');
    expect(imported['answer'], '3');

    // 清理測試資料
    await db.delete('questions', where: 'id = ?', whereArgs: [questionId]);
    await db.delete('questions', where: 'id = ?', whereArgs: [importedQuestionId]);
    await db.delete('posts', where: 'id = ?', whereArgs: [postId]);
  });
}
