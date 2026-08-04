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
        version: 17,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
      ),
    );

    // 確保 is_edited 欄位存在，防止 onCreate 沒有建立此欄位
    try {
      // 確保 user_papers 與 wrong_questions 資料表存在 (防禦性建立，防止 migration 未執行)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_papers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id VARCHAR NOT NULL,
          name VARCHAR NOT NULL,
          question_ids TEXT NOT NULL DEFAULT '[]',
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS wrong_questions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id VARCHAR NOT NULL,
          question_id INTEGER NOT NULL,
          note TEXT DEFAULT '',
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
          FOREIGN KEY (question_id) REFERENCES questions (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS diaries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id VARCHAR NOT NULL,
          date TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');

      var postCols = await db.rawQuery('PRAGMA table_info(posts)');
      if (!postCols.any((c) => c['name'] == 'is_edited')) {
        await db.execute(
            'ALTER TABLE posts ADD COLUMN is_edited INTEGER DEFAULT 0');
        debugPrint('Dynamic migration: Added is_edited column to posts table.');
      }
      if (!postCols.any((c) => c['name'] == 'group_id')) {
        await db.execute('ALTER TABLE posts ADD COLUMN group_id INTEGER');
        debugPrint('Dynamic migration: Added group_id column to posts table.');
      }
      if (!postCols.any((c) => c['name'] == 'file_blob')) {
        await db.execute('ALTER TABLE posts ADD COLUMN file_blob BLOB');
        debugPrint('Dynamic migration: Added file_blob column to posts table.');
      }

      var quizCols = await db.rawQuery('PRAGMA table_info(quiz_results)');
      if (!quizCols.any((c) => c['name'] == 'subject')) {
        await db.execute("ALTER TABLE quiz_results ADD COLUMN subject TEXT DEFAULT ''");
        debugPrint('Dynamic migration: Added subject column to quiz_results table.');
      }
      if (!quizCols.any((c) => c['name'] == 'paper_id')) {
        await db.execute('ALTER TABLE quiz_results ADD COLUMN paper_id INTEGER DEFAULT NULL');
        debugPrint('Dynamic migration: Added paper_id column to quiz_results table.');
      }

      // 社群群組相關資料表（防禦性建立）
      await db.execute('''
        CREATE TABLE IF NOT EXISTS community_groups (
          id               INTEGER PRIMARY KEY AUTOINCREMENT,
          name             TEXT    NOT NULL,
          description      TEXT    DEFAULT '',
          icon_emoji       TEXT    DEFAULT '📚',
          type             TEXT    NOT NULL DEFAULT 'public',
          owner_id         TEXT    NOT NULL,
          tags             TEXT    DEFAULT '[]',
          member_count     INTEGER DEFAULT 1,
          invite_token     TEXT,
          token_expires_at DATETIME,
          invite_link_active INTEGER DEFAULT 1,
          created_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS group_members (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          group_id     INTEGER NOT NULL,
          user_id      TEXT    NOT NULL,
          role         TEXT    DEFAULT 'member',
          status       TEXT    DEFAULT 'active',
          joined_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
          last_read_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          is_muted     INTEGER DEFAULT 0,
          FOREIGN KEY (group_id) REFERENCES community_groups(id) ON DELETE CASCADE,
          FOREIGN KEY (user_id)  REFERENCES users(id) ON DELETE CASCADE,
          UNIQUE (group_id, user_id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS group_announcements (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          group_id   INTEGER NOT NULL,
          author_id  TEXT    NOT NULL,
          content    TEXT    NOT NULL,
          is_pinned  INTEGER DEFAULT 0,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (group_id) REFERENCES community_groups(id) ON DELETE CASCADE
        )
      ''');

      var userCols = await db.rawQuery('PRAGMA table_info(users)');
      if (!userCols.any((c) => c['name'] == 'deleted_at')) {
        await db.execute('ALTER TABLE users ADD COLUMN deleted_at DATETIME');
        debugPrint(
            'Dynamic migration: Added deleted_at column to users table.');
      }

      if (!userCols.any((c) => c['name'] == 'gemini_api_key')) {
        await db.execute('ALTER TABLE users ADD COLUMN gemini_api_key TEXT');
        debugPrint(
            'Dynamic migration: Added gemini_api_key column to users table.');
      }

      if (!userCols.any((c) => c['name'] == 'is_google')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN is_google INTEGER DEFAULT 0');
        debugPrint('Dynamic migration: Added is_google column to users table.');
      }

      if (!userCols.any((c) => c['name'] == 'calendar_view_mode')) {
        await db.execute(
            "ALTER TABLE users ADD COLUMN calendar_view_mode TEXT DEFAULT 'dot'");
        debugPrint(
            'Dynamic migration: Added calendar_view_mode column to users table.');
      }

      if (!userCols.any((c) => c['name'] == 'social_feed_layout')) {
        await db.execute(
            "ALTER TABLE users ADD COLUMN social_feed_layout TEXT DEFAULT 'card'");
        debugPrint(
            'Dynamic migration: Added social_feed_layout column to users table.');
      }

      if (!userCols.any((c) => c['name'] == 'is_currently_logged_in')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN is_currently_logged_in INTEGER DEFAULT 0');
        debugPrint(
            'Dynamic migration: Added is_currently_logged_in column to users table.');
      }

      if (!userCols.any((c) => c['name'] == 'show_floating_nav_bar')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN show_floating_nav_bar INTEGER DEFAULT 0');
        debugPrint(
            'Dynamic migration: Added show_floating_nav_bar column to users table.');
      }

      if (!userCols.any((c) => c['name'] == 'has_seen_tour')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN has_seen_tour INTEGER DEFAULT 0');
        debugPrint(
            'Dynamic migration: Added has_seen_tour column to users table.');
      }

      quizCols = await db.rawQuery('PRAGMA table_info(quiz_results)');
      if (!quizCols.any((c) => c['name'] == 'duration_seconds')) {
        await db.execute(
            'ALTER TABLE quiz_results ADD COLUMN duration_seconds INTEGER DEFAULT 0');
        debugPrint(
            'Dynamic migration: Added duration_seconds column to quiz_results table.');
      }

      var eventCols = await db.rawQuery('PRAGMA table_info(calendar_events)');
      if (!eventCols.any((c) => c['name'] == 'recurrence_type')) {
        await db.execute(
            "ALTER TABLE calendar_events ADD COLUMN recurrence_type TEXT DEFAULT 'none'");
        debugPrint(
            'Dynamic migration: Added recurrence_type column to calendar_events table.');
      }
      if (!eventCols.any((c) => c['name'] == 'recurrence_days')) {
        await db.execute(
            "ALTER TABLE calendar_events ADD COLUMN recurrence_days TEXT DEFAULT ''");
        debugPrint(
            'Dynamic migration: Added recurrence_days column to calendar_events table.');
      }
      if (!eventCols.any((c) => c['name'] == 'recurrence_end')) {
        await db.execute(
            "ALTER TABLE calendar_events ADD COLUMN recurrence_end TEXT DEFAULT ''");
        debugPrint(
            'Dynamic migration: Added recurrence_end column to calendar_events table.');
      }

      var gmCols = await db.rawQuery('PRAGMA table_info(group_members)');
      if (gmCols.isNotEmpty &&
          !gmCols.any((c) => c['name'] == 'last_read_at')) {
        await db.execute(
            "ALTER TABLE group_members ADD COLUMN last_read_at DATETIME DEFAULT CURRENT_TIMESTAMP");
        debugPrint(
            'Dynamic migration: Added last_read_at column to group_members table.');
      }
      if (gmCols.isNotEmpty && !gmCols.any((c) => c['name'] == 'is_muted')) {
        await db.execute(
            "ALTER TABLE group_members ADD COLUMN is_muted INTEGER DEFAULT 0");
        debugPrint(
            'Dynamic migration: Added is_muted column to group_members table.');
      }

      // 自我修復：如果原廠測試帳號被清空，自動重新導入 (以 Sharon 帳號 id = u1 為指標)
      final u1Check = await db.query('users', where: "id = 'u1'");
      if (u1Check.isEmpty) {
        debugPrint(
            'Dynamic migration: Restoring original seed users and data (Sharon, etc.)...');
        await _seedDatabase(db);
      }

      // 檢查是否已寫入新測試題庫 (歷史、理化)
      final extraCheck = await db.query('tags', where: "name = '中國史'");
      if (extraCheck.isEmpty) {
        await _seedExtraQuestions(db);
      }

      final qCountCheck =
          await db.rawQuery('SELECT COUNT(*) as count FROM questions');
      final qCount =
          int.tryParse(qCountCheck.first['count']?.toString() ?? '0') ?? 0;
      if (qCount < 100) {
        await _seedAllChapterMockQuestions(db);
      }
      await _healOrphanedGroups(db);
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
        await db.execute(
            'ALTER TABLE quiz_results ADD COLUMN duration_seconds INTEGER DEFAULT 0');
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
        await db.execute(
            'ALTER TABLE users ADD COLUMN is_google INTEGER DEFAULT 0');
      }
    }
    if (oldVersion < 13) {
      var userCols = await db.rawQuery('PRAGMA table_info(users)');
      if (!userCols.any((c) => c['name'] == 'show_floating_nav_bar')) {
        await db.execute(
            'ALTER TABLE users ADD COLUMN show_floating_nav_bar INTEGER DEFAULT 0');
      }
    }
    if (oldVersion < 15) {
      // posts.group_id
      var postCols = await db.rawQuery('PRAGMA table_info(posts)');
      if (!postCols.any((c) => c['name'] == 'group_id')) {
        await db.execute('ALTER TABLE posts ADD COLUMN group_id INTEGER');
      }
      // community_groups
      await db.execute('''
        CREATE TABLE IF NOT EXISTS community_groups (
          id               INTEGER PRIMARY KEY AUTOINCREMENT,
          name             TEXT    NOT NULL,
          description      TEXT    DEFAULT '',
          icon_emoji       TEXT    DEFAULT '📚',
          type             TEXT    NOT NULL DEFAULT 'public',
          owner_id         TEXT    NOT NULL,
          tags             TEXT    DEFAULT '[]',
          member_count     INTEGER DEFAULT 1,
          invite_token     TEXT,
          token_expires_at DATETIME,
          invite_link_active INTEGER DEFAULT 1,
          join_requires_approval INTEGER DEFAULT 0,
          created_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');
      // group_members
      await db.execute('''
        CREATE TABLE IF NOT EXISTS group_members (
          id        INTEGER PRIMARY KEY AUTOINCREMENT,
          group_id  INTEGER NOT NULL,
          user_id   TEXT    NOT NULL,
          role      TEXT    DEFAULT 'member',
          status    TEXT    DEFAULT 'active',
          joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (group_id) REFERENCES community_groups(id) ON DELETE CASCADE,
          FOREIGN KEY (user_id)  REFERENCES users(id) ON DELETE CASCADE,
          UNIQUE (group_id, user_id)
        )
      ''');
      // group_announcements
      await db.execute('''
        CREATE TABLE IF NOT EXISTS group_announcements (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          group_id   INTEGER NOT NULL,
          author_id  TEXT    NOT NULL,
          content    TEXT    NOT NULL,
          is_pinned  INTEGER DEFAULT 0,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (group_id) REFERENCES community_groups(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 16) {
      var gmCols = await db.rawQuery('PRAGMA table_info(group_members)');
      if (gmCols.isNotEmpty &&
          !gmCols.any((c) => c['name'] == 'last_read_at')) {
        await db.execute(
            "ALTER TABLE group_members ADD COLUMN last_read_at DATETIME DEFAULT '1970-01-01T00:00:00.000'");
      }
      if (gmCols.isNotEmpty && !gmCols.any((c) => c['name'] == 'is_muted')) {
        await db.execute(
            "ALTER TABLE group_members ADD COLUMN is_muted INTEGER DEFAULT 0");
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
        social_feed_layout TEXT DEFAULT 'card',
        is_currently_logged_in INTEGER DEFAULT 0,
        show_floating_nav_bar INTEGER DEFAULT 0,
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
        recurrence_type TEXT DEFAULT 'none',
        recurrence_days TEXT DEFAULT '',
        recurrence_end TEXT DEFAULT '',
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

    // 6.5 diaries
    await db.execute('''
      CREATE TABLE diaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id VARCHAR NOT NULL,
        date TEXT NOT NULL,
        content TEXT NOT NULL,
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
        group_id INTEGER,
        content TEXT NOT NULL,
        type VARCHAR DEFAULT 'text',
        attached_data TEXT DEFAULT '{}',
        media_blob BLOB,
        file_blob BLOB,
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
        subject TEXT DEFAULT '',
        paper_id INTEGER DEFAULT NULL,
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

    // 13. community_groups
    await db.execute('''
      CREATE TABLE community_groups (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        name             TEXT    NOT NULL,
        description      TEXT    DEFAULT '',
        icon_emoji       TEXT    DEFAULT '📚',
        type             TEXT    NOT NULL DEFAULT 'public',
        owner_id         TEXT    NOT NULL,
        tags             TEXT    DEFAULT '[]',
        member_count     INTEGER DEFAULT 1,
        invite_token     TEXT,
        token_expires_at DATETIME,
        invite_link_active INTEGER DEFAULT 1,
        join_requires_approval INTEGER DEFAULT 0,
        created_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // 14. group_members
    await db.execute('''
      CREATE TABLE group_members (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id     INTEGER NOT NULL,
        user_id      TEXT    NOT NULL,
        role         TEXT    DEFAULT 'member',
        status       TEXT    DEFAULT 'active',
        joined_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_read_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        is_muted     INTEGER DEFAULT 0,
        FOREIGN KEY (group_id) REFERENCES community_groups(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id)  REFERENCES users(id) ON DELETE CASCADE,
        UNIQUE (group_id, user_id)
      )
    ''');

    // 15. group_announcements
    await db.execute('''
      CREATE TABLE group_announcements (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id   INTEGER NOT NULL,
        author_id  TEXT    NOT NULL,
        content    TEXT    NOT NULL,
        is_pinned  INTEGER DEFAULT 0,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (group_id) REFERENCES community_groups(id) ON DELETE CASCADE
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
    await db.execute('CREATE INDEX idx_diaries_user_id ON diaries (user_id)');
    await db.execute(
        'CREATE INDEX idx_group_members_group ON group_members (group_id)');
    await db.execute(
        'CREATE INDEX idx_group_members_user ON group_members (user_id)');
    await db.execute('CREATE INDEX idx_posts_group_id ON posts (group_id)');

    await _seedDatabase(db);
  }

  // --- Auto-login helpers ---

  /// 設定當前登入使用者（先清除所有人的登入標記，再標記指定使用者）
  Future<void> setLoggedInUser(String userId) async {
    try {
      final db = await database;
      await db.execute('UPDATE users SET is_currently_logged_in = 0');
      await db.update('users', <String, Object?>{'is_currently_logged_in': 1},
        where: 'id = ?',
        whereArgs: [userId],
      );
      debugPrint('Auto-login: Set logged-in user to $userId');
    } catch (e) {
      debugPrint('Auto-login: Failed to set logged-in user: $e');
    }
  }

  /// 查詢指定使用者是否已看過互動引導
  Future<bool> hasSeenTour(String userId) async {
    try {
      final db = await database;
      final rows = await db.query('users',
          columns: ['has_seen_tour'], where: 'id = ?', whereArgs: [userId]);
      if (rows.isEmpty) return false;
      return (rows.first['has_seen_tour'] as int? ?? 0) == 1;
    } catch (e) {
      debugPrint('Tour: Failed to query has_seen_tour: $e');
      return false;
    }
  }

  /// 標記指定使用者已看過互動引導
  Future<void> setHasSeenTour(String userId) async {
    try {
      final db = await database;
      await db.update('users', <String, Object?>{'has_seen_tour': 1},
        where: 'id = ?',
        whereArgs: [userId],
      );
      debugPrint('Tour: Marked has_seen_tour=1 for user $userId');
    } catch (e) {
      debugPrint('Tour: Failed to set has_seen_tour: $e');
    }
  }

  /// 清除指定使用者的登入標記（登出時呼叫）
  Future<void> clearLoggedInUser(String userId) async {
    try {
      final db = await database;
      await db.update('users', <String, Object?>{'is_currently_logged_in': 0},
        where: 'id = ?',
        whereArgs: [userId],
      );
      debugPrint('Auto-login: Cleared logged-in user $userId');
    } catch (e) {
      debugPrint('Auto-login: Failed to clear logged-in user: $e');
    }
  }

  /// 讀取當前登入的使用者（APP 啟動時呼叫，用於自動登入）
  /// 若返回 null，表示無已登入的使用者，需要顯示登入頁面。
  Future<Map<String, dynamic>?> getLoggedInUser() async {
    try {
      final db = await database;
      final res = await db.query(
        'users',
        where:
            'is_currently_logged_in = 1 AND (deleted_at IS NULL OR deleted_at = "")',
        limit: 1,
      );
      if (res.isNotEmpty) {
        final userMap = Map<String, dynamic>.from(res.first);
        // 訪客帳號不自動登入
        if (userMap['id'] == 'u4') return null;
        userMap['session_post_ids'] = <int>{};
        userMap['session_comment_ids'] = <int>{};
        debugPrint(
            'Auto-login: Found logged-in user: ${userMap['display_name'] ?? userMap['username']}');
        return userMap;
      }
    } catch (e) {
      debugPrint('Auto-login: Failed to get logged-in user: $e');
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  // 社群群組 Helper Methods
  // ─────────────────────────────────────────────────────────────────

  /// 產生一個簡單的 UUID-like token（不依賴外部套件）
  String _generateToken() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = (now * 6364136223846793005 + 1442695040888963407) % (1 << 53);
    return '${now.toRadixString(16)}-${rand.abs().toRadixString(16)}';
  }

  /// 動態修復 group_members 欄位 (確保 last_read_at 與 is_muted 存在)
  Future<void> _ensureGroupMembersColumns(Database db) async {
    try {
      var gmCols = await db.rawQuery('PRAGMA table_info(group_members)');
      if (gmCols.isNotEmpty) {
        if (!gmCols.any((c) => c['name'] == 'last_read_at')) {
          await db.execute(
              "ALTER TABLE group_members ADD COLUMN last_read_at DATETIME DEFAULT '1970-01-01T00:00:00.000'");
          debugPrint(
              'Dynamic migration: Added last_read_at column to group_members table.');
        }
        if (!gmCols.any((c) => c['name'] == 'is_muted')) {
          await db.execute(
              "ALTER TABLE group_members ADD COLUMN is_muted INTEGER DEFAULT 0");
          debugPrint(
              'Dynamic migration: Added is_muted column to group_members table.');
        }
      }

      var cgCols = await db.rawQuery('PRAGMA table_info(community_groups)');
      if (cgCols.isNotEmpty) {
        if (!cgCols.any((c) => c['name'] == 'join_requires_approval')) {
          await db.execute(
              "ALTER TABLE community_groups ADD COLUMN join_requires_approval INTEGER");
          debugPrint(
              'Dynamic migration: Added join_requires_approval column to community_groups table.');
          await db.execute(
              "UPDATE community_groups SET join_requires_approval = CASE WHEN type = 'private' THEN 1 ELSE 0 END");
        }
      }
    } catch (e) {
      debugPrint('Error in _ensureGroupMembersColumns: $e');
    }
  }

  /// 建立群組，自動加入 owner 成員，返回新群組 id
  Future<int> createGroup({
    required String name,
    required String description,
    required String iconEmoji,
    required String type, // 'public' | 'private'
    required String ownerId,
    required bool joinRequiresApproval,
    List<String> tags = const [],
  }) async {
    final db = await database;
    await _ensureGroupMembersColumns(db);

    final token = _generateToken();
    final groupId = await db.insert('community_groups', <String, Object?>{
      'name': name,
      'description': description,
      'icon_emoji': iconEmoji,
      'type': type,
      'owner_id': ownerId,
      'tags': jsonEncode(tags),
      'member_count': 1,
      'invite_token': token,
      'invite_link_active': 1,
      'join_requires_approval': joinRequiresApproval ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    final now = DateTime.now().toIso8601String();

    // 自動加入 owner 成員 (帶容錯降級處理)
    try {
      await db.insert('group_members', <String, Object?>{
        'group_id': groupId,
        'user_id': ownerId,
        'role': 'owner',
        'status': 'active',
        'joined_at': now,
        'last_read_at': now,
        'is_muted': 0,
      });
    } catch (e) {
      debugPrint(
          'createGroup insert with new columns failed, repairing schema...: $e');
      await _ensureGroupMembersColumns(db);
      try {
        await db.insert('group_members', <String, Object?>{
          'group_id': groupId,
          'user_id': ownerId,
          'role': 'owner',
          'status': 'active',
          'joined_at': now,
          'last_read_at': now,
          'is_muted': 0,
        });
      } catch (_) {
        await db.insert('group_members', <String, Object?>{
          'group_id': groupId,
          'user_id': ownerId,
          'role': 'owner',
          'status': 'active',
          'joined_at': now,
        });
      }
    }
    return groupId;
  }

  /// 自我修復：將孤立的群組（有 community_groups 但創辦者未加入 group_members）自動補齊至 group_members
  Future<void> _healOrphanedGroups(Database db) async {
    try {
      await _ensureGroupMembersColumns(db);
      // 1. 補齊未出現在 group_members 的群組創辦者 (正確對應 group_id, user_id，不覆蓋 group_members.id)
      await db.execute('''
        INSERT INTO group_members (group_id, user_id, role, status, joined_at, last_read_at, is_muted)
        SELECT cg.id, cg.owner_id, 'owner', 'active', cg.created_at, cg.created_at, 0
        FROM community_groups cg
        WHERE cg.owner_id IS NOT NULL AND cg.owner_id != ''
          AND NOT EXISTS (
            SELECT 1 FROM group_members gm WHERE gm.group_id = cg.id AND gm.user_id = cg.owner_id
          )
      ''');
      // 2. 確保所有創辦者成員狀態皆為 owner / active
      await db.execute('''
        UPDATE group_members
        SET role = 'owner', status = 'active'
        WHERE EXISTS (
          SELECT 1 FROM community_groups cg
          WHERE cg.id = group_members.group_id AND cg.owner_id = group_members.user_id
        )
      ''');
    } catch (e) {
      debugPrint('Error healing orphaned groups: $e');
    }
  }

  /// 取得我加入（或我建立）的所有群組，含待審核人數 pending_count、未讀動態數 unread_count 與靜音狀態 is_muted
  Future<List<Map<String, dynamic>>> getMyGroups(String userId) async {
    try {
      final db = await database;
      await _healOrphanedGroups(db);
      return await db.rawQuery('''
        SELECT cg.*,
               COALESCE(gm.role, 'owner') as role,
               COALESCE(gm.status, 'active') as status,
               COALESCE(gm.last_read_at, '1970-01-01') as last_read_at,
               COALESCE(gm.is_muted, 0) as is_muted,
               (SELECT COUNT(*) FROM group_members gm2 WHERE gm2.group_id = cg.id AND gm2.status = 'pending') as pending_count,
               (SELECT COUNT(*) FROM posts p WHERE p.group_id = cg.id AND p.created_at > COALESCE(gm.last_read_at, '1970-01-01')) as unread_count
        FROM community_groups cg
        LEFT JOIN group_members gm ON cg.id = gm.group_id AND gm.user_id = ?
        WHERE (gm.user_id = ? AND gm.status = 'active') OR cg.owner_id = ?
        ORDER BY (CASE WHEN COALESCE(gm.is_muted, 0) = 1 THEN 1 ELSE 0 END) ASC, unread_count DESC, cg.created_at DESC
      ''', [userId, userId, userId]);
    } catch (e) {
      debugPrint('Error in getMyGroups: $e');
      return [];
    }
  }

  /// 將指定群組標記為已讀（更新 last_read_at 時間）
  Future<void> markGroupAsRead(int groupId, String userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update('group_members', <String, Object?>{'last_read_at': now},
      where: 'group_id = ? AND user_id = ?',
      whereArgs: [groupId, userId],
    );
  }

  /// 將指定群組標記為未讀（重置 last_read_at）
  Future<void> markGroupAsUnread(int groupId, String userId) async {
    final db = await database;
    await db.update('group_members', <String, Object?>{'last_read_at': '1970-01-01 00:00:00'},
      where: 'group_id = ? AND user_id = ?',
      whereArgs: [groupId, userId],
    );
  }

  /// 一鍵將所有群組標記為已讀（LINE 經典功能）
  Future<void> markAllGroupsAsRead(String userId) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update('group_members', <String, Object?>{'last_read_at': now},
      where: 'user_id = ? AND status = "active"',
      whereArgs: [userId],
    );
  }

  /// 切換群組靜音狀態（0 <-> 1）
  Future<bool> toggleGroupMute(int groupId, String userId) async {
    final db = await database;
    final rows = await db.query('group_members',
        where: 'group_id = ? AND user_id = ?',
        whereArgs: [groupId, userId],
        limit: 1);
    if (rows.isEmpty) return false;
    final currentMuted = (rows.first['is_muted'] as int? ?? 0) == 1;
    final newMuted = !currentMuted;
    await db.update('group_members', <String, Object?>{'is_muted': newMuted ? 1 : 0},
      where: 'group_id = ? AND user_id = ?',
      whereArgs: [groupId, userId],
    );
    return newMuted;
  }

  /// 取得所有公開群組
  Future<List<Map<String, dynamic>>> getAllPublicGroups() async {
    final db = await database;
    return await db.query('community_groups',
        where: "type = 'public'",
        orderBy: 'member_count DESC, created_at DESC');
  }

  /// 取得所有群組（公開 + 私人，用於探索頁）
  Future<List<Map<String, dynamic>>> getAllGroups() async {
    final db = await database;
    return await db.query('community_groups',
        orderBy: 'member_count DESC, created_at DESC');
  }

  /// 取得群組詳細資料（含成員數）
  Future<Map<String, dynamic>?> getGroupById(int groupId) async {
    final db = await database;
    final rows = await db.query('community_groups',
        where: 'id = ?', whereArgs: [groupId], limit: 1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  /// 取得群組成員列表（含使用者資訊，使用 LEFT JOIN 防止使用者不存在引發成員歸零）
  Future<List<Map<String, dynamic>>> getGroupMembers(int groupId) async {
    final db = await database;
    await _healOrphanedGroups(db);
    return await db.rawQuery('''
      SELECT gm.*,
             COALESCE(u.display_name, '群組成員') as display_name,
             u.avatar_blob, u.avatar_color, u.avatar_selected, u.bio
      FROM group_members gm
      LEFT JOIN users u ON gm.user_id = u.id
      WHERE gm.group_id = ? AND gm.status IN ('active', 'pending')
      ORDER BY
        CASE gm.role WHEN 'owner' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END,
        gm.joined_at ASC
    ''', [groupId]);
  }

  /// 取得群組貼文
  Future<List<Map<String, dynamic>>> getGroupPosts(int groupId) async {
    final db = await database;
    return await db.query('posts',
        where: 'group_id = ?',
        whereArgs: [groupId],
        orderBy: 'created_at DESC');
  }

  /// 查詢使用者是否為群組成員（status = active）
  Future<Map<String, dynamic>?> getGroupMembership(
      int groupId, String userId) async {
    final db = await database;
    final rows = await db.query('group_members',
        where: 'group_id = ? AND user_id = ?',
        whereArgs: [groupId, userId],
        limit: 1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  /// 加入公開群組 / 申請私人群組
  /// isPending: true = 申請中（私人群組），false = 直接加入（公開群組）
  Future<void> joinGroup(int groupId, String userId,
      {bool isPending = false}) async {
    final db = await database;
    await _ensureGroupMembersColumns(db);
    final status = isPending ? 'pending' : 'active';
    final now = DateTime.now().toIso8601String();
    // 若已存在則更新 status
    final existing = await db.query('group_members',
        where: 'group_id = ? AND user_id = ?',
        whereArgs: [groupId, userId],
        limit: 1);
    if (existing.isEmpty) {
      try {
        await db.insert('group_members', <String, Object?>{
          'group_id': groupId,
          'user_id': userId,
          'role': 'member',
          'status': status,
          'joined_at': now,
          'last_read_at': now,
          'is_muted': 0,
        });
      } catch (_) {
        await db.insert('group_members', <String, Object?>{
          'group_id': groupId,
          'user_id': userId,
          'role': 'member',
          'status': status,
          'joined_at': now,
        });
      }
    } else {
      await db.update('group_members', <String, Object?>{'status': status},
          where: 'group_id = ? AND user_id = ?', whereArgs: [groupId, userId]);
    }
    if (!isPending) {
      // 更新成員數
      await db.execute(
          'UPDATE community_groups SET member_count = member_count + 1 WHERE id = ?',
          [groupId]);
    }
  }

  /// 離開群組
  Future<void> leaveGroup(int groupId, String userId) async {
    final db = await database;
    await db.delete('group_members',
        where: 'group_id = ? AND user_id = ?', whereArgs: [groupId, userId]);
    await db.execute(
        'UPDATE community_groups SET member_count = MAX(0, member_count - 1) WHERE id = ?',
        [groupId]);
  }

  /// 審核申請（同意 / 拒絕）
  Future<void> approveGroupRequest(
      int groupId, String userId, bool approved) async {
    final db = await database;
    if (approved) {
      await db.update('group_members', <String, Object?>{'status': 'active'},
          where: 'group_id = ? AND user_id = ?', whereArgs: [groupId, userId]);
      await db.execute(
          'UPDATE community_groups SET member_count = member_count + 1 WHERE id = ?',
          [groupId]);
    } else {
      await db.delete('group_members',
          where: 'group_id = ? AND user_id = ?', whereArgs: [groupId, userId]);
    }
  }

  /// 透過 invite_token 查詢群組
  Future<Map<String, dynamic>?> getGroupByToken(String token) async {
    final db = await database;
    final rows = await db.query('community_groups',
        where: 'invite_token = ? AND invite_link_active = 1',
        whereArgs: [token],
        limit: 1);
    if (rows.isEmpty) return null;
    final group = Map<String, dynamic>.from(rows.first);
    // 檢查是否過期
    final expiresAt = group['token_expires_at'] as String?;
    if (expiresAt != null && expiresAt.isNotEmpty) {
      final exp = DateTime.tryParse(expiresAt);
      if (exp != null && exp.isBefore(DateTime.now())) return null;
    }
    return group;
  }

  /// 重新生成 invite_token（讓舊連結失效）
  Future<String> regenerateInviteToken(int groupId) async {
    final db = await database;
    final token = _generateToken();
    await db.update('community_groups', <String, Object?>{'invite_token': token},
        where: 'id = ?', whereArgs: [groupId]);
    return token;
  }

  /// 設定邀請連結過期時間（null = 永久）
  Future<void> setTokenExpiry(int groupId, DateTime? expiresAt) async {
    final db = await database;
    await db.update('community_groups', <String, Object?>{'token_expires_at': expiresAt?.toIso8601String()},
        where: 'id = ?', whereArgs: [groupId]);
  }

  /// 開啟/關閉邀請連結
  Future<void> setInviteLinkActive(int groupId, bool active) async {
    final db = await database;
    await db.update('community_groups', <String, Object?>{'invite_link_active': active ? 1 : 0},
        where: 'id = ?', whereArgs: [groupId]);
  }

  /// 刪除群組（同步連動清理成員、公告與貼文）
  Future<void> deleteGroup(int groupId) async {
    final db = await database;
    await db.delete('community_groups', where: 'id = ?', whereArgs: [groupId]);
    await db
        .delete('group_members', where: 'group_id = ?', whereArgs: [groupId]);
    await db.delete('group_announcements',
        where: 'group_id = ?', whereArgs: [groupId]);
    await db.delete('posts', where: 'group_id = ?', whereArgs: [groupId]);
  }

  // --- Paper helpers ---
  Future<int> createPaper(
      String userId, String name, List<int> questionIds) async {
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
    return await db.query('user_papers',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getPaperById(int id) async {
    final db = await database;
    final rows = await db.query('user_papers',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<int>> getQuestionIdsForPaper(int paperId) async {
    final row = await getPaperById(paperId);
    if (row == null) return [];
    final raw = row['question_ids']?.toString() ?? '[]';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((v) => v > 0)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<int> deletePaper(int id) async {
    final db = await database;
    return await db.delete('user_papers', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updatePaper(int id, String name, List<int> questionIds) async {
    final db = await database;
    return await db.update('user_papers', <String, Object?>{
          'name': name,
          'question_ids': jsonEncode(questionIds),
          'created_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  // --- Wrong question helpers ---
  Future<int> addWrongQuestion(String userId, int questionId,
      {String note = ''}) async {
    final db = await database;
    final existing = await db.query(
      'wrong_questions',
      where: 'user_id = ? AND question_id = ?',
      whereArgs: [userId, questionId],
    );
    if (existing.isNotEmpty) {
      if (note.isNotEmpty) {
        await db.update('wrong_questions', <String, Object?>{'note': note},
          where: 'user_id = ? AND question_id = ?',
          whereArgs: [userId, questionId],
        );
      }
      return int.tryParse(existing.first['id'].toString()) ?? 0;
    }
    return await db.insert('wrong_questions', <String, Object?>{
      'user_id': userId,
      'question_id': questionId,
      'note': note,
    });
  }

  Future<List<Map<String, dynamic>>> getWrongQuestions(String userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT wq.*, q.text, q.options, q.answer, q.explanation, q.subject, q.difficulty, q.type, q.bookmarked
      FROM wrong_questions wq
      JOIN questions q ON wq.question_id = q.id
      WHERE wq.user_id = ?
      ORDER BY wq.created_at DESC
    ''', [userId]);
  }

  Future<int> deleteWrongQuestionByRecordId(int recordId) async {
    final db = await database;
    return await db
        .delete('wrong_questions', where: 'id = ?', whereArgs: [recordId]);
  }

  Future<int> deleteWrongQuestionsBulk(List<int> recordIds) async {
    if (recordIds.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(recordIds.length, '?').join(',');
    return await db.delete('wrong_questions',
        where: 'id IN ($placeholders)', whereArgs: recordIds);
  }

  Future<int> createNote(String userId, String title, String content) async {
    final db = await database;
    return await db.insert('notes', <String, Object?>{
      'user_id': userId,
      'title': title,
      'content': content,
    });
  }

  Future<void> _seedDatabase(Database db) async {
    // 1. Users
    await db.insert('users', <String, Object?>{
          'id': 'u1',
          'username': 'Sharon',
          'email': 'sharon@gmail.com',
          'hashed_password': 'mock_password',
          'display_name': 'Sharon',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('users', <String, Object?>{
          'id': 'u2',
          'username': '陳教授',
          'email': 'prof@gmail.com',
          'hashed_password': 'mock_password',
          'display_name': '陳教授',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('users', <String, Object?>{
          'id': 'u3',
          'username': '系統',
          'email': 'sys@gmail.com',
          'hashed_password': 'mock_password',
          'display_name': '系統',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('users', <String, Object?>{
          'id': 'u4',
          'username': '訪客',
          'email': 'guest@gmail.com',
          'hashed_password': 'mock_password',
          'display_name': '訪客',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('users', <String, Object?>{
          'id': 'u5',
          'username': '李同學',
          'email': 'lee@gmail.com',
          'hashed_password': 'mock_password',
          'display_name': '李同學',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('users', <String, Object?>{
          'id': 'u6',
          'username': '陳助教',
          'email': 'ta@gmail.com',
          'hashed_password': 'mock_password',
          'display_name': '陳助教',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    // 2. Calendar Event
    await db.insert('calendar_events', <String, Object?>{
          'user_id': 'u1',
          'title': '專題討論會議',
          'start_time': '2026-03-30 09:10:00',
          'end_time': '2026-03-30 12:00:00',
          'color': '0xFFFFE082',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    // 3. Todo
    await db.insert('todos', <String, Object?>{
          'user_id': 'u1',
          'text': '確認 AutoCAD 圓角圖層',
          'done': 0,
          'created_at': '2026-03-30 00:00:00',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    // 4. Posts (Seed a real functional post, but no hardcoded test strings from Sharon)
    await db.insert('posts', <String, Object?>{
          'id': 1,
          'user_id': 'u2',
          'content': '歡迎大家在社群分享學習心得與專題進度！',
          'likes': 5,
          'type': 'text',
          'created_at': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('posts', <String, Object?>{
          'id': 2,
          'user_id': 'u5',
          'content': '我分享了我的學習筆記《測試》，歡迎點擊一鍵匯入！ 📝',
          'likes': 12,
          'type': 'share',
          'attached_data': jsonEncode({
            'shared_type': 'note',
            'title': '測試',
            'category': '未分類',
            'content':
                '巴威颱風強勢逼近台灣，北部地區首當其衝。台北市、新北市、基隆市及桃園市達成共識，宣布今（10）日停止上班上課。然而，外界有輿論質疑...',
          }),
          'created_at': DateTime.now()
              .subtract(const Duration(days: 18))
              .toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    // 5. Questions
    await db.insert('questions', <String, Object?>{
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
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('questions', <String, Object?>{
          'id': 2,
          'user_id': 'u1',
          'text': '《師說》的作者是誰？',
          'options': jsonEncode(['柳宗元', '韓愈', '歐陽脩', '蘇軾']),
          'answer': '1',
          'explanation': '韓愈倡導古文運動，作《師說》。',
          'subject': '國文',
          'difficulty': '易',
          'bookmarked': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('questions', <String, Object?>{
          'id': 3,
          'user_id': 'u3',
          'text': '長方形長5寬4，面積為何？',
          'options': jsonEncode(['18', '20', '25', '9']),
          'answer': '1',
          'explanation': '5x4=20',
          'subject': '數學',
          'difficulty': '易',
          'bookmarked': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    // 6. Tags map (for chapter matching in old logic)
    await db.insert('tags', <String, Object?>{'id': 1, 'name': '第二章 資料庫管理'},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('tags', <String, Object?>{'id': 2, 'name': '師說'},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('tags', <String, Object?>{'id': 3, 'name': '面積'},
        conflictAlgorithm: ConflictAlgorithm.ignore);

    await db.insert('question_tag_map', <String, Object?>{'question_id': 1, 'tag_id': 1},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('question_tag_map', <String, Object?>{'question_id': 2, 'tag_id': 2},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('question_tag_map', <String, Object?>{'question_id': 3, 'tag_id': 3},
        conflictAlgorithm: ConflictAlgorithm.ignore);

    // TOEIC 題庫 (101-250: Part 5-7 試題)
    // Part 5: 101-130
    await db.insert('questions', <String, Object?>{
          'id': 4,
          'user_id': 'u2',
          'text':
              'Former Sendai Company CEO Ken Nakata spoke about ------- career experiences.',
          'options': jsonEncode(['he', 'his', 'him', 'himself']),
          'answer': '1',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 5,
          'user_id': 'u2',
          'text':
              'Passengers who will be taking a ------ domestic flight should go to Terminal A.',
          'options':
              jsonEncode(['connectivity', 'connects', 'connect', 'connecting']),
          'answer': '3',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 6,
          'user_id': 'u2',
          'text':
              'Fresh and ------- apple-cider donuts are available at Oakcrest Orchard\'s retail shop for £6 per dozen.',
          'options': jsonEncode(['eaten', 'open', 'tasty', 'free']),
          'answer': '2',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 7,
          'user_id': 'u2',
          'text':
              'Zahn Flooring has the widest selection of ------- in the United Kingdom.',
          'options': jsonEncode(['paints', 'tiles', 'furniture', 'curtains']),
          'answer': '1',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 8,
          'user_id': 'u2',
          'text':
              'One responsibility of the IT department is to ensure that the company is using ------- software.',
          'options': jsonEncode(['update', 'updating', 'updates', 'updated']),
          'answer': '3',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 9,
          'user_id': 'u2',
          'text':
              'It is wise to check a company\'s dress code ------- visiting its head office.',
          'options': jsonEncode(['so', 'how', 'like', 'before']),
          'answer': '3',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 10,
          'user_id': 'u2',
          'text':
              'Wexler Store\'s management team expects that employees will ------- support any new hires.',
          'options': jsonEncode(
              ['enthusiastically', 'enthusiasm', 'enthusiastic', 'enthused']),
          'answer': '0',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 11,
          'user_id': 'u2',
          'text':
              'Wheel alignments and brake system ------- are part of our vehicle service plan.',
          'options':
              jsonEncode(['inspects', 'inspector', 'inspected', 'inspections']),
          'answer': '3',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 12,
          'user_id': 'u2',
          'text':
              'Registration for the Marketing Coalition Conference is now open ------- September 30.',
          'options': jsonEncode(['until', 'into', 'yet', 'while']),
          'answer': '0',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 13,
          'user_id': 'u2',
          'text':
              'Growth in the home entertainment industry has been ------- this quarter.',
          'options': jsonEncode(['separate', 'limited', 'willing', 'assorted']),
          'answer': '1',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 14,
          'user_id': 'u2',
          'text':
              'Hawson Furniture will be making ------- on the east side of town on Thursday.',
          'options':
              jsonEncode(['deliveries', 'delivered', 'deliver', 'deliverable']),
          'answer': '0',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 15,
          'user_id': 'u2',
          'text':
              'The Marlton City Council does not have the authority to ------- parking on city streets.',
          'options': jsonEncode(['drive', 'prohibit', 'bother', 'travel']),
          'answer': '1',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 16,
          'user_id': 'u2',
          'text':
              'Project Earth Group is ------- for ways to reduce transport-related greenhouse gas emissions.',
          'options': jsonEncode(['looking', 'seeing', 'driving', 'leaning']),
          'answer': '0',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 17,
          'user_id': 'u2',
          'text':
              'Our skilled tailors are happy to design a custom-made suit that fits your style and budget -------.',
          'options':
              jsonEncode(['perfect', 'perfects', 'perfectly', 'perfection']),
          'answer': '2',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 18,
          'user_id': 'u2',
          'text':
              'Project manager Hannah Chung has proved to be very ------- with completing company projects.',
          'options':
              jsonEncode(['helpfulness', 'help', 'helpfully', 'helpful']),
          'answer': '3',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 19,
          'user_id': 'u2',
          'text':
              'Lehua Vacation Club members will receive double points ------- the month of August at participating hotels.',
          'options': jsonEncode(['onto', 'above', 'during', 'between']),
          'answer': '2',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 20,
          'user_id': 'u2',
          'text':
              'The costumes were not received ------- enough to be used in the first dress rehearsal.',
          'options': jsonEncode(['far', 'very', 'almost', 'soon']),
          'answer': '3',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 21,
          'user_id': 'u2',
          'text':
              'As a former publicist for several renowned orchestras, Mr. Wu would excel in the role of event -------.',
          'options': jsonEncode(
              ['organized', 'organizer', 'organizes', 'organizational']),
          'answer': '1',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 22,
          'user_id': 'u2',
          'text':
              'The northbound lane on Davis Street will be ------- closed because of the city\'s bridge reinforcement project.',
          'options': jsonEncode(
              ['temporarily', 'competitively', 'recently', 'collectively']),
          'answer': '0',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 23,
          'user_id': 'u2',
          'text':
              'Airline representatives must handle a wide range of passenger issues, ------- missed connections to lost luggage.',
          'options': jsonEncode(['from', 'under', 'on', 'against']),
          'answer': '0',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 24,
          'user_id': 'u2',
          'text':
              'The meeting notes were ------- deleted, but Mr. Hahm was able to recreate them from memory.',
          'options': jsonEncode(
              ['accident', 'accidental', 'accidents', 'accidentally']),
          'answer': '3',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 25,
          'user_id': 'u2',
          'text':
              'The current issue of Farming Scene magazine predicts that the price of corn will rise 5 percent over the ------- year.',
          'options': jsonEncode(['next', 'with', 'which', 'now']),
          'answer': '0',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 26,
          'user_id': 'u2',
          'text':
              'Anyone who still ------- to take the fire safety training should do so before the end of the month.',
          'options':
              jsonEncode(['needing', 'needs', 'has needed', 'were needing']),
          'answer': '1',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 27,
          'user_id': 'u2',
          'text':
              'Emerging technologies have ------- begun to transform the shipping industry in ways that were once unimaginable.',
          'options': jsonEncode(['already', 'exactly', 'hardly', 'closely']),
          'answer': '0',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 28,
          'user_id': 'u2',
          'text':
              'The company handbook outlines the high ------- that employees are expected to meet every day.',
          'options': jsonEncode(
              ['experts', 'accounts', 'recommendations', 'standards']),
          'answer': '3',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 29,
          'user_id': 'u2',
          'text':
              'Because ------- of the board members have scheduling conflicts, the board meeting will be moved to a date when all can attend.',
          'options': jsonEncode(['any', 'everybody', 'those', 'some']),
          'answer': '3',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 30,
          'user_id': 'u2',
          'text':
              'The project ------- the collaboration of several teams across the company.',
          'options': jsonEncode(['passed', 'decided', 'required', 'performed']),
          'answer': '2',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
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
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 32,
          'user_id': 'u2',
          'text':
              '------- the closure of Verdigold Transport Services, we are looking for a new shipping company.',
          'options': jsonEncode(
              ['In spite of', 'Just as', 'In light of', 'According to']),
          'answer': '2',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 33,
          'user_id': 'u2',
          'text':
              'The ------- information provided by Uniss Bank\'s brochure helps applicants understand the terms of their loans.',
          'options': jsonEncode(
              ['arbitrary', 'supplemental', 'superfluous', 'potential']),
          'answer': '1',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    // Part 6: 131-146
    await db.insert('questions', <String, Object?>{
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
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
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
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
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
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 37,
          'user_id': 'u2',
          'text':
              'Part 6-134: Multiple benefits - Which pronoun should replace the blank?',
          'options': jsonEncode(['we', 'they', 'both', 'yours']),
          'answer': '2',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 38,
          'user_id': 'u2',
          'text':
              'Part 6-135: Amazing support - Which word form fits with gratitude for support?',
          'options':
              jsonEncode(['amazed', 'amazement', 'amazing', 'amazingly']),
          'answer': '2',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 39,
          'user_id': 'u2',
          'text':
              'Part 6-136: Social media response - What did the designs receive on social media?',
          'options':
              jsonEncode(['attention', 'proposals', 'innovation', 'criticism']),
          'answer': '0',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
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
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 41,
          'user_id': 'u2',
          'text':
              'Part 6-138: Award program - Which verb form fits with the upcoming auction?',
          'options': jsonEncode(
              ['will benefit', 'to benefit', 'has benefited', 'benefits']),
          'answer': '3',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 42,
          'user_id': 'u2',
          'text': 'Part 6-139: Card renewal - What must be renewed?',
          'options': jsonEncode(['It', 'You', 'Our', 'Each']),
          'answer': '0',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
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
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 44,
          'user_id': 'u2',
          'text':
              'Part 6-141: Conditional statement - Which word best introduces the condition about closing an account?',
          'options': jsonEncode(['Also', 'Should', 'Because', 'Although']),
          'answer': '1',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 45,
          'user_id': 'u2',
          'text':
              'Part 6-142: Renewal deadline - Which word form means "exactly stated or determined"?',
          'options': jsonEncode(
              ['specifically', 'specifics', 'specified', 'specificity']),
          'answer': '2',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
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
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 47,
          'user_id': 'u2',
          'text':
              'Part 6-144: Image creation - What does Droplight Studio do when creating images?',
          'options': jsonEncode(
              ['researching', 'creating', 'purchasing', 'displaying']),
          'answer': '1',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 48,
          'user_id': 'u2',
          'text':
              'Part 6-145: Studio equipment advantages - Which transition word best connects the equipment benefits?',
          'options':
              jsonEncode(['If not', 'By comparison', 'Otherwise', 'Indeed']),
          'answer': '3',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 49,
          'user_id': 'u2',
          'text':
              'Part 6-146: Image editing - What happens to every image after the photo shoot?',
          'options': jsonEncode(
              ['receives', 'is receiving', 'had received', 'had to receive']),
          'answer': '0',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    // Part 7: 147-150
    await db.insert('questions', <String, Object?>{
          'id': 50,
          'user_id': 'u2',
          'text':
              'Part 7-147: Where is the information about assembly most likely found?',
          'options': jsonEncode(
              ['On a door', 'On a receipt', 'In a box', 'On a Web site']),
          'answer': '2',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
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
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
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
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('questions', <String, Object?>{
          'id': 53,
          'user_id': 'u2',
          'text':
              'Part 7-150: What is indicated about 11:00 A.M. Winnipeg time?',
          'options': jsonEncode([
            'It is when the Winnipeg office closes for lunch.',
            'It is when staff in Toulouse begin their workday.',
            'It is not a preferred time to schedule a meeting.',
            'It has just been added to the schedule.'
          ]),
          'answer': '2',
          'subject': 'TOEIC',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    // 7. Simulated wrong question records in quiz_results to match ui state isWrong: true
    await db.insert('quiz_results', <String, Object?>{
          'user_id': 'u1',
          'total': 10,
          'correct': 8,
          'wrong_question_ids': jsonEncode([1, 3]),
          'duration_seconds': 720,
          'timestamp': '2026-05-25 14:30:00'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('quiz_results', <String, Object?>{
          'user_id': 'u1',
          'total': 15,
          'correct': 13,
          'wrong_question_ids': jsonEncode([2]),
          'duration_seconds': 1200,
          'timestamp': '2026-05-26 16:00:00'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    // 8. 排行榜種子資料：u2 陳教授
    await db.insert('quiz_results', <String, Object?>{
          'user_id': 'u2',
          'total': 20,
          'correct': 20,
          'wrong_question_ids': jsonEncode([]),
          'duration_seconds': 900,
          'timestamp': '2026-05-24 09:00:00'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('quiz_results', <String, Object?>{
          'user_id': 'u2',
          'total': 25,
          'correct': 24,
          'wrong_question_ids': jsonEncode([5]),
          'duration_seconds': 1100,
          'timestamp': '2026-05-26 10:30:00'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('quiz_results', <String, Object?>{
          'user_id': 'u2',
          'total': 15,
          'correct': 15,
          'wrong_question_ids': jsonEncode([]),
          'duration_seconds': 600,
          'timestamp': '2026-05-27 08:00:00'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    // 9. 排行榜種子資料：u5 李同學
    await db.insert('quiz_results', <String, Object?>{
          'user_id': 'u5',
          'total': 12,
          'correct': 9,
          'wrong_question_ids': jsonEncode([4, 7, 10]),
          'duration_seconds': 800,
          'timestamp': '2026-05-23 15:00:00'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('quiz_results', <String, Object?>{
          'user_id': 'u5',
          'total': 18,
          'correct': 14,
          'wrong_question_ids': jsonEncode([2, 6, 8, 11]),
          'duration_seconds': 1300,
          'timestamp': '2026-05-25 11:00:00'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('quiz_results', <String, Object?>{
          'user_id': 'u5',
          'total': 10,
          'correct': 8,
          'wrong_question_ids': jsonEncode([3, 9]),
          'duration_seconds': 700,
          'timestamp': '2026-05-27 14:00:00'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    // 10. 排行榜種子資料：u6 陳助教
    await db.insert('quiz_results', <String, Object?>{
          'user_id': 'u6',
          'total': 30,
          'correct': 27,
          'wrong_question_ids': jsonEncode([1, 4, 12]),
          'duration_seconds': 1500,
          'timestamp': '2026-05-22 10:00:00'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('quiz_results', <String, Object?>{
          'user_id': 'u6',
          'total': 20,
          'correct': 19,
          'wrong_question_ids': jsonEncode([8]),
          'duration_seconds': 950,
          'timestamp': '2026-05-24 16:00:00'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('quiz_results', <String, Object?>{
          'user_id': 'u6',
          'total': 25,
          'correct': 22,
          'wrong_question_ids': jsonEncode([2, 6, 13]),
          'duration_seconds': 1200,
          'timestamp': '2026-05-27 09:30:00'
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _seedExtraQuestions(Database db) async {
    // 插入歷史和理化的 Tag
    await db.insert('tags', <String, Object?>{'name': '中國史'},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('tags', <String, Object?>{'name': '理化'},
        conflictAlgorithm: ConflictAlgorithm.ignore);

    final historyTag = await db.query('tags', where: "name = '中國史'");
    final physicsTag = await db.query('tags', where: "name = '理化'");

    int historyTagId =
        historyTag.isNotEmpty ? historyTag.first['id'] as int : 0;
    int physicsTagId =
        physicsTag.isNotEmpty ? physicsTag.first['id'] as int : 0;

    // 插入測試題目
    int q1Id = await db.insert('questions', <String, Object?>{
          'user_id': 'u2',
          'text': '中國歷史上第一個大一統的帝國是？',
          'options': jsonEncode(['漢朝', '秦朝', '唐朝', '宋朝']),
          'answer': '1',
          'explanation': '秦始皇統一六國，建立秦朝，為第一個大一統帝國。',
          'subject': '歷史',
          'difficulty': '易',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    int q2Id = await db.insert('questions', <String, Object?>{
          'user_id': 'u2',
          'text': '下列何者為牛頓第二運動定律公式？',
          'options': jsonEncode(['F = ma', 'E = mc²', 'V = IR', 'P = IV']),
          'answer': '0',
          'explanation': '牛頓第二運動定律公式為 F = ma。',
          'subject': '理化',
          'difficulty': '中',
          'bookmarked': 0
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);

    if (historyTagId > 0 && q1Id > 0) {
      await db.insert('question_tag_map', <String, Object?>{'question_id': q1Id, 'tag_id': historyTagId},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    if (physicsTagId > 0 && q2Id > 0) {
      await db.insert('question_tag_map', <String, Object?>{'question_id': q2Id, 'tag_id': physicsTagId},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
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
    await db.update('users', <String, Object?>{
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
        },
        where: 'id = ?',
        whereArgs: ['u4']);
  }

  Future<void> _seedChapterQuestions(Database db, String subject,
      String chapter, List<Map<String, dynamic>> mockData) async {
    await db.insert('tags', <String, Object?>{'name': chapter},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    final tagRow = await db.query('tags',
        where: 'name = ?', whereArgs: [chapter], limit: 1);
    if (tagRow.isEmpty) return;
    final tagId = tagRow.first['id'] as int;

    for (final item in mockData) {
      final qId = await db.insert('questions', <String, Object?>{
            'user_id': 'u2',
            'text': item['text'],
            'options': jsonEncode(item['options']),
            'answer': item['answer'].toString(),
            'explanation': item['explanation'] ?? '',
            'subject': subject,
            'difficulty': item['difficulty'] ?? '中',
            'type': '單選題',
            'is_public': 1,
            'bookmarked': 0,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);

      if (qId > 0) {
        await db.insert('question_tag_map', <String, Object?>{
              'question_id': qId,
              'tag_id': tagId,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  Future<void> _seedAllChapterMockQuestions(Database db) async {
    final Map<String, Map<String, List<Map<String, dynamic>>>> data = {
      '資訊管理': {
        '第一章 資訊系統簡介': [
          {
            'text': '資訊系統（IS）的四大基本元件不包含下列何者？',
            'options': ['硬體設備', '應用軟體', '資料庫', '咖啡機'],
            'answer': '3',
            'explanation': '咖啡機非資訊系統基本元件。',
            'difficulty': '易'
          },
          {
            'text': '企業流程再造（BPR）的核心思想是什麼？',
            'options': ['微調流程', '根本性重新思考與徹底翻修流程', '增加更多管理階層', '購買更多伺服器'],
            'answer': '1',
            'explanation': 'BPR 旨在進行根本性與徹底的變革。',
            'difficulty': '中'
          },
          {
            'text': '什麼系統旨在支援高階主管的非結構化決策？',
            'options': ['TPS', 'MIS', 'ESS / EIS', 'DSS'],
            'answer': '2',
            'explanation': '主管支援系統（ESS）主要針對高階主管策略決策。',
            'difficulty': '難'
          },
          {
            'text': '顧客關係管理系統的英文簡稱是？',
            'options': ['ERP', 'SCM', 'CRM', 'KMS'],
            'answer': '2',
            'explanation': 'Customer Relationship Management 簡稱 CRM。',
            'difficulty': '易'
          },
          {
            'text': '供應鏈管理系統（SCM）主要管理什麼？',
            'options': ['客戶抱怨', '產品從原材料到最終消費者的流動', '員工考勤', '財務報表'],
            'answer': '1',
            'explanation': 'SCM 覆蓋供應鏈上下游物流、資訊流與金流。',
            'difficulty': '中'
          },
          {
            'text': '下列何者是知識管理系統（KMS）的範疇？',
            'options': ['員工請假單', '企業內部最佳實踐庫', '資料庫備份檔', '薪資轉帳清單'],
            'answer': '1',
            'explanation': 'KMS 用於捕捉、儲存與分享企業內部隱性與顯性知識。',
            'difficulty': '中'
          },
          {
            'text': '企業資源規劃（ERP）的最大價值在於？',
            'options': ['分散各部門系統', '高度整合的單一資料庫與跨部門流程', '加速網頁載入', '自動回覆郵件'],
            'answer': '1',
            'explanation': 'ERP 強調企業流程與資訊的整合性。',
            'difficulty': '中'
          },
          {
            'text': '雲端運算提供軟體作為服務的模式稱為？',
            'options': ['IaaS', 'PaaS', 'SaaS', 'DaaS'],
            'answer': '2',
            'explanation': 'Software as a Service 簡稱 SaaS。',
            'difficulty': '易'
          },
          {
            'text': '下列何者不屬於企業數位轉型的核心支柱？',
            'options': ['優化營運流程', '改善客戶體驗', '維持傳統封閉文化', '創新商業模式'],
            'answer': '2',
            'explanation': '數位轉型需要組織文化的開放與敏捷。',
            'difficulty': '難'
          },
          {
            'text': '大數據的「5V」特性中，Velocity 指的是什麼？',
            'options': ['資料真實性', '資料多樣性', '資料處理與產生的速度', '資料海量規模'],
            'answer': '2',
            'explanation': 'Velocity 代表速度；Volume 為規模，Variety 為多樣性。',
            'difficulty': '中'
          },
        ],
        '第二章 資料庫管理': [
          {
            'text': '在關聯式資料庫中，用來建立資料表之間關聯的欄位稱為？',
            'options': [
              '主鍵 Primary Key',
              '外鍵 Foreign Key',
              '索引 Index',
              '唯一鍵 Unique Key'
            ],
            'answer': '1',
            'explanation': '外鍵（FK）用於參照另一個表的主鍵以建立關聯。',
            'difficulty': '中'
          },
          {
            'text': '資料庫的「正規化」主要用來解決什麼問題？',
            'options': ['加快查詢速度', '資料重複性與更新異常', '增加資料表的欄位數', '加強資料加密防護'],
            'answer': '1',
            'explanation': '正規化（Normalization）是為了消除贅餘資料，避免新增、修改、刪除異常。',
            'difficulty': '中'
          },
          {
            'text': '下列何者是用來保證資料庫交易（Transaction）的安全屬性？',
            'options': ['HTML特性', 'ACID特性', 'RESTful API', 'MVC架構'],
            'answer': '1',
            'explanation': 'ACID 包括：原子性、一致性、隔離性、持久性。',
            'difficulty': '易'
          },
          {
            'text': '在SQL中，用於修改資料表中現有資料的指令是？',
            'options': ['INSERT', 'UPDATE', 'ALTER', 'MODIFY'],
            'answer': '1',
            'explanation': 'UPDATE 用來修改資料列內容；ALTER 用來修改資料表結構。',
            'difficulty': '易'
          },
          {
            'text': 'SQL查詢中，若要去除重複的結果，應使用哪一個關鍵字？',
            'options': ['UNIQUE', 'DISTINCT', 'ONLY', 'DIFFERENT'],
            'answer': '1',
            'explanation': 'SELECT DISTINCT 用於回傳不重複的資料。',
            'difficulty': '易'
          },
          {
            'text': '資料庫管理系統（DBMS）不包含下列哪項功能？',
            'options': ['資料定義', '資料操作', '硬體零件組裝', '並行控制與安全維護'],
            'answer': '2',
            'explanation': 'DBMS 屬於系統軟體，不負責硬體組裝。',
            'difficulty': '易'
          },
          {
            'text': '實體完整性規則（Entity Integrity）要求主鍵欄位不能為什麼？',
            'options': ['零字串', '負數', '空值 Null', '重複值'],
            'answer': '2',
            'explanation': '主鍵欄位不能為 Null 且必須唯一。',
            'difficulty': '中'
          },
          {
            'text': 'NoSQL 資料庫如 MongoDB 主要是哪種類型的資料庫？',
            'options': [
              '鍵值 (Key-Value) 型',
              '文件 (Document) 型',
              '圖形 (Graph) 型',
              '關係 (Relational) 型'
            ],
            'answer': '1',
            'explanation': 'MongoDB 是最著名的文件型 NoSQL 資料庫，儲存 JSON/BSON 格式。',
            'difficulty': '難'
          },
          {
            'text': '在SQL中，如何從資料表刪除整張表結構？',
            'options': [
              'DELETE TABLE',
              'TRUNCATE TABLE',
              'DROP TABLE',
              'REMOVE TABLE'
            ],
            'answer': '2',
            'explanation': 'DROP TABLE 刪除結構與所有資料；DELETE 僅刪除資料列。',
            'difficulty': '中'
          },
          {
            'text': '資料庫交易 ACID 特性中的「I」（Isolation）代表什麼意思？',
            'options': ['一致性', '隔離性，指多個交易並行執行時不受干擾', '不可分割性', '持久性'],
            'answer': '1',
            'explanation': 'Isolation（隔離性）確保並行交易的執行結果如同序列化執行一般。',
            'difficulty': '難'
          },
        ]
      },
      '國文': {
        '師說': [
          {
            'text': '韓愈〈師說〉中，「師者，所以傳道、受業、解惑也」的「受」通何字？',
            'options': ['授', '收', '守', '壽'],
            'answer': '0',
            'explanation': '「受」通「授」，指傳授。',
            'difficulty': '易'
          },
          {
            'text': '〈師說〉作者韓愈字什麼？',
            'options': ['退之', '子厚', '介甫', '微之'],
            'answer': '0',
            'explanation': '韓愈字退之，柳宗元字子厚，王安石字介甫，元稹字微之。',
            'difficulty': '易'
          },
          {
            'text': '韓愈被列為「唐宋八大家」之首，蘇軾讚譽他「文起八代之衰，而道濟天下之溺」。這「八代」指的是哪些朝代？',
            'options': ['東漢至隋', '戰國至西漢', '唐宋金元', '秦漢晉唐'],
            'answer': '0',
            'explanation': '八代指東漢、魏、晉、宋、齊、梁、陳、隋，駢文盛行而古文衰弱。',
            'difficulty': '難'
          },
          {
            'text': '〈師說〉中，「巫、醫、樂師、百工之人，君子不齒」的「不齒」意指？',
            'options': ['不刷牙', '不願提及', '看不起，不屑與之並列', '沒有牙齒'],
            'answer': '2',
            'explanation': '齒有並列之意，不齒代表不屑與之並列、瞧不起。',
            'difficulty': '中'
          },
          {
            'text': '「聖人無常師」這句話在〈師說〉中是用來證明什麼？',
            'options': ['聖人不需要老師', '聖人沒有固定的老師，應該廣泛學習', '聖人都很聰明', '老師不重要'],
            'answer': '1',
            'explanation': '韓愈引用孔子師事郯子、萇弘等，證明「弟子不必不如師，師不必賢於弟子」。',
            'difficulty': '中'
          },
          {
            'text': '〈師說〉中「六藝經傳皆通習之」的「傳」字讀音與字義為何？',
            'options': ['ㄓㄨㄢˋ，解釋經書的著作', 'ㄔㄨㄢˊ，遞送', 'ㄓㄨㄢˋ，傳記小說', 'ㄔㄨㄢˊ，推廣'],
            'answer': '0',
            'explanation': '傳讀「ㄓㄨㄢˋ」，指解釋經義的文字或註釋。',
            'difficulty': '中'
          },
          {
            'text': '〈師說〉中，「句讀之不知，惑之不解，或師焉，或不焉」的「不」通何字？',
            'options': ['否', '弗', '勿', '無'],
            'answer': '0',
            'explanation': '「不」通「否」，讀作ㄈㄡˇ，指句讀去向老師學習，惑卻不向老師請教。',
            'difficulty': '中'
          },
          {
            'text': '下列關於韓愈的敘述，何者錯誤？',
            'options': [
              '自署「郡望昌黎」，世稱「韓昌黎」',
              '倡導古文運動，主張「文以載道」',
              '與柳宗元同為中唐古文運動領袖',
              '極力尊崇佛老，寫下〈諫迎佛骨表〉以表支持'
            ],
            'answer': '3',
            'explanation': '韓愈是辟佛老的代表，〈諫迎佛骨表〉是反對迎佛骨而非支持。',
            'difficulty': '難'
          },
          {
            'text': '〈師說〉：「是故無貴無賤，無長無少，道之所存，師之所存也。」這句話表達的觀點是？',
            'options': ['擇師的標準在於對方是否擁有真理（道）', '年紀大的人才有道', '貴族不需要拜師', '知識是有階級的'],
            'answer': '0',
            'explanation': '只要對方有「道」，不論貴賤長幼，皆可為師。',
            'difficulty': '易'
          },
          {
            'text': '下列何者不是古文運動所反對的文風？',
            'options': ['駢文', '講求對仗、聲律的文體', '樸實無華的散文', '華而不實的偶麗文字'],
            'answer': '2',
            'explanation': '古文運動反對六朝以來的駢儷文，主張恢復先秦裝飾偶麗文。',
            'difficulty': '易'
          },
        ],
        '出師表': [
          {
            'text': '諸葛亮〈出師表〉：「先帝創業未半，而中道崩殂。」「崩殂」在古代指誰的過世？',
            'options': ['百姓', '諸侯', '帝王', '士大夫'],
            'answer': '2',
            'explanation': '天子死曰崩，諸侯死曰薨，大夫死曰卒，士死曰不祿，庶人死曰死。',
            'difficulty': '易'
          },
          {
            'text': '諸葛亮在〈出師表〉中，建議後主劉禪治理國家首先應做到？',
            'options': ['廣開言路（開張聖聽）', '嚴刑峻法', '窮兵黷武', '偏聽偏信'],
            'answer': '0',
            'explanation': '「誠宜開張聖聽，以光先帝遺德，恢弘志士之氣」。',
            'difficulty': '中'
          },
          {
            'text': '〈出師表〉中，「陟罰臧否，不宜異同」的「臧否」意思為何？',
            'options': ['褒貶、善惡', '升遷、降職', '同意、反對', '高低、胖瘦'],
            'answer': '0',
            'explanation': '臧是善，否是惡。臧否即褒獎善的，懲罰惡的。',
            'difficulty': '中'
          },
          {
            'text': '「臣本布衣，躬耕於南陽。」句中「布衣」借代為？',
            'options': ['農夫', '平民百姓', '讀書人', '隱士'],
            'answer': '1',
            'explanation': '古代平民穿麻布衣服，故以「布衣」代指平民。',
            'difficulty': '易'
          },
          {
            'text': '諸葛亮寫〈出師表〉的背景是準備進行什麼軍事行動？',
            'options': ['聯吳抗曹', '北伐曹魏', '平定南方孟獲', '東征孫吳'],
            'answer': '1',
            'explanation': '當時蜀漢平定南方，諸葛亮上表準備率軍北伐魏國。',
            'difficulty': '易'
          },
          {
            'text': '〈出師表〉中，「三顧臣於草廬之中，諮臣以當世之事」指的是先主劉備的什麼典故？',
            'options': ['單刀赴會', '草船借箭', '三顧茅廬', '桃園三結義'],
            'answer': '2',
            'explanation': '指劉備三次拜訪諸葛亮草廬請其出山的歷史事件。',
            'difficulty': '易'
          },
          {
            'text': '「受任於敗軍之際，奉命於難妥之間」這句話展現了諸葛亮的什麼精神？',
            'options': ['臨危受命，勇於擔當', '推諉責任', '無奈悲觀', '居功自傲'],
            'answer': '0',
            'explanation': '寫出在最艱難、失敗的關頭挑起重擔的忠誠與擔當。',
            'difficulty': '中'
          },
          {
            'text': '諸葛亮在〈出師表〉中極力推薦的賢臣不包括下列哪一位？',
            'options': ['郭攸之', '費禕', '董允', '魏延'],
            'answer': '3',
            'explanation': '諸葛亮推薦了郭攸之、費禕、董允、向寵等人。',
            'difficulty': '難'
          },
          {
            'text': '〈出師表〉中，「臨表涕泣，不知所云」的「涕」字在古代漢語中主要指？',
            'options': ['鼻涕', '眼淚', '汗水', '口水'],
            'answer': '1',
            'explanation': '古語中「涕」指眼淚。',
            'difficulty': '中'
          },
          {
            'text': '下列關於諸葛亮〈出師表〉寫作風格的評語，何者最貼切？',
            'options': [
              '詞藻華麗，氣勢磅礡',
              '動之以情，曉之以理，情深意切',
              '冷酷嚴肅，條理分明',
              '幽默風趣，寓意深遠'
            ],
            'answer': '1',
            'explanation': '〈出師表〉以肺腑之言勸諫後主，字字忠貞。',
            'difficulty': '中'
          },
        ]
      },
      '數學': {
        '面積': [
          {
            'text': '正方形邊長為 a，其面積公式為何？',
            'options': ['4a', 'a²', '2a', 'a³'],
            'answer': '1',
            'explanation': '正方形面積 = 邊長 x 邊長 = a²。',
            'difficulty': '易'
          },
          {
            'text': '直角三角形兩直角邊分別為 6 和 8，則其面積為多少？',
            'options': ['24', '48', '14', '10'],
            'answer': '0',
            'explanation': '三角形面積 = 6 x 8 / 2 = 24。',
            'difficulty': '易'
          },
          {
            'text': '半徑為 r 的圓形面積公式為何？',
            'options': ['2πr', 'πr²', 'πd', '4πr²'],
            'answer': '1',
            'explanation': '圓面積 = πr²。',
            'difficulty': '易'
          },
          {
            'text': '平行四邊形底為 10，高為 5，則其面積為何？',
            'options': ['25', '50', '15', '20'],
            'answer': '1',
            'explanation': '平行四邊形面積 = 底 x 高 = 10 x 5 = 50。',
            'difficulty': '易'
          },
          {
            'text': '梯形上底為 4，下底為 6，高為 5，則其面積為？',
            'options': ['25', '50', '24', '30'],
            'answer': '0',
            'explanation': '梯形面積 = (4 + 6) x 5 / 2 = 25。',
            'difficulty': '中'
          },
          {
            'text': '若一個圓的直徑為 10，則其面積為多少？（π以 3.14 計算）',
            'options': ['314', '78.5', '157', '25'],
            'answer': '1',
            'explanation': '半徑 r = 5，面積 = 5² x 3.14 = 78.5。',
            'difficulty': 'Ref'
          },
          {
            'text': '扇形半徑為 6，圓心角為 60 度，則此扇形面積為多少？',
            'options': ['6π', '36π', '12π', '8π'],
            'answer': '0',
            'explanation': '36π x (60/360) = 6π。',
            'difficulty': '中'
          },
          {
            'text': '菱形的兩條對角線長分別為 12 和 16，則其面積為多少？',
            'options': ['192', '96', '28', '48'],
            'answer': '1',
            'explanation': '菱形面積 = 12 x 16 / 2 = 96。',
            'difficulty': '中'
          },
          {
            'text': '正三角形邊長為 4，其面積為多少？',
            'options': ['4√3', '2√3', '8√3', '16'],
            'answer': '0',
            'explanation': '正三角形面積公式為 (√3/4) * s² = 4√3。',
            'difficulty': '難'
          },
          {
            'text': '邊長為 5, 12, 13 的三角形，其面積為多少？',
            'options': ['30', '60', '78', '32.5'],
            'answer': '0',
            'explanation': '5-12-13為直角三角形，面積 = 5 x 12 / 2 = 30。',
            'difficulty': '難'
          },
        ],
        '機率': [
          {
            'text': '同時丟擲兩枚公正的硬幣，兩枚皆為正面的機率是多少？',
            'options': ['1/2', '1/4', '3/4', '1/3'],
            'answer': '1',
            'explanation': '正正機率為 1/4。',
            'difficulty': '易'
          },
          {
            'text': '投擲一顆公正的六面骰子，點數為偶數的機率為多少？',
            'options': ['1/2', '1/3', '1/6', '2/3'],
            'answer': '0',
            'explanation': '2, 4, 6 共 3 種情況，機率 = 3/6 = 1/2。',
            'difficulty': '易'
          },
          {
            'text': '袋中有紅球 3 個、黃球 2 個，隨機抽取一球，抽中紅球的機率是多少？',
            'options': ['3/5', '2/5', '1/2', '1/3'],
            'answer': '0',
            'explanation': '紅球佔 3/5。',
            'difficulty': '易'
          },
          {
            'text': '袋中有紅球 3 個、白球 5 個，每次取一球不放回，連取兩次，皆為紅球的機率？',
            'options': ['9/64', '3/28', '9/56', '5/14'],
            'answer': '1',
            'explanation': '3/8 x 2/7 = 6/56 = 3/28。',
            'difficulty': '難'
          },
          {
            'text': '從一副撲克牌中隨機抽取一張，抽到黑桃A的機率為多少？',
            'options': ['1/52', '1/13', '1/4', '4/52'],
            'answer': '0',
            'explanation': '黑桃A只有一張，機率 = 1/52。',
            'difficulty': '易'
          },
          {
            'text': '甲、乙兩人比賽，甲贏的機率是 0.6，如果進行三戰兩勝制比賽（不考慮和局），甲獲勝的機率是多少？',
            'options': ['0.648', '0.36', '0.72', '0.5'],
            'answer': '0',
            'explanation': '0.36 + 0.144 + 0.144 = 0.648。',
            'difficulty': '難'
          },
          {
            'text': '任選一個二位數正整數，該數是 5 的倍數之機率是多少？',
            'options': ['1/5', '18/90', '1/10', '19/90'],
            'answer': '0',
            'explanation': '18/90 = 1/5。',
            'difficulty': '中'
          },
          {
            'text': '某測試通過率為 80%。若隨機選取 3 人參加測試，至少有 1 人通過的機率為多少？',
            'options': ['0.992', '0.512', '0.8', '0.96'],
            'answer': '0',
            'explanation': '1 - 0.2³ = 0.992。',
            'difficulty': '難'
          },
          {
            'text': '若事件 A 與事件 B 為獨立事件，P(A) = 0.5, P(B) = 0.4，則 P(A ∩ B) 為多少？',
            'options': ['0.9', '0.1', '0.2', '0.3'],
            'answer': '2',
            'explanation': '0.5 x 0.4 = 0.2。',
            'difficulty': '中'
          },
          {
            'text': '同時丟擲三顆公正骰子，點數和為 4 的機率是多少？',
            'options': ['3/216', '1/72', '1/216', '4/216'],
            'answer': '0',
            'explanation': '情況有 (1,1,2), (1,2,1), (2,1,1)，機率 = 3/216 = 1/72。',
            'difficulty': '難'
          },
        ]
      },
      '歷史': {
        '台灣史': [
          {
            'text': '台灣歷史上著名的「牡丹社事件」發生於哪一個時期？',
            'options': ['荷蘭時期', '鄭氏時期', '清領時期', '日治時期'],
            'answer': '2',
            'explanation': '牡丹社事件發生於 1874 年。',
            'difficulty': '中'
          },
          {
            'text': '台灣歷史上的「二二八事件」爆發於西元哪一年？',
            'options': ['1945年', '1947年', '1949年', '1950年'],
            'answer': '1',
            'explanation': '二二八事件爆發於 1947 年。',
            'difficulty': '易'
          },
          {
            'text': '日治時期，帶領台灣民眾爭取設立台灣議會，領導請願運動的先驅是誰？',
            'options': ['蔣渭水', '林獻堂', '賴和', '羅福星'],
            'answer': '1',
            'explanation': '林獻堂為台灣自治運動領袖。',
            'difficulty': '難'
          },
          {
            'text': '荷蘭人在淡水建造了哪座著名的城堡？',
            'options': ['安平古堡', '熱蘭遮城', '紅毛城', '億載金城'],
            'answer': '2',
            'explanation': '西班牙人建聖多明哥城，荷蘭人重建後被稱為紅毛城。',
            'difficulty': '中'
          },
          {
            'text': '鄭成功率軍擊敗荷蘭人，於台灣建立的第一個漢人政權，史稱？',
            'options': ['東寧王國', '福爾摩沙共和國', '台灣民主國', '明朝內閣'],
            'answer': '0',
            'explanation': '鄭氏政權史稱東寧王國。',
            'difficulty': '中'
          },
          {
            'text': '清廷在甲午戰爭失敗後，與日本簽訂哪一個條約將台灣割讓給日本？',
            'options': ['南京條約', '馬關條約', '辛丑條約', '北京條約'],
            'answer': '1',
            'explanation': '1895年簽訂《馬關條約》割讓台澎。',
            'difficulty': '易'
          },
          {
            'text': '台灣在 1970 年代推動的重大基礎建設工程，史稱？',
            'options': ['六年國建', '十大建設', '新十大建設', '振興方案'],
            'answer': '1',
            'explanation': '十大建設奠定了台灣現代化工業的基礎。',
            'difficulty': '易'
          },
          {
            'text': '日治時期台灣總督府為壓制台灣抗日意識，推動的「皇民化運動」不包括下列哪一項措施？',
            'options': ['鼓勵說日語', '改用日本姓名', '全面推廣漢文教育', '參拜神社'],
            'answer': '2',
            'explanation': '皇民化運動期間廢止了報紙漢文版，限制漢文。',
            'difficulty': '中'
          },
          {
            'text': '清領時期，台灣因為茶葉、樟腦的出口，導致經濟重心產生了什麼變化？',
            'options': ['南重北輕轉為北重南輕', '完全衰退', '東部開發超越西部', '城鄉差距縮小'],
            'answer': '0',
            'explanation': '茶葉與樟腦出口使北部崛起，重心北移。',
            'difficulty': '難'
          },
          {
            'text': '台灣原住民中，以「矮靈祭（巴斯達隘）」聞名的是哪一族？',
            'options': ['阿美族', '泰雅族', '賽夏族', '排灣族'],
            'answer': '2',
            'explanation': '巴斯達隘是賽夏族重要祭典。',
            'difficulty': '中'
          },
        ],
        '中國史': [
          {
            'text': '漢武帝時期，為獨尊儒術，採納了哪位學者的建議？',
            'options': ['董仲舒', '李斯', '賈誼', '司馬遷'],
            'answer': '0',
            'explanation': '董仲舒提出「罷黜百家，獨尊儒術」。',
            'difficulty': '中'
          },
          {
            'text': '唐朝歷史上著名的「貞觀之治」是哪一位皇帝的治世？',
            'options': ['唐太宗', '唐高祖', '唐玄宗', '唐高宗'],
            'answer': '0',
            'explanation': '唐太宗李世民年號貞觀。',
            'difficulty': '易'
          },
          {
            'text': '中國歷史上唯一得到普遍承認的女皇帝是？',
            'options': ['慈禧太后', '武則天', '呂后', '王昭君'],
            'answer': '1',
            'explanation': '武則天改唐為周。',
            'difficulty': '易'
          },
          {
            'text': '北宋時期，為解決財政與軍事危機，推動熙寧變法的宰相是？',
            'options': ['王安石', '司馬光', '蘇軾', '寇準'],
            'answer': '0',
            'explanation': '王安石於宋神宗時期推動新法。',
            'difficulty': '中'
          },
          {
            'text': '元朝是由哪一個民族所建立的？',
            'options': ['滿族', '蒙古族', '契丹族', '女真族'],
            'answer': '1',
            'explanation': '忽必烈建立元朝，為蒙古族政權。',
            'difficulty': '易'
          },
          {
            'text': '清朝康熙、雍正、乾隆三代被稱為？',
            'options': ['開皇之治', '康雍乾盛世', '同光中興', '光武中興'],
            'answer': '1',
            'explanation': '康熙、雍正、乾隆三朝的一百多年為清朝發展巔峰，稱康雍乾盛世。',
            'difficulty': '易'
          },
          {
            'text': '三國時期，奠定赤壁之戰「三分天下」基礎的蜀漢謀士是？',
            'options': ['周瑜', '諸葛亮', '司馬懿', '龐統'],
            'answer': '1',
            'explanation': '諸葛亮隆中對策，促成三分天下。',
            'difficulty': '中'
          },
          {
            'text': '秦始皇為鞏固中央集權，採納李斯建議推動了什麼思想控制政策？',
            'options': ['百家爭鳴', '焚書坑儒', '獨尊儒術', '黃老治術'],
            'answer': '1',
            'explanation': '秦始皇下令焚毀百家書籍，史稱焚書坑儒。',
            'difficulty': '中'
          },
          {
            'text': '明朝時期，率領龐大船隊七次下西洋的太監是？',
            'options': ['鄭和', '魏忠賢', '李蓮英', '趙高'],
            'answer': '0',
            'explanation': '鄭和於永樂、宣德年間七下西洋。',
            'difficulty': '易'
          },
          {
            'text': '中國歷史上由盛轉衰的關鍵戰亂「安史之亂」發生於哪一個朝代？',
            'options': ['漢朝', '唐朝', '宋朝', '明朝'],
            'answer': '1',
            'explanation': '安史之亂是唐代由盛轉衰的轉折點。',
            'difficulty': '中'
          },
        ],
        '世界史': [
          {
            'text': '文藝復興運動最早發源於哪一個國家？',
            'options': ['英國', '法國', '義大利', '德國'],
            'answer': '2',
            'explanation': '文藝復興發源於 14 世紀的義大利城市。',
            'difficulty': '中'
          },
          {
            'text': '發起宗教改革，發表《九十五條論綱》對抗羅馬天主氣的歷史人物是？',
            'options': ['馬丁·路德', '喀爾文', '亨利八世', '羅耀拉'],
            'answer': '0',
            'explanation': '1517年馬丁·路德發表《九十五條論綱》。',
            'difficulty': '中'
          },
          {
            'text': '工業革命最早於 18 世紀中期爆發於哪一個國家？',
            'options': ['美國', '法國', '德國', '英國'],
            'answer': '3',
            'explanation': '英國最早爆發工業革命。',
            'difficulty': '易'
          },
          {
            'text': '法國大革命爆發的標誌性事件是 1789 年巴黎市民攻佔了哪座監獄？',
            'options': ['巴士底監獄', '凡爾賽宮', '羅浮宮', '倫敦塔'],
            'answer': '0',
            'explanation': '1789 年 7 月 14 日巴黎群眾攻佔巴士底監獄。',
            'difficulty': '易'
          },
          {
            'text': '提出「日心說」挑戰教會權威，並寫下《天體運行論》的科學家是？',
            'options': ['伽利略', '哥白尼', '牛頓', '愛因斯坦'],
            'answer': '1',
            'explanation': '哥白尼提出太陽中心說，動搖了宇宙神學觀。',
            'difficulty': '中'
          },
          {
            'text': '美國《獨立宣言》是於西元哪一年發表，標誌著美國的誕生？',
            'options': ['1776年', '1789年', '1861年', '1914年'],
            'answer': '0',
            'explanation': '1776年7月4日發表《獨立宣言》。',
            'difficulty': '易'
          },
          {
            'text': '第一次世界大戰的導火線是發生於薩拉耶夫的什麼事件？',
            'options': ['奧匈帝國皇儲斐迪南大公遇刺', '雷根號事件', '德國入侵波蘭', '珍珠港事件'],
            'answer': '0',
            'explanation': '奧匈皇儲遇刺引爆了一戰。',
            'difficulty': '中'
          },
          {
            'text': '第二次世界大戰中，日本偷襲美國哪一個港口，促使美國正式參戰？',
            'options': ['諾曼第', '中途島', '珍珠港', '雪梨港'],
            'answer': '2',
            'explanation': '1941年12月日軍偷襲珍珠港。',
            'difficulty': '易'
          },
          {
            'text': '古代歐洲的「民主政治」最早發源於哪一個城邦？',
            'options': ['雅典', '斯巴達', '羅馬', '迦太基'],
            'answer': '0',
            'explanation': '雅典的公民大會奠定了西方民主制度的雛形。',
            'difficulty': '易'
          },
          {
            'text': '冷戰時期，象徵東西方分裂、最著名的實體地標圍牆是？',
            'options': ['長城', '柏林圍牆', '哈德良長城', '巴以隔離牆'],
            'answer': '1',
            'explanation': '柏林圍牆分割了東西德。',
            'difficulty': '易'
          },
        ]
      },
      '理化': {
        '力學': [
          {
            'text': '牛頓第一運動定律又被稱為什麼定律？',
            'options': ['加速度定律', '慣性定律', '作用力與反作用力定律', '萬有引力定律'],
            'answer': '1',
            'explanation': '即慣性定律。',
            'difficulty': '易'
          },
          {
            'text': '在彈性限度內，彈簧的伸長量與所受外力成正比，這稱為什麼定律？',
            'options': ['牛頓定律', '虎克定律', '阿基米德原理', '帕斯卡原理'],
            'answer': '1',
            'explanation': 'F = kx 為虎克定律公式。',
            'difficulty': '易'
          },
          {
            'text': '物體所受的合力為零時，下列敘述何者正確？',
            'options': ['物體必定靜止', '物體必定在運動', '物體必定沒有速度', '物體必定無加速度（靜止或等速度運動）'],
            'answer': '3',
            'explanation': '合力為零代表加速度為零。',
            'difficulty': '中'
          },
          {
            'text': '在地球表面，一個質量為 10 公斤的物體，所受的重力約為多少牛頓？（g以 9.8 m/s² 計算）',
            'options': ['10', '98', '1', '9.8'],
            'answer': '1',
            'explanation': 'F = mg = 10 x 9.8 = 98 N。',
            'difficulty': '中'
          },
          {
            'text': '摩擦力的大小與下列哪一項因素無關？',
            'options': ['接觸面的粗糙程度', '垂直壓在接觸面上的正向力', '接觸面積的大小', '接觸面之間的滑動狀態'],
            'answer': '2',
            'explanation': '最大靜摩擦力與接觸面積無關。',
            'difficulty': '難'
          },
          {
            'text': '功率的國際標準單位（SI）是什麼？',
            'options': ['焦耳 (J)', '瓦特 (W)', '牛頓 (N)', '帕斯卡 (Pa)'],
            'answer': '1',
            'explanation': '功率單位為瓦特（W）。',
            'difficulty': '易'
          },
          {
            'text': '功的公式為 W = Fs，若施力方向與物體位移方向垂直，則施力對物體作功多少？',
            'options': ['正功', '負功', '不作功（功為零）', '無限大'],
            'answer': '2',
            'explanation': '當施力與位移垂直時，夾角為 90 度，作功為 0。',
            'difficulty': '中'
          },
          {
            'text': '動能的公式與下列哪兩項因素有關？',
            'options': ['質量與高度', '力與時間', '質量與速度的平方', '彈性係數與伸長量'],
            'answer': '2',
            'explanation': '動能 Ek = (1/2)mv²。',
            'difficulty': '易'
          },
          {
            'text': '阿基米德原理指出，物體在液體中所受的浮力等於什麼？',
            'options': ['物體的重量', '物體排開液體的重量', '液體的密度', '物體的體積'],
            'answer': '1',
            'explanation': '即排開液體的重量。',
            'difficulty': '中'
          },
          {
            'text': '槓桿原理中，當達到平衡時，順時針力矩必須等於什麼？',
            'options': ['逆時針力矩', '支點壓力', '施力大小', '抗力大小'],
            'answer': '0',
            'explanation': '力矩平衡條件：順時針力矩 = 逆時針力矩。',
            'difficulty': '易'
          },
        ],
        '電磁學': [
          {
            'text': '電荷間作用力與它們電荷乘積成正比，與距離的平方成反比，這稱為什麼定律？',
            'options': ['安培定律', '庫侖定律', '法拉第定律', '高斯定律'],
            'answer': '1',
            'explanation': 'F = k * (q1*q2)/r² 為庫侖定律。',
            'difficulty': '易'
          },
          {
            'text': '下列何者是電阻的國際標準單位？',
            'options': ['安培 (A)', '伏特 (V)', '歐姆 (Ω)', '瓦特 (W)'],
            'answer': '2',
            'explanation': '電阻單位為歐姆（Ω）。',
            'difficulty': '易'
          },
          {
            'text': '歐姆定律的公式 V = IR 中，I 代表什麼？',
            'options': ['電壓', '電阻', '電流', '電功率'],
            'answer': '2',
            'explanation': 'I 代表電流。',
            'difficulty': '易'
          },
          {
            'text': '若將兩個 10 歐姆的電阻「串聯」在一起，其總電阻為多少歐姆？',
            'options': ['5', '10', '20', '100'],
            'answer': '2',
            'explanation': '串聯總電阻 = 10 + 10 = 20 Ω。',
            'difficulty': '易'
          },
          {
            'text': '若將兩個 10 歐姆的電阻「並聯」在一起，其總電阻為多少歐姆？',
            'options': ['5', '10', '20', '100'],
            'answer': '0',
            'explanation': '並聯總電阻 = 5 Ω。',
            'difficulty': '中'
          },
          {
            'text': '磁力線的流動方向在磁鐵外部是如何規定的？',
            'options': ['從 S 極出發指向 N 極', '從 N 極出發指向 S 極', '無固定方向', '從中心向外擴散'],
            'answer': '1',
            'explanation': '外部磁力線由 N 極指向 S 極。',
            'difficulty': '易'
          },
          {
            'text': '法拉第電磁感應定律指出，當穿過封閉迴路的磁通量發生變化時，會產生什麼？',
            'options': ['靜電荷', '感應電動勢', '永久磁鐵', '電阻消失'],
            'answer': '1',
            'explanation': '磁通量變化產生感應電動勢。',
            'difficulty': '中'
          },
          {
            'text': '決定感應電流方向的物理定律是？',
            'options': ['安培右手定則', '冷次定律', '歐姆定律', '焦耳定律'],
            'answer': '1',
            'explanation': '冷次定律決定感應電流方向。',
            'difficulty': '中'
          },
          {
            'text': '電功率的計算公式 P = IV 中，若電壓不變，電流加倍，則電功率變為多少倍？',
            'options': ['2', '4', '1', '8'],
            'answer': '0',
            'explanation': 'P 與 I 成正比，功率變為 2 倍。',
            'difficulty': '中'
          },
          {
            'text': '家庭用電的「度」是哪一種物理量的單位？',
            'options': ['電流', '電壓', '能量（電能）', '電功率'],
            'answer': '2',
            'explanation': '1 度電 = 1 kWh，是能量單位。',
            'difficulty': '中'
          },
        ],
        '光學': [
          {
            'text': '光在真空中的傳播速度約為每秒多少公里？',
            'options': ['30萬', '3萬', '3000', '300'],
            'answer': '0',
            'explanation': '光速約為每秒 30 萬公里。',
            'difficulty': '易'
          },
          {
            'text': '光線由空氣斜射入水中時，其傳播方向會偏折，這種現象稱為什麼？',
            'options': ['光的反射', '光的折射', '光的直線傳播', '光的色散'],
            'answer': '1',
            'explanation': '光在不同介質速度不同產生折射。',
            'difficulty': '易'
          },
          {
            'text': '平面鏡成像的性質為何？',
            'options': ['實像、上下顛倒', '虛像、左右相反、大小相等', '實像、左右相反、放大', '虛像、正立、縮小'],
            'answer': '1',
            'explanation': '平面鏡成等大對稱虛像。',
            'difficulty': '易'
          },
          {
            'text': '下列何者是近視眼鏡所使用的透鏡類型？',
            'options': ['凹透鏡', '凸透鏡', '平面鏡', '凹面鏡'],
            'answer': '0',
            'explanation': '近視眼鏡使用凹透鏡將光線發散。',
            'difficulty': '中'
          },
          {
            'text': '將太陽光通過三稜鏡後，會分裂成七色光的現象，稱為什麼？',
            'options': ['光的折射', '光的色散', '光的干涉', '光的繞射'],
            'answer': '1',
            'explanation': '此為色散現象。',
            'difficulty': '中'
          },
          {
            'text': '凹透鏡成像的性質，不論物體放在何處，皆成什麼樣的像？',
            'options': ['倒立放大的實像', '正立放大的虛像', '正立縮小的虛像', '倒立縮小的實像'],
            'answer': '2',
            'explanation': '凹透鏡僅能成正立縮小虛像。',
            'difficulty': '中'
          },
          {
            'text': '光線反射時，入射角與反射角之關係為何？',
            'options': ['入射角大於反射角', '入射角小於反射角', '入射角等於反射角', '兩者夾角固定'],
            'answer': '2',
            'explanation': '反射角等於入射角。',
            'difficulty': '易'
          },
          {
            'text': '當光線從水射入空氣時，若入射角大於臨界角，光線會全部反射，此現象稱為？',
            'options': ['漫反射', '全反射', '繞射', '折射'],
            'answer': '1',
            'explanation': '此為全反射。',
            'difficulty': '難'
          },
          {
            'text': '彩虹的形成主要是太陽光經過空氣中的小水滴產生了哪兩種光學效應？',
            'options': ['反射與繞射', '折射與反射（色散）', '干涉與繞射', '直線傳播與漫反射'],
            'answer': '1',
            'explanation': '陽光經水滴折射、內反射再折射。',
            'difficulty': '中'
          },
          {
            'text': '照相機的鏡頭相當於哪一種透鏡？',
            'options': ['凹透鏡', '凸透鏡', '平面鏡', '雙凹透鏡'],
            'answer': '1',
            'explanation': '照相機鏡頭相當於凸透鏡。',
            'difficulty': '中'
          },
        ]
      }
    };

    for (final subject in data.keys) {
      final chapters = data[subject]!;
      for (final chapter in chapters.keys) {
        final mockList = chapters[chapter]!;
        await _seedChapterQuestions(db, subject, chapter, mockList);
      }
    }
    debugPrint(
        'Database Seeding: Inserted 120 chapter questions successfully!');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
