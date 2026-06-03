import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  // 測試用的可覆寫路徑（可設為 ':memory:' 或臨時檔名）
  static String? _testDbPath;
  

  DatabaseHelper._init();
  
  /// 在測試中呼叫以指定 DB 路徑或使用 ':memory:'
  static void setTestDbPath(String? path) {
    _testDbPath = path;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;

    DatabaseFactory factory;
    if (kIsWeb) {
      // 在本機開發或未設定 COOP/COEP header 的伺服器上，必須停用 WebWorker 才能避免載入異常 (unsupported result null)
      factory = databaseFactoryFfiWebNoWebWorker;
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    } else {
      factory = databaseFactory; // default sqflite on android/ios
    }

    // Set global factory to be safe
    databaseFactory = factory;

    _database = await _initDB(_testDbPath ?? 'app_database.db', factory);
    return _database!;
  }

  Future<Database> _initDB(String filePath, DatabaseFactory factory) async {
    // 若有設定測試路徑，優先使用測試路徑（例如 ':memory:'）
    final effectiveFilePath = _testDbPath ?? filePath;
    String path;
    if (effectiveFilePath == ':memory:') {
      // SQLite in-memory database
      path = ':memory:';
    } else if (kIsWeb) {
      path = effectiveFilePath;
    } else {
      final dbPath = await factory.getDatabasesPath();
      path = join(dbPath, effectiveFilePath);
    }

    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 12,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
      ),
    );

    // 確保 is_edited 欄位存在，防止 onCreate 沒有建立此欄位
    try {
      var postCols = await db.rawQuery('PRAGMA table_info(posts)');
      if (!postCols.any((c) => c['name'] == 'is_edited')) {
        await db.execute(
            'ALTER TABLE posts ADD COLUMN is_edited INTEGER DEFAULT 0');
        debugPrint('Dynamic migration: Added is_edited column to posts table.');
      }
      
      var userCols = await db.rawQuery('PRAGMA table_info(users)');
      if (!userCols.any((c) => c['name'] == 'deleted_at')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN deleted_at DATETIME');
        debugPrint('Dynamic migration: Added deleted_at column to users table.');
      }
      
      if (!userCols.any((c) => c['name'] == 'gemini_api_key')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN gemini_api_key TEXT');
        debugPrint('Dynamic migration: Added gemini_api_key column to users table.');
      }

      if (!userCols.any((c) => c['name'] == 'is_google')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN is_google INTEGER DEFAULT 0');
        debugPrint('Dynamic migration: Added is_google column to users table.');
      }

      if (!userCols.any((c) => c['name'] == 'calendar_view_mode')) {
        await db.execute(
            "ALTER TABLE users ADD COLUMN calendar_view_mode TEXT DEFAULT 'dot'");
        debugPrint('Dynamic migration: Added calendar_view_mode column to users table.');
      }

      // 自我修復：如果原廠測試帳號被清空，自動重新導入 (以 Sharon 帳號 id = u1 為指標)
      final u1Check = await db.query('users', where: "id = 'u1'");
      if (u1Check.isEmpty) {
        debugPrint('Dynamic migration: Restoring original seed users and data (Sharon, etc.)...');
        await _seedDatabase(db);
      }
    } catch (e) {
      debugPrint('Error checking/adding dynamic columns or cleaning up: $e');
    }

    return db;
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Check for done_at in todos
      var columns = await db.rawQuery('PRAGMA table_info(todos)');
      bool columnExists = columns.any((column) => column['name'] == 'done_at');
      if (!columnExists) {
        await db.execute('ALTER TABLE todos ADD COLUMN done_at DATETIME');
      }
    }
    if (oldVersion < 3) {
      // Check for parent_id in comments
      var columns = await db.rawQuery('PRAGMA table_info(comments)');
      bool parentExists =
          columns.any((column) => column['name'] == 'parent_id');
      if (!parentExists) {
        await db.execute(
            'ALTER TABLE comments ADD COLUMN parent_id INTEGER DEFAULT 0');
      }
    }
    if (oldVersion < 4) {
      // Add media_blob to posts for reliable binary storage
      var columns = await db.rawQuery('PRAGMA table_info(posts)');
      bool blobExists = columns.any((column) => column['name'] == 'media_blob');
      if (!blobExists) {
        await db.execute('ALTER TABLE posts ADD COLUMN media_blob BLOB');
      }
    }
    if (oldVersion < 5) {
      // Add avatar columns to users
      var cols = await db.rawQuery('PRAGMA table_info(users)');
      bool hasBlob = cols.any((c) => c['name'] == 'avatar_blob');
      bool hasColor = cols.any((c) => c['name'] == 'avatar_color');
      if (!hasBlob) {
        await db.execute('ALTER TABLE users ADD COLUMN avatar_blob BLOB');
      }
      if (!hasColor) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN avatar_color INTEGER DEFAULT 0');
      }
    }
    if (oldVersion < 6) {
      // avatar_selected: 0=未選取(顯示預設人頭), 1=已明確選取
      var userCols = await db.rawQuery('PRAGMA table_info(users)');
      if (!userCols.any((c) => c['name'] == 'avatar_selected')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN avatar_selected INTEGER DEFAULT 0');
      }
      // is_edited: 0=未編輯, 1=已編輯後發佈
      var postCols = await db.rawQuery('PRAGMA table_info(posts)');
      if (!postCols.any((c) => c['name'] == 'is_edited')) {
        await db.execute(
            'ALTER TABLE posts ADD COLUMN is_edited INTEGER DEFAULT 0');
      }
    }
    if (oldVersion < 7) {
      var userCols = await db.rawQuery('PRAGMA table_info(users)');
      if (!userCols.any((c) => c['name'] == 'nickname_updated_at')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN nickname_updated_at DATETIME');
      }
      if (!userCols.any((c) => c['name'] == 'is_email_verified')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN is_email_verified INTEGER DEFAULT 0');
      }
    }
    if (oldVersion < 8) {
      var userCols = await db.rawQuery('PRAGMA table_info(users)');
      if (!userCols.any((c) => c['name'] == 'bio')) {
        await db.execute('ALTER TABLE users ADD COLUMN bio TEXT DEFAULT ""');
      }
      if (!userCols.any((c) => c['name'] == 'font_size_factor')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN font_size_factor REAL DEFAULT 1.0');
      }
      if (!userCols.any((c) => c['name'] == 'theme_color_idx')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN theme_color_idx INTEGER DEFAULT 0');
      }
      if (!userCols.any((c) => c['name'] == 'is_dark_mode')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN is_dark_mode INTEGER DEFAULT 0');
      }
    }
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE post_bookmarks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          post_id INTEGER NOT NULL,
          user_id VARCHAR NOT NULL,
          UNIQUE (post_id, user_id),
          FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 10) {
      await db.execute(
          "UPDATE users SET email = REPLACE(email, '@example.com', '@gmail.com') WHERE email LIKE '%@example.com'");
    }
    if (oldVersion < 11) {
      final questionCols = await db.rawQuery('PRAGMA table_info(questions)');
      if (!questionCols.any((c) => c['name'] == 'type')) {
        await db.execute(
            "ALTER TABLE questions ADD COLUMN type VARCHAR DEFAULT '單選題'");
      }
      var cols = await db.rawQuery('PRAGMA table_info(quiz_results)');
      if (!cols.any((c) => c['name'] == 'duration_seconds')) {
        await db.execute('ALTER TABLE quiz_results ADD COLUMN duration_seconds INTEGER DEFAULT 0');
      }
    }
    if (oldVersion < 12) {
      // Add user-defined papers and wrong question tracking
      await db.execute('''
        CREATE TABLE user_papers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id VARCHAR NOT NULL,
          name VARCHAR NOT NULL,
          question_ids TEXT NOT NULL DEFAULT '[]',
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE wrong_questions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id VARCHAR NOT NULL,
          question_id INTEGER NOT NULL,
          note TEXT DEFAULT '',
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
          FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
        )
      ''');

      var cols = await db.rawQuery('PRAGMA table_info(users)');
      if (!cols.any((c) => c['name'] == 'gemini_api_key')) {
        await db.execute('ALTER TABLE users ADD COLUMN gemini_api_key TEXT');
      }
      if (!cols.any((c) => c['name'] == 'is_google')) {
        await db.execute('ALTER TABLE users ADD COLUMN is_google INTEGER DEFAULT 0');
      }
    }
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
        avatar_blob BLOB,
        avatar_color INTEGER DEFAULT 0,
        avatar_selected INTEGER DEFAULT 0,
        nickname_updated_at DATETIME,
        is_email_verified INTEGER DEFAULT 0,
        font_size_factor REAL DEFAULT 1.0,
        theme_color_idx INTEGER DEFAULT 0,
        is_dark_mode INTEGER DEFAULT 0,
        gemini_api_key TEXT,
        is_google INTEGER DEFAULT 0,
        calendar_view_mode TEXT DEFAULT 'dot',
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
        type VARCHAR DEFAULT '單選題',
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
        done_at DATETIME,
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
        media_blob BLOB,
        likes INTEGER DEFAULT 0,
        is_edited INTEGER DEFAULT 0,
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
        parent_id INTEGER DEFAULT 0,
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
        duration_seconds INTEGER DEFAULT 0,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 12. post_bookmarks
    await db.execute('''
      CREATE TABLE post_bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        post_id INTEGER NOT NULL,
        user_id VARCHAR NOT NULL,
        UNIQUE (post_id, user_id),
        FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Indexes
    await db.execute(
        'CREATE INDEX idx_events_user_id ON calendar_events (user_id)');
    await db.execute(
        'CREATE INDEX idx_events_start_time ON calendar_events (start_time)');
    await db
        .execute('CREATE INDEX idx_questions_user_id ON questions (user_id)');
    await db
        .execute('CREATE INDEX idx_questions_subject ON questions (subject)');
    await db.execute(
        'CREATE INDEX idx_questions_difficulty ON questions (difficulty)');
    await db.execute('CREATE INDEX idx_notes_user_id ON notes (user_id)');
    await db.execute('CREATE INDEX idx_todos_user_id ON todos (user_id)');
    await db.execute('CREATE INDEX idx_posts_user_id ON posts (user_id)');
    await db.execute('CREATE INDEX idx_posts_type ON posts (type)');
    await db.execute('CREATE INDEX idx_comments_post_id ON comments (post_id)');

    await _seedDatabase(db);
  }

  // --- Paper helpers ---
  Future<int> createPaper(String userId, String name, List<int> questionIds) async {
    final db = await database;
    final data = {
      'user_id': userId,
      'name': name,
      'question_ids': jsonEncode(questionIds),
    };
    return await db.insert('user_papers', data);
  }

  Future<List<Map<String, dynamic>>> getPapersForUser(String userId) async {
    final db = await database;
    return await db.query('user_papers', where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getPaperById(int id) async {
    final db = await database;
    final rows = await db.query('user_papers', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<int>> getQuestionIdsForPaper(int paperId) async {
    final row = await getPaperById(paperId);
    if (row == null) return [];
    final raw = row['question_ids']?.toString() ?? '[]';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.map((e) => int.tryParse(e.toString()) ?? 0).where((v) => v > 0).toList();
    } catch (_) {}
    return [];
  }

  Future<int> deletePaper(int id) async {
    final db = await database;
    return await db.delete('user_papers', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updatePaper(int id, String name, List<int> questionIds) async {
    final db = await database;
    return await db.update('user_papers', {
      'name': name,
      'question_ids': jsonEncode(questionIds),
      'created_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  // --- Wrong question helpers ---
  Future<int> addWrongQuestion(String userId, int questionId, {String note = ''}) async {
    final db = await database;
    return await db.insert('wrong_questions', {
      'user_id': userId,
      'question_id': questionId,
      'note': note,
    });
  }

  Future<List<Map<String, dynamic>>> getWrongQuestions(String userId) async {
    final db = await database;
    return await db.query('wrong_questions', where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
  }

  Future<int> deleteWrongQuestionByRecordId(int recordId) async {
    final db = await database;
    return await db.delete('wrong_questions', where: 'id = ?', whereArgs: [recordId]);
  }

  Future<int> deleteWrongQuestionsBulk(List<int> recordIds) async {
    if (recordIds.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(recordIds.length, '?').join(',');
    return await db.delete('wrong_questions', where: 'id IN ($placeholders)', whereArgs: recordIds);
  }

  Future<int> createNote(String userId, String title, String content) async {
    final db = await database;
    return await db.insert('notes', {
      'user_id': userId,
      'title': title,
      'content': content,
    });
  }

  Future<void> _seedDatabase(Database db) async {
    // 1. Users
    await db.insert('users', {
      'id': 'u1',
      'username': 'Sharon',
      'email': 'sharon@gmail.com',
      'hashed_password': 'mock_password',
      'display_name': 'Sharon',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('users', {
      'id': 'u2',
      'username': '陳教授',
      'email': 'prof@gmail.com',
      'hashed_password': 'mock_password',
      'display_name': '陳教授',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('users', {
      'id': 'u3',
      'username': '系統',
      'email': 'sys@gmail.com',
      'hashed_password': 'mock_password',
      'display_name': '系統',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('users', {
      'id': 'u4',
      'username': '訪客',
      'email': 'guest@gmail.com',
      'hashed_password': 'mock_password',
      'display_name': '訪客',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('users', {
      'id': 'u5',
      'username': '李同學',
      'email': 'lee@gmail.com',
      'hashed_password': 'mock_password',
      'display_name': '李同學',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('users', {
      'id': 'u6',
      'username': '陳助教',
      'email': 'ta@gmail.com',
      'hashed_password': 'mock_password',
      'display_name': '陳助教',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 2. Calendar Event
    await db.insert('calendar_events', {
      'user_id': 'u1',
      'title': '專題討論會議',
      'start_time': '2026-03-30 09:10:00',
      'end_time': '2026-03-30 12:00:00',
      'color': '0xFFFFE082',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 3. Todo
    await db.insert('todos', {
      'user_id': 'u1',
      'text': '確認 AutoCAD 圓角圖層',
      'done': 0,
      'created_at': '2026-03-30 00:00:00',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 4. Posts (Seed a real functional post, but no hardcoded test strings from Sharon)
    await db.insert('posts', {
      'id': 1,
      'user_id': 'u2',
      'content': '歡迎大家在社群分享學習心得與專題進度！',
      'likes': 5,
      'type': 'text',
      'created_at':
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 5. Questions
    await db.insert('questions', {
      'id': 1,
      'user_id': 'u2',
      'text': '下列何者不是關聯式資料庫的特性？',
      'options':
          jsonEncode(['支援 SQL 語法', '具備 ACID 特性', '採用樹狀結構存放', '資料以二維表格呈現']),
      'answer': '2',
      'explanation': '樹狀結構屬於階層式資料庫，而非關聯式。',
      'subject': '資訊管理',
      'difficulty': '中',
      'bookmarked': 1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

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
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

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
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 6. Tags map (for chapter matching in old logic)
    await db.insert('tags', {'id': 1, 'name': '第二章 資料庫管理'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('tags', {'id': 2, 'name': '師說'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('tags', {'id': 3, 'name': '面積'}, conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('question_tag_map', {'question_id': 1, 'tag_id': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('question_tag_map', {'question_id': 2, 'tag_id': 2}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('question_tag_map', {'question_id': 3, 'tag_id': 3}, conflictAlgorithm: ConflictAlgorithm.ignore);

    // TOEIC 題庫 (101-250: Part 5-7 試題)
    // Part 5: 101-130
    await db.insert('questions', {
      'id': 4,
      'user_id': 'u2',
      'text':
          'Former Sendai Company CEO Ken Nakata spoke about ------- career experiences.',
      'options': jsonEncode(['he', 'his', 'him', 'himself']),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 5,
      'user_id': 'u2',
      'text':
          'Passengers who will be taking a ------ domestic flight should go to Terminal A.',
      'options':
          jsonEncode(['connectivity', 'connects', 'connect', 'connecting']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 6,
      'user_id': 'u2',
      'text':
          'Fresh and ------- apple-cider donuts are available at Oakcrest Orchard\'s retail shop for £6 per dozen.',
      'options': jsonEncode(['eaten', 'open', 'tasty', 'free']),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 7,
      'user_id': 'u2',
      'text':
          'Zahn Flooring has the widest selection of ------- in the United Kingdom.',
      'options': jsonEncode(['paints', 'tiles', 'furniture', 'curtains']),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 8,
      'user_id': 'u2',
      'text':
          'One responsibility of the IT department is to ensure that the company is using ------- software.',
      'options': jsonEncode(['update', 'updating', 'updates', 'updated']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 9,
      'user_id': 'u2',
      'text':
          'It is wise to check a company\'s dress code ------- visiting its head office.',
      'options': jsonEncode(['so', 'how', 'like', 'before']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 10,
      'user_id': 'u2',
      'text':
          'Wexler Store\'s management team expects that employees will ------- support any new hires.',
      'options': jsonEncode(
          ['enthusiastically', 'enthusiasm', 'enthusiastic', 'enthused']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 11,
      'user_id': 'u2',
      'text':
          'Wheel alignments and brake system ------- are part of our vehicle service plan.',
      'options':
          jsonEncode(['inspects', 'inspector', 'inspected', 'inspections']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 12,
      'user_id': 'u2',
      'text':
          'Registration for the Marketing Coalition Conference is now open ------- September 30.',
      'options': jsonEncode(['until', 'into', 'yet', 'while']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 13,
      'user_id': 'u2',
      'text':
          'Growth in the home entertainment industry has been ------- this quarter.',
      'options': jsonEncode(['separate', 'limited', 'willing', 'assorted']),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 14,
      'user_id': 'u2',
      'text':
          'Hawson Furniture will be making ------- on the east side of town on Thursday.',
      'options':
          jsonEncode(['deliveries', 'delivered', 'deliver', 'deliverable']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 15,
      'user_id': 'u2',
      'text':
          'The Marlton City Council does not have the authority to ------- parking on city streets.',
      'options': jsonEncode(['drive', 'prohibit', 'bother', 'travel']),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 16,
      'user_id': 'u2',
      'text':
          'Project Earth Group is ------- for ways to reduce transport-related greenhouse gas emissions.',
      'options': jsonEncode(['looking', 'seeing', 'driving', 'leaning']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 17,
      'user_id': 'u2',
      'text':
          'Our skilled tailors are happy to design a custom-made suit that fits your style and budget -------.',
      'options': jsonEncode(['perfect', 'perfects', 'perfectly', 'perfection']),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 18,
      'user_id': 'u2',
      'text':
          'Project manager Hannah Chung has proved to be very ------- with completing company projects.',
      'options': jsonEncode(['helpfulness', 'help', 'helpfully', 'helpful']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 19,
      'user_id': 'u2',
      'text':
          'Lehua Vacation Club members will receive double points ------- the month of August at participating hotels.',
      'options': jsonEncode(['onto', 'above', 'during', 'between']),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 20,
      'user_id': 'u2',
      'text':
          'The costumes were not received ------- enough to be used in the first dress rehearsal.',
      'options': jsonEncode(['far', 'very', 'almost', 'soon']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 21,
      'user_id': 'u2',
      'text':
          'As a former publicist for several renowned orchestras, Mr. Wu would excel in the role of event -------.',
      'options':
          jsonEncode(['organized', 'organizer', 'organizes', 'organizational']),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 22,
      'user_id': 'u2',
      'text':
          'The northbound lane on Davis Street will be ------- closed because of the city\'s bridge reinforcement project.',
      'options': jsonEncode(
          ['temporarily', 'competitively', 'recently', 'collectively']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 23,
      'user_id': 'u2',
      'text':
          'Airline representatives must handle a wide range of passenger issues, ------- missed connections to lost luggage.',
      'options': jsonEncode(['from', 'under', 'on', 'against']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 24,
      'user_id': 'u2',
      'text':
          'The meeting notes were ------- deleted, but Mr. Hahm was able to recreate them from memory.',
      'options':
          jsonEncode(['accident', 'accidental', 'accidents', 'accidentally']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 25,
      'user_id': 'u2',
      'text':
          'The current issue of Farming Scene magazine predicts that the price of corn will rise 5 percent over the ------- year.',
      'options': jsonEncode(['next', 'with', 'which', 'now']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 26,
      'user_id': 'u2',
      'text':
          'Anyone who still ------- to take the fire safety training should do so before the end of the month.',
      'options': jsonEncode(['needing', 'needs', 'has needed', 'were needing']),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 27,
      'user_id': 'u2',
      'text':
          'Emerging technologies have ------- begun to transform the shipping industry in ways that were once unimaginable.',
      'options': jsonEncode(['already', 'exactly', 'hardly', 'closely']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 28,
      'user_id': 'u2',
      'text':
          'The company handbook outlines the high ------- that employees are expected to meet every day.',
      'options':
          jsonEncode(['experts', 'accounts', 'recommendations', 'standards']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 29,
      'user_id': 'u2',
      'text':
          'Because ------- of the board members have scheduling conflicts, the board meeting will be moved to a date when all can attend.',
      'options': jsonEncode(['any', 'everybody', 'those', 'some']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 30,
      'user_id': 'u2',
      'text':
          'The project ------- the collaboration of several teams across the company.',
      'options': jsonEncode(['passed', 'decided', 'required', 'performed']),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 31,
      'user_id': 'u2',
      'text':
          'We cannot send the store\'s coupon booklet to the printers until it ------- by Ms. Jeon.',
      'options': jsonEncode([
        'is approving',
        'approves',
        'has been approved',
        'will be approved'
      ]),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 32,
      'user_id': 'u2',
      'text':
          '------- the closure of Verdigold Transport Services, we are looking for a new shipping company.',
      'options':
          jsonEncode(['In spite of', 'Just as', 'In light of', 'According to']),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 33,
      'user_id': 'u2',
      'text':
          'The ------- information provided by Uniss Bank\'s brochure helps applicants understand the terms of their loans.',
      'options':
          jsonEncode(['arbitrary', 'supplemental', 'superfluous', 'potential']),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Part 6: 131-146
    await db.insert('questions', {
      'id': 34,
      'user_id': 'u2',
      'text':
          'Part 6-131: Rain garden definition - Which phrase best fits the blank about what a rain garden is?',
      'options': jsonEncode([
        'with a special soil mix to filter pollutants',
        'that requires professional landscaping',
        'made of concrete and stones',
        'located near residential areas'
      ]),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 35,
      'user_id': 'u2',
      'text':
          'Part 6-132: Rainwater filtering - The text discusses filtering pollutants from what?',
      'options': jsonEncode([
        'to use rainwater',
        'used to collect water',
        'by using natural filters',
        'that uses sustainable methods'
      ]),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 36,
      'user_id': 'u2',
      'text':
          'Part 6-133: Rain garden benefits - Which transition best introduces the benefits of rain gardens?',
      'options': jsonEncode([
        'Best of all',
        'For example',
        'In any event',
        'As a matter of fact'
      ]),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 37,
      'user_id': 'u2',
      'text':
          'Part 6-134: Multiple benefits - Which pronoun should replace the blank?',
      'options': jsonEncode(['we', 'they', 'both', 'yours']),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 38,
      'user_id': 'u2',
      'text':
          'Part 6-135: Amazing support - Which word form fits with gratitude for support?',
      'options': jsonEncode(['amazed', 'amazement', 'amazing', 'amazingly']),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 39,
      'user_id': 'u2',
      'text':
          'Part 6-136: Social media response - What did the designs receive on social media?',
      'options':
          jsonEncode(['attention', 'proposals', 'innovation', 'criticism']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 40,
      'user_id': 'u2',
      'text':
          'Part 6-137: Acknowledgment of efforts - Which sentence best fits as an appreciation statement?',
      'options': jsonEncode([
        'Several other events have gone surprisingly well.',
        'Thank you also for your flexibility in planning the event.',
        'Please stop by our office the next time you are in the city.',
        'Tokyo is a top tourism destination for many reasons.'
      ]),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 41,
      'user_id': 'u2',
      'text':
          'Part 6-138: Award program - Which verb form fits with the upcoming auction?',
      'options': jsonEncode(
          ['will benefit', 'to benefit', 'has benefited', 'benefits']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 42,
      'user_id': 'u2',
      'text': 'Part 6-139: Card renewal - What must be renewed?',
      'options': jsonEncode(['It', 'You', 'Our', 'Each']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 43,
      'user_id': 'u2',
      'text':
          'Part 6-140: Library renewal information - Which sentence provides additional helpful information?',
      'options': jsonEncode([
        'To sign up for a card, visit your local library branch.',
        'For questions about library membership, please visit our Web site.',
        'Renewal must be completed at least one week before your card expires.',
        'You may opt out of this program at any time.'
      ]),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 44,
      'user_id': 'u2',
      'text':
          'Part 6-141: Conditional statement - Which word best introduces the condition about closing an account?',
      'options': jsonEncode(['Also', 'Should', 'Because', 'Although']),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 45,
      'user_id': 'u2',
      'text':
          'Part 6-142: Renewal deadline - Which word form means "exactly stated or determined"?',
      'options':
          jsonEncode(['specifically', 'specifics', 'specified', 'specificity']),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 46,
      'user_id': 'u2',
      'text':
          'Part 6-143: Photography introduction - Which sentence best introduces Droplight Studio?',
      'options': jsonEncode([
        'I would like to introduce you to our business.',
        'Great photographs can make your property stand out.',
        'We are looking forward to your visit.',
        'It was the first studio of its kind to open in this area.'
      ]),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 47,
      'user_id': 'u2',
      'text':
          'Part 6-144: Image creation - What does Droplight Studio do when creating images?',
      'options':
          jsonEncode(['researching', 'creating', 'purchasing', 'displaying']),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 48,
      'user_id': 'u2',
      'text':
          'Part 6-145: Studio equipment advantages - Which transition word best connects the equipment benefits?',
      'options': jsonEncode(['If not', 'By comparison', 'Otherwise', 'Indeed']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 49,
      'user_id': 'u2',
      'text':
          'Part 6-146: Image editing - What happens to every image after the photo shoot?',
      'options': jsonEncode(
          ['receives', 'is receiving', 'had received', 'had to receive']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Part 7: 147-150
    await db.insert('questions', {
      'id': 50,
      'user_id': 'u2',
      'text':
          'Part 7-147: Where is the information about assembly most likely found?',
      'options': jsonEncode(
          ['On a door', 'On a receipt', 'In a box', 'On a Web site']),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 51,
      'user_id': 'u2',
      'text':
          'Part 7-148: What kind of item is most likely discussed in the assembly instructions?',
      'options': jsonEncode([
        'A desktop computer',
        'A piece of furniture',
        'A household appliance',
        'A power tool'
      ]),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 52,
      'user_id': 'u2',
      'text':
          'Part 7-149: What is suggested by the Winnipeg-Toulouse schedule?',
      'options': jsonEncode([
        'A conference has been scheduled.',
        'A firm has offices in two time zones.',
        'Administrative assistants make travel plans.',
        'Some meeting times have been changed.'
      ]),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', {
      'id': 53,
      'user_id': 'u2',
      'text': 'Part 7-150: What is indicated about 11:00 A.M. Winnipeg time?',
      'options': jsonEncode([
        'It is when the Winnipeg office closes for lunch.',
        'It is when staff in Toulouse begin their workday.',
        'It is not a preferred time to schedule a meeting.',
        'It has just been added to the schedule.'
      ]),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 7. Simulated wrong question records in quiz_results to match ui state isWrong: true
    await db.insert('quiz_results', {
      'user_id': 'u1',
      'total': 10,
      'correct': 8,
      'wrong_question_ids': jsonEncode([1, 3]),
      'duration_seconds': 720,
      'timestamp': '2026-05-25 14:30:00'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('quiz_results', {
      'user_id': 'u1',
      'total': 15,
      'correct': 13,
      'wrong_question_ids': jsonEncode([2]),
      'duration_seconds': 1200,
      'timestamp': '2026-05-26 16:00:00'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 8. 排行榜種子資料：u2 陳教授
    await db.insert('quiz_results', {
      'user_id': 'u2',
      'total': 20,
      'correct': 20,
      'wrong_question_ids': jsonEncode([]),
      'duration_seconds': 900,
      'timestamp': '2026-05-24 09:00:00'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('quiz_results', {
      'user_id': 'u2',
      'total': 25,
      'correct': 24,
      'wrong_question_ids': jsonEncode([5]),
      'duration_seconds': 1100,
      'timestamp': '2026-05-26 10:30:00'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('quiz_results', {
      'user_id': 'u2',
      'total': 15,
      'correct': 15,
      'wrong_question_ids': jsonEncode([]),
      'duration_seconds': 600,
      'timestamp': '2026-05-27 08:00:00'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 9. 排行榜種子資料：u5 李同學
    await db.insert('quiz_results', {
      'user_id': 'u5',
      'total': 12,
      'correct': 9,
      'wrong_question_ids': jsonEncode([4, 7, 10]),
      'duration_seconds': 800,
      'timestamp': '2026-05-23 15:00:00'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('quiz_results', {
      'user_id': 'u5',
      'total': 18,
      'correct': 14,
      'wrong_question_ids': jsonEncode([2, 6, 8, 11]),
      'duration_seconds': 1300,
      'timestamp': '2026-05-25 11:00:00'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('quiz_results', {
      'user_id': 'u5',
      'total': 10,
      'correct': 8,
      'wrong_question_ids': jsonEncode([3, 9]),
      'duration_seconds': 700,
      'timestamp': '2026-05-27 14:00:00'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // 10. 排行榜種子資料：u6 陳助教
    await db.insert('quiz_results', {
      'user_id': 'u6',
      'total': 30,
      'correct': 27,
      'wrong_question_ids': jsonEncode([1, 4, 12]),
      'duration_seconds': 1500,
      'timestamp': '2026-05-22 10:00:00'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('quiz_results', {
      'user_id': 'u6',
      'total': 20,
      'correct': 19,
      'wrong_question_ids': jsonEncode([8]),
      'duration_seconds': 950,
      'timestamp': '2026-05-24 16:00:00'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('quiz_results', {
      'user_id': 'u6',
      'total': 25,
      'correct': 22,
      'wrong_question_ids': jsonEncode([2, 6, 13]),
      'duration_seconds': 1200,
      'timestamp': '2026-05-27 09:30:00'
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> clearVisitorData() async {
    final db = await database;
    // 1. 刪除所有與訪客 (u4) 關聯的資料庫表資料
    await db.delete('calendar_events', where: 'user_id = ?', whereArgs: ['u4']);
    await db.delete('todos', where: 'user_id = ?', whereArgs: ['u4']);
    await db.delete('quiz_results', where: 'user_id = ?', whereArgs: ['u4']);
    await db.delete('questions', where: 'user_id = ?', whereArgs: ['u4']);
    await db.delete('notes', where: 'user_id = ?', whereArgs: ['u4']);
    await db.delete('posts', where: 'user_id = ?', whereArgs: ['u4']);
    await db.delete('post_likes', where: 'user_id = ?', whereArgs: ['u4']);
    await db.delete('post_bookmarks', where: 'user_id = ?', whereArgs: ['u4']);
    await db.delete('comments', where: 'user_id = ?', whereArgs: ['u4']);

    // 2. 重新計算所有貼文的 likes 數量（扣除訪客點讚）
    await db.execute(
        'UPDATE posts SET likes = (SELECT COUNT(*) FROM post_likes WHERE post_likes.post_id = posts.id)');

    // 3. 重置訪客帳號的設定與基本資訊
    await db.update('users', {
      'username': '訪客',
      'email': 'guest@gmail.com',
      'hashed_password': 'mock_password',
      'display_name': '訪客',
      'bio': '',
      'tags': '[]',
      'avatar_blob': null,
      'avatar_color': 0,
      'avatar_selected': 0,
      'nickname_updated_at': null,
      'is_email_verified': 0,
      'font_size_factor': 1.0,
      'theme_color_idx': 0,
      'is_dark_mode': 0,
      'gemini_api_key': null,
      'is_google': 0,
    }, where: 'id = ?', whereArgs: ['u4']);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
