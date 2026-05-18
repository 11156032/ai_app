import 'package:flutter/foundation.dart';
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

    _database = await _initDB('app_database.db', factory);
    return _database!;
  }

  Future<Database> _initDB(String filePath, DatabaseFactory factory) async {
    String path;
    if (kIsWeb) {
      path = filePath;
    } else {
      final dbPath = await factory.getDatabasesPath();
      path = join(dbPath, filePath);
    }

    return await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
      ),
    );
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

    // 4. Posts (Seed a real functional post, but no hardcoded test strings from Sharon)
    await db.insert('posts', {
      'id': 1,
      'user_id': 'u2',
      'content': '歡迎大家在社群分享學習心得與專題進度！',
      'likes': 5,
      'type': 'text',
      'created_at':
          DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    });

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
    });
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
    });
    await db.insert('questions', {
      'id': 6,
      'user_id': 'u2',
      'text':
          'Fresh and ------- apple-cider donuts are available at Oakcrest Orchard\'s retail shop for £6 per dozen.',
      'options': jsonEncode(['eaten', 'open', 'tasty', 'free']),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
    await db.insert('questions', {
      'id': 7,
      'user_id': 'u2',
      'text':
          'Zahn Flooring has the widest selection of ------- in the United Kingdom.',
      'options': jsonEncode(['paints', 'tiles', 'furniture', 'curtains']),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
    await db.insert('questions', {
      'id': 8,
      'user_id': 'u2',
      'text':
          'One responsibility of the IT department is to ensure that the company is using ------- software.',
      'options': jsonEncode(['update', 'updating', 'updates', 'updated']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
    await db.insert('questions', {
      'id': 9,
      'user_id': 'u2',
      'text':
          'It is wise to check a company\'s dress code ------- visiting its head office.',
      'options': jsonEncode(['so', 'how', 'like', 'before']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
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
    });
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
    });
    await db.insert('questions', {
      'id': 12,
      'user_id': 'u2',
      'text':
          'Registration for the Marketing Coalition Conference is now open ------- September 30.',
      'options': jsonEncode(['until', 'into', 'yet', 'while']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
    await db.insert('questions', {
      'id': 13,
      'user_id': 'u2',
      'text':
          'Growth in the home entertainment industry has been ------- this quarter.',
      'options': jsonEncode(['separate', 'limited', 'willing', 'assorted']),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
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
    });
    await db.insert('questions', {
      'id': 15,
      'user_id': 'u2',
      'text':
          'The Marlton City Council does not have the authority to ------- parking on city streets.',
      'options': jsonEncode(['drive', 'prohibit', 'bother', 'travel']),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
    await db.insert('questions', {
      'id': 16,
      'user_id': 'u2',
      'text':
          'Project Earth Group is ------- for ways to reduce transport-related greenhouse gas emissions.',
      'options': jsonEncode(['looking', 'seeing', 'driving', 'leaning']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
    await db.insert('questions', {
      'id': 17,
      'user_id': 'u2',
      'text':
          'Our skilled tailors are happy to design a custom-made suit that fits your style and budget -------.',
      'options': jsonEncode(['perfect', 'perfects', 'perfectly', 'perfection']),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
    await db.insert('questions', {
      'id': 18,
      'user_id': 'u2',
      'text':
          'Project manager Hannah Chung has proved to be very ------- with completing company projects.',
      'options': jsonEncode(['helpfulness', 'help', 'helpfully', 'helpful']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
    await db.insert('questions', {
      'id': 19,
      'user_id': 'u2',
      'text':
          'Lehua Vacation Club members will receive double points ------- the month of August at participating hotels.',
      'options': jsonEncode(['onto', 'above', 'during', 'between']),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
    await db.insert('questions', {
      'id': 20,
      'user_id': 'u2',
      'text':
          'The costumes were not received ------- enough to be used in the first dress rehearsal.',
      'options': jsonEncode(['far', 'very', 'almost', 'soon']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
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
    });
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
    });
    await db.insert('questions', {
      'id': 23,
      'user_id': 'u2',
      'text':
          'Airline representatives must handle a wide range of passenger issues, ------- missed connections to lost luggage.',
      'options': jsonEncode(['from', 'under', 'on', 'against']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
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
    });
    await db.insert('questions', {
      'id': 25,
      'user_id': 'u2',
      'text':
          'The current issue of Farming Scene magazine predicts that the price of corn will rise 5 percent over the ------- year.',
      'options': jsonEncode(['next', 'with', 'which', 'now']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
    await db.insert('questions', {
      'id': 26,
      'user_id': 'u2',
      'text':
          'Anyone who still ------- to take the fire safety training should do so before the end of the month.',
      'options': jsonEncode(['needing', 'needs', 'has needed', 'were needing']),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
    await db.insert('questions', {
      'id': 27,
      'user_id': 'u2',
      'text':
          'Emerging technologies have ------- begun to transform the shipping industry in ways that were once unimaginable.',
      'options': jsonEncode(['already', 'exactly', 'hardly', 'closely']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
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
    });
    await db.insert('questions', {
      'id': 29,
      'user_id': 'u2',
      'text':
          'Because ------- of the board members have scheduling conflicts, the board meeting will be moved to a date when all can attend.',
      'options': jsonEncode(['any', 'everybody', 'those', 'some']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
    await db.insert('questions', {
      'id': 30,
      'user_id': 'u2',
      'text':
          'The project ------- the collaboration of several teams across the company.',
      'options': jsonEncode(['passed', 'decided', 'required', 'performed']),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
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
    });
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
    });
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
    });

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
    });
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
    });
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
    });
    await db.insert('questions', {
      'id': 37,
      'user_id': 'u2',
      'text':
          'Part 6-134: Multiple benefits - Which pronoun should replace the blank?',
      'options': jsonEncode(['we', 'they', 'both', 'yours']),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
    await db.insert('questions', {
      'id': 38,
      'user_id': 'u2',
      'text':
          'Part 6-135: Amazing support - Which word form fits with gratitude for support?',
      'options': jsonEncode(['amazed', 'amazement', 'amazing', 'amazingly']),
      'answer': '2',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
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
    });
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
    });
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
    });
    await db.insert('questions', {
      'id': 42,
      'user_id': 'u2',
      'text': 'Part 6-139: Card renewal - What must be renewed?',
      'options': jsonEncode(['It', 'You', 'Our', 'Each']),
      'answer': '0',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
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
    });
    await db.insert('questions', {
      'id': 44,
      'user_id': 'u2',
      'text':
          'Part 6-141: Conditional statement - Which word best introduces the condition about closing an account?',
      'options': jsonEncode(['Also', 'Should', 'Because', 'Although']),
      'answer': '1',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
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
    });
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
    });
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
    });
    await db.insert('questions', {
      'id': 48,
      'user_id': 'u2',
      'text':
          'Part 6-145: Studio equipment advantages - Which transition word best connects the equipment benefits?',
      'options': jsonEncode(['If not', 'By comparison', 'Otherwise', 'Indeed']),
      'answer': '3',
      'subject': 'TOEIC',
      'bookmarked': 0
    });
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
    });

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
    });
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
    });
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
    });
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
    });

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
