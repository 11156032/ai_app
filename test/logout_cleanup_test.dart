import 'dart:convert';
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

  test('Test Visitor Logout Data Cleanup', () async {
    final db = await DatabaseHelper.instance.database;

    // --- 1. 準備測試資料 ---
    // A. 為訪客 (u4) 新增資料庫關聯資料
    await db.insert('calendar_events', {
      'user_id': 'u4',
      'title': '訪客行程',
      'start_time': '2026-06-01 10:00:00',
      'end_time': '2026-06-01 11:00:00',
    });

    await db.insert('todos', {
      'user_id': 'u4',
      'text': '訪客待辦事項',
      'done': 0,
    });

    await db.insert('quiz_results', {
      'user_id': 'u4',
      'total': 10,
      'correct': 8,
      'duration_seconds': 300,
    });

    await db.insert('questions', {
      'user_id': 'u4',
      'text': '訪客題目？',
      'options': jsonEncode(['A', 'B', 'C', 'D']),
      'answer': '0',
    });

    // 建立訪客點讚另外一個非訪客帳戶發佈的貼文 (id: 1)
    await db.insert('post_likes', {
      'post_id': 1,
      'user_id': 'u4',
    });
    // 預先手動更新 likes = 1，測試登出時扣除點讚的重新計算功能
    await db.update('posts', {'likes': 1}, where: 'id = ?', whereArgs: [1]);

    // 建立訪客收藏與留言
    await db.insert('post_bookmarks', {
      'post_id': 1,
      'user_id': 'u4',
    });

    await db.insert('comments', {
      'post_id': 1,
      'user_id': 'u4',
      'text': '訪客留言',
    });

    // B. 修改訪客帳號的設定與基本資訊
    await db.update(
        'users',
        {
          'display_name': '自訂訪客暱稱',
          'bio': '訪客簡介內容',
          'theme_color_idx': 2,
          'is_dark_mode': 1,
        },
        where: 'id = ?',
        whereArgs: ['u4']);

    // C. 模擬記憶體快取變更
    NotesDatabase.notes.add(Note(
      id: 'custom_note_u4',
      userId: 'u4',
      title: '訪客筆記標題',
      content: '訪客筆記內容',
      category: '工作',
      strokes: [],
      updatedAt: DateTime.now(),
    ));
    NotesDatabase.categories.add('訪客新增分類');

    // --- 2. 驗證資料是否已正確寫入 ---
    final eventsBefore = await db
        .query('calendar_events', where: 'user_id = ?', whereArgs: ['u4']);
    expect(eventsBefore.length, 1);

    final todosBefore =
        await db.query('todos', where: 'user_id = ?', whereArgs: ['u4']);
    expect(todosBefore.length, 1);

    final quizBefore =
        await db.query('quiz_results', where: 'user_id = ?', whereArgs: ['u4']);
    expect(quizBefore.length, 1);

    final questionsBefore =
        await db.query('questions', where: 'user_id = ?', whereArgs: ['u4']);
    expect(questionsBefore.length, 1);

    final likesBefore =
        await db.query('post_likes', where: 'user_id = ?', whereArgs: ['u4']);
    expect(likesBefore.length, 1);

    final commentsBefore =
        await db.query('comments', where: 'user_id = ?', whereArgs: ['u4']);
    expect(commentsBefore.length, 1);

    final bookmarksBefore = await db
        .query('post_bookmarks', where: 'user_id = ?', whereArgs: ['u4']);
    expect(bookmarksBefore.length, 1);

    final userBefore =
        (await db.query('users', where: 'id = ?', whereArgs: ['u4'])).first;
    expect(userBefore['display_name'], '自訂訪客暱稱');
    expect(userBefore['is_dark_mode'], 1);

    expect(NotesDatabase.notes.any((n) => n.userId == 'u4'), isTrue);
    expect(NotesDatabase.categories.contains('訪客新增分類'), isTrue);

    // --- 3. 執行登出清除程序 ---
    await DatabaseHelper.instance.clearVisitorData();
    NotesDatabase.notes.removeWhere((note) => note.userId == 'u4');
    NotesDatabase.categories = ['全部', '未分類', '學習', '工作', '生活'];

    // --- 4. 驗證資料是否被徹底清除與重置 ---
    final eventsAfter = await db
        .query('calendar_events', where: 'user_id = ?', whereArgs: ['u4']);
    expect(eventsAfter, isEmpty);

    final todosAfter =
        await db.query('todos', where: 'user_id = ?', whereArgs: ['u4']);
    expect(todosAfter, isEmpty);

    final quizAfter =
        await db.query('quiz_results', where: 'user_id = ?', whereArgs: ['u4']);
    expect(quizAfter, isEmpty);

    final questionsAfter =
        await db.query('questions', where: 'user_id = ?', whereArgs: ['u4']);
    expect(questionsAfter, isEmpty);

    final likesAfter =
        await db.query('post_likes', where: 'user_id = ?', whereArgs: ['u4']);
    expect(likesAfter, isEmpty);

    final commentsAfter =
        await db.query('comments', where: 'user_id = ?', whereArgs: ['u4']);
    expect(commentsAfter, isEmpty);

    final bookmarksAfter = await db
        .query('post_bookmarks', where: 'user_id = ?', whereArgs: ['u4']);
    expect(bookmarksAfter, isEmpty);

    // 驗證被訪客點讚貼文 (id: 1) 的 likes 數是否已被重新計算降回 0
    final postOne =
        (await db.query('posts', where: 'id = ?', whereArgs: [1])).first;
    expect(postOne['likes'], 0);

    // 驗證訪客的帳號設定是否已被重置回預設值
    final userAfter =
        (await db.query('users', where: 'id = ?', whereArgs: ['u4'])).first;
    expect(userAfter['display_name'], '訪客');
    expect(userAfter['bio'], '');
    expect(userAfter['is_dark_mode'], 0);
    expect(userAfter['font_size_factor'], 1.2);

    // 驗證記憶體快取清除
    expect(NotesDatabase.notes.any((n) => n.userId == 'u4'), isFalse);
    expect(NotesDatabase.categories.contains('訪客新增分類'), isFalse);
    expect(NotesDatabase.categories.length, 5);

    await db.close();
  });
}
