import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    _database = await _initDB('app_database.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String path;
    if (kIsWeb) {
      path = filePath;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    // 1. users
    await db.execute('''
      CREATE TABLE users (
        id VARCHAR PRIMARY KEY,
        username VARCHAR NOT NULL UNIQUE,
        email VARCHAR NOT NULL UNIQUE,
        hashed_password TEXT NOT NULL,
        display_name VARCHAR DEFAULT '',
        bio TEXT DEFAULT '',
        tags TEXT DEFAULT '[]',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 2. calendar_events
    await db.execute('''
      CREATE TABLE calendar_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id VARCHAR NOT NULL,
        title VARCHAR NOT NULL,
        description TEXT DEFAULT '',
        is_all_day BOOLEAN DEFAULT 0,
        start_time DATETIME NOT NULL,
        end_time DATETIME NOT NULL,
        location VARCHAR DEFAULT '',
        color VARCHAR DEFAULT 'bg-blue-400',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 3. tags
    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name VARCHAR NOT NULL UNIQUE
      )
    ''');

    // 4. questions
    await db.execute('''
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id VARCHAR NOT NULL,
        text TEXT NOT NULL,
        options TEXT NOT NULL,
        answer VARCHAR NOT NULL,
        explanation TEXT DEFAULT '',
        subject VARCHAR DEFAULT '',
        difficulty VARCHAR DEFAULT 'easy',
        is_public BOOLEAN DEFAULT 0,
        bookmarked BOOLEAN DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 5. question_tag_map
    await db.execute('''
      CREATE TABLE question_tag_map (
        question_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (question_id, tag_id),
        FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
      )
    ''');

    // 6. notes
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id VARCHAR NOT NULL,
        title VARCHAR NOT NULL,
        content TEXT DEFAULT '',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 7. todos
    await db.execute('''
      CREATE TABLE todos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id VARCHAR NOT NULL,
        text TEXT NOT NULL,
        done BOOLEAN DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 8. posts
    await db.execute('''
      CREATE TABLE posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id VARCHAR NOT NULL,
        content TEXT NOT NULL,
        type VARCHAR DEFAULT 'text',
        attached_data TEXT DEFAULT '{}',
        likes INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 9. post_likes
    await db.execute('''
      CREATE TABLE post_likes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        post_id INTEGER NOT NULL,
        user_id VARCHAR NOT NULL,
        UNIQUE (post_id, user_id),
        FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 10. comments
    await db.execute('''
      CREATE TABLE comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        post_id INTEGER NOT NULL,
        user_id VARCHAR NOT NULL,
        text TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 11. quiz_results
    await db.execute('''
      CREATE TABLE quiz_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id VARCHAR NOT NULL,
        total INTEGER NOT NULL,
        correct INTEGER NOT NULL,
        wrong_question_ids TEXT DEFAULT '[]',
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_events_user_id ON calendar_events (user_id)');
    await db.execute('CREATE INDEX idx_events_start_time ON calendar_events (start_time)');
    await db.execute('CREATE INDEX idx_questions_user_id ON questions (user_id)');
    await db.execute('CREATE INDEX idx_questions_subject ON questions (subject)');
    await db.execute('CREATE INDEX idx_questions_difficulty ON questions (difficulty)');
    await db.execute('CREATE INDEX idx_notes_user_id ON notes (user_id)');
    await db.execute('CREATE INDEX idx_todos_user_id ON todos (user_id)');
    await db.execute('CREATE INDEX idx_posts_user_id ON posts (user_id)');
    await db.execute('CREATE INDEX idx_posts_type ON posts (type)');
    await db.execute('CREATE INDEX idx_comments_post_id ON comments (post_id)');

    await _seedDatabase(db);
  }

  Future<void> _seedDatabase(Database db) async {
    // 1. Users
    await db.insert('users', {
      'id': 'u1',
      'username': 'Sharon',
      'email': 'sharon@example.com',
      'hashed_password': 'mock_password',
      'display_name': 'Sharon',
    });
    await db.insert('users', {
      'id': 'u2',
      'username': '陳教授',
      'email': 'prof@example.com',
      'hashed_password': 'mock_password',
      'display_name': '陳教授',
    });
    await db.insert('users', {
      'id': 'u3',
      'username': '系統',
      'email': 'sys@example.com',
      'hashed_password': 'mock_password',
      'display_name': '系統',
    });
    await db.insert('users', {
      'id': 'u4',
      'username': '訪客',
      'email': 'guest@example.com',
      'hashed_password': 'mock_password',
      'display_name': '訪客',
    });
    
    await db.insert('users', {
      'id': 'u5',
      'username': '李同學',
      'email': 'lee@example.com',
      'hashed_password': 'mock_password',
      'display_name': '李同學',
    });
    
    await db.insert('users', {
      'id': 'u6',
      'username': '陳助教',
      'email': 'ta@example.com',
      'hashed_password': 'mock_password',
      'display_name': '陳助教',
    });

    // 2. Calendar Event
    await db.insert('calendar_events', {
      'user_id': 'u1',
      'title': '專題討論會議',
      'start_time': '2026-03-30 09:10:00',
      'end_time': '2026-03-30 12:00:00',
      'color': '0xFFFFE082',
    });

    // 3. Todo
    await db.insert('todos', {
      'user_id': 'u1',
      'text': '確認 AutoCAD 圓角圖層',
      'done': 0,
      'created_at': '2026-03-30 00:00:00',
    });

    // 4. Posts
    await db.insert('posts', {
      'id': 1,
      'user_id': 'u1',
      'content': '準備來寫 Flutter 專題啦🚀',
      'likes': 12,
      'type': 'text',
      'created_at': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
    });
    await db.insert('post_likes', {'post_id': 1, 'user_id': 'u1'});
    await db.insert('comments', {'post_id': 1, 'user_id': 'u5', 'text': '加油！推一個', 'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()});
    await db.insert('comments', {'post_id': 1, 'user_id': 'u6', 'text': '排序逻辑我发系上群組囉', 'created_at': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String()});

    // 5. Questions
    await db.insert('questions', {
      'id': 1,
      'user_id': 'u2',
      'text': '下列何者不是關聯式資料庫的特性？',
      'options': jsonEncode(['支援 SQL 語法', '具備 ACID 特性', '採用樹狀結構存放', '資料以二維表格呈現']),
      'answer': '2',
      'explanation': '樹狀結構屬於階層式資料庫，而非關聯式。',
      'subject': '資訊管理',
      'difficulty': '中',
      'bookmarked': 1,
    });
    
    await db.insert('questions', {
      'id': 2,
      'user_id': 'u1',
      'text': '《師說》的作者是誰？',
      'options': jsonEncode(['柳宗元', '韓愈', '歐陽脩', '蘇軾']),
      'answer': '1',
      'explanation': '韓愈倡導古文運動，作《師說》。',
      'subject': '國文',
      'difficulty': '易',
      'bookmarked': 0,
    });
    
    await db.insert('questions', {
      'id': 3,
      'user_id': 'u3',
      'text': '長方形長5寬4，面積為何？',
      'options': jsonEncode(['18', '20', '25', '9']),
      'answer': '1',
      'explanation': '5x4=20',
      'subject': '數學',
      'difficulty': '易',
      'bookmarked': 0,
    });

    // 6. Tags map (for chapter matching in old logic)
    await db.insert('tags', {'id': 1, 'name': '第二章 資料庫管理'});
    await db.insert('tags', {'id': 2, 'name': '師說'});
    await db.insert('tags', {'id': 3, 'name': '面積'});
    
    await db.insert('question_tag_map', {'question_id': 1, 'tag_id': 1});
    await db.insert('question_tag_map', {'question_id': 2, 'tag_id': 2});
    await db.insert('question_tag_map', {'question_id': 3, 'tag_id': 3});

    // 7. Simulated wrong question records in quiz_results to match ui state isWrong: true
    await db.insert('quiz_results', {
      'user_id': 'u1',
      'total': 10,
      'correct': 8,
      'wrong_question_ids': jsonEncode([1, 3]),
      'timestamp': '2026-03-30 10:00:00'
    });
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
