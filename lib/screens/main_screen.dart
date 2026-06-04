// ignore_for_file: prefer_final_fields
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart';
import '../widgets/common_widgets.dart';
import '../services/ai_intent_service.dart';
import 'question_list_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart';
import '../services/ai_diagnosis_service.dart';
import 'notes_screen.dart';

part 'main_screen_profile_tab.part.dart';
part 'main_screen_social_tab.part.dart';
part 'main_screen_activity_tab.part.dart';
part 'main_screen_leaderboard_tab.part.dart';

// 移除原本在這裡的 kPresetAvatars 與 _buildAvatar，已移至 common_widgets.dart

// ─────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────

// ── 社群貼文相關常量 (移至頂層以便分片檔案存取) ──
const Map<String, String?> kSocialFilterMap = {
  '全部': null,
  '📝 學習筆記': 'note',
  '💭 心情文章': 'mood',
  '📄 分享資料': 'doc',
};

const Map<String, String> kPostTypeLabel = {
  'note': '📝 學習筆記',
  'mood': '💭 心情文章',
  'doc': '📄 分享資料',
};

class MainScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final Future<void> Function() onLogout;
  const MainScreen(
      {super.key, required this.currentUser, required this.onLogout});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0; // 預設進日曆
  String _appBarTitle = "日曆行程";

  // --- 資料庫區 ---
  // 使用真實今天（只取年月日，去掉時分秒）
  String _calendarViewMode = 'dot';
  late final DateTime _simulatedToday;
  late DateTime _selectedDate;
  late DateTime _calendarMonth;
  late PageController _calendarPageController;
  late PageController _timelinePageController;

  Uint8List? _userAvatarBlob;
  int _userAvatarColor = 0;
  bool _userAvatarSelected = false;
  String? _userBio;
  double _fontSizeFactor = 1.0;
  int _themeColorIdx = 0;
  bool _isDarkMode = false;
  bool _showFloatingNavBar = false;
  String _socialFilter = '全部'; // 社群貼文分類筛選狀態
  bool _isEmailVerified = false;
  String? _displayName;

  Map<String, List<Map<String, dynamic>>> allSchedules = {};
  List<Map<String, dynamic>> allTodos = [];
  List<Map<String, dynamic>> socialPosts = [];
  List<Map<String, dynamic>> scheduledPosts = [];
  List<Map<String, dynamic>> questionBank = [];
  final ScrollController _chatScrollController = ScrollController();
  final ScrollController _profileScrollController = ScrollController();
  bool _isDisposed = false;

  // --- 學習歷程動態統計變數 ---
  double _todayStudyHours = 0.0;
  int _todayCompletedQuestions = 0;
  int _streakDays = 0;
  // 本週每日正確率 (0.0~100.0)，-1 代表當天無作答
  List<double> _weeklyAccuracyList = [-1, -1, -1, -1, -1, -1, -1];
  double _weeklyAvgAccuracy = -1; // 本週平均正確率，-1 代表無資料
  int _totalQuestionsAnswered = 0;
  int _selectedBarIndex = DateTime.now().weekday - 1;
  String _latestQuizScore = '暫無測驗紀錄';

  // --- 排行榜資料 ---
  List<Map<String, dynamic>> _leaderboardList = [];
  String _leaderboardSortType = 'accuracy'; // 'accuracy' | 'total'
  late DateTime _sessionStartTime;

  List<String> allSubjects = ['資訊管理', '作業系統', '國文', '數學', '微積分'];
  Map<String, List<String>> subjectChapters = {
    '資訊管理': ['第一章 資訊系統簡介', '第二章 資料庫管理'],
    '國文': ['師說', '出師表'],
    '數學': ['面積', '機率'],
  };

  // --- 狀態控制區 ---
  int _quizStep = 0;
  String _quizSelectedSubject = "";
  DiagnosisResult? _diagnosisResult;
  bool _isDiagnosing = false;
  // ignore: unused_field
  StateSetter? _sheetStateSetter;
  List<int> _lastQuizWrongIds = [];
  // ── 串流診斷狀態 ──
  String _streamedDiagnosisText = ''; // 逐步累積的串流文字
  StreamSubscription<String>? _diagnosisStreamSub; // 訂閱管理
  final List<String> _quizSelectedChapters = [];
  Map<String, Map<String, int>> _quizPickedCounts = {
    '單選題': {'易': 0, '中': 0, '難': 0},
    '是非題': {'易': 0, '中': 0, '難': 0},
    '申論題': {'易': 0, '中': 0, '難': 0}
  };
  Map<String, Map<String, int>> _availableCounts = {};
  final List<Map<String, dynamic>> _currentQuizQuestions = [];
  final Map<int, int> _userAnswers = {};
  Timer? _quizTimer;
  Timer? _scheduleTimer;
  final List<Timer> _postTimers = [];

  void _clearPostTimers() {
    for (var t in _postTimers) {
      t.cancel();
    }
    _postTimers.clear();
  }

  // ignore: unused_field
  int _remainingSeconds = 1800;
  final ScrollController _quizScrollController = ScrollController();

  // ignore: unused_field
  bool _showStudyAnswers = false;
  // ignore: unused_field
  String _studySearchQuery = "";

  // ignore: unused_field
  int _personalFilterIndex = 0;
  // ignore: unused_field
  String? _selectedFolder;
  // ignore: unused_field
  String? _selectedSubjectForStudy; // 新增：追蹤題庫中選擇的科目

  String _aiFlowState = 'none';
  Map<String, dynamic> _aiFlowData = {};

  int _aiReplyPostIndex = 0;
  List<Map<String, dynamic>> _aiPendingReplyPosts = [];

  List<Map<String, dynamic>> chatLogs = [
    {
      'isAI': true,
      'text':
          '哈囉👋 我是你的專屬代理人！很高興為您服務。😊\n\n我可以協助您管理行程、發佈貼文、回覆留言以及調整個人化設定。您可以隨時輸入「幫助」或點擊下方功能來了解更多！',
      'isCard': false
    },
    {'isAI': true, 'text': '', 'isCard': false, 'widgetType': 'help_options'}
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionStartTime = DateTime.now();
    // 初始化為真實今天（去掉時分秒）
    final now = DateTime.now();
    _simulatedToday = DateTime(now.year, now.month, now.day);
    _selectedDate = _simulatedToday;
    _calendarMonth = DateTime(now.year, now.month, 1);

    // 以 2026年3月 為基準 (page 12)，計算今天所在月份的頁碼
    const baseYear = 2026;
    const baseMonth = 3;
    final monthOffset = (now.year - baseYear) * 12 + (now.month - baseMonth);
    _calendarPageController = PageController(initialPage: 12 + monthOffset);
    _timelinePageController = PageController(initialPage: 1000);
    _displayName = widget.currentUser['display_name'];
    _initApp();
  }

  Future<void> _initApp() async {
    // 啟動時只執行一次的清理動作
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('comments', where: 'user_id = ?', whereArgs: ['u1']);
      await db.delete('posts', where: 'user_id = ?', whereArgs: ['u1']);
      await db.delete('quiz_results',
          where: "timestamp = '2026-05-27 10:15:00'");
    } catch (e) {
      debugPrint('清理舊資料失敗: $e');
    }

    _scheduleTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _loadData();
    });

    await _loadData();
  }

  /// 供分片檔案（Extensions）呼叫 setState 的輔助方法
  void _update(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  // _formatRelativeTime 已移至 common_widgets.dart

  Future<void> _loadData() async {
    _clearPostTimers();
    try {
      final db = await DatabaseHelper.instance.database;
      final currentUserId = widget.currentUser['id'];

      // Fetch schedules
      final schedulesList = await db.query('calendar_events',
          where: 'user_id = ?', whereArgs: [currentUserId]);

      final List<Map<String, dynamic>> validSchedulesList = [];
      for (var s in schedulesList) {
        final startTimeStr = s['start_time'] as String? ?? '';
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(startTimeStr.trim())) {
          await db
              .delete('calendar_events', where: 'id = ?', whereArgs: [s['id']]);
          debugPrint(
              'Deleted malformed calendar event: ${s['id']} (${s['title']})');
        } else {
          validSchedulesList.add(s);
        }
      }

      Map<String, List<Map<String, dynamic>>> schedulesMap = {};
      for (var s in validSchedulesList) {
        final startTimeStr = s['start_time'] as String? ?? '';
        final endTimeStr = s['end_time'] as String? ?? '';

        String startHr = '00:00';
        String endHr = '00:00';

        final startParts = startTimeStr.split(' ');
        if (startParts.isNotEmpty && startParts.length > 1) {
          final rawTime = startParts[1];
          startHr =
              rawTime.substring(0, rawTime.length >= 5 ? 5 : rawTime.length);
        }

        final endParts = endTimeStr.split(' ');
        if (endParts.length > 1) {
          final rawTime = endParts[1];
          endHr =
              rawTime.substring(0, rawTime.length >= 5 ? 5 : rawTime.length);
        }

        String colorStr = s['color'] as String? ?? '';
        int colorVal = 0xFFFFCC80; // Default color
        try {
          if (colorStr.isNotEmpty) {
            String hex = colorStr.replaceAll('0x', '');
            if (hex.length == 6) hex = 'FF$hex';
            colorVal = int.parse(hex, radix: 16);
          }
        } catch (e) {
          debugPrint('顏色解析失敗: $e');
        }

        // Parse date range for multi-day support
        try {
          DateTime startDate = DateTime.parse(startTimeStr.split(' ')[0]);
          DateTime endDate = DateTime.parse(endTimeStr.split(' ')[0]);
          if (endDate.isBefore(startDate)) {
            endDate = startDate;
          }
          int diffDays = endDate.difference(startDate).inDays;
          for (int idx = 0; idx <= diffDays; idx++) {
            DateTime currentDay = startDate.add(Duration(days: idx));
            String dateKey =
                "${currentDay.year}-${currentDay.month.toString().padLeft(2, '0')}-${currentDay.day.toString().padLeft(2, '0')}";
            schedulesMap.putIfAbsent(dateKey, () => []).add({
              'id': s['id'],
              'time': '$startHr~$endHr',
              'title': s['title'],
              'color': colorVal,
              'date': startTimeStr.split(' ')[
                  0], // Keep start date for single-day list match if needed
              'start_date': startTimeStr.split(' ')[0],
              'end_date': endTimeStr.split(' ')[0],
            });
          }
        } catch (e) {
          debugPrint('時間範圍解析失敗: $e');
          // Fallback if parsing fails
          String date = startTimeStr.split(' ')[0];
          schedulesMap.putIfAbsent(date, () => []).add({
            'id': s['id'],
            'time': '$startHr~$endHr',
            'title': s['title'],
            'color': colorVal,
            'date': date,
            'start_date': date,
            'end_date': date,
          });
        }
      }

      // Fetch todos
      final tododb = await db
          .query('todos', where: 'user_id = ?', whereArgs: [currentUserId]);
      List<Map<String, dynamic>> todosList = tododb
          .map((t) => {
                'id': t['id'].toString(),
                'title': t['text'],
                'isDone': (t['done'] as int) == 1,
                'doneDate': t['done_at'] != null
                    ? (t['done_at'] as String).substring(0, 10)
                    : null,
              })
          .toList();

      // ── 載入貼文（含作者頭像資料與貼文分類）──────────────────────
      final postsdb = await db.query('posts', orderBy: 'created_at DESC');
      List<Map<String, dynamic>> pList = [];
      List<Map<String, dynamic>> sList = [];
      for (var p in postsdb) {
        final u =
            await db.query('users', where: 'id = ?', whereArgs: [p['user_id']]);
        final String author =
            u.isNotEmpty ? u.first['display_name'] as String : '未知用戶';
        // 作者頭像（emoji 預設索引 或 自訂圖片）
        final int authorAvatarColor =
            u.isNotEmpty ? ((u.first['avatar_color'] as int?) ?? 0) : 0;
        final Uint8List? authorAvatarBlob =
            u.isNotEmpty ? u.first['avatar_blob'] as Uint8List? : null;
        // avatar_selected=1 表示使用者已明確選取頭像
        final int authorAvatarSelected =
            u.isNotEmpty ? ((u.first['avatar_selected'] as int?) ?? 0) : 0;
        final String authorBio =
            u.isNotEmpty ? (u.first['bio'] as String? ?? '') : '';

        final likesCount = await db.query('post_likes',
            where: 'post_id = ? AND user_id = ?',
            whereArgs: [p['id'], currentUserId]);
        final bookmarks = await db.query('post_bookmarks',
            where: 'post_id = ? AND user_id = ?',
            whereArgs: [p['id'], currentUserId]);
        final bool isBookmarked = bookmarks.isNotEmpty;

        final resCount = await db.rawQuery(
            'SELECT COUNT(*) as c FROM comments WHERE post_id = ?', [p['id']]);
        final int replies = (resCount.first['c'] as int?) ?? 0;

        final Map<String, dynamic> attached =
            jsonDecode((p['attached_data'] as String?) ?? '{}');
        final Uint8List? blobData = p['media_blob'] as Uint8List?;

        Map<String, dynamic> postData = {
          'id': p['id'],
          'userId': p['user_id'],
          'author': author,
          'authorAvatarColor': authorAvatarColor,
          'authorAvatarBlob': authorAvatarBlob,
          'authorAvatarSelected': authorAvatarSelected,
          'authorBio': authorBio,
          'time': formatRelativeTime(p['created_at']),
          'content': p['content'],
          'postType': p['type'] ?? 'text',
          'isEdited': (p['is_edited'] as int?) ?? 0,
          'isLiked': likesCount.isNotEmpty,
          'isBookmarked': isBookmarked,
          'likes': p['likes'] ?? 0,
          'replies': replies,
          'media': attached['media_url'],
          'media_blob': blobData,
          'fileName': attached['file_name'],
          'scheduled_at': attached['scheduled_at'],
        };

        try {
          if (attached.containsKey('scheduled_at') &&
              attached['scheduled_at'] != null) {
            String rawTime = attached['scheduled_at'].toString().trim();
            // 增強格式相容性：支援 / 換成 -
            rawTime = rawTime.replaceAll('/', '-');
            if (rawTime.contains(' ') && !rawTime.contains('T')) {
              rawTime = rawTime.replaceFirst(' ', 'T');
            }
            if (rawTime.length <= 16 &&
                rawTime.contains('T') &&
                rawTime.split('T')[1].length <= 5) {
              rawTime = '$rawTime:00';
            }

            DateTime? sTime = DateTime.tryParse(rawTime);
            // 【修復】DateTime.tryParse 對無時區標記的字串會視為 UTC。
            // 儲存的排程時間是本地時間，需強制轉為本地 DateTime 再比較。
            if (sTime != null &&
                !rawTime.contains('Z') &&
                !rawTime.contains('+')) {
              sTime = DateTime(sTime.year, sTime.month, sTime.day, sTime.hour,
                  sTime.minute, sTime.second);
            }
            if (sTime != null) {
              final now = DateTime.now();
              if (sTime.isAfter(now)) {
                if (p['user_id'] == currentUserId) {
                  sList.add(postData);
                  Duration diff = sTime.difference(now);
                  if (!diff.isNegative && diff.inDays <= 1) {
                    _postTimers.add(Timer(diff, () {
                      if (mounted) _loadData();
                    }));
                  }
                }
                continue;
              } else {
                // 自動發佈邏輯
                attached.remove('scheduled_at');
                String nowStr = now.toIso8601String();
                await db.update(
                    'posts',
                    {
                      'attached_data': jsonEncode(attached),
                      'created_at': nowStr,
                    },
                    where: 'id = ?',
                    whereArgs: [p['id']]);
                postData['scheduled_at'] = null;
                postData['time'] = '剛剛';
              }
            }
          }
          pList.add(postData);
        } catch (e) {
          debugPrint('處理單篇貼文失敗 (ID: ${p['id']}): $e');
          // 即使出錯也盡量加入列表，避免遺漏
          pList.add(postData);
        }
      }

      // Fetch Questions
      final questionsdb = await db.rawQuery('''
      SELECT q.*, u.display_name
      FROM questions q
      JOIN users u ON q.user_id = u.id
    ''');
      List<Map<String, dynamic>> qList = [];
      for (var q in questionsdb) {
        final tagsdb = await db.rawQuery('''
         SELECT t.name FROM tags t
         JOIN question_tag_map qm ON t.id = qm.tag_id
         WHERE qm.question_id = ?
       ''', [q['id']]);
        String chapter =
            tagsdb.isNotEmpty ? tagsdb.first['name'] as String : '';

        qList.add({
          'id': 'q${q['id']}',
          'subject': q['subject'],
          'chapter': chapter,
          'difficulty': q['difficulty'],
          'type': '單選題',
          'question': q['text'],
          'options': jsonDecode(q['options'] as String),
          'answerIndex': int.parse((q['answer'] as String)),
          'explanation': q['explanation'],
          'isFavorite': (q['bookmarked'] as int) == 1,
          'author': q['display_name'],
          'replies': 2,
          'isWrong': false,
        });
      }

      // Match wrong items
      final res = await db.query('quiz_results');
      List<dynamic> wrongIds = [];
      for (var r in res) {
        if (r['wrong_question_ids'] != null) {
          wrongIds.addAll(jsonDecode(r['wrong_question_ids'] as String));
        }
      }
      for (var q in qList) {
        int numericId = int.parse((q['id'] as String).replaceAll('q', ''));
        if (wrongIds.contains(numericId)) {
          q['isWrong'] = true;
        }
      }

      // 載入當前使用者頭像
      final userRows =
          await db.query('users', where: 'id = ?', whereArgs: [currentUserId]);
      bool isEmailVerified = false;
      String? displayName;
      Uint8List? userAvatar;
      int userAvatarColor = 0;
      int userAvatarSelected = 0;
      if (userRows.isNotEmpty) {
        userAvatar = userRows.first['avatar_blob'] as Uint8List?;
        userAvatarColor = (userRows.first['avatar_color'] as int?) ?? 0;
        userAvatarSelected = (userRows.first['avatar_selected'] as int?) ?? 0;
        displayName = userRows.first['display_name'] as String?;

        isEmailVerified =
            (userRows.first['is_email_verified'] as int? ?? 0) == 1;
      }

      // --- 學習歷程動態統計查詢 ---
      // 1. 今日統計（時數與答題數）
      final todayRows = await db.rawQuery('''
        SELECT SUM(duration_seconds) as total_sec, SUM(total) as total_q 
        FROM quiz_results 
        WHERE user_id = ? AND date(timestamp) = date('now', 'localtime')
      ''', [currentUserId]);

      double todayStudyHours = 0.0;
      int todayCompletedQuestions = 0;
      if (todayRows.isNotEmpty) {
        if (todayRows.first['total_sec'] != null) {
          todayStudyHours =
              (todayRows.first['total_sec'] as num).toDouble() / 3600.0;
        }
        if (todayRows.first['total_q'] != null) {
          todayCompletedQuestions = (todayRows.first['total_q'] as num).toInt();
        }
      }

      // 2. 累積答題數 (取代 LV)
      final totalAnsweredRows = await db.rawQuery('''
        SELECT SUM(total) as grand_total 
        FROM quiz_results 
        WHERE user_id = ?
      ''', [currentUserId]);

      int totalQuestionsAnswered = 0;
      if (totalAnsweredRows.isNotEmpty &&
          totalAnsweredRows.first['grand_total'] != null) {
        totalQuestionsAnswered =
            (totalAnsweredRows.first['grand_total'] as num).toInt();
      }

      // 3. 連續學習天數 (Streak)
      final streakRows = await db.rawQuery('''
        SELECT DISTINCT date(timestamp) as active_date FROM quiz_results WHERE user_id = ?
        UNION
        SELECT DISTINCT date(done_at) as active_date FROM todos WHERE user_id = ? AND done = 1
        ORDER BY active_date DESC
      ''', [currentUserId, currentUserId]);

      int streakDays = 0;
      if (streakRows.isNotEmpty) {
        final List<String> activeDates = streakRows
            .where((r) => r['active_date'] != null)
            .map((r) => r['active_date'] as String)
            .toList();

        final now = DateTime.now();
        final todayStr =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

        final yesterday = now.subtract(const Duration(days: 1));
        final yesterdayStr =
            "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

        if (activeDates.contains(todayStr) ||
            activeDates.contains(yesterdayStr)) {
          streakDays = 1;
          DateTime checkDate = activeDates.contains(todayStr) ? now : yesterday;
          while (true) {
            checkDate = checkDate.subtract(const Duration(days: 1));
            final checkStr =
                "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
            if (activeDates.contains(checkStr)) {
              streakDays++;
            } else {
              break;
            }
          }
        }
      }

      // 4. 本週時間基準點 (以週一為起始點)
      final now = DateTime.now();
      final monday = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));

      // 5. 最近一次測驗分數（用於「測驗歷史」副標題）
      final latestQuizRows = await db.rawQuery('''
        SELECT correct, total, timestamp FROM quiz_results
        WHERE user_id = ? AND total > 0
        ORDER BY timestamp DESC LIMIT 1
      ''', [currentUserId]);

      String latestQuizScore = '暫無測驗紀錄';
      if (latestQuizRows.isNotEmpty) {
        final correct = (latestQuizRows.first['correct'] as num).toInt();
        final total = (latestQuizRows.first['total'] as num).toInt();
        final pct = total > 0 ? ((correct / total) * 100).round() : 0;
        latestQuizScore = '最近一次：$correct/$total 題（$pct 分）';
      }

      // 6. 本週每日正確率統計
      final weeklyAccRows = await db.rawQuery('''
        SELECT
          strftime('%w', timestamp) as dow,
          SUM(correct) as sumCorrect,
          SUM(total) as sumTotal
        FROM quiz_results
        WHERE user_id = ? AND total > 0
          AND timestamp >= ?
        GROUP BY strftime('%w', timestamp)
      ''', [currentUserId, monday.toIso8601String().substring(0, 10)]);

      List<double> weeklyAccuracyList = List.filled(7, -1);
      for (var row in weeklyAccRows) {
        // SQLite %w: 0=Sunday,1=Mon,...,6=Sat → 轉為 Mon=0,...,Sun=6
        int dow = int.tryParse(row['dow'].toString()) ?? -1;
        int dayIdx = (dow == 0) ? 6 : dow - 1; // 0=Mon,6=Sun
        final int sumCorrect = (row['sumCorrect'] as num?)?.toInt() ?? 0;
        final int sumTotal = (row['sumTotal'] as num?)?.toInt() ?? 0;
        if (dayIdx >= 0 && dayIdx < 7 && sumTotal > 0) {
          weeklyAccuracyList[dayIdx] =
              (sumCorrect / sumTotal * 100).roundToDouble();
        }
      }

      // 本週平均正確率
      final validAcc = weeklyAccuracyList.where((v) => v >= 0).toList();
      double weeklyAvgAccuracy = validAcc.isEmpty
          ? -1
          : validAcc.reduce((a, b) => a + b) / validAcc.length;
      if (weeklyAvgAccuracy >= 0) {
        weeklyAvgAccuracy = double.parse(weeklyAvgAccuracy.toStringAsFixed(1));
      }

      // 7. 排行榜資料（所有使用者的累積正確率與答題數）
      final leaderboardRows = await db.rawQuery('''
        SELECT
          u.id as uid,
          u.display_name as name,
          u.avatar_blob,
          u.avatar_color,
          u.avatar_selected,
          COALESCE(SUM(qr.total), 0) as total_answered,
          COALESCE(SUM(qr.correct), 0) as total_correct
        FROM users u
        LEFT JOIN quiz_results qr ON u.id = qr.user_id AND qr.total > 0
        WHERE u.id != 'u4'
        GROUP BY u.id
        ORDER BY
          CASE WHEN COALESCE(SUM(qr.total), 0) = 0 THEN 1 ELSE 0 END,
          (CAST(COALESCE(SUM(qr.correct), 0) AS REAL) / NULLIF(COALESCE(SUM(qr.total), 0), 0)) DESC
      ''');

      List<Map<String, dynamic>> leaderboardList = leaderboardRows.map((r) {
        final int tot = (r['total_answered'] as num?)?.toInt() ?? 0;
        final int cor = (r['total_correct'] as num?)?.toInt() ?? 0;
        final double acc = tot > 0 ? (cor / tot * 100) : 0.0;
        return {
          'userId': r['uid'],
          'name': r['name'],
          'avatarBlob': r['avatar_blob'],
          'avatarColor': (r['avatar_color'] as int?) ?? 0,
          'avatarSelected': (r['avatar_selected'] as int?) ?? 0,
          'totalAnswered': tot,
          'totalCorrect': cor,
          'accuracy': double.parse(acc.toStringAsFixed(1)),
        };
      }).toList();

      if (mounted) {
        setState(() {
          allSchedules = schedulesMap;
          allTodos = todosList;
          socialPosts = pList;
          scheduledPosts = sList;
          questionBank = qList;
          _userAvatarBlob = userAvatar;
          _userAvatarColor = userAvatarColor;
          _userAvatarSelected = userAvatarSelected == 1;
          _isEmailVerified = isEmailVerified;
          _displayName = displayName;

          // 更新學習統計狀態
          _todayStudyHours = todayStudyHours;
          _todayCompletedQuestions = todayCompletedQuestions;
          _streakDays = streakDays;
          _weeklyAccuracyList = weeklyAccuracyList;
          _weeklyAvgAccuracy = weeklyAvgAccuracy;
          _totalQuestionsAnswered = totalQuestionsAnswered;
          _latestQuizScore = latestQuizScore;
          _leaderboardList = leaderboardList;

          // 個人化設定：安全處理資料類型並觸發 UI 更新
          if (userRows.isNotEmpty) {
            _userBio = userRows.first['bio'] as String?;
            _fontSizeFactor =
                ((userRows.first['font_size_factor'] ?? 1.0) as num).toDouble();
            _themeColorIdx = (userRows.first['theme_color_idx'] ?? 0) as int;
            _isDarkMode = (userRows.first['is_dark_mode'] ?? 0) == 1;
            _calendarViewMode =
                (userRows.first['calendar_view_mode'] as String?) ?? 'dot';
            debugPrint(
                'Theme Loaded: _themeColorIdx=$_themeColorIdx, _isDarkMode=$_isDarkMode, _calendarViewMode=$_calendarViewMode');
          }
        });
      }
    } catch (e) {
      debugPrint('載入資料庫發生錯誤: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _recordAppUsageTime();
    } else if (state == AppLifecycleState.resumed) {
      _sessionStartTime = DateTime.now();
    }
  }

  Future<void> _recordAppUsageTime() async {
    final int seconds = DateTime.now().difference(_sessionStartTime).inSeconds;
    if (seconds < 5) return;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('quiz_results', {
        'user_id': widget.currentUser['id'],
        'total': 0,
        'correct': 0,
        'wrong_question_ids': '[]',
        'duration_seconds': seconds,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _loadData();
    } catch (e) {
      debugPrint('記錄 App 使用時間失敗: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordAppUsageTime();
    _isDisposed = true;
    _quizTimer?.cancel();
    _scheduleTimer?.cancel();
    _diagnosisStreamSub?.cancel(); // 取消 AI 診斷串流訂閱
    _clearPostTimers();
    _quizScrollController.dispose();
    _profileScrollController.dispose();
    _chatScrollController.dispose();
    _calendarPageController.dispose();
    _timelinePageController.dispose();
    super.dispose();
  }

  // ==========================================
  // 【重要修復】: 將漏掉的日曆與核心切換方法補回
  // ==========================================
  void _changePage(int index, String title) {
    if (index == 5 && widget.currentUser['id'] == 'u4') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ 訪客帳戶無法使用筆記本功能，請註冊/登入正式帳號以開啟功能！'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _currentIndex = index;
      _appBarTitle = title;
      _resetQuiz();
      _selectedFolder = null;
    });

    // 當切換到個人檔案分頁時，重置捲動位置到頂部
    if (index == 4 && _profileScrollController.hasClients) {
      _profileScrollController.jumpTo(0);
    }
  }

  void _resetQuiz() {
    setState(() {
      _quizStep = 0;
      _quizSelectedSubject = "";
      _quizSelectedChapters.clear();
      _quizTimer?.cancel();
      _userAnswers.clear();
    });
  }

  // 補回：日曆點擊日期時的同步跳轉
  void _syncDate(DateTime date, {bool fromCalendar = false}) {
    setState(() => _selectedDate = date);
    if (fromCalendar) {
      _timelinePageController
          .jumpToPage(1000 + date.difference(_simulatedToday).inDays);
    }
  }

  void _scrollToBottom() {
    if (_isDisposed) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_isDisposed) return;
      try {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } catch (_) {}
    });
  }

  void _showEditScheduledPostDialog(Map<String, dynamic> sp) {
    final contentController = TextEditingController(text: sp['content']);
    String currentTime = sp['scheduled_at'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.edit_calendar, color: Colors.orange),
            SizedBox(width: 8),
            Text('編輯排程貼文', style: TextStyle(fontSize: 18)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('貼文內容',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: contentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: '輸入貼文內容',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('排定發佈時間',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: now,
                      firstDate: now,
                      lastDate: DateTime(2030),
                      locale: const Locale('zh', 'TW'),
                    );
                    if (date != null) {
                      if (!ctx.mounted) return;
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.now(),
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(context)
                                .copyWith(alwaysUse24HourFormat: true),
                            child: child!,
                          );
                        },
                      );
                      if (time != null) {
                        setDialogState(() {
                          currentTime =
                              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        });
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 18, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          currentTime.isEmpty ? '點擊選擇時間' : currentTime,
                          style: TextStyle(
                              fontSize: 14,
                              color: currentTime.isEmpty
                                  ? Colors.grey
                                  : Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8D6E63),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final newContent = contentController.text.trim();
                if (newContent.isEmpty) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('貼文內容不能為空')));
                  return;
                }
                final db = await DatabaseHelper.instance.database;
                String newAttached = '{}';
                if (currentTime.isNotEmpty) {
                  newAttached = '{"scheduled_at": "$currentTime"}';
                }
                final spId = int.tryParse(sp['id'].toString()) ?? sp['id'];
                await db.update(
                    'posts',
                    {
                      'content': newContent,
                      'attached_data': newAttached,
                    },
                    where: 'id = ?',
                    whereArgs: [spId]);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('✅ 排程貼文已更新')));
                }
              },
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
  }

  void _publishAIPost(Map<String, dynamic> pData, bool isScheduled) async {
    Navigator.pop(context);
    _changePage(2, '社群');
    final db = await DatabaseHelper.instance.database;
    String tType = 'text';
    if (pData['type'] == '學習筆記') tType = 'note';
    if (pData['type'] == '心情文章') tType = 'diary';
    if (pData['type'] == '分享資料') tType = 'share';

    String attached = '{}';
    if (isScheduled) {
      attached = '{"scheduled_at": "${pData['time']}"}';
    }

    await db.insert('posts', {
      'user_id': widget.currentUser['id'],
      'content': pData['content'],
      'type': tType,
      'attached_data': attached,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isScheduled ? '代理人已為您完成貼文排程！' : '貼文已立即發佈！')));
    }
  }

  Future<void> _addPostFromAI(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;
    final userId = widget.currentUser['id'];

    // Mapping Chinese labels to internal keys
    String typeKey = 'text';
    if (data['type'] == '學習筆記') {
      typeKey = 'note';
    } else if (data['type'] == '心情文章') {
      typeKey = 'mood';
    } else if (data['type'] == '分享資料') {
      typeKey = 'doc';
    }

    await db.insert('posts', {
      'user_id': userId,
      'content': data['content'],
      'type': typeKey,
      'attached_data': jsonEncode({
        'scheduled_at': (data['time'] == null || data['time'] == '現在')
            ? null
            : data['time'],
      }),
      'created_at': DateTime.now().toIso8601String(),
    });
    await _loadData();
  }

  Future<void> _toggleBookmark(Map<String, dynamic> post) async {
    final db = await DatabaseHelper.instance.database;
    final postId = post['id'] as int;
    final userId = widget.currentUser['id'] as String;

    final existing = await db.query(
      'post_bookmarks',
      where: 'post_id = ? AND user_id = ?',
      whereArgs: [postId, userId],
    );

    if (existing.isNotEmpty) {
      await db.delete(
        'post_bookmarks',
        where: 'post_id = ? AND user_id = ?',
        whereArgs: [postId, userId],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消收藏')),
        );
      }
    } else {
      await db.insert('post_bookmarks', {
        'post_id': postId,
        'user_id': userId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已收藏貼文')),
        );
      }
    }
    await _loadData();
  }

  // 補回：手動新增行程
  void _addSchedule(String timeRange, String title, int color,
      {DateTime? startDate, DateTime? endDate}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      DateTime sDate = startDate ?? _selectedDate;
      DateTime eDate = endDate ?? _selectedDate;
      String startKey = sDate.toString().split(' ')[0];
      String endKey = eDate.toString().split(' ')[0];
      String startStr = "$startKey ${timeRange.split('~')[0]}:00";
      String endStr = "$endKey ${timeRange.split('~')[1]}:00";
      await db.insert('calendar_events', {
        'user_id': widget.currentUser['id'],
        'title': title,
        'start_time': startStr,
        'end_time': endStr,
        'color': '0x${color.toRadixString(16)}',
      });
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已新增行程：$title'),
          backgroundColor: const Color(0xFF8D6E63),
        ),
      );
    } catch (e) {
      debugPrint('新增行程失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新增行程失敗，請稍後再試')),
      );
    }
  }

  // 新增：編輯現有行程
  void _editSchedule(int id, String timeRange, String title, int color,
      {DateTime? startDate, DateTime? endDate}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      DateTime sDate = startDate ?? _selectedDate;
      DateTime eDate = endDate ?? _selectedDate;
      String startKey = sDate.toString().split(' ')[0];
      String endKey = eDate.toString().split(' ')[0];
      String startStr = "$startKey ${timeRange.split('~')[0]}:00";
      String endStr = "$endKey ${timeRange.split('~')[1]}:00";
      await db.update(
          'calendar_events',
          {
            'title': title,
            'start_time': startStr,
            'end_time': endStr,
            'color': '0x${color.toRadixString(16)}',
          },
          where: 'id = ?',
          whereArgs: [id]);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已更新行程：$title')),
      );
    } catch (e) {
      debugPrint('更新行程失敗: $e');
    }
  }

  // 新增：刪除現有行程
  void _deleteSchedule(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('calendar_events', where: 'id = ?', whereArgs: [id]);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('行程已刪除')),
      );
    } catch (e) {
      debugPrint('刪除行程失敗: $e');
    }
  }

  // 補回：手動新增待辦事項
  void _addTodo(String title) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('todos', {
        'user_id': widget.currentUser['id'],
        'text': title,
        'done': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已新增待辦：$title'),
          backgroundColor: const Color(0xFF8D6E63),
        ),
      );
    } catch (e) {
      debugPrint('新增待辦失敗: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新增待辦失敗，請稍後再試')),
      );
    }
  }

  void _showMonthYearPicker() {
    int selectedYear = _calendarMonth.year;
    int selectedMonth = _calendarMonth.month;
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('跳轉至特定年月份'),
                content: StatefulBuilder(builder: (context, setDialogState) {
                  return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DropdownButton<int>(
                          value: selectedYear,
                          items: List.generate(20, (index) => 2020 + index)
                              .map((y) => DropdownMenuItem(
                                  value: y, child: Text('$y年')))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedYear = v!),
                        ),
                        const SizedBox(width: 20),
                        DropdownButton<int>(
                          value: selectedMonth,
                          items: List.generate(12, (index) => 1 + index)
                              .map((m) => DropdownMenuItem(
                                  value: m, child: Text('$m月')))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedMonth = v!),
                        ),
                      ]);
                }),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8D6E63),
                          foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(ctx);
                        // 同樣以 2026年3月 = page 12 為基準計算目標頁
                        int deltaMonths =
                            (selectedYear - 2026) * 12 + (selectedMonth - 3);
                        int targetPage = 12 + deltaMonths;
                        _calendarPageController.animateToPage(targetPage,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      },
                      child: const Text('確定'))
                ]));
  }

  void _returnToToday() {
    setState(() {
      _syncDate(_simulatedToday, fromCalendar: true);
      _calendarMonth = DateTime(_simulatedToday.year, _simulatedToday.month, 1);
    });
    int deltaMonths =
        (_simulatedToday.year - 2026) * 12 + (_simulatedToday.month - 3);
    int targetPage = 12 + deltaMonths;
    _calendarPageController.animateToPage(targetPage,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _showLogoutDialog() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('系統提示'),
                content: const Text('確定要登出並切換至其他帳號嗎？'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8D6E63),
                          foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onLogout();
                      },
                      child: const Text('確定登出'))
                ]));
  }

  // --- 測驗精靈邏輯 ---
  // ignore: unused_element
  void _calculateAvailableQuestions() {
    _availableCounts = {
      '單選題': {'易': 0, '中': 0, '難': 0},
      '是非題': {'易': 0, '中': 0, '難': 0},
      '申論題': {'易': 0, '中': 0, '難': 0}
    };
    _quizPickedCounts = {
      '單選題': {'易': 0, '中': 0, '難': 0},
      '是非題': {'易': 0, '中': 0, '難': 0},
      '申論題': {'易': 0, '中': 0, '難': 0}
    };
    for (var q in questionBank) {
      if (q['subject'] != _quizSelectedSubject) continue;
      if (_quizSelectedChapters.isNotEmpty &&
          !_quizSelectedChapters.contains(q['chapter'])) {
        continue;
      }
      if (_availableCounts.containsKey(q['type']) &&
          _availableCounts[q['type']]!.containsKey(q['difficulty'])) {
        _availableCounts[q['type']]![q['difficulty']] =
            _availableCounts[q['type']]![q['difficulty']]! + 1;
      }
    }
  }

  // ignore: unused_element
  void _generateQuizPaper() {
    _currentQuizQuestions.clear();
    List<Map<String, dynamic>> scopeQs = questionBank
        .where((q) =>
            q['subject'] == _quizSelectedSubject &&
            (_quizSelectedChapters.isEmpty ||
                _quizSelectedChapters.contains(q['chapter'])))
        .toList();
    _quizPickedCounts.forEach((type, diffs) {
      diffs.forEach((diff, count) {
        if (count > 0) {
          var matched = scopeQs
              .where((q) => q['type'] == type && q['difficulty'] == diff)
              .toList();
          matched.shuffle();
          _currentQuizQuestions.addAll(matched.take(count));
        }
      });
    });
    _currentQuizQuestions.shuffle();
  }

  // --- UI 組件區 ---
  @override
  Widget build(BuildContext context) {
    // 根據使用者設定建立主題
    final baseTheme = _isDarkMode ? ThemeData.dark() : ThemeData.light();
    final primaryColor = _themeColorIdx == 1
        ? const Color(0xFF6B8A96) // 孔雀藍 (霧霾藍，淡雅且內斂)
        : (_themeColorIdx == 2
            ? const Color(0xFF8AA682) // 森林綠 (鼠尾草綠，柔和且自然)
            : const Color(0xFF9E8E81)); // 經典暖棕 (莫蘭迪棕，溫潤且協調)

    return Theme(
      data: baseTheme.copyWith(
        primaryColor: primaryColor,
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: primaryColor,
          secondary: primaryColor.withValues(alpha: 0.8),
        ),
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(_fontSizeFactor),
        ),
        child: Builder(builder: (context) {
          return Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.transparent, // Let Container behind it show
            extendBody: true, // Allow body to scroll under bottom nav bar
            appBar: _quizStep == 2
                ? null
                : AppBar(
                    title: _currentIndex == 0
                        ? TextButton(
                            onPressed: _showMonthYearPicker,
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(
                                  "${_calendarMonth.year}年 ${_calendarMonth.month}月",
                                  style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w700)),
                              const Icon(Icons.keyboard_arrow_down,
                                  color: Colors.black87)
                            ]))
                        : Text(_appBarTitle,
                            style: const TextStyle(
                                fontSize: 18,
                                color: Colors.black87,
                                fontWeight: FontWeight.bold)),
                    backgroundColor: Colors.white.withValues(alpha: 0.7),
                    flexibleSpace: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                    elevation: 0,
                    actions: [
                        if (_currentIndex == 0)
                          IconButton(
                              icon: const Icon(Icons.today_rounded,
                                  color: Colors.black87),
                              onPressed: _returnToToday,
                              tooltip: '回到今日'),
                        IconButton(
                            icon: const Icon(Icons.logout_rounded,
                                color: Colors.black87),
                            onPressed: _showLogoutDialog)
                      ]),
            drawer: Drawer(
                child: SafeArea(
                    child: ListView(children: [
              Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text('系統選單',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor))),
              ListTile(
                  leading: Icon(Icons.calendar_month,
                      color: Theme.of(context).primaryColor),
                  title: const Text('日曆行程'),
                  onTap: () {
                    _changePage(0, '日曆行程');
                    Navigator.pop(context);
                  }),
              if (widget.currentUser['id'] != 'u4')
                ListTile(
                    leading: Icon(Icons.edit_note,
                        color: Theme.of(context).primaryColor),
                    title: const Text('筆記本'),
                    onTap: () {
                      _changePage(5, '筆記本');
                      Navigator.pop(context);
                    }),
              ListTile(
                  leading: Icon(Icons.menu_book,
                      color: Theme.of(context).primaryColor),
                  title: const Text('題庫'),
                  onTap: () {
                    _changePage(1, '題庫');
                    Navigator.pop(context);
                  }),
              ListTile(
                  leading:
                      Icon(Icons.forum, color: Theme.of(context).primaryColor),
                  title: const Text('社群'),
                  onTap: () {
                    _changePage(2, '社群');
                    Navigator.pop(context);
                  }),
              const Divider(indent: 20, endIndent: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('互動與管理',
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
              ListTile(
                  leading: Icon(Icons.history_edu_rounded,
                      color: Theme.of(context).primaryColor),
                  title: const Text('社群動態'),
                  onTap: () {
                    _changePage(3, '社群動態');
                    Navigator.pop(context);
                  }),
              ListTile(
                  leading: Icon(Icons.settings_suggest_rounded,
                      color: Theme.of(context).primaryColor),
                  title: const Text('個人檔案'),
                  onTap: () {
                    _changePage(4, '個人檔案');
                    Navigator.pop(context);
                  }),
              ListTile(
                  leading: Icon(Icons.leaderboard_rounded,
                      color: Theme.of(context).primaryColor),
                  title: const Text('排行榜'),
                  onTap: () {
                    _changePage(6, '排行榜');
                    Navigator.pop(context);
                  }),
            ]))),
            body: Container(
              color: _isDarkMode ? Colors.black87 : Colors.white,
              child: SafeArea(
                bottom: false, // Let bottom bar handle bottom safe area
                child: Column(children: [
                  Expanded(
                      child: IndexedStack(index: _currentIndex, children: [
                    _buildCalendarTab(),
                    _buildQuestionBankTab(),
                    _buildSocialTab(),
                    _buildSocialActivityTab(),
                    _buildPersonalProfileTab(context),
                    NotesScreen(currentUser: widget.currentUser),
                    _buildLeaderboardTab(),
                  ])),
                  if (_currentIndex != 1 || _quizStep == 0) _buildAIChatBar(),
                  if (_showFloatingNavBar) const SizedBox(height: 80), // Padding for floating nav bar
                ]),
              ),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
            floatingActionButton: (_quizStep == 2 || !_showFloatingNavBar)
                ? null
                : FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    child: _buildFloatingNavBar(),
                  ),
          );
        }),
      ),
    );
  }

  Widget _buildFloatingNavBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 65,
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.black.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(Icons.calendar_month_rounded, '日曆行程', 0),
              _buildNavItem(Icons.menu_book_rounded, '題庫', 1),
              _buildNavItem(Icons.forum_rounded, '社群', 2),
              _buildNavItem(Icons.person_rounded, '個人檔案', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String fullLabel, int index) {
    final bool isSelected = _currentIndex == index;
    final primaryColor = Theme.of(context).primaryColor;

    // 取前兩個字當作簡稱
    final String label =
        fullLabel.length > 2 ? fullLabel.substring(0, 2) : fullLabel;

    return GestureDetector(
      onTap: () {
        _changePage(index, fullLabel);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        padding:
            EdgeInsets.symmetric(horizontal: isSelected ? 16 : 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : Colors.grey.shade500,
              size: isSelected ? 26 : 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // --- AI 助理全螢幕面板 ---
  void _openChatModal() {
    TextEditingController modalController = TextEditingController();
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          _scrollToBottom();
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(
                  color: Color(0xFFF5F0EE),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(25))),
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 40),
                          const Text('代理人助理',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8D6E63),
                                  fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.cleaning_services_outlined,
                                size: 20, color: Colors.grey),
                            tooltip: '開啟新對話',
                            onPressed: () {
                              setModalState(() {
                                chatLogs = [
                                  {
                                    'isAI': true,
                                    'text':
                                        '好的，已為您重啟對話！😊\n我是您的代理人，請問今天有什麼我可以幫您的嗎？',
                                    'isCard': false
                                  },
                                  {
                                    'isAI': true,
                                    'text': '',
                                    'isCard': false,
                                    'widgetType': 'help_options'
                                  }
                                ];
                                _aiFlowState = 'none';
                              });
                            },
                          )
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        controller: _chatScrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: chatLogs.length,
                        itemBuilder: (context, i) {
                          var msg = chatLogs[i];
                          if (msg['isCard'] == true) {
                            return _buildConfirmationCard(
                                msg['pendingData'], setModalState);
                          }

                          if (msg['widgetType'] == 'date_picker') {
                            return Container(
                                margin: const EdgeInsets.only(
                                    bottom: 14, left: 40, right: 10),
                                child: GestureDetector(
                                  onTap: () async {
                                    DateTime? date = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime(2030),
                                      locale: const Locale('zh', 'TW'),
                                    );
                                    if (date == null) return;
                                    if (!context.mounted) return;
                                    TimeOfDay? time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );
                                    if (time == null) return;
                                    if (!context.mounted) return;
                                    String timeStr =
                                        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                                    String dateTimeStr =
                                        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $timeStr";
                                    _handleAISubmit(dateTimeStr,
                                        modalController, setModalState);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 14),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF8D6E63),
                                          Color(0xFFBCAAA4)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF8D6E63)
                                              .withValues(alpha: 0.35),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        )
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.25),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                              Icons.calendar_month_rounded,
                                              color: Colors.white,
                                              size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        const Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('選擇發布日期與時間',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14)),
                                            SizedBox(height: 2),
                                            Text('點擊以開啟日期選擇器',
                                                style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 11)),
                                          ],
                                        ),
                                        const SizedBox(width: 16),
                                        const Icon(Icons.arrow_forward_ios,
                                            color: Colors.white70, size: 14),
                                      ],
                                    ),
                                  ),
                                ));
                          }
                          if (msg['widgetType'] == 'time_range_picker') {
                            // 行內版滾輪選擇器 (與 AIAssistantPanel 版相同邏輯)
                            final now = DateTime.now();
                            final dates = List.generate(
                                60, (i) => now.add(Duration(days: i)));
                            final hours = List.generate(24, (h) => h);
                            final minutes = List.generate(12, (m) => m * 5);
                            int selDateIdx = 0;
                            int selStartHour = now.hour;
                            int selStartMin = (now.minute ~/ 5) * 5;
                            int selEndHour = (now.hour + 1) % 24;
                            int selEndMin = selStartMin;
                            String fmt2(int v) => v.toString().padLeft(2, '0');
                            String dateLabel(DateTime d) {
                              const wds = ['一', '二', '三', '四', '五', '六', '日'];
                              return '${d.month}/${d.day}（${wds[d.weekday - 1]}）';
                            }

                            Widget wheel(
                                {required List items,
                                required int initIdx,
                                required void Function(int) onSel,
                                required String Function(dynamic) lbl,
                                double w = 56}) {
                              final ctrl = FixedExtentScrollController(
                                  initialItem: initIdx);
                              return SizedBox(
                                width: w,
                                height: 130,
                                child: ListWheelScrollView.useDelegate(
                                  controller: ctrl,
                                  itemExtent: 36,
                                  perspective: 0.004,
                                  diameterRatio: 1.5,
                                  physics: const FixedExtentScrollPhysics(),
                                  onSelectedItemChanged: onSel,
                                  childDelegate: ListWheelChildBuilderDelegate(
                                    childCount: items.length,
                                    builder: (c, idx) => Center(
                                        child: Text(lbl(items[idx]),
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600))),
                                  ),
                                ),
                              );
                            }

                            return StatefulBuilder(builder: (ctx2, setL) {
                              return Container(
                                margin: const EdgeInsets.only(
                                    bottom: 16, left: 16, right: 16),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                        color: const Color(0xFF8D6E63)
                                            .withValues(alpha: 0.12),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4))
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFF8D6E63)
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: const Icon(Icons.schedule,
                                              color: Color(0xFF8D6E63),
                                              size: 18)),
                                      const SizedBox(width: 10),
                                      const Text('選擇日期與時段',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: Color(0xFF4E342E))),
                                    ]),
                                    const SizedBox(height: 12),
                                    const Text('日期',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                              height: 36,
                                              decoration: BoxDecoration(
                                                  color: const Color(0xFF8D6E63)
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10))),
                                          wheel(
                                              items: dates,
                                              initIdx: 0,
                                              onSel: (i) => selDateIdx = i,
                                              lbl: (d) =>
                                                  dateLabel(d as DateTime),
                                              w: double.infinity),
                                        ]),
                                    const SizedBox(height: 12),
                                    Row(children: [
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Row(children: [
                                              Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration:
                                                      const BoxDecoration(
                                                          color:
                                                              Color(0xFF66BB6A),
                                                          shape:
                                                              BoxShape.circle)),
                                              const SizedBox(width: 5),
                                              const Text('開始',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey))
                                            ]),
                                            const SizedBox(height: 5),
                                            Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Container(
                                                      height: 36,
                                                      decoration: BoxDecoration(
                                                          color: const Color(
                                                                  0xFF66BB6A)
                                                              .withValues(
                                                                  alpha: 0.08),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      10))),
                                                  Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        wheel(
                                                            items: hours,
                                                            initIdx:
                                                                selStartHour,
                                                            onSel: (i) {
                                                              selStartHour =
                                                                  hours[i];
                                                              if (selStartHour >
                                                                      selEndHour ||
                                                                  (selStartHour ==
                                                                          selEndHour &&
                                                                      selStartMin >=
                                                                          selEndMin)) {
                                                                selEndHour =
                                                                    (selStartHour +
                                                                            1) %
                                                                        24;
                                                                setL(() {});
                                                              }
                                                            },
                                                            lbl: (h) =>
                                                                fmt2(h as int)),
                                                        const Text(':',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 18)),
                                                        wheel(
                                                            items: minutes,
                                                            initIdx:
                                                                minutes.indexOf(
                                                                    selStartMin),
                                                            onSel: (i) =>
                                                                selStartMin =
                                                                    minutes[i],
                                                            lbl: (m) =>
                                                                fmt2(m as int)),
                                                      ]),
                                                ]),
                                          ])),
                                      const Padding(
                                          padding: EdgeInsets.only(top: 18),
                                          child: Icon(Icons.arrow_forward_ios,
                                              size: 12,
                                              color: Color(0xFFBCAAA4))),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Row(children: [
                                              Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration:
                                                      const BoxDecoration(
                                                          color:
                                                              Color(0xFFEF5350),
                                                          shape:
                                                              BoxShape.circle)),
                                              const SizedBox(width: 5),
                                              const Text('結束',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey))
                                            ]),
                                            const SizedBox(height: 5),
                                            Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Container(
                                                      height: 36,
                                                      decoration: BoxDecoration(
                                                          color: const Color(
                                                                  0xFFEF5350)
                                                              .withValues(
                                                                  alpha: 0.07),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      10))),
                                                  Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        wheel(
                                                            items: hours,
                                                            initIdx: selEndHour,
                                                            onSel: (i) =>
                                                                selEndHour =
                                                                    hours[i],
                                                            lbl: (h) =>
                                                                fmt2(h as int)),
                                                        const Text(':',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 18)),
                                                        wheel(
                                                            items: minutes,
                                                            initIdx:
                                                                minutes.indexOf(
                                                                    selEndMin),
                                                            onSel: (i) =>
                                                                selEndMin =
                                                                    minutes[i],
                                                            lbl: (m) =>
                                                                fmt2(m as int)),
                                                      ]),
                                                ]),
                                          ])),
                                    ]),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(
                                            Icons.check_circle_outline,
                                            size: 18),
                                        label: const Text('確認時段'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF8D6E63),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(14)),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 11),
                                        ),
                                        onPressed: () {
                                          final d = dates[selDateIdx];
                                          final dp =
                                              '${d.year}-${fmt2(d.month)}-${fmt2(d.day)}';
                                          final s =
                                              '$dp ${fmt2(selStartHour)}:${fmt2(selStartMin)}';
                                          final e =
                                              '$dp ${fmt2(selEndHour)}:${fmt2(selEndMin)}';
                                          _handleAISubmit('$s|||$e',
                                              modalController, setModalState);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            });
                          }
                          // ── \u6df1\u6dfa\u98a8\u683c\u9078\u64c7 ──────────────────────────────────────────
                          if (msg['widgetType'] == 'color_style_picker') {
                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 14, left: 16, right: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                      child: _buildStyleBtn(
                                    icon: '🌸',
                                    label: '\u6dfa\u8272\u7cfb',
                                    sub:
                                        '\u6e05\u6de1\u3001\u8f15\u76c8\u3001\u6d3b\u6f51',
                                    grad: const [
                                      Color(0xFFFCE4EC),
                                      Color(0xFFE1F5FE)
                                    ],
                                    onTap: () => _handleAISubmit(
                                        '\u6dfa\u8272\u7cfb',
                                        modalController,
                                        setModalState),
                                  )),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: _buildStyleBtn(
                                    icon: '🌲',
                                    label: '\u6df1\u8272\u7cfb',
                                    sub:
                                        '\u6c89\u7a69\u3001\u8cea\u611f\u3001\u4f4e\u8abf',
                                    grad: const [
                                      Color(0xFF263238),
                                      Color(0xFF37474F)
                                    ],
                                    onTap: () => _handleAISubmit(
                                        '\u6df1\u8272\u7cfb',
                                        modalController,
                                        setModalState),
                                    isDark: true,
                                  )),
                                ],
                              ),
                            );
                          }

                          // ── \u9032\u968e\u8abf\u8272\u76e4 ──────────────────────────────────────────────
                          if (msg['widgetType'] == 'color_palette') {
                            final style = msg['colorStyle'] ?? 'light';
                            return _buildInlineColorPalette(
                                style, modalController, setModalState);
                          }

                          if (msg['widgetType'] == 'color_picker') {
                            List<Map<String, dynamic>> colors = [
                              {
                                'name': '\u7d05\u8272',
                                'color': const Color(0xFFE57373)
                              },
                              {
                                'name': '\u85cd\u8272',
                                'color': const Color(0xFF64B5F6)
                              },
                              {
                                'name': '\u7da0\u8272',
                                'color': const Color(0xFF81C784)
                              },
                              {
                                'name': '\u9ec3\u8272',
                                'color': const Color(0xFFFFD54F)
                              },
                            ];
                            return Container(
                                margin:
                                    const EdgeInsets.only(bottom: 12, left: 40),
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8,
                                  children: colors
                                      .map((c) => GestureDetector(
                                            onTap: () {
                                              _handleAISubmit(
                                                  c['name'],
                                                  modalController,
                                                  setModalState);
                                            },
                                            child: Chip(
                                              avatar: CircleAvatar(
                                                  backgroundColor: c['color'],
                                                  radius: 8),
                                              label: Text(c['name']),
                                              backgroundColor: Colors.white,
                                            ),
                                          ))
                                      .toList(),
                                ));
                          }

                          if (msg['widgetType'] == 'skip_button') {
                            return Container(
                                margin:
                                    const EdgeInsets.only(bottom: 12, left: 40),
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.skip_next, size: 18),
                                  label: const Text('跳過此留言'),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey,
                                      side:
                                          const BorderSide(color: Colors.grey),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20))),
                                  onPressed: () {
                                    _handleAISubmit(
                                        '跳過', modalController, setModalState);
                                  },
                                ));
                          }

                          if (msg['widgetType'] == 'intent_suggestions') {
                            final suggestions = [
                              {'l': '🖼️ 換頭像', 'v': '更換頭像'},
                              {'l': '👤 改暱稱', 'v': '修改暱稱'},
                              {'l': '🎨 換主題', 'v': '切換主題'},
                              {'l': '📏 字體', 'v': '字體大小'},
                              {'l': '📧 驗證', 'v': 'Email 驗證'},
                              {'l': '🔑 改密碼', 'v': '修改密碼'},
                            ];
                            return Container(
                                margin:
                                    const EdgeInsets.only(bottom: 12, left: 40),
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: suggestions
                                      .map((s) => ActionChip(
                                            label: Text(s['l']!,
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                            backgroundColor: Colors.white,
                                            onPressed: () => _handleAISubmit(
                                                s['v']!,
                                                modalController,
                                                setModalState),
                                          ))
                                      .toList(),
                                ));
                          }

                          if (msg['widgetType'] == 'notebook_options') {
                            final categories = <Map<String, dynamic>>[
                              {
                                'title': '📚 筆記管理常用功能',
                                'color': const Color(0xFF8D6E63),
                                'bgColor': const Color(0xFFEFEBE9),
                                'items': <Map<String, dynamic>>[
                                  {
                                    'icon': Icons.menu_book_outlined,
                                    'l': '跳轉筆記本',
                                    'sub': '切換分頁查看所有筆記',
                                    'v': '查看筆記本',
                                    'c': const Color(0xFF1E88E5),
                                  },
                                  {
                                    'icon': Icons.add_circle_outline,
                                    'l': '新增筆記',
                                    'sub': '快速建立一篇新筆記',
                                    'v': '新增筆記',
                                    'c': const Color(0xFF43A047),
                                  },
                                  {
                                    'icon': Icons.note_alt_outlined,
                                    'l': '整理筆記',
                                    'sub': '由 AI 為您整理重點大綱',
                                    'v': '整理筆記',
                                    'c': const Color(0xFF7E57C2),
                                  },
                                  {
                                    'icon': Icons.search_outlined,
                                    'l': '搜尋筆記',
                                    'sub': '輸入關鍵字尋找特定筆記',
                                    'v': '搜尋筆記',
                                    'c': const Color(0xFFFB8C00),
                                  },
                                  {
                                    'icon': Icons.delete_outline,
                                    'l': '刪除筆記',
                                    'sub': '刪除不再需要的筆記項目',
                                    'v': '刪除筆記',
                                    'c': const Color(0xFFE53935),
                                  },
                                ],
                              }
                            ];

                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 12, left: 40, right: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: categories.map((cat) {
                                  final catColor = cat['color'] as Color;
                                  final catBg = cat['bgColor'] as Color;
                                  final catTitle = cat['title'] as String;
                                  final catItems = cat['items']
                                      as List<Map<String, dynamic>>;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 6, left: 2),
                                          child: Row(children: [
                                            Container(
                                              width: 3,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: catColor,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 7),
                                            Text(catTitle,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: catColor,
                                                    letterSpacing: 0.4)),
                                          ]),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color:
                                                catBg.withValues(alpha: 0.45),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: catColor.withValues(
                                                    alpha: 0.12),
                                                width: 1),
                                          ),
                                          child: Column(
                                            children: catItems
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              final idx = entry.key;
                                              final opt = entry.value;
                                              final isLast =
                                                  idx == catItems.length - 1;
                                              final itemColor =
                                                  opt['c'] as Color;
                                              return Column(children: [
                                                InkWell(
                                                  onTap: () => _handleAISubmit(
                                                      opt['v'] as String,
                                                      modalController,
                                                      setModalState),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12,
                                                        vertical: 10),
                                                    child: Row(children: [
                                                      Container(
                                                        width: 36,
                                                        height: 36,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: itemColor
                                                              .withValues(
                                                                  alpha: 0.12),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                        child: Icon(
                                                            opt['icon']
                                                                as IconData,
                                                            size: 19,
                                                            color: itemColor),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                                opt['l']
                                                                    as String,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        13.5,
                                                                    color: Colors
                                                                        .black87,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600)),
                                                            const SizedBox(
                                                                height: 1),
                                                            Text(
                                                                opt['sub']
                                                                    as String,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color: Colors
                                                                        .grey
                                                                        .shade500)),
                                                          ],
                                                        ),
                                                      ),
                                                      Icon(
                                                          Icons
                                                              .chevron_right_rounded,
                                                          size: 18,
                                                          color: Colors
                                                              .grey.shade400),
                                                    ]),
                                                  ),
                                                ),
                                                if (!isLast)
                                                  Divider(
                                                      height: 1,
                                                      thickness: 0.5,
                                                      indent: 60,
                                                      endIndent: 12,
                                                      color:
                                                          catColor.withValues(
                                                              alpha: 0.15)),
                                              ]);
                                            }).toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }

                          if (msg['widgetType'] == 'notebook_category_picker') {
                            final filteredCats = NotesDatabase.categories
                                .where((c) => c != '全部')
                                .toList();
                            final categories = <Map<String, dynamic>>[
                              {
                                'title': '📁 選擇筆記分類',
                                'color': const Color(0xFF8D6E63),
                                'bgColor': const Color(0xFFEFEBE9),
                                'items': filteredCats.map((cat) {
                                  return {
                                    'icon': Icons.folder_open_outlined,
                                    'l': cat,
                                    'sub': '將此筆記歸類於 $cat',
                                    'v': cat,
                                    'c': const Color(0xFF8D6E63),
                                  };
                                }).toList(),
                              }
                            ];

                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 12, left: 40, right: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: categories.map((cat) {
                                  final catColor = cat['color'] as Color;
                                  final catBg = cat['bgColor'] as Color;
                                  final catTitle = cat['title'] as String;
                                  final catItems = cat['items']
                                      as List<Map<String, dynamic>>;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 6, left: 2),
                                          child: Row(children: [
                                            Container(
                                              width: 3,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: catColor,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 7),
                                            Text(catTitle,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: catColor,
                                                    letterSpacing: 0.4)),
                                          ]),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color:
                                                catBg.withValues(alpha: 0.45),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: catColor.withValues(
                                                    alpha: 0.12),
                                                width: 1),
                                          ),
                                          child: Column(
                                            children: catItems
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              final idx = entry.key;
                                              final opt = entry.value;
                                              final isLast =
                                                  idx == catItems.length - 1;
                                              final itemColor =
                                                  opt['c'] as Color;
                                              return Column(children: [
                                                InkWell(
                                                  onTap: () => _handleAISubmit(
                                                      opt['v'] as String,
                                                      modalController,
                                                      setModalState),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12,
                                                        vertical: 10),
                                                    child: Row(children: [
                                                      Container(
                                                        width: 36,
                                                        height: 36,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: itemColor
                                                              .withValues(
                                                                  alpha: 0.12),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                        child: Icon(
                                                            opt['icon']
                                                                as IconData,
                                                            size: 19,
                                                            color: itemColor),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                                opt['l']
                                                                    as String,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        13.5,
                                                                    color: Colors
                                                                        .black87,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600)),
                                                            const SizedBox(
                                                                height: 1),
                                                            Text(
                                                                opt['sub']
                                                                    as String,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color: Colors
                                                                        .grey
                                                                        .shade500)),
                                                          ],
                                                        ),
                                                      ),
                                                      Icon(
                                                          Icons
                                                              .chevron_right_rounded,
                                                          size: 18,
                                                          color: Colors
                                                              .grey.shade400),
                                                    ]),
                                                  ),
                                                ),
                                                if (!isLast)
                                                  Divider(
                                                      height: 1,
                                                      thickness: 0.5,
                                                      indent: 60,
                                                      endIndent: 12,
                                                      color:
                                                          catColor.withValues(
                                                              alpha: 0.15)),
                                              ]);
                                            }).toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }

                          if (msg['widgetType'] == 'confirm_note') {
                            final note = msg['pendingData'] as Note;
                            return Container(
                                margin: const EdgeInsets.only(
                                    bottom: 16, left: 40, right: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: Colors.brown.shade200),
                                ),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(note.title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.brown.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(note.category,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.brown)),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(note.content,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87)),
                                      const SizedBox(height: 12),
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () {
                                                if (Navigator.canPop(context)) {
                                                  Navigator.pop(context);
                                                }
                                                _changePage(5, '筆記本');
                                              },
                                              child: const Text('完成',
                                                  style: TextStyle(
                                                      color: Colors.grey)),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.brown,
                                                  foregroundColor:
                                                      Colors.white),
                                              onPressed: () {
                                                if (Navigator.canPop(context)) {
                                                  Navigator.pop(context);
                                                }
                                                _changePage(5, '筆記本');
                                                Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            NoteEditorScreen(
                                                                note: note)));
                                              },
                                              child: const Text('立即開啟'),
                                            )
                                          ])
                                    ]));
                          }

                          if (msg['widgetType'] == 'note_search_results') {
                            final results = msg['pendingData'] as List<Note>;
                            return Container(
                                margin: const EdgeInsets.only(
                                    bottom: 16, left: 40, right: 10),
                                child: Column(
                                  children: results
                                      .map((note) => Card(
                                          elevation: 2,
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          child: ListTile(
                                              title: Text(note.title),
                                              subtitle: Text(note.content,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                              trailing: const Icon(
                                                  Icons.arrow_forward_ios,
                                                  size: 14),
                                              onTap: () {
                                                if (Navigator.canPop(context)) {
                                                  Navigator.pop(context);
                                                }
                                                _changePage(5, '筆記本');
                                                Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (_) =>
                                                            NoteEditorScreen(
                                                                note: note)));
                                              })))
                                      .toList(),
                                ));
                          }

                          if (msg['widgetType'] == 'help_options') {
                            final isGuest = widget.currentUser['id'] == 'u4';

                            // ── 分類結構定義 ──────────────────────────────
                            final categories = <Map<String, dynamic>>[
                              {
                                'title': '📅 行程管理',
                                'color': const Color(0xFF42A5F5),
                                'bgColor': const Color(0xFFE3F2FD),
                                'items': <Map<String, dynamic>>[
                                  {
                                    'icon': Icons.add_circle_outline,
                                    'l': '新增行程或待辦',
                                    'sub': '對話建立日曆行程或待辦事項',
                                    'v': '新增',
                                    'c': const Color(0xFF42A5F5),
                                  },
                                  {
                                    'icon': Icons.edit_note_outlined,
                                    'l': '修改行程或待辦',
                                    'sub': '編輯或刪除已建立項目',
                                    'v': '修改',
                                    'c': const Color(0xFF66BB6A),
                                  },
                                ],
                              },
                              if (!isGuest)
                                {
                                  'title': '🌐 社群互動',
                                  'color': const Color(0xFFFF7043),
                                  'bgColor': const Color(0xFFFBE9E7),
                                  'items': <Map<String, dynamic>>[
                                    {
                                      'icon': Icons.dynamic_feed_outlined,
                                      'l': '發佈社群貼文',
                                      'sub': '分享學習心得與文章',
                                      'v': '發佈貼文',
                                      'c': const Color(0xFFFF7043),
                                    },
                                    {
                                      'icon': Icons.question_answer_outlined,
                                      'l': '回覆社群留言',
                                      'sub': '與同學互動交流',
                                      'v': '回覆哪些留言',
                                      'c': const Color(0xFF26C6DA),
                                    },
                                  ],
                                },
                              {
                                'title': '📚 學習工具',
                                'color': const Color(0xFF26A69A),
                                'bgColor': const Color(0xFFE0F2F1),
                                'items': <Map<String, dynamic>>[
                                  {
                                    'icon': Icons.menu_book_outlined,
                                    'l': '跳轉題庫測驗',
                                    'sub': '開始練習與自我測試',
                                    'v': '題庫',
                                    'c': const Color(0xFF26A69A),
                                  },
                                  if (!isGuest)
                                    {
                                      'icon': Icons.note_alt_outlined,
                                      'l': '筆記本管理',
                                      'sub': '整理並查閱學習筆記',
                                      'v': '筆記本管理',
                                      'c': const Color(0xFF8D6E63),
                                    },
                                ],
                              },
                              {
                                'title': '⚙️ 個人設定',
                                'color': const Color(0xFFAB47BC),
                                'bgColor': const Color(0xFFF3E5F5),
                                'items': <Map<String, dynamic>>[
                                  {
                                    'icon': Icons.manage_accounts_outlined,
                                    'l': '修改個人資料',
                                    'sub': '更新頭像、暱稱與簡介',
                                    'v': '個人檔案',
                                    'c': const Color(0xFFAB47BC),
                                  },
                                  {
                                    'icon': Icons.palette_outlined,
                                    'l': '切換佈景主題',
                                    'sub': '調整顏色風格與深淺模式',
                                    'v': '切換主題',
                                    'c': const Color(0xFFEC407A),
                                  },
                                ],
                              },
                            ];

                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 12, left: 40, right: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: categories.map((cat) {
                                  final catColor = cat['color'] as Color;
                                  final catBg = cat['bgColor'] as Color;
                                  final catTitle = cat['title'] as String;
                                  final catItems = cat['items']
                                      as List<Map<String, dynamic>>;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // ── 分組標題列 ──────────────────
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 6, left: 2),
                                          child: Row(children: [
                                            Container(
                                              width: 3,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: catColor,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                            const SizedBox(width: 7),
                                            Text(catTitle,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: catColor,
                                                    letterSpacing: 0.4)),
                                          ]),
                                        ),
                                        // ── 卡片群組容器 ─────────────────
                                        Container(
                                          decoration: BoxDecoration(
                                            color:
                                                catBg.withValues(alpha: 0.45),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: catColor.withValues(
                                                    alpha: 0.12),
                                                width: 1),
                                          ),
                                          child: Column(
                                            children: catItems
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              final idx = entry.key;
                                              final opt = entry.value;
                                              final isLast =
                                                  idx == catItems.length - 1;
                                              final itemColor =
                                                  opt['c'] as Color;
                                              return Column(children: [
                                                InkWell(
                                                  onTap: () => _handleAISubmit(
                                                      opt['v'] as String,
                                                      modalController,
                                                      setModalState),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12,
                                                        vertical: 10),
                                                    child: Row(children: [
                                                      Container(
                                                        width: 36,
                                                        height: 36,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: itemColor
                                                              .withValues(
                                                                  alpha: 0.12),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                        child: Icon(
                                                            opt['icon']
                                                                as IconData,
                                                            size: 19,
                                                            color: itemColor),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                                opt['l']
                                                                    as String,
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        13.5,
                                                                    color: Colors
                                                                        .black87,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600)),
                                                            const SizedBox(
                                                                height: 1),
                                                            Text(
                                                                opt['sub']
                                                                    as String,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color: Colors
                                                                        .grey
                                                                        .shade500)),
                                                          ],
                                                        ),
                                                      ),
                                                      Icon(
                                                          Icons
                                                              .chevron_right_rounded,
                                                          size: 18,
                                                          color: Colors
                                                              .grey.shade400),
                                                    ]),
                                                  ),
                                                ),
                                                if (!isLast)
                                                  Divider(
                                                      height: 1,
                                                      thickness: 0.5,
                                                      indent: 60,
                                                      endIndent: 12,
                                                      color:
                                                          catColor.withValues(
                                                              alpha: 0.15)),
                                              ]);
                                            }).toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }

                          if (msg['widgetType'] == 'post_type_picker') {
                            final categories = <Map<String, dynamic>>[
                              {
                                'title': '🌐 選擇貼文類型',
                                'color': const Color(0xFFFF7043),
                                'bgColor': const Color(0xFFFBE9E7),
                                'items': <Map<String, dynamic>>[
                                  {
                                    'icon': Icons.chat_bubble_outline_rounded,
                                    'l': '一般貼文',
                                    'sub': '日常點滴與心情分享',
                                    'v': '一般',
                                    'c': const Color(0xFF78909C),
                                  },
                                  {
                                    'icon': Icons.note_alt_outlined,
                                    'l': '學習筆記',
                                    'sub': '記錄學習過程與心得',
                                    'v': '學習筆記',
                                    'c': const Color(0xFF43A047),
                                  },
                                  {
                                    'icon': Icons.psychology_outlined,
                                    'l': '心情文章',
                                    'sub': '抒發生活與讀書心得',
                                    'v': '心情文章',
                                    'c': const Color(0xFF7E57C2),
                                  },
                                  {
                                    'icon': Icons.folder_shared_outlined,
                                    'l': '分享資料',
                                    'sub': '提供考試或學術資源分享',
                                    'v': '分享資料',
                                    'c': const Color(0xFF1E88E5),
                                  },
                                ],
                              }
                            ];
                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 14, left: 40, right: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── 提示 Banner ──
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF8E1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFFFFE082)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.touch_app_outlined,
                                            size: 15, color: Color(0xFFF9A825)),
                                        SizedBox(width: 6),
                                        Text(
                                          '請點選下方貼文類型來繼續 👇',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFF57F17),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // ── 卡片清單 ──
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: categories.map((cat) {
                                      final catColor = cat['color'] as Color;
                                      final catBg = cat['bgColor'] as Color;
                                      final catTitle = cat['title'] as String;
                                      final catItems = cat['items']
                                          as List<Map<String, dynamic>>;

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 6, left: 2),
                                            child: Row(children: [
                                              Container(
                                                width: 3,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: catColor,
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                ),
                                              ),
                                              const SizedBox(width: 7),
                                              Text(catTitle,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: catColor,
                                                      letterSpacing: 0.4)),
                                            ]),
                                          ),
                                          Container(
                                            decoration: BoxDecoration(
                                              color:
                                                  catBg.withValues(alpha: 0.45),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                  color: catColor.withValues(
                                                      alpha: 0.12),
                                                  width: 1),
                                            ),
                                            child: Column(
                                              children: catItems
                                                  .asMap()
                                                  .entries
                                                  .map((entry) {
                                                final idx = entry.key;
                                                final opt = entry.value;
                                                final isLast =
                                                    idx == catItems.length - 1;
                                                final itemColor =
                                                    opt['c'] as Color;
                                                return Column(children: [
                                                  InkWell(
                                                    onTap: () =>
                                                        _handleAISubmit(
                                                            opt['v'] as String,
                                                            modalController,
                                                            setModalState),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14),
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 12,
                                                          vertical: 10),
                                                      child: Row(children: [
                                                        Container(
                                                          width: 36,
                                                          height: 36,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: itemColor
                                                                .withValues(
                                                                    alpha:
                                                                        0.12),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                          ),
                                                          child: Icon(
                                                              opt['icon']
                                                                  as IconData,
                                                              size: 19,
                                                              color: itemColor),
                                                        ),
                                                        const SizedBox(
                                                            width: 12),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                  opt['l']
                                                                      as String,
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          13.5,
                                                                      color: Colors
                                                                          .black87,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600)),
                                                              const SizedBox(
                                                                  height: 1),
                                                              Text(
                                                                  opt['sub']
                                                                      as String,
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      color: Colors
                                                                          .grey
                                                                          .shade500)),
                                                            ],
                                                          ),
                                                        ),
                                                        Icon(
                                                            Icons
                                                                .chevron_right_rounded,
                                                            size: 18,
                                                            color: Colors
                                                                .grey.shade400),
                                                      ]),
                                                    ),
                                                  ),
                                                  if (!isLast)
                                                    Divider(
                                                        height: 1,
                                                        thickness: 0.5,
                                                        indent: 60,
                                                        endIndent: 12,
                                                        color:
                                                            catColor.withValues(
                                                                alpha: 0.15)),
                                                ]);
                                              }).toList(),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (msg['widgetType'] == 'ai_loading') {
                            return _buildAiLoading(msg);
                          }

                          if (msg['widgetType'] == 'organize_note_picker') {
                            return _OrganizeNotePickerWidget(
                                userId: widget.currentUser['id'] as String?,
                                onSelected: (title) => _handleAISubmit(
                                    title, modalController, setModalState));
                          }

                          if (msg['widgetType'] == 'organized_note_result') {
                            return _OrganizedNoteResultWidget(
                                data: msg['pendingData'] ?? {},
                                onReplace: () {
                                  showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                              title: const Text('確認附加'),
                                              content: const Text(
                                                  '確定要將大綱加入原筆記的最上方嗎？'),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                    child: const Text('取消')),
                                                TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(ctx);
                                                      final title = msg[
                                                              'pendingData'][
                                                          'selected_note_title'];
                                                      final summary = msg[
                                                                  'pendingData']
                                                              ['summary'] ??
                                                          '• 本篇重點：介紹了基本概念與應用場景\n• 待辦事項：複習第二章、完成課後練習';
                                                      final idx = NotesDatabase
                                                          .notes
                                                          .indexWhere((n) =>
                                                              n.title == title);
                                                      if (idx != -1) {
                                                        NotesDatabase.notes[idx]
                                                                .content =
                                                            '# AI 整理大綱\n$summary\n\n---\n\n${NotesDatabase.notes[idx].content}';
                                                      }
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                              const SnackBar(
                                                                  content: Text(
                                                                      '已成功附加！')));
                                                      _changePage(5, '筆記本');
                                                      Navigator.pop(context);
                                                    },
                                                    child: const Text('確定'))
                                              ]));
                                },
                                onSaveNew: () {
                                  final title =
                                      msg['pendingData']['selected_note_title'];
                                  final summary = msg['pendingData']
                                          ['summary'] ??
                                      '• 本篇重點：介紹了基本概念與應用場景\n• 待辦事項：複習第二章、完成課後練習';
                                  final newNote = Note(
                                      id: DateTime.now()
                                          .millisecondsSinceEpoch
                                          .toString(),
                                      userId: widget.currentUser['id'],
                                      title: '${title ?? ''} (AI整理)',
                                      content: '# AI 整理大綱\n$summary',
                                      category: 'AI 整理',
                                      strokes: [],
                                      updatedAt: DateTime.now());
                                  NotesDatabase.notes.insert(0, newNote);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('已儲存為新筆記！')));
                                  _changePage(5, '筆記本');
                                  Navigator.pop(context);
                                },
                                onImport: () {
                                  final questions = msg['pendingData']
                                      ['questions'] as List<dynamic>?;
                                  final List<Map<String, dynamic>> toAdd = [];
                                  if (questions != null &&
                                      questions.isNotEmpty) {
                                    for (var q in questions) {
                                      toAdd.add({
                                        'subject': q['subject'] ?? 'AI 生成',
                                        'difficulty': q['difficulty'] ?? '中',
                                        'question': q['question'] ?? '',
                                        'options':
                                            List<String>.from(q['options']),
                                        'answerIndex': q['answerIndex'] ?? 0,
                                        'explanation': q['explanation'] ?? '',
                                      });
                                    }
                                  } else {
                                    toAdd.addAll([
                                      {
                                        'subject': 'AI 生成',
                                        'difficulty': '中',
                                        'question': '根據筆記，核心架構分為幾個步驟？',
                                        'options': ['二個', '三個', '四個'],
                                        'answerIndex': 1,
                                        'explanation': '筆記重點指出核心架構分為三個主要步驟進行。'
                                      },
                                      {
                                        'subject': 'AI 生成',
                                        'difficulty': '易',
                                        'question': '以下何者為待辦事項？',
                                        'options': ['撰寫報告', '複習第二章', '參加會議'],
                                        'answerIndex': 1,
                                        'explanation': '筆記中的待辦事項有明確列出：複習第二章。'
                                      }
                                    ]);
                                  }
                                  setState(() {
                                    questionBank.addAll(toAdd);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              '✅ 已成功匯入 ${toAdd.length} 題測驗至題庫！')));
                                });
                          }

                          if (msg['widgetType'] == 'add_type_confirmation') {
                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 12, left: 40, right: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(
                                          Icons.calendar_month_outlined,
                                          size: 16),
                                      label: const Text('日曆行程'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF42A5F5),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _handleAISubmit('日曆行程',
                                          modalController, setModalState),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.check_box_outlined,
                                          size: 16),
                                      label: const Text('待辦事項'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFFF9800),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _handleAISubmit('待辦事項',
                                          modalController, setModalState),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (msg['widgetType'] == 'edit_type_confirmation') {
                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 12, left: 40, right: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(
                                          Icons.edit_calendar_outlined,
                                          size: 16),
                                      label: const Text('修改行程'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF66BB6A),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _handleAISubmit('日曆行程',
                                          modalController, setModalState),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.check_box_outlined,
                                          size: 16),
                                      label: const Text('修改待辦'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFFF9800),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _handleAISubmit('待辦事項',
                                          modalController, setModalState),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (msg['widgetType'] == 'edit_todo_picker') {
                            if (allTodos.isEmpty) {
                              return Container(
                                margin:
                                    const EdgeInsets.only(bottom: 12, left: 40),
                                alignment: Alignment.centerLeft,
                                child: const Text('目前您沒有任何待辦事項。',
                                    style: TextStyle(color: Colors.grey)),
                              );
                            }
                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 12, left: 16, right: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: allTodos.map((todo) {
                                  final isDone =
                                      todo['isDone'] as bool? ?? false;
                                  final titleStr =
                                      todo['title'] as String? ?? '無內容';
                                  final todoId = todo['id'].toString();
                                  return GestureDetector(
                                    onTap: () => _handleAISubmit(
                                        'EDIT_TODO:$todoId|||$titleStr',
                                        modalController,
                                        setModalState),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDone
                                            ? Colors.grey.shade100
                                            : const Color(0xFF8D6E63)
                                                .withValues(alpha: 0.1),
                                        border: Border.all(
                                            color: isDone
                                                ? Colors.grey.shade300
                                                : const Color(0xFF8D6E63)
                                                    .withValues(alpha: 0.4)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isDone
                                                ? Icons.check_circle_outline
                                                : Icons.circle_outlined,
                                            color: isDone
                                                ? Colors.grey
                                                : const Color(0xFF8D6E63),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              titleStr,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                decoration: isDone
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                                color: isDone
                                                    ? Colors.grey
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          const Icon(Icons.edit,
                                              size: 14, color: Colors.grey),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }

                          if (msg['widgetType'] == 'edit_todo_field_picker') {
                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 12, left: 40, right: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('修改內容'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF8D6E63),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _handleAISubmit('修改內容',
                                          modalController, setModalState),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 16),
                                      label: const Text('刪除待辦'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _handleAISubmit('刪除待辦',
                                          modalController, setModalState),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (msg['widgetType'] == 'confirm_cancel_picker') {
                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 12, left: 40, right: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('確定'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _handleAISubmit(
                                          '確定', modalController, setModalState),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('取消'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade400,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _handleAISubmit(
                                          '取消', modalController, setModalState),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (msg['widgetType'] == 'add_type_confirmation' ||
                              msg['widgetType'] == 'edit_type_confirmation') {
                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 12, left: 40, right: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.event, size: 16),
                                      label: Text(msg['widgetType'] ==
                                              'add_type_confirmation'
                                          ? '新增行程'
                                          : '修改行程'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF8D6E63),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _handleAISubmit(
                                          '行程', modalController, setModalState),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.check_box_outlined,
                                          size: 16),
                                      label: Text(msg['widgetType'] ==
                                              'add_type_confirmation'
                                          ? '新增待辦'
                                          : '修改待辦'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _handleAISubmit(
                                          '待辦', modalController, setModalState),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (msg['widgetType'] == 'edit_event_picker') {
                            final sortedKeys = allSchedules.keys.toList()
                              ..sort();
                            // Filter out dates that are too old (e.g., before today)
                            final todayStr = DateTime.now()
                                .toIso8601String()
                                .substring(0, 10);
                            final futureKeys = sortedKeys
                                .where((k) => k.compareTo(todayStr) >= 0)
                                .toList();

                            if (futureKeys.isEmpty) {
                              return Container(
                                margin:
                                    const EdgeInsets.only(bottom: 12, left: 40),
                                alignment: Alignment.centerLeft,
                                child: const Text('目前您沒有任何即將到來的行程。',
                                    style: TextStyle(color: Colors.grey)),
                              );
                            }
                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 12, left: 16, right: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: futureKeys.map((dk) {
                                  final dayEvs = allSchedules[dk] ?? [];
                                  if (dayEvs.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 4, bottom: 8, top: 12),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today,
                                                size: 14,
                                                color: Colors.grey.shade600),
                                            const SizedBox(width: 6),
                                            Text(
                                              dk,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ...dayEvs.map((ev) {
                                        final colorVal =
                                            ev['color'] as int? ?? 0xFFFFCC80;
                                        final timeStr =
                                            ev['time'] as String? ?? '';
                                        final titleStr =
                                            ev['title'] as String? ?? '無標題';
                                        final evId = ev['id'].toString();
                                        return GestureDetector(
                                          onTap: () => _handleAISubmit(
                                              'EDIT_EVENT:$evId|||$titleStr|||$dk|||$timeStr',
                                              modalController,
                                              setModalState),
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 8),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Color(colorVal)
                                                  .withValues(alpha: 0.25),
                                              border: Border.all(
                                                  color: Color(colorVal)
                                                      .withValues(alpha: 0.7)),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(children: [
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: Color(colorVal),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(titleStr,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13)),
                                                    Text(timeStr,
                                                        style: const TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                Colors.grey)),
                                                  ],
                                                ),
                                              ),
                                              const Icon(
                                                  Icons.arrow_forward_ios,
                                                  size: 12,
                                                  color: Colors.grey),
                                            ]),
                                          ),
                                        );
                                      }),
                                      const SizedBox(height: 6),
                                    ],
                                  );
                                }).toList(),
                              ),
                            );
                          }

                          // ── 修改行程欄位選擇器 ──
                          if (msg['widgetType'] == 'edit_event_field_picker') {
                            return Container(
                              margin:
                                  const EdgeInsets.only(bottom: 12, left: 40),
                              alignment: Alignment.centerLeft,
                              child: Wrap(spacing: 8, children: [
                                ActionChip(
                                  label: const Text('✏️ 修改標題'),
                                  backgroundColor: const Color(0xFFFFF3E0),
                                  onPressed: () => _handleAISubmit(
                                      '修改標題', modalController, setModalState),
                                ),
                                ActionChip(
                                  label: const Text('🕒 修改時間與日期'),
                                  backgroundColor: const Color(0xFFE3F2FD),
                                  onPressed: () => _handleAISubmit('修改時間與日期',
                                      modalController, setModalState),
                                ),
                              ]),
                            );
                          }

                          if (msg['widgetType'] == 'confirm_post') {
                            var pData = msg['pendingData'] ?? {};
                            final typeLabel = pData['type'] ?? '一般';
                            final typeIconMap = {
                              '一般': '💬',
                              '學習筆記': '📝',
                              '心情文章': '💭',
                              '分享資料': '📄'
                            };
                            final typeIcon = typeIconMap[typeLabel] ?? '💬';
                            return Container(
                              margin: const EdgeInsets.only(
                                  bottom: 14, left: 16, right: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8D6E63)
                                        .withValues(alpha: 0.15),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── Header gradient bar ──
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF6D4C41),
                                          Color(0xFF8D6E63)
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(20)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                              Icons.schedule_send_rounded,
                                              color: Colors.white,
                                              size: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('待發布排程確認',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15)),
                                              Text('請確認以下貼文資訊',
                                                  style: TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // ── Info section ──
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Type chip
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF5F0EE),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                    color:
                                                        const Color(0xFFBCAAA4),
                                                    width: 1),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(typeIcon,
                                                      style: const TextStyle(
                                                          fontSize: 13)),
                                                  const SizedBox(width: 5),
                                                  Text(typeLabel,
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                              0xFF5D4037))),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        // Content preview
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFAF7F5),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: const Color(0xFFEEE0D8)),
                                          ),
                                          child: Text(
                                            pData['content'] ?? '',
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF4E342E),
                                                height: 1.5),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        // Schedule time row
                                        Row(
                                          children: [
                                            const Icon(
                                                Icons
                                                    .access_time_filled_rounded,
                                                size: 15,
                                                color: Color(0xFF8D6E63)),
                                            const SizedBox(width: 6),
                                            Text(
                                              pData['time'] != null &&
                                                      pData['time']
                                                          .toString()
                                                          .isNotEmpty
                                                  ? pData['time'].toString()
                                                  : '立即發布',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF8D6E63),
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // ── Divider ──
                                  const Divider(
                                      height: 1, color: Color(0xFFF0E9E6)),
                                  // ── Action buttons ──
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        // Discard
                                        TextButton(
                                          onPressed: () => _handleAISubmit('取消',
                                              modalController, setModalState),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                Colors.red.shade400,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.delete_outline,
                                                  size: 15),
                                              SizedBox(width: 4),
                                              Text('捨棄',
                                                  style:
                                                      TextStyle(fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        // Publish now
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                const Color(0xFF8D6E63),
                                            side: const BorderSide(
                                                color: Color(0xFF8D6E63),
                                                width: 1.2),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 9),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                          ),
                                          onPressed: () =>
                                              _publishAIPost(pData, false),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.send_rounded,
                                                  size: 14),
                                              SizedBox(width: 5),
                                              Text('立即發布',
                                                  style:
                                                      TextStyle(fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Confirm schedule
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF6D4C41),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 9),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                          ),
                                          onPressed: () =>
                                              _publishAIPost(pData, true),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.schedule_rounded,
                                                  size: 14),
                                              SizedBox(width: 5),
                                              Text('確認排程',
                                                  style:
                                                      TextStyle(fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (msg['text'] == null || msg['text'].isEmpty) {
                            return const SizedBox();
                          }

                          Widget messageWidget = Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.65),
                            decoration: BoxDecoration(
                                color: msg['isAI']
                                    ? Colors.white
                                    : const Color(0xFF8D6E63),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: msg['isAI']
                                    ? [
                                        BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.03),
                                            blurRadius: 5)
                                      ]
                                    : []),
                            child: Text(msg['text'],
                                style: TextStyle(
                                    fontSize: 14,
                                    color: msg['isAI']
                                        ? Colors.black87
                                        : Colors.white)),
                          );

                          if (!msg['isAI']) {
                            messageWidget = GestureDetector(
                              onLongPress: () {
                                showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    builder: (ctx) => Container(
                                        decoration: const BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.vertical(
                                                top: Radius.circular(20))),
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                  leading: const Icon(
                                                      Icons.copy,
                                                      color: Color(0xFF8D6E63)),
                                                  title: const Text('複製文字'),
                                                  onTap: () {
                                                    Navigator.pop(ctx);
                                                    Clipboard.setData(
                                                        ClipboardData(
                                                            text: msg['text']));
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                            const SnackBar(
                                                                content: Text(
                                                                    '已複製到剪貼簿')));
                                                  }),
                                              ListTile(
                                                  leading: const Icon(
                                                      Icons.edit,
                                                      color: Color(0xFF8D6E63)),
                                                  title: const Text('編輯'),
                                                  onTap: () async {
                                                    Navigator.pop(ctx);

                                                    final confirm =
                                                        await showDialog<bool>(
                                                      context: context,
                                                      builder: (dialogCtx) =>
                                                          AlertDialog(
                                                        title: const Text(
                                                            '編輯並回溯對話'),
                                                        content: const Text(
                                                            '您確定要重新執行此步驟嗎？這會清除該步驟之後的所有對話紀錄。'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    dialogCtx,
                                                                    false),
                                                            child: const Text(
                                                                '取消'),
                                                          ),
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    dialogCtx,
                                                                    true),
                                                            child: const Text(
                                                                '確定'),
                                                          ),
                                                        ],
                                                      ),
                                                    );

                                                    if (confirm == true) {
                                                      final targetState =
                                                          msg['stateAtTime'] ??
                                                              'none';
                                                      const pickerStates = {
                                                        'editing_event_pick',
                                                        'editing_event_field',
                                                        'editing_event_new_time',
                                                        'organizing_note_select'
                                                      };

                                                      setModalState(() {
                                                        _aiFlowState =
                                                            targetState;
                                                        // Remove the edited message and all subsequent messages
                                                        chatLogs.removeRange(
                                                            i, chatLogs.length);

                                                        if (pickerStates
                                                            .contains(
                                                                targetState)) {
                                                          modalController
                                                              .clear();
                                                        } else {
                                                          modalController.text =
                                                              msg['text'];
                                                        }
                                                      });
                                                    }
                                                  }),
                                              const SizedBox(height: 20)
                                            ])));
                              },
                              child: messageWidget,
                            );
                          }

                          return Align(
                            alignment: msg['isAI']
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: msg['isAI']
                                ? Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Color(0xFF8D6E63),
                                        child: Icon(Icons.smart_toy,
                                            size: 18, color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      messageWidget,
                                    ],
                                  )
                                : messageWidget,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Text('提醒：代理人可能會產生不準確的資訊，請自行查證。',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 11)),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16,
                          MediaQuery.of(context).viewInsets.bottom + 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Focus(
                              onKeyEvent: (FocusNode node, KeyEvent event) {
                                final isMobile = !kIsWeb &&
                                    (Platform.isAndroid || Platform.isIOS);
                                if (isMobile) {
                                  return KeyEventResult.ignored;
                                }
                                final isEnter = event.logicalKey ==
                                        LogicalKeyboardKey.enter ||
                                    event.logicalKey ==
                                        LogicalKeyboardKey.numpadEnter;
                                if (event is KeyDownEvent && isEnter) {
                                  if (HardwareKeyboard
                                      .instance.isShiftPressed) {
                                    final text = modalController.text;
                                    final selection = modalController.selection;
                                    if (selection.start >= 0) {
                                      final newText = text.replaceRange(
                                          selection.start, selection.end, '\n');
                                      modalController.value = TextEditingValue(
                                        text: newText,
                                        selection: TextSelection.collapsed(
                                            offset: selection.start + 1),
                                      );
                                    } else {
                                      modalController.text = '$text\n';
                                    }
                                    return KeyEventResult.handled;
                                  } else {
                                    _handleAISubmit(modalController.text,
                                        modalController, setModalState);
                                    return KeyEventResult.handled;
                                  }
                                }
                                return KeyEventResult.ignored;
                              },
                              child: TextField(
                                controller: modalController,
                                minLines: 1,
                                maxLines: 5,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                decoration: InputDecoration(
                                    hintText: '去題庫 / 看日曆 / 加行程...',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                              backgroundColor: const Color(0xFF8D6E63),
                              child: IconButton(
                                  icon: const Icon(Icons.send,
                                      color: Colors.white, size: 20),
                                  onPressed: () => _handleAISubmit(
                                      modalController.text,
                                      modalController,
                                      setModalState))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        });
  }

  /// 意圖解析函數：根據使用者輸入文字，自動關聯並執行對應的功能方法
  bool _parseIntent(String userInput, StateSetter setModalState) {
    final result = AIIntentService.parse(userInput);

    // 內部輔助：同時更新主頁面與彈窗狀態，確保對話紀錄不遺失
    void updateLogs(VoidCallback fn) {
      setModalState(fn); // 執行修改 chatLogs 並刷新彈窗
      if (mounted) setState(() {}); // 刷新主頁面
    }

    // 如果完全沒有意圖也沒有建議，才回傳 false 觸發後備清單
    if (result.intent == UserIntent.none && result.suggestionLabel == null) {
      return false;
    }

    // 處理「建議引導」 (中等信心度)
    if (result.intent == UserIntent.none && result.suggestionLabel != null) {
      updateLogs(() {
        chatLogs.add({'isAI': false, 'text': userInput});
        chatLogs.add({
          'isAI': true,
          'text':
              '唔... 您是指「${result.suggestionLabel}」功能嗎？😅\n如果是的話，您可以點擊下方按鈕，或輸入「${result.suggestionKeyword}」來處理。',
          'isCard': false
        });
        // 新增：提供點擊按鈕
        chatLogs.add({
          'isAI': true,
          'text': '',
          'isCard': false,
          'widgetType': 'suggestion_action',
          'suggestionLabel': result.suggestionLabel,
          'suggestionKeyword': result.suggestionKeyword,
        });
        _scrollToBottom();
      });
      return true;
    }

    final intent = result.intent;

    // 輔助方法：切換到個人主頁並捲動
    void goToProfile(double offset) {
      if (Navigator.canPop(context)) Navigator.pop(context); // 關閉聊天面板
      _changePage(4, '個人檔案');
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_profileScrollController.hasClients) {
          _profileScrollController.animateTo(offset,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut);
        }
      });
    }

    switch (intent) {
      case UserIntent.changeNickname:
        updateLogs(() {
          chatLogs.add({'isAI': false, 'text': userInput});
          chatLogs.add(
              {'isAI': true, 'text': '沒問題！這就為您開啟相關設定介面 🛠️', 'isCard': false});
        });
        goToProfile(650);
        _showEditNicknameDialog();
        return true;
      case UserIntent.changeAvatar:
        updateLogs(() {
          chatLogs.add({'isAI': false, 'text': userInput});
          chatLogs.add(
              {'isAI': true, 'text': '沒問題！這就為您開啟相關設定介面 🛠️', 'isCard': false});
        });
        goToProfile(0);
        _pickAvatarFromLocal();
        return true;
      case UserIntent.editBio:
        updateLogs(() {
          chatLogs.add({'isAI': false, 'text': userInput});
          chatLogs.add(
              {'isAI': true, 'text': '沒問題！這就為您開啟相關設定介面 🛠️', 'isCard': false});
        });
        goToProfile(650);
        _showEditBioDialog();
        return true;
      case UserIntent.changeFontSize:
        updateLogs(() {
          chatLogs.add({'isAI': false, 'text': userInput});
          chatLogs.add(
              {'isAI': true, 'text': '沒問題！這就為您開啟相關設定介面 🛠️', 'isCard': false});
        });
        goToProfile(400);
        _showFontSizeDialog();
        return true;
      case UserIntent.changeTheme:
        updateLogs(() {
          chatLogs.add({'isAI': false, 'text': userInput});
          chatLogs.add(
              {'isAI': true, 'text': '沒問題！這就為您開啟相關設定介面 🛠️', 'isCard': false});
        });
        goToProfile(400);
        _showThemeColorDialog();
        return true;
      case UserIntent.verifyEmail:
        updateLogs(() {
          chatLogs.add({'isAI': false, 'text': userInput});
          chatLogs.add(
              {'isAI': true, 'text': '沒問題！這就為您開啟相關設定介面 🛠️', 'isCard': false});
        });
        goToProfile(900);
        _showEmailVerificationFlow();
        return true;
      case UserIntent.changePassword:
        updateLogs(() {
          chatLogs.add({'isAI': false, 'text': userInput});
          chatLogs.add(
              {'isAI': true, 'text': '沒問題！這就為您開啟相關設定介面 🛠️', 'isCard': false});
        });
        goToProfile(900);
        _showChangePasswordDialog();
        return true;
      case UserIntent.logout:
        _showLogoutDialog();
        return true;
      case UserIntent.createPost:
        // 觸發發文流程 — 先選類型
        updateLogs(() {
          chatLogs.add(
              {'isAI': false, 'text': userInput, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'adding_post_type';
          _aiFlowData = {};
          chatLogs.add({
            'isAI': true,
            'text': '好的，我們來發佈一則貼文吧！\n請先選擇貼文的類型：',
            'isCard': false,
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'post_type_picker'
          });
          _scrollToBottom();
        });
        return true;
      case UserIntent.viewItinerary:
        if (Navigator.canPop(context)) Navigator.pop(context);
        _changePage(0, '日曆行程');
        updateLogs(() {
          chatLogs.add({'isAI': false, 'text': userInput});
          chatLogs
              .add({'isAI': true, 'text': '沒問題，已為您跳轉至日曆！', 'isCard': false});
        });
        return true;
      case UserIntent.createItinerary:
        // 觸發新增行程流程
        updateLogs(() {
          chatLogs.add(
              {'isAI': false, 'text': userInput, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'adding_event_title';
          _aiFlowData = {};
          chatLogs.add({
            'isAI': true,
            'text': '我很樂意幫您新增行程！\n請問這個行程的標題是什麼？',
            'isCard': false
          });
          _scrollToBottom();
        });
        return true;
      case UserIntent.createTodo:
        // 觸發新增待辦流程
        updateLogs(() {
          chatLogs.add(
              {'isAI': false, 'text': userInput, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'adding_todo_title';
          _aiFlowData = {};
          chatLogs.add({
            'isAI': true,
            'text': '我很樂意幫您新增待辦事項！\n，請問這個待辦事項的標題是什麼？',
            'isCard': false
          });
          _scrollToBottom();
        });
        return true;
      case UserIntent.editItinerary:
        // 觸發修改現有行程流程
        updateLogs(() {
          chatLogs.add(
              {'isAI': false, 'text': userInput, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'editing_event_pick';
          _aiFlowData = {};
          chatLogs.add({
            'isAI': true,
            'text': '好的！請問您想修改哪一個行程？\n請從下方列表點選：',
            'isCard': false
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'edit_event_picker',
          });
          _scrollToBottom();
        });
        return true;
      case UserIntent.editTodo:
        // 觸發修改現有待辦流程
        updateLogs(() {
          chatLogs.add(
              {'isAI': false, 'text': userInput, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'editing_todo_pick';
          _aiFlowData = {};
          chatLogs.add({
            'isAI': true,
            'text': '好的！請問您想修改哪一個待辦事項？\n請從下方列表點選：',
            'isCard': false
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'edit_todo_picker',
          });
          _scrollToBottom();
        });
        return true;
      case UserIntent.addGeneric:
        // 觸發新增確認流程
        updateLogs(() {
          chatLogs.add(
              {'isAI': false, 'text': userInput, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'confirming_add_type';
          _aiFlowData = {};
          chatLogs.add({
            'isAI': true,
            'text': '好的，請問您想要新增『日曆行程』還是『待辦事項』呢？',
            'isCard': false
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'add_type_confirmation',
          });
          _scrollToBottom();
        });
        return true;
      case UserIntent.editGeneric:
        // 觸發修改確認流程
        updateLogs(() {
          chatLogs.add(
              {'isAI': false, 'text': userInput, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'confirming_edit_type';
          _aiFlowData = {};
          chatLogs.add({
            'isAI': true,
            'text': '好的，請問您想要修改『日曆行程』還是『待辦事項』呢？',
            'isCard': false
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'edit_type_confirmation',
          });
          _scrollToBottom();
        });
        return true;
      case UserIntent.viewSocial:
        if (Navigator.canPop(context)) Navigator.pop(context);
        _changePage(2, '社群');
        updateLogs(() {
          chatLogs.add({'isAI': false, 'text': userInput});
          chatLogs.add({'isAI': true, 'text': '好的，帶您去社群！', 'isCard': false});
        });
        return true;
      case UserIntent.viewQuestionBank:
        if (Navigator.canPop(context)) Navigator.pop(context);
        _changePage(1, '題庫');
        updateLogs(() {
          chatLogs.add({'isAI': false, 'text': userInput});
          chatLogs.add({'isAI': true, 'text': '切換至題庫系統！', 'isCard': false});
        });
        return true;
      case UserIntent.viewProfile:
        if (Navigator.canPop(context)) Navigator.pop(context);
        _changePage(4, '個人檔案');
        updateLogs(() {
          chatLogs.add({'isAI': false, 'text': userInput});
          chatLogs.add({'isAI': true, 'text': '已為您打開個人檔案！', 'isCard': false});
        });
        return true;
      case UserIntent.viewActivity:
        if (Navigator.canPop(context)) Navigator.pop(context);
        _changePage(3, '社群動態');
        updateLogs(() {
          chatLogs.add({'isAI': false, 'text': userInput});
          chatLogs
              .add({'isAI': true, 'text': '好的，帶您去看看您的社群動態！', 'isCard': false});
        });
        return true;
      case UserIntent.viewPendingComments:
        _handleViewPendingComments(setModalState);
        return true;
      case UserIntent.help:
        updateLogs(() {
          chatLogs.add({'isAI': false, 'text': userInput});
          chatLogs.add({
            'isAI': true,
            'text':
                '我可以幫您處理以下事項：\n\n1. 📅 **新增行程**：直接輸入標題，或說「加行程」。\n2. 📝 **發布貼文**：輸入「發貼文」或「分享心情」。\n3. 🛠️ **個人設定**：修改暱稱、換頭像、改顏色或字體。\n4. 👤 **個人檔案**：查看您的詳細資料與設定。\n\n請問您現在需要哪方面的協助？',
            'isCard': false,
            'widgetType': 'help_options'
          });
          _scrollToBottom();
        });
        return true;
      case UserIntent.viewNotes:
        if (Navigator.canPop(context)) Navigator.pop(context);
        _changePage(5, '筆記本');
        updateLogs(() {
          chatLogs.add({'isAI': false, 'text': userInput});
          chatLogs.add({'isAI': true, 'text': '已為您切換至筆記本畫面！', 'isCard': false});
        });
        return true;
      case UserIntent.createNote:
        updateLogs(() {
          chatLogs.add(
              {'isAI': false, 'text': userInput, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'adding_note_title';
          _aiFlowData = {};
          chatLogs.add({
            'isAI': true,
            'text': '好的，讓我來協助您新增一篇筆記！📓\n首先，請問這篇筆記的標題是什麼？',
            'isCard': false
          });
          _scrollToBottom();
        });
        return true;
      case UserIntent.searchNote:
        updateLogs(() {
          chatLogs.add(
              {'isAI': false, 'text': userInput, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'searching_note';
          chatLogs
              .add({'isAI': true, 'text': '請問您想搜尋什麼關鍵字或分類？', 'isCard': false});
          _scrollToBottom();
        });
        // 若直接包含關鍵字，可優化提取
        return true;
      case UserIntent.deleteNote:
        updateLogs(() {
          chatLogs.add(
              {'isAI': false, 'text': userInput, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'deleting_note_title';
          chatLogs.add({
            'isAI': true,
            'text': '請告訴我您想刪除的筆記標題，我會幫您找出來。',
            'isCard': false
          });
          _scrollToBottom();
        });
        return true;
      case UserIntent.organizeNote:
        final isGuest = widget.currentUser['id'] == 'u4';
        if (isGuest) {
          updateLogs(() {
            chatLogs.add({
              'isAI': false,
              'text': userInput,
              'stateAtTime': _aiFlowState
            });
            chatLogs.add({
              'isAI': true,
              'text': '抱歉，訪客帳戶無法使用筆記與相關的 AI 整理功能。請登入或註冊正式帳號以開啟此功能！',
              'isCard': false
            });
            _scrollToBottom();
          });
          return true;
        }
        updateLogs(() {
          chatLogs.add(
              {'isAI': false, 'text': userInput, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'organizing_note_select';
          chatLogs.add({
            'isAI': true,
            'text': '好的！請問您想整理哪一篇筆記？請在下方搜尋或選擇：',
            'isCard': false
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'organize_note_picker'
          });
          _scrollToBottom();
        });
        return true;
      default:
        return false;
    }
  }

  void _handleViewPendingComments(StateSetter setModalState) async {
    setModalState(() {
      chatLogs.add({
        'isAI': true,
        'text': '沒問題，我這就幫您看看有哪些需要回覆的留言... 💬',
        'isCard': false
      });
      _scrollToBottom();
    });

    final db = await DatabaseHelper.instance.database;
    final myPostIds = socialPosts
        .where((p) => p['userId'] == widget.currentUser['id'])
        .map((p) => p['id'])
        .toList();

    List<Map<String, dynamic>> pendingComments = [];
    if (myPostIds.isNotEmpty) {
      final placeholders = List.filled(myPostIds.length, '?').join(',');
      final comments = await db.query('comments',
          where: 'post_id IN ($placeholders)', whereArgs: myPostIds);
      for (var c in comments) {
        if (c['user_id'] != widget.currentUser['id']) {
          // 【修復】原本用 parent_id 嚴格匹配，但用戶在 PostReplyPage
          // 直接留言時 parent_id=0，導致誤判為「未回覆」。
          // 改為：只要貼文下有任何來自當前用戶、發布時間晚於該留言的回覆，
          // 就視為「已處理」。
          final alreadyReplied = await db.rawQuery(
            'SELECT id FROM comments WHERE post_id = ? AND user_id = ? AND created_at > ?',
            [c['post_id'], widget.currentUser['id'], c['created_at']],
          );
          if (alreadyReplied.isNotEmpty) continue;

          var u = await db
              .query('users', where: 'id = ?', whereArgs: [c['user_id']]);
          String authorName =
              u.isNotEmpty ? u.first['display_name'] as String : '未知用戶';
          pendingComments.add({
            'commentId': c['id'],
            'postId': c['post_id'],
            'text': c['text'],
            'authorId': c['user_id'],
            'authorName': authorName,
          });
        }
      }
    }

    setModalState(() {
      if (pendingComments.isEmpty) {
        chatLogs
            .add({'isAI': true, 'text': '目前您的貼文下沒有需要回覆的留言喔！', 'isCard': false});
        _scrollToBottom();
      } else {
        _aiPendingReplyPosts = pendingComments.take(2).toList();
        _aiFlowState = 'replying';
        _aiReplyPostIndex = 0;
        var firstItem = _aiPendingReplyPosts[0];
        var originalPost = socialPosts.firstWhere(
            (p) => p['id'] == firstItem['postId'],
            orElse: () => {'content': '未知貼文'});
        chatLogs.add({
          'isAI': true,
          'text':
              '為您找到 ${_aiPendingReplyPosts.length} 則可以回覆的留言！\n\n您的貼文：「${originalPost['content']}」\n底下有來自「${firstItem['authorName']}」的留言：\n「${firstItem['text']}」\n請問您想回覆什麼？(若不想回覆這則請點擊下方按鈕或說「跳過」)',
          'isCard': false
        });
        chatLogs.add({
          'isAI': true,
          'text': '',
          'isCard': false,
          'widgetType': 'skip_button'
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _handleAISubmit(String input, TextEditingController controller,
      StateSetter setModalState) async {
    if (input.trim().isEmpty) return;
    String text = input.trim();
    final inputLower = text.toLowerCase();
    controller.clear();
    _scrollToBottom();

    // 若在任務流程中，但使用者輸入的是系統的頂層指令（如 ActionChips 按鈕），則打斷並重置流程
    if (_aiFlowState != 'none') {
      const systemCommands = {
        '查看筆記本',
        '新增筆記',
        '整理筆記',
        '搜尋筆記',
        '刪除筆記',
        '筆記本管理',
        '社群',
        '社群動態',
        '新增行程',
        '新增待辦',
        '發佈貼文',
        '回覆哪些留言',
        '個人檔案',
        '切換主題',
        '題庫',
        '重來',
        '取消',
        '取消行程',
        '取消待辦',
        '取消發佈',
        '新增',
        '修改',
        '修改待辦'
      };
      if (systemCommands.contains(text)) {
        _aiFlowState = 'none';
      }
    }

    if (_aiFlowState == 'none') {
      if (text == '筆記本管理') {
        setModalState(() {
          chatLogs.add({'isAI': false, 'text': text});
          chatLogs.add({
            'isAI': true,
            'text':
                '📓 您好！我是您的筆記本小助手。請問今天有什麼我可以幫忙的呢？\n\n您可以直接打字對我說，例如：「幫我新增筆記」、「幫我整理某篇筆記的重點摘要」或「搜尋筆記」。\n\n或者也可以直接點選下方的常用功能喔：',
            'isCard': false
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'notebook_options'
          });
          _scrollToBottom();
        });
        return;
      }

      // 簡單對話處理 (Chitchat)
      if (inputLower == '哈囉' ||
          inputLower == '你好' ||
          inputLower == '嗨' ||
          inputLower == 'hi' ||
          inputLower == 'hello') {
        setModalState(() {
          chatLogs.add({'isAI': false, 'text': text});
          chatLogs.add({
            'isAI': true,
            'text': '嗨！很高興見到你！😊 我是你的代理人助手，隨時準備好為你服務。今天有什麼我可以幫你的嗎？',
            'isCard': false
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'help_options'
          });
          _scrollToBottom();
        });
        return;
      }

      // 意圖解析處理已移至下方統一由 _parseIntent 處理

      if (inputLower.contains('謝謝') ||
          inputLower.contains('感恩') ||
          inputLower.contains('太棒了') ||
          inputLower.contains('thanks')) {
        setModalState(() {
          chatLogs.add({'isAI': false, 'text': text});
          chatLogs.add({
            'isAI': true,
            'text': '不客氣！這是我應該做的。😊 如果還有其他需要，隨時跟我說喔！',
            'isCard': false
          });
          _scrollToBottom();
        });
        return;
      }

      if (inputLower == '掰掰' ||
          inputLower == '再見' ||
          inputLower == '掰' ||
          inputLower == 'bye' ||
          inputLower.contains('下次見')) {
        setModalState(() {
          chatLogs.add({'isAI': false, 'text': text});
          chatLogs.add(
              {'isAI': true, 'text': '好的，下次見囉！👋 祝你有個美好的一天！', 'isCard': false});
          _scrollToBottom();
        });
        return;
      }

      // 幫助指令處理
      if (inputLower == 'help' ||
          inputLower == '幫助' ||
          inputLower.contains('你能做什麼') ||
          inputLower.contains('可以幫什麼') ||
          inputLower.contains('指令') ||
          inputLower.contains('功能')) {
        setModalState(() {
          chatLogs.add({'isAI': false, 'text': text});
          chatLogs.add({
            'isAI': true,
            'text': '沒問題！我很樂意向您介紹。😊\n以下是我目前可以為您提供的協助事項：',
            'isCard': false
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'help_options'
          });
          chatLogs.add(
              {'isAI': true, 'text': '您可以點擊上方選項，或直接說給我聽吧！', 'isCard': false});
          _scrollToBottom();
        });
        return;
      }
    } // End of _aiFlowState == 'none' check

    if (text == '重來' || text == '取消' || text == '取消行程' || text == '取消發佈') {
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'none';
        chatLogs.add({
          'isAI': true,
          'text': '好的，已為您取消目前的進度。請問還有什麼我可以幫忙的？',
          'isCard': false
        });
        _scrollToBottom();
      });
      return;
    }

    if (_aiFlowState == 'replying') {
      var commentItem = _aiPendingReplyPosts[_aiReplyPostIndex];
      var post = socialPosts.firstWhere((p) => p['id'] == commentItem['postId'],
          orElse: () => {'content': '未知貼文'});

      if (text == '跳過' || text == '跳過這則' || text == '不用') {
        setModalState(() {
          chatLogs
              .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        });
        _aiReplyPostIndex++;
        if (_aiReplyPostIndex < _aiPendingReplyPosts.length) {
          var nextItem = _aiPendingReplyPosts[_aiReplyPostIndex];
          var nextPost = socialPosts.firstWhere(
              (p) => p['id'] == nextItem['postId'],
              orElse: () => {'content': '未知貼文'});
          setModalState(() {
            chatLogs.add({
              'isAI': true,
              'text':
                  '已跳過！下一則留言是針對您的貼文：「${nextPost['content']}」\n來自「${nextItem['authorName']}」：\n「${nextItem['text']}」\n請問您想回覆什麼？(若不回覆請點擊下方按鈕或說「跳過」)',
              'isCard': false
            });
            chatLogs.add({
              'isAI': true,
              'text': '',
              'isCard': false,
              'widgetType': 'skip_button'
            });
            _scrollToBottom();
          });
        } else {
          setModalState(() {
            chatLogs.add(
                {'isAI': true, 'text': '🎉 所有待回覆的留言都已處理完畢！', 'isCard': false});
            _aiFlowState = 'none';
            _scrollToBottom();
          });
        }
        return;
      }

      String replyText = text;

      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        chatLogs.add(
            {'isAI': true, 'text': '好的！立刻帶您到畫面上執行回覆動作...', 'isCard': false});
        _scrollToBottom();
      });

      Navigator.pop(context);
      _changePage(2, '社群');

      final navigator = Navigator.of(context);
      Future.delayed(const Duration(milliseconds: 600), () {
        navigator
            .push(MaterialPageRoute(
                builder: (_) => PostReplyPage(
                    originalPost: post,
                    currentUser: widget.currentUser,
                    autoTypeMessage: replyText,
                    targetCommentId: commentItem['commentId'],
                    targetCommentName: commentItem['authorName'],
                    onAutoTypeDone: () {
                      _aiReplyPostIndex++;
                      if (_aiReplyPostIndex < _aiPendingReplyPosts.length) {
                        var nextItem = _aiPendingReplyPosts[_aiReplyPostIndex];
                        var nextPost = socialPosts.firstWhere(
                            (p) => p['id'] == nextItem['postId'],
                            orElse: () => {'content': '未知貼文'});
                        chatLogs.add({
                          'isAI': true,
                          'text':
                              '已完成！下一則留言是針對您的貼文：「${nextPost['content']}」\n來自「${nextItem['authorName']}」：\n「${nextItem['text']}」\n請問您想回覆什麼？(若不回覆請點擊下方按鈕或說「跳過」)',
                          'isCard': false
                        });
                        chatLogs.add({
                          'isAI': true,
                          'text': '',
                          'isCard': false,
                          'widgetType': 'skip_button'
                        });
                        _openChatModal();
                      } else {
                        chatLogs.add({
                          'isAI': true,
                          'text': '🎉 所有待回覆的留言都已處理完畢！',
                          'isCard': false
                        });
                        _aiFlowState = 'none';
                        _openChatModal();
                      }
                    })))
            .then((_) => _loadData());
      });
      return;
    }

    if (_aiFlowState == 'adding_event_title') {
      _aiFlowData['title'] = text;
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'adding_event_datetime';
        chatLogs.add({
          'isAI': true,
          'text': '收到了，行程標題為「$text」。\n請用滾輪一次選好日期、開始與結束時間：',
          'isCard': false
        });
        chatLogs.add({
          'isAI': true,
          'text': '',
          'isCard': false,
          'widgetType': 'time_range_picker'
        });
        _scrollToBottom();
      });
      return;
    }

    if (_aiFlowState == 'adding_event_datetime') {
      // 格式: "2026-05-21 09:00|||2026-05-21 10:00"
      String cleanText = text;
      if (cleanText.contains('開始') || cleanText.contains('結束')) {
        final matches = RegExp(r'\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}')
            .allMatches(cleanText)
            .map((m) => m.group(0)!)
            .toList();
        if (matches.length >= 2) {
          cleanText = '${matches[0]}|||${matches[1]}';
        } else if (matches.length == 1) {
          cleanText = '${matches[0]}|||${matches[0]}';
        }
      }
      final parts = cleanText.split('|||');
      _aiFlowData['start_date'] = parts[0].trim();
      _aiFlowData['end_date'] =
          parts.length > 1 ? parts[1].trim() : parts[0].trim();

      final displayStart = _aiFlowData['start_date'];
      final displayEnd = _aiFlowData['end_date'];
      setModalState(() {
        chatLogs.add({
          'isAI': false,
          'text': '開始：$displayStart  結束：$displayEnd',
          'stateAtTime': _aiFlowState
        });
        _aiFlowState = 'adding_event_color_style';
        chatLogs.add({
          'isAI': true,
          'text':
              '已設定時段：\n🟢 開始：$displayStart\n🔴 結束：$displayEnd\n\n最後一步，想幫這個行程挑選什麼風格的標籤顏色呢？',
          'isCard': false
        });
        chatLogs.add({
          'isAI': true,
          'text': '',
          'isCard': false,
          'widgetType': 'color_style_picker'
        });
        _scrollToBottom();
      });
      return;
    }

    if (_aiFlowState == 'adding_event_color_style') {
      final isLight = text.contains('淺');
      _aiFlowData['color_style'] = isLight ? 'light' : 'dark';
      final styleLabel = isLight ? '淺色系' : '深色系';
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'adding_event_color';
        chatLogs.add({
          'isAI': true,
          'text': '好的！已為您準備【$styleLabel】專屬色盤 🎨\n請從下方點選喜歡的顏色，或拖動滑桿自訂顏色：',
          'isCard': false
        });
        chatLogs.add({
          'isAI': true,
          'text': '',
          'isCard': false,
          'widgetType': 'color_palette',
          'colorStyle': _aiFlowData['color_style'],
        });
        _scrollToBottom();
      });
      return;
    }

    if (_aiFlowState == 'adding_event_color') {
      // text 傳入的是 ARGB int 字串，例如 "4294951115"
      final colorValue = int.tryParse(text) ?? 0xFF8D6E63;
      _aiFlowData['color'] = colorValue;

      // 從 int 轉 Color 以顯示預覽
      final previewColor = Color(colorValue);
      final hexStr = colorValue.toRadixString(16).toUpperCase().padLeft(8, '0');

      setModalState(() {
        chatLogs.add({
          'isAI': false,
          'text': '已選擇顏色 #${hexStr.substring(2)}',
          'stateAtTime': _aiFlowState
        });
        chatLogs
            .add({'isAI': true, 'text': '漂亮的選擇！ 正在為您加入行程...', 'isCard': false});
        _scrollToBottom();
      });

      Navigator.pop(context);
      _changePage(0, '日曆行程');

      Future.delayed(const Duration(milliseconds: 600), () async {
        try {
          final db = await DatabaseHelper.instance.database;
          String? startStr = _aiFlowData['start_date'] as String?;
          String? endStr = _aiFlowData['end_date'] as String?;

          if (startStr == null || startStr.isEmpty) {
            startStr = DateTime.now().toIso8601String().substring(0, 16);
          }
          if (endStr == null || endStr.isEmpty) {
            endStr = DateTime.now()
                .add(const Duration(hours: 1))
                .toIso8601String()
                .substring(0, 16);
          }

          if (startStr.length <= 16) startStr = "$startStr:00";
          if (endStr.length <= 16) endStr = "$endStr:00";

          await db.insert('calendar_events', {
            'user_id': widget.currentUser['id'],
            'title': _aiFlowData['title'] ?? '無標題行程',
            'start_time': startStr,
            'end_time': endStr,
            'color': '0x${colorValue.toRadixString(16)}',
          });
          await _loadData();

          // 自動同步與跳轉至新行程的日期與月份，方便用戶在畫面上直接看到
          final eventDate = DateTime.tryParse(startStr);
          if (eventDate != null) {
            _syncDate(eventDate, fromCalendar: true);
            // 計算年份與月份差距，跳轉日曆月視圖 PageController
            final deltaMonths =
                (eventDate.year - 2026) * 12 + (eventDate.month - 3);
            final targetPage = 12 + deltaMonths;
            if (_calendarPageController.hasClients) {
              _calendarPageController.jumpToPage(targetPage);
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(children: [
                  Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                          color: previewColor, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  const Text('代理人已為您成功加入行程！'),
                ]),
              ),
            );
          }
        } catch (e) {
          debugPrint('代理人新增行程失敗: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('代理人新增行程失敗: $e'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      });
      _aiFlowState = 'none';
      return;
    }

    // --- 修改行程流程 ---
    if (_aiFlowState == 'editing_event_pick') {
      if (text.startsWith('EDIT_EVENT:')) {
        final payload = text.substring('EDIT_EVENT:'.length);
        final parts = payload.split('|||');
        if (parts.length >= 4) {
          _aiFlowData['edit_event_id'] = parts[0];
          _aiFlowData['edit_event_title'] = parts[1];
          _aiFlowData['edit_event_date'] = parts[2];
          _aiFlowData['edit_event_time'] = parts[3];
        }
        final evTitle = _aiFlowData['edit_event_title'] ?? '這個行程';
        final evDate = _aiFlowData['edit_event_date'] ?? '';
        final evTime = _aiFlowData['edit_event_time'] ?? '';
        setModalState(() {
          chatLogs.add({
            'isAI': false,
            'text': '選擇行程：$evTitle',
            'stateAtTime': _aiFlowState
          });
          _aiFlowState = 'editing_event_field';
          chatLogs.add({
            'isAI': true,
            'text': '好的！您選擇了「$evTitle」($evDate $evTime)。\n請問您想修改什麼？',
            'isCard': false,
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'edit_event_field_picker',
          });
          _scrollToBottom();
        });
        return;
      }
    }

    if (_aiFlowState == 'editing_event_field') {
      if (text == '修改標題') {
        setModalState(() {
          chatLogs
              .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'editing_event_new_title';
          chatLogs.add({'isAI': true, 'text': '請輸入新的行程標題：', 'isCard': false});
          _scrollToBottom();
        });
        return;
      }
      if (text == '修改時間與日期') {
        setModalState(() {
          chatLogs
              .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'editing_event_new_time';
          chatLogs
              .add({'isAI': true, 'text': '請使用滾輪選擇新的日期與時段：', 'isCard': false});
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'time_range_picker',
          });
          _scrollToBottom();
        });
        return;
      }
    }

    if (_aiFlowState == 'editing_event_new_title') {
      final newTitle = text;
      final eventId = int.tryParse(_aiFlowData['edit_event_id'] ?? '') ?? -1;
      final oldTimeRange =
          _aiFlowData['edit_event_time'] as String? ?? '00:00~00:00';
      final eventDate = _aiFlowData['edit_event_date'] as String?;
      setModalState(() {
        chatLogs.add(
            {'isAI': false, 'text': newTitle, 'stateAtTime': _aiFlowState});
        chatLogs.add({'isAI': true, 'text': '正在更新行程標題...', 'isCard': false});
        _scrollToBottom();
      });
      Future.delayed(const Duration(milliseconds: 400), () async {
        try {
          final db = await DatabaseHelper.instance.database;
          final current = await db
              .query('calendar_events', where: 'id = ?', whereArgs: [eventId]);
          int colorVal = 0xFFFFCC80;
          if (current.isNotEmpty) {
            final colorStr = current.first['color'] as String? ?? '';
            if (colorStr.isNotEmpty) {
              final hex = colorStr.replaceAll('0x', '');
              colorVal =
                  int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16) ??
                      colorVal;
            }
          }
          DateTime? parsedDate = DateTime.tryParse(eventDate ?? "");
          _editSchedule(eventId, oldTimeRange, newTitle, colorVal,
              startDate: parsedDate, endDate: parsedDate);
          if (mounted) {
            if (Navigator.canPop(context)) Navigator.pop(context);
            _changePage(0, '日曆行程');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ 行程標題已更新為「$newTitle」！'),
                backgroundColor: const Color(0xFF8D6E63),
              ),
            );
          }
        } catch (e) {
          debugPrint('AI修改行程標題失敗: $e');
        }
      });
      _aiFlowState = 'none';
      return;
    }

    if (_aiFlowState == 'editing_event_new_time') {
      // 格式: '2026-06-03 09:00|||2026-06-03 10:00'
      String cleanText = text;
      if (cleanText.contains('開始') ||
          cleanText.contains('結束') ||
          cleanText.contains('時段') ||
          cleanText.contains('新時段')) {
        final matches = RegExp(r'\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}')
            .allMatches(cleanText)
            .map((m) => m.group(0)!)
            .toList();
        if (matches.length >= 2) {
          cleanText = '${matches[0]}|||${matches[1]}';
        } else if (matches.length == 1) {
          cleanText = '${matches[0]}|||${matches[0]}';
        }
      }
      final parts = cleanText.split('|||');
      if (parts.length >= 2) {
        final newStartFull = parts[0].trim();
        final newEndFull = parts[1].trim();
        final eventId = int.tryParse(_aiFlowData['edit_event_id'] ?? '') ?? -1;
        final startParts = newStartFull.split(' ');
        final endParts = newEndFull.split(' ');
        final newDate = startParts.isNotEmpty
            ? startParts[0]
            : (_aiFlowData['edit_event_date'] ?? '');
        final startTime = startParts.length > 1 ? startParts[1] : '09:00';
        final endTime = endParts.length > 1 ? endParts[1] : '10:00';
        final newTimeRange = '$startTime~$endTime';
        final eventTitle = _aiFlowData['edit_event_title'] as String? ?? '行程';
        setModalState(() {
          chatLogs.add({
            'isAI': false,
            'text':
                '新時段：$newStartFull ~ ${endParts.length > 1 ? endParts[1] : ""}',
            'stateAtTime': _aiFlowState
          });
          chatLogs.add({'isAI': true, 'text': '正在更新行程時間...', 'isCard': false});
          _scrollToBottom();
        });
        Future.delayed(const Duration(milliseconds: 400), () async {
          try {
            final db = await DatabaseHelper.instance.database;
            final current = await db.query('calendar_events',
                where: 'id = ?', whereArgs: [eventId]);
            int colorVal = 0xFFFFCC80;
            if (current.isNotEmpty) {
              final colorStr = current.first['color'] as String? ?? '';
              if (colorStr.isNotEmpty) {
                final hex = colorStr.replaceAll('0x', '');
                colorVal =
                    int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16) ??
                        colorVal;
              }
            }
            DateTime? parsedDate = DateTime.tryParse(newDate);
            _editSchedule(eventId, newTimeRange, eventTitle, colorVal,
                startDate: parsedDate, endDate: parsedDate);
            if (mounted) {
              if (Navigator.canPop(context)) Navigator.pop(context);
              _changePage(0, '日曆行程');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('✅ 行程「$eventTitle」時間已更新至 $newDate $newTimeRange！'),
                  backgroundColor: const Color(0xFF8D6E63),
                ),
              );
            }
          } catch (e) {
            debugPrint('AI修改行程時間失敗: $e');
          }
        });
        _aiFlowState = 'none';
        return;
      }
    }

    if (_aiFlowState == 'adding_todo_title') {
      _aiFlowData['title'] = text;
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'none';
        chatLogs.add({'isAI': true, 'text': '為您建立待辦事項中...', 'isCard': false});
        _scrollToBottom();
      });

      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          final db = await DatabaseHelper.instance.database;
          await db.insert('todos', {
            'user_id': widget.currentUser['id'],
            'text': _aiFlowData['title'] ?? '無標題待辦',
            'done': 0,
            'created_at': DateTime.now().toIso8601String(),
          });
          await _loadData();

          if (mounted) {
            if (Navigator.canPop(context)) Navigator.pop(context);
            _changePage(0, '日曆行程');

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ 代理人已新增待辦：${_aiFlowData['title']}'),
                backgroundColor: const Color(0xFF8D6E63),
              ),
            );
          }
        } catch (e) {
          debugPrint('代理人新增待辦失敗: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('新增待辦事項失敗，請稍後再試。'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      });
      return;
    }

    if (_aiFlowState == 'confirming_add_type') {
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
      });
      if (text.contains('行程') || text.contains('日曆')) {
        setModalState(() {
          _aiFlowState = 'adding_event_title';
          _aiFlowData = {};
          chatLogs.add({
            'isAI': true,
            'text': '好的，開始建立新行程！請問這個行程的標題是什麼？',
            'isCard': false
          });
          _scrollToBottom();
        });
      } else if (text.contains('待辦') || text.contains('代辦')) {
        setModalState(() {
          _aiFlowState = 'adding_todo_title';
          _aiFlowData = {};
          chatLogs.add({
            'isAI': true,
            'text': '好的，開始建立新待辦事項！請問這個待辦事項的標題是什麼？',
            'isCard': false
          });
          _scrollToBottom();
        });
      } else {
        setModalState(() {
          _aiFlowState = 'none';
          chatLogs.add(
              {'isAI': true, 'text': '已取消新增。請問還有什麼我可以幫忙的？', 'isCard': false});
          _scrollToBottom();
        });
      }
      return;
    }

    if (_aiFlowState == 'confirming_edit_type') {
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
      });
      if (text.contains('行程') || text.contains('日曆')) {
        setModalState(() {
          _aiFlowState = 'editing_event_pick';
          _aiFlowData = {};
          chatLogs.add({
            'isAI': true,
            'text': '好的！請問您想修改哪一個行程？\n請從下方列表點選：',
            'isCard': false
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'edit_event_picker',
          });
          _scrollToBottom();
        });
      } else if (text.contains('待辦') || text.contains('代辦')) {
        setModalState(() {
          _aiFlowState = 'editing_todo_pick';
          _aiFlowData = {};
          chatLogs.add({
            'isAI': true,
            'text': '好的！請問您想修改哪一個待辦事項？\n請從下方列表點選：',
            'isCard': false
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'edit_todo_picker',
          });
          _scrollToBottom();
        });
      } else {
        setModalState(() {
          _aiFlowState = 'none';
          chatLogs.add(
              {'isAI': true, 'text': '已取消修改。請問還有什麼我可以幫忙的？', 'isCard': false});
          _scrollToBottom();
        });
      }
      return;
    }

    // --- 編輯待辦事項流程 ---
    if (_aiFlowState == 'editing_todo_pick') {
      if (text.startsWith('EDIT_TODO:')) {
        final payload = text.substring('EDIT_TODO:'.length);
        final parts = payload.split('|||');
        if (parts.length >= 2) {
          _aiFlowData['edit_todo_id'] = parts[0];
          _aiFlowData['edit_todo_title'] = parts[1];
        }
        final todoTitle = _aiFlowData['edit_todo_title'] ?? '這個待辦事項';
        setModalState(() {
          chatLogs.add({
            'isAI': false,
            'text': '選擇待辦事項：$todoTitle',
            'stateAtTime': _aiFlowState
          });
          _aiFlowState = 'editing_todo_field';
          chatLogs.add({
            'isAI': true,
            'text': '好的！您選擇了「$todoTitle」。\n請問您想做什麼？',
            'isCard': false,
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'edit_todo_field_picker',
          });
          _scrollToBottom();
        });
        return;
      }
    }

    if (_aiFlowState == 'editing_todo_field') {
      if (text == '修改內容') {
        setModalState(() {
          chatLogs
              .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'editing_todo_new_title';
          chatLogs.add({'isAI': true, 'text': '請輸入新的待辦事項內容：', 'isCard': false});
          _scrollToBottom();
        });
        return;
      }
      if (text == '刪除待辦') {
        final todoTitle = _aiFlowData['edit_todo_title'] ?? '這個待辦事項';
        setModalState(() {
          chatLogs
              .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'confirming_delete_todo';
          chatLogs.add({
            'isAI': true,
            'text': '確定要刪除待辦事項「$todoTitle」嗎？(請輸入 確定/取消)',
            'isCard': false
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'confirm_cancel_picker'
          });
          _scrollToBottom();
        });
        return;
      }
    }

    if (_aiFlowState == 'editing_todo_new_title') {
      final newTitle = text;
      final todoId = int.tryParse(_aiFlowData['edit_todo_id'] ?? '') ?? -1;
      setModalState(() {
        chatLogs.add(
            {'isAI': false, 'text': newTitle, 'stateAtTime': _aiFlowState});
        chatLogs.add({'isAI': true, 'text': '正在更新待辦事項內容...', 'isCard': false});
        _scrollToBottom();
      });
      Future.delayed(const Duration(milliseconds: 400), () async {
        try {
          final db = await DatabaseHelper.instance.database;
          await db.update('todos', {'text': newTitle},
              where: 'id = ?', whereArgs: [todoId]);
          await _loadData();
          if (mounted) {
            if (Navigator.canPop(context)) Navigator.pop(context);
            _changePage(0, '日曆行程');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ 待辦事項內容已更新為「$newTitle」！'),
                backgroundColor: const Color(0xFF8D6E63),
              ),
            );
          }
        } catch (e) {
          debugPrint('AI修改待辦內容失敗: $e');
        }
      });
      _aiFlowState = 'none';
      return;
    }

    if (_aiFlowState == 'confirming_delete_todo') {
      final todoId = int.tryParse(_aiFlowData['edit_todo_id'] ?? '') ?? -1;
      final todoTitle = _aiFlowData['edit_todo_title'] ?? '這個待辦事項';
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'none';
      });

      if (text.contains('確認') ||
          text.contains('確定') ||
          text.toLowerCase() == 'yes' ||
          text.toLowerCase() == 'y') {
        Future.delayed(const Duration(milliseconds: 400), () async {
          try {
            final db = await DatabaseHelper.instance.database;
            await db.delete('todos', where: 'id = ?', whereArgs: [todoId]);
            await _loadData();
            if (mounted) {
              if (Navigator.canPop(context)) Navigator.pop(context);
              _changePage(0, '日曆行程');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ 已刪除待辦事項：「$todoTitle」！'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          } catch (e) {
            debugPrint('AI刪除待辦失敗: $e');
          }
        });
      } else {
        setModalState(() {
          chatLogs.add({'isAI': true, 'text': '已取消刪除待辦事項。👌', 'isCard': false});
          _scrollToBottom();
        });
      }
      return;
    }

    if (_aiFlowState == 'adding_note_title') {
      _aiFlowData['title'] = text;
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'adding_note_category';
        chatLogs.add({
          'isAI': true,
          'text': '已記錄標題「$text」。\n接著，請選擇或輸入這篇筆記的分類：',
          'isCard': false
        });
        chatLogs.add({
          'isAI': true,
          'text': '',
          'isCard': false,
          'widgetType': 'notebook_category_picker'
        });
        _scrollToBottom();
      });
      return;
    }

    if (_aiFlowState == 'adding_note_category') {
      _aiFlowData['category'] = text;
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'adding_note_content';
        chatLogs.add({
          'isAI': true,
          'text': '好的，分類為「$text」。\n最後，請輸入筆記的內容：',
          'isCard': false
        });
        _scrollToBottom();
      });
      return;
    }

    if (_aiFlowState == 'adding_note_content') {
      _aiFlowData['content'] = text;
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'none';
        chatLogs.add({'isAI': true, 'text': '為您建立筆記中...', 'isCard': false});
        _scrollToBottom();
      });

      // 寫入 NotesDatabase
      final newNote = Note(
        id: 'note_ai_${DateTime.now().millisecondsSinceEpoch}',
        userId: widget.currentUser['id'],
        title: _aiFlowData['title'] ?? '無標題',
        category: _aiFlowData['category'] ?? '未分類',
        content: _aiFlowData['content'] ?? '',
        strokes: [],
        updatedAt: DateTime.now(),
      );
      if (!NotesDatabase.categories.contains(newNote.category)) {
        NotesDatabase.categories.add(newNote.category);
      }
      NotesDatabase.notes.insert(0, newNote);

      setModalState(() {
        chatLogs.add({
          'isAI': true,
          'text': '',
          'isCard': false,
          'widgetType': 'confirm_note',
          'pendingData': newNote
        });
        _scrollToBottom();
      });
      return;
    }

    if (_aiFlowState == 'searching_note') {
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'none';
      });

      final query = text.toLowerCase();
      final results = NotesDatabase.notes
          .where((n) =>
              n.userId == widget.currentUser['id'] &&
              (n.title.toLowerCase().contains(query) ||
                  n.content.toLowerCase().contains(query) ||
                  n.category.toLowerCase().contains(query)))
          .toList();

      setModalState(() {
        if (results.isEmpty) {
          chatLogs.add(
              {'isAI': true, 'text': '抱歉，沒有找到符合「$text」的筆記喔！', 'isCard': false});
        } else {
          chatLogs.add({
            'isAI': true,
            'text': '為您找到 ${results.length} 篇相關筆記：',
            'isCard': false
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'note_search_results',
            'pendingData': results
          });
        }
        _scrollToBottom();
      });
      return;
    }

    if (_aiFlowState == 'deleting_note_title') {
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
      });

      final query = text.toLowerCase();
      final results = NotesDatabase.notes
          .where((n) =>
              n.userId == widget.currentUser['id'] &&
              n.title.toLowerCase().contains(query))
          .toList();

      if (results.isEmpty) {
        setModalState(() {
          _aiFlowState = 'none';
          chatLogs.add(
              {'isAI': true, 'text': '抱歉，找不到標題包含「$text」的筆記。', 'isCard': false});
          _scrollToBottom();
        });
      } else if (results.length == 1) {
        final note = results.first;
        _aiFlowData['note_to_delete'] = note;
        setModalState(() {
          _aiFlowState = 'confirm_delete_note';
          chatLogs.add({
            'isAI': true,
            'text': '找到筆記「${note.title}」，確定要刪除嗎？(輸入 確定/取消)',
            'isCard': false
          });
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'confirm_cancel_picker'
          });
          _scrollToBottom();
        });
      } else {
        setModalState(() {
          _aiFlowState = 'none';
          chatLogs.add({
            'isAI': true,
            'text': '找到多篇名稱相似的筆記，為避免誤刪，請至筆記本首頁手動刪除喔！',
            'isCard': false
          });
          _scrollToBottom();
        });
      }
      return;
    }

    if (_aiFlowState == 'confirm_delete_note') {
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'none';
      });

      if (text.contains('確認') ||
          text.contains('確定') ||
          text.toLowerCase() == 'yes' ||
          text.toLowerCase() == 'y') {
        final note = _aiFlowData['note_to_delete'] as Note?;
        if (note != null) {
          NotesDatabase.notes.remove(note);
          setModalState(() {
            chatLogs.add({
              'isAI': true,
              'text': '已成功為您刪除筆記「${note.title}」！',
              'isCard': false
            });
          });
        }
      } else {
        setModalState(() {
          chatLogs.add({'isAI': true, 'text': '已取消刪除筆記動作。', 'isCard': false});
        });
      }
      setModalState(() {
        _scrollToBottom();
      });
      return;
    }

    if (_aiFlowState == 'adding_post_type') {
      _aiFlowData['type'] = text;
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'adding_post_content';
        chatLogs.add({
          'isAI': true,
          'text': '類型已選擇「$text」。\n接下來，請輸入這篇貼文的內容：',
          'isCard': false
        });
        _scrollToBottom();
      });
      return;
    }

    if (_aiFlowState == 'adding_post_content') {
      _aiFlowData['content'] = text;
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'adding_post_time';
        chatLogs.add({
          'isAI': true,
          'text': '收到！✍️\n最後，請問這篇貼文要什麼時候發佈？\n(可以直接點擊下方按鈕選取時間)',
          'isCard': false
        });
        chatLogs.add({
          'isAI': true,
          'text': '',
          'isCard': false,
          'widgetType': 'date_picker'
        });
        _scrollToBottom();
      });
      return;
    }

    if (_aiFlowState == 'adding_post_time') {
      _aiFlowData['time'] = text;
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'adding_post_confirm';
        chatLogs.add({
          'isAI': true,
          'text': '沒問題！為您建立以下貼文預覽：',
          'isCard': false,
          'widgetType': 'confirm_post',
          'pendingData': Map<String, dynamic>.from(_aiFlowData)
        });
        _scrollToBottom();
      });
      return;
    }

    if (_aiFlowState == 'adding_post_confirm') {
      if (text == '確認發佈') {
        setModalState(() {
          chatLogs.add({'isAI': false, 'text': text});
          chatLogs.add(
              {'isAI': true, 'text': '好的！正在為您發佈貼文... 🚀', 'isCard': false});
        });
        await _addPostFromAI(_aiFlowData);
        if (mounted) {
          if (Navigator.canPop(context)) Navigator.pop(context);
          _changePage(3, '社群動態');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 貼文已成功發佈！'),
              backgroundColor: Color(0xFF8D6E63),
            ),
          );
        }
        _aiFlowState = 'none';
      } else if (text == '取消發佈') {
        setModalState(() {
          chatLogs.add({'isAI': false, 'text': text});
          chatLogs.add({'isAI': true, 'text': '已取消貼文發佈。👌', 'isCard': false});
        });
        _aiFlowState = 'none';
      }
      _scrollToBottom();
      return;
    }

    if (_aiFlowState == 'organizing_note_select') {
      _aiFlowData['selected_note_title'] = text;

      // 尋找該筆記內容，動態生成摘要與題目
      final noteTitle = text;
      final noteIndex =
          NotesDatabase.notes.indexWhere((n) => n.title == noteTitle);
      Note? selectedNote;
      if (noteIndex != -1) {
        selectedNote = NotesDatabase.notes[noteIndex];
      }

      String noteContent = selectedNote?.content ?? '這是一篇空白筆記。';
      try {
        setModalState(() {
          chatLogs
              .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'organizing_note_processing';

          // 新增一個獨立的 Loading 動畫氣泡
          chatLogs.add({
            'isAI': true,
            'text': '',
            'isCard': false,
            'widgetType': 'ai_loading',
          });
          _scrollToBottom();
        });
      } catch (_) {}

      // 呼叫 AI 整理筆記服務
      AiDiagnosisService.generateNoteSummary(
        userId: widget.currentUser['id'],
        noteTitle: noteTitle,
        noteContent: noteContent,
      ).then((structuredData) {
        if (!mounted || _aiFlowState != 'organizing_note_processing') return;
        // Store structured data directly (points list + actions list)
        _aiFlowData['points'] = structuredData['points'] ?? [];
        _aiFlowData['actions'] = structuredData['actions'] ?? [];
        _aiFlowData['isAiGenerated'] = structuredData['isAiGenerated'] ?? false;
        // Also keep a plain text summary for note append
        final pts = (structuredData['points'] as List).join('\n• ');
        final acts = (structuredData['actions'] as List).join('\n• ');
        _aiFlowData['summary'] = '【重點摘要】\n• $pts\n\n【行動建議】\n• $acts';
        try {
          setModalState(() {
            _aiFlowState = 'none';
            // 移除 Loading 動畫氣泡
            chatLogs.removeWhere((msg) => msg['widgetType'] == 'ai_loading');

            chatLogs.add({
              'isAI': true,
              'text': '整理完成！🎉 以下是為您生成的 AI 重點摘要：',
              'isCard': false
            });
            chatLogs.add({
              'isAI': true,
              'text': '',
              'isCard': false,
              'widgetType': 'organized_note_result',
              'pendingData': Map<String, dynamic>.from(_aiFlowData)
            });
            _scrollToBottom();
          });
        } catch (_) {}
      });
      return;
    }

    // 意圖解析 (處理加行程、發貼文、改設定、跳轉頁面、幫助等)
    if (_aiFlowState == 'none' && _parseIntent(text, setModalState)) {
      return;
    }

    // 最終後備：如果完全聽不懂，且不在任何流程中
    setModalState(() {
      chatLogs.add({'isAI': false, 'text': text});
      chatLogs.add({
        'isAI': true,
        'text':
            '抱歉抱歉!我還太笨了~沒能理解您的意思... 😅\n但我可以幫您處理行程、貼文、或是修改個人設定！您可以輸入「幫助」來看看我能做什麼。',
        'isCard': false,
        'widgetType': 'help_options'
      });
      _scrollToBottom();
    });
  }

  // ── 風格選擇按鈕 ────────────────────────────────────────────────────────
  Widget _buildStyleBtn({
    required String icon,
    required String label,
    required String sub,
    required List<Color> grad,
    required VoidCallback onTap,
    List<Color> previewColors = const [],
    bool isDark = false,
  }) {
    final borderColor = isDark
        ? const Color(0xFF4A7C59).withValues(alpha: 0.45)
        : const Color(0xFFFF8FAB).withValues(alpha: 0.9);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.38)
        : const Color(0xFFFF8FAB).withValues(alpha: 0.32);
    final textColor = isDark ? Colors.white : const Color(0xFF3E2723);
    final subColor = isDark ? Colors.white60 : const Color(0xFF795548);
    final arrowBg = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFFF8FAB).withValues(alpha: 0.18);
    final arrowColor = isDark ? Colors.white54 : const Color(0xFFFF4081);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: grad,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: shadowColor,
                blurRadius: 14,
                spreadRadius: 0,
                offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(icon, style: const TextStyle(fontSize: 28)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  decoration: BoxDecoration(
                      color: arrowBg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      size: 11, color: arrowColor),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                    letterSpacing: 0.3)),
            const SizedBox(height: 3),
            Text(sub, style: TextStyle(fontSize: 11, color: subColor)),
            if (previewColors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: previewColors
                    .take(5)
                    .map((c) => Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: c.withValues(alpha: 0.45),
                                  blurRadius: 3,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                        ))
                    .toList(),
              )
            ],
          ],
        ),
      ),
    );
  }

  // ── 進階色盤（行程用）────────────────────────────────────────────────────
  Widget _buildInlineColorPalette(
      String style, TextEditingController ctrl, StateSetter setModalState) {
    final isLight = style == 'light';
    final presets = isLight
        ? <Color>[
            const Color(0xFFFFB3C1),
            const Color(0xFFFFD6A5),
            const Color(0xFFCAFFBF),
            const Color(0xFFBDE0FE),
            const Color(0xFFE2C2FF),
            const Color(0xFFFFF3B0),
          ]
        : <Color>[
            const Color(0xFF8B2635),
            const Color(0xFF2D6A4F),
            const Color(0xFF1B4F72),
            const Color(0xFF7D5A00),
            const Color(0xFF4A235A),
            const Color(0xFF2E4057),
          ];
    final double sat = isLight ? 0.70 : 0.55;
    final double lig = isLight ? 0.82 : 0.35;

    Color hslToColor(double h) {
      final double c = (1 - (2 * lig - 1).abs()) * sat;
      final double x = c * (1 - ((h / 60) % 2 - 1).abs());
      final double m = lig - c / 2;
      double r = 0, g = 0, b = 0;
      if (h < 60) {
        r = c;
        g = x;
        b = 0;
      } else if (h < 120) {
        r = x;
        g = c;
        b = 0;
      } else if (h < 180) {
        r = 0;
        g = c;
        b = x;
      } else if (h < 240) {
        r = 0;
        g = x;
        b = c;
      } else if (h < 300) {
        r = x;
        g = 0;
        b = c;
      } else {
        r = c;
        g = 0;
        b = x;
      }
      return Color.fromARGB(255, ((r + m) * 255).round(),
          ((g + m) * 255).round(), ((b + m) * 255).round());
    }

    Color selectedColor = presets[0];
    double selectedHue = 0.0;
    bool isCustom = false;

    return StatefulBuilder(builder: (ctx, setLocal) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16, left: 12, right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF8D6E63).withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 標題 ──
            Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: selectedColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.palette, color: selectedColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(isLight ? '🌸 淺色系 色盤' : '🌲 深色系 色盤',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF4E342E))),
            ]),
            const SizedBox(height: 14),
            // ── 精選色磚 ──
            const Text('精選配色',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: presets
                  .map((c) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: GestureDetector(
                            onTap: () => setLocal(() {
                              selectedColor = c;
                              isCustom = false;
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              height: 36,
                              decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(10),
                                border: (selectedColor == c && !isCustom)
                                    ? Border.all(
                                        color: const Color(0xFF4E342E),
                                        width: 2.5)
                                    : Border.all(color: Colors.transparent),
                                boxShadow: (selectedColor == c && !isCustom)
                                    ? [
                                        BoxShadow(
                                            color: c.withValues(alpha: 0.5),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3))
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            // ── 自訂滑桿分隔 ──
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('自訂顏色',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600)),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 12),
            // ── 彩虹色相滑桿 ──
            LayoutBuilder(builder: (ctx2, constraints) {
              final sliderWidth = constraints.maxWidth;
              final thumbLeft = ((selectedHue / 360.0) * sliderWidth - 13)
                  .clamp(0.0, sliderWidth - 26);
              return GestureDetector(
                onHorizontalDragUpdate: (d) {
                  final hue = ((d.localPosition.dx / sliderWidth) * 360)
                      .clamp(0.0, 360.0);
                  setLocal(() {
                    selectedHue = hue;
                    selectedColor = hslToColor(hue);
                    isCustom = true;
                  });
                },
                onTapDown: (d) {
                  final hue = ((d.localPosition.dx / sliderWidth) * 360)
                      .clamp(0.0, 360.0);
                  setLocal(() {
                    selectedHue = hue;
                    selectedColor = hslToColor(hue);
                    isCustom = true;
                  });
                },
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      gradient: const LinearGradient(colors: [
                        Color(0xFFFF0000),
                        Color(0xFFFFFF00),
                        Color(0xFF00FF00),
                        Color(0xFF00FFFF),
                        Color(0xFF0000FF),
                        Color(0xFFFF00FF),
                        Color(0xFFFF0000),
                      ]),
                    ),
                  ),
                  Positioned(
                    left: thumbLeft,
                    top: -4,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: selectedColor, width: 4),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4)
                        ],
                      ),
                    ),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 20),
            // ── 預覽 + 確認 ──
            Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selectedColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: selectedColor.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                      '#${selectedColor.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0').substring(2)}',
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4E342E)),
                    ),
                    Text(isCustom ? '自訂顏色' : '精選配色',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ])),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('確認'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedColor,
                  foregroundColor:
                      isLight ? const Color(0xFF4E342E) : Colors.white,
                  elevation: 3,
                  shadowColor: selectedColor.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: () => _handleAISubmit(
                    '${selectedColor.toARGB32()}', ctrl, setModalState),
              ),
            ]),
          ],
        ),
      );
    });
  }

  Widget _buildAiLoading(Map<String, dynamic> msg) {
    return const _NoteSummaryLoadingBubble();
  }

  Widget _buildConfirmationCard(
      Map<String, dynamic> data, StateSetter setModalState) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF8D6E63), width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.report_problem_outlined, color: Colors.amber),
            SizedBox(width: 8),
            Text('User 確認操作', style: TextStyle(fontWeight: FontWeight.bold))
          ]),
          const SizedBox(height: 12),
          Text('📌 項目：${data['title']}', style: const TextStyle(fontSize: 15)),
          Text('⏰ 時間：${data['time']}', style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                  onPressed: () => setModalState(() => chatLogs
                      .add({'isAI': true, 'text': '好的，已取消。', 'isCard': false})),
                  child: const Text('取消',
                      style: TextStyle(color: Colors.redAccent))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8D6E63),
                      foregroundColor: Colors.white),
                  onPressed: () {
                    _addSchedule(data['time'], data['title'], data['color']);
                    setModalState(() => chatLogs.add(
                        {'isAI': true, 'text': '✅ 已加入行程！', 'isCard': false}));
                  },
                  child: const Text('確認加入'))
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAIChatBar() => GestureDetector(
      onTap: _openChatModal,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2))
          ]),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(30)),
              child: const Row(children: [
                Icon(Icons.chat_bubble_outline,
                    color: Color(0xFF8D6E63), size: 18),
                SizedBox(width: 10),
                Text('去社群 / 加行程...',
                    style: TextStyle(color: Colors.grey, fontSize: 14))
              ]))));

  // --- 1. 日曆行程 (含待辦) ---
  Widget _buildCalendarTab() => Column(children: [
        SizedBox(
            height: _calendarViewMode == 'bar' ? 380 : 330,
            child: PageView.builder(
                controller: _calendarPageController,
                // page 12 固定 = 2026年3月（全域基準），initialPage 動態偏移以跳到今月
                onPageChanged: (i) => setState(
                    () => _calendarMonth = DateTime(2026, 3 + (i - 12), 1)),
                itemBuilder: (ctx, i) =>
                    _buildMonthGrid(DateTime(2026, 3 + (i - 12), 1)))),
        Padding(
            padding: const EdgeInsets.fromLTRB(25, 0, 15, 0),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${_selectedDate.month}/${_selectedDate.day} 行程",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8D6E63))),
                  IconButton(
                      icon: const Icon(Icons.add_circle,
                          color: Color(0xFFD7CCC8), size: 30),
                      onPressed: _showManualAddDialog)
                ])),
        Expanded(
            child: PageView.builder(
                controller: _timelinePageController,
                onPageChanged: (i) {
                  DateTime newDate =
                      _simulatedToday.add(Duration(days: i - 1000));
                  // 用完整日期（年月日）比較，避免跨月時月份顯示錯誤
                  if (newDate.year != _selectedDate.year ||
                      newDate.month != _selectedDate.month ||
                      newDate.day != _selectedDate.day) {
                    _syncDate(newDate);
                  }
                },
                itemBuilder: (ctx, i) => _buildUnifiedDayEvents(
                    _simulatedToday.add(Duration(days: i - 1000))))),
      ]);

  Widget _buildMonthGrid(DateTime date) {
    int empty = DateTime(date.year, date.month, 1).weekday - 1;
    int days = DateTime(date.year, date.month + 1, 0).day;
    int rows = ((empty + days) / 7).ceil();

    return LayoutBuilder(builder: (context, constraints) {
      double itemWidth = (constraints.maxWidth - 40 - 48) / 7;

      // 動態計算需要的高度比例，避免跨越 6 列的月份溢出 (例如 2026年3月)
      double headerHeight = 36.0; // 星期列約略佔用高度
      double mainAxisSpacing = 8.0;
      double availableHeight = constraints.maxHeight > 0
          ? constraints.maxHeight -
              headerHeight -
              ((rows - 1) * mainAxisSpacing)
          : rows * 50.0;

      double itemHeight = availableHeight / rows;
      if (itemHeight < 38.0) itemHeight = 38.0; // 保護機制，確保內容塞得下

      double childAspectRatio = itemWidth / itemHeight;

      if (_calendarViewMode == 'bar') {
        // Build the weeks list of dates
        List<List<DateTime>> weeks = [];
        for (int w = 0; w < rows; w++) {
          List<DateTime> week = [];
          for (int col = 0; col < 7; col++) {
            int i = w * 7 + col;
            week.add(DateTime(date.year, date.month, i - empty + 1));
          }
          weeks.add(week);
        }

        return Column(children: [
          // 星期標題行
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                  children: ['一', '二', '三', '四', '五', '六', '日']
                      .map((d) => Expanded(
                          child: Center(
                              child: Text(d,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold)))))
                      .toList())),

          // 週行渲染
          ...weeks.asMap().entries.map((entry) {
            int idx = entry.key;
            List<DateTime> week = entry.value;
            bool isLast = (idx == weeks.length - 1);
            // Find all unique events that overlap with this week
            List<Map<String, dynamic>> weekEvents = [];
            Set<int> seenEventIds = {};
            for (var day in week) {
              String key =
                  "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
              List<Map<String, dynamic>> dayEvs = allSchedules[key] ?? [];
              for (var ev in dayEvs) {
                if (ev['id'] != null && !seenEventIds.contains(ev['id'])) {
                  seenEventIds.add(ev['id']);
                  weekEvents.add(ev);
                }
              }
            }

            // Sort events by start date and span length
            weekEvents.sort((a, b) {
              String startA = a['start_date'] ?? a['date'] ?? '';
              String startB = b['start_date'] ?? b['date'] ?? '';
              int comp = startA.compareTo(startB);
              if (comp != 0) return comp;
              return b['title']
                  .toString()
                  .length
                  .compareTo(a['title'].toString().length);
            });

            // Greedy interval scheduling for vertical levels (lanes)
            List<List<bool>> lanes = [
              List.filled(7, false), // Lane 0
              List.filled(7, false), // Lane 1
            ];
            Map<int, int> eventLanes = {};

            // Reserve Lane 1 for "+N" badge if the day has > 2 events
            for (int col = 0; col < 7; col++) {
              DateTime cellDate = week[col];
              String key =
                  "${cellDate.year}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.day.toString().padLeft(2, '0')}";
              int dayEvCount = allSchedules[key]?.length ?? 0;
              if (dayEvCount > 2) {
                lanes[1][col] = true;
              }
            }

            for (var ev in weekEvents) {
              String startStr = ev['start_date'] ?? ev['date'] ?? '';
              String endStr = ev['end_date'] ?? ev['date'] ?? '';
              DateTime evStart = DateTime.tryParse(startStr) ?? week.first;
              DateTime evEnd = DateTime.tryParse(endStr) ?? week.last;

              int startCol = 0;
              if (evStart.isAfter(week.first)) {
                startCol = week.indexWhere((d) =>
                    d.year == evStart.year &&
                    d.month == evStart.month &&
                    d.day == evStart.day);
                if (startCol == -1) startCol = 0;
              }

              int endCol = 6;
              if (evEnd.isBefore(week.last)) {
                endCol = week.indexWhere((d) =>
                    d.year == evEnd.year &&
                    d.month == evEnd.month &&
                    d.day == evEnd.day);
                if (endCol == -1) endCol = 6;
              }

              int assignedLane = -1;
              for (int l = 0; l < lanes.length; l++) {
                bool isFree = true;
                for (int c = startCol; c <= endCol; c++) {
                  if (lanes[l][c]) {
                    isFree = false;
                    break;
                  }
                }
                if (isFree) {
                  assignedLane = l;
                  break;
                }
              }

              if (assignedLane == -1) {
                lanes.add(List.filled(7, false));
                assignedLane = lanes.length - 1;
              }

              for (int c = startCol; c <= endCol; c++) {
                lanes[assignedLane][c] = true;
              }
              eventLanes[ev['id']] = assignedLane;
            }

            // Draw stack of backgrounds and positioned bars
            return Container(
              height: itemHeight,
              margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
              child: Stack(
                children: [
                  // 1. Background layer: Day grid numbers
                  Row(
                    children: week.map((cellDate) {
                      bool isCurrentMonth = cellDate.month == date.month;
                      if (!isCurrentMonth) {
                        return const Expanded(child: SizedBox());
                      }

                      int d = cellDate.day;
                      bool isSel = _selectedDate.day == d &&
                          _selectedDate.month == cellDate.month &&
                          _selectedDate.year == cellDate.year;
                      bool isToday = _simulatedToday.day == d &&
                          _simulatedToday.month == cellDate.month &&
                          _simulatedToday.year == cellDate.year;

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _syncDate(cellDate, fromCalendar: true),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              margin: const EdgeInsets.only(
                                  top: 2), // Small offset from top
                              width: 20, // Reduced from 24
                              height: 20, // Reduced from 24
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSel
                                    ? const Color(0xFF8D6E63)
                                    : (isToday
                                        ? (Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.redAccent
                                                .withValues(alpha: 0.15)
                                            : const Color(0xFFF5E6E6))
                                        : Colors.transparent),
                                border: Border.all(
                                  color: isSel
                                      ? const Color(0xFF8D6E63)
                                      : (isToday
                                          ? Colors.redAccent
                                              .withValues(alpha: 0.5)
                                          : Colors.transparent),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$d',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSel || isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSel
                                        ? Colors.white
                                        : (isToday
                                            ? Colors.redAccent
                                            : (Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white70
                                                : Colors.black87)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // 2. Foreground layer: Positioned event bars
                  ...weekEvents.map((ev) {
                    String startStr = ev['start_date'] ?? ev['date'] ?? '';
                    String endStr = ev['end_date'] ?? ev['date'] ?? '';
                    DateTime evStart =
                        DateTime.tryParse(startStr) ?? week.first;
                    DateTime evEnd = DateTime.tryParse(endStr) ?? week.last;

                    int startCol = 0;
                    bool isStartOfWeek = true;
                    if (evStart.isAfter(week.first)) {
                      startCol = week.indexWhere((d) =>
                          d.year == evStart.year &&
                          d.month == evStart.month &&
                          d.day == evStart.day);
                      if (startCol == -1) startCol = 0;
                    } else {
                      isStartOfWeek = false; // Event started in previous week
                    }

                    int endCol = 6;
                    bool isEndOfWeek = true;
                    if (evEnd.isBefore(week.last)) {
                      endCol = week.indexWhere((d) =>
                          d.year == evEnd.year &&
                          d.month == evEnd.month &&
                          d.day == evEnd.day);
                      if (endCol == -1) endCol = 6;
                    } else {
                      isEndOfWeek = false; // Event ends in subsequent week
                    }

                    int lane = eventLanes[ev['id']] ?? 0;

                    // We only render up to 2 lanes to prevent vertical overflow of the row height
                    if (lane >= 2) return const SizedBox();

                    // Increased top offset to avoid being too close to dates
                    double topOffset = 30.0 + lane * 13.0;

                    // Prevent rendering if the bar overflows the height of the row
                    if (topOffset + 10.0 > itemHeight) return const SizedBox();

                    bool isSingleDay = startCol == endCol &&
                        isStartOfWeek &&
                        isEndOfWeek &&
                        (evStart.year == evEnd.year &&
                            evStart.month == evEnd.month &&
                            evStart.day == evEnd.day);

                    // Calculate positioning using parent constraints
                    double availableWidth = constraints.maxWidth - 40;
                    double colWidth = (availableWidth - (6 * 8)) / 7;
                    double left = 20 + startCol * (colWidth + 8);
                    double width = (endCol - startCol + 1) * colWidth +
                        (endCol - startCol) * 8;

                    if (isSingleDay) {
                      left += 3;
                      width -= 6;
                    }

                    return Positioned(
                      left: left,
                      width: width,
                      top: topOffset,
                      height:
                          14, // Adjusted height to fit text without clipping
                      child: GestureDetector(
                        onTap: () => _showEditScheduleDialog(ev),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(ev['color']),
                            borderRadius: BorderRadius.only(
                              topLeft: isStartOfWeek || isSingleDay
                                  ? const Radius.circular(4)
                                  : Radius.zero,
                              bottomLeft: isStartOfWeek || isSingleDay
                                  ? const Radius.circular(4)
                                  : Radius.zero,
                              topRight: isEndOfWeek || isSingleDay
                                  ? const Radius.circular(4)
                                  : Radius.zero,
                              bottomRight: isEndOfWeek || isSingleDay
                                  ? const Radius.circular(4)
                                  : Radius.zero,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              )
                            ],
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            ev['title'],
                            style: const TextStyle(
                              fontSize: 8.5, // Slightly larger font size
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height:
                                  1.1, // Adjust line height to prevent clipping
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    );
                  }),

                  // 3. Foreground layer: Positioned "+N" badges
                  ...List.generate(7, (col) {
                    DateTime cellDate = week[col];
                    bool isCurrentMonth = cellDate.month == date.month;
                    if (!isCurrentMonth) return const SizedBox();

                    String key =
                        "${cellDate.year}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.day.toString().padLeft(2, '0')}";
                    int dayEvCount = allSchedules[key]?.length ?? 0;
                    if (dayEvCount > 2) {
                      double availableWidth = constraints.maxWidth - 40;
                      double colWidth = (availableWidth - (6 * 8)) / 7;
                      double left = 20 + col * (colWidth + 8);

                      return Positioned(
                        left: left,
                        width: colWidth,
                        top:
                            55.0, // Placed below the second lane (30 + 13 + 8 + small gap)
                        height: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? Colors.white12
                                : const Color(0xFF8D6E63)
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+${dayEvCount - 1}',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              color: _isDarkMode
                                  ? Colors.white70
                                  : const Color(0xFF8D6E63),
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  }),
                ],
              ),
            );
          }),
        ]);
      }

      // Default classic dot mode (the original implementation)
      return Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
                children: ['一', '二', '三', '四', '五', '六', '日']
                    .map((d) => Expanded(
                        child: Center(
                            child: Text(d,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold)))))
                    .toList())),
        GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: childAspectRatio),
            itemCount: empty + days,
            itemBuilder: (ctx, i) {
              if (i < empty) return const SizedBox();
              int d = i - empty + 1;
              DateTime cellDate = DateTime(date.year, date.month, d);
              String key = cellDate.toString().split(' ')[0];
              bool isSel = _selectedDate.day == d &&
                  _selectedDate.month == date.month &&
                  _selectedDate.year == date.year;
              bool isToday = _simulatedToday.day == d &&
                  _simulatedToday.month == date.month &&
                  _simulatedToday.year == date.year;

              // 檢查該日期是否有行程
              List<Map<String, dynamic>> dayEvents = allSchedules[key] ?? [];

              return GestureDetector(
                  onTap: () => _syncDate(cellDate, fromCalendar: true),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSel
                                  ? const Color(0xFF8D6E63)
                                  : (isToday
                                      ? (Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.redAccent
                                              .withValues(alpha: 0.15)
                                          : const Color(0xFFF5E6E6))
                                      : Colors.transparent),
                              border: Border.all(
                                  color: isSel
                                      ? const Color(0xFF8D6E63)
                                      : (isToday
                                          ? Colors.redAccent
                                              .withValues(alpha: 0.5)
                                          : Colors
                                              .transparent))), // 去除無行程非今日日期的白色圓邊框，美化日曆
                          child: Center(
                              child: Text('$d',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSel || isToday
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSel
                                          ? Colors.white
                                          : (isToday
                                              ? Colors.redAccent
                                              : (Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? Colors.white70
                                                  : Colors.black87)))))),
                      // u{884c}u{7a0b}u{6a19}u{8a18}u{ff1a}u{6539}u{7528}u{81a0}u{56ca}u{578b}u{8272}u{689d} (Pills)u{ff0c}u{5916}u{89c0}u{66f4}u{73fe}u{4ee3}u{4e14}u{8272}u{5f69}u{9bae}u{660e}
                      if (dayEvents.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 2, left: 4, right: 4),
                          child: Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            alignment: WrapAlignment.center,
                            children: [
                              ...dayEvents.take(2).map((e) => Container(
                                    width: 12, // Increased width
                                    height: 4, // Increased height
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: Color(
                                          e['color'] as int? ?? 0xFF8D6E63),
                                    ),
                                  )),
                              if (dayEvents.length > 2)
                                Text('+${dayEvents.length - 2}',
                                    style: const TextStyle(
                                        fontSize: 7,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey))
                            ],
                          ),
                        )
                      else
                        const SizedBox(height: 5), // 減少預留高度，避免溢出
                    ],
                  ));
            })
      ]);
    });
  }

  Widget _buildUnifiedDayEvents(DateTime targetDate) {
    String dateKey = targetDate.toString().split(' ')[0];
    bool isPast = targetDate.isBefore(_simulatedToday);

    // Itinerary Logic: Sort by time
    List<Map<String, dynamic>> schedules =
        List.from(allSchedules[dateKey] ?? []);
    schedules.sort((a, b) => (a['time'] as String).compareTo(b['time']));

    // Todo Logic: Separation and Restoration
    // Show uncompleted todos if today or future, and completed todos if they were done on this date
    List<Map<String, dynamic>> uncompletedTodos = allTodos.where((todo) {
      return !todo['isDone'] && !isPast;
    }).toList();

    List<Map<String, dynamic>> completedTodos = allTodos.where((todo) {
      return todo['isDone'] && todo['doneDate'] == dateKey;
    }).toList();

    if (schedules.isEmpty &&
        uncompletedTodos.isEmpty &&
        completedTodos.isEmpty) {
      return const Padding(
          padding: EdgeInsets.only(top: 20),
          child: Center(
              child: Text('本日尚無行程與待辦', style: TextStyle(color: Colors.grey))));
    }

    int delay = 0;
    Widget staggered(Widget child) {
      delay += 50;
      return FadeInUp(
        delay: Duration(milliseconds: delay),
        duration: const Duration(milliseconds: 500),
        child: child,
      );
    }

    return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        children: [
          // --- Itinerary Section ---
          if (schedules.isNotEmpty) ...[
            staggered(Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                const Icon(Icons.event_note,
                    size: 20, color: Color(0xFF8D6E63)),
                const SizedBox(width: 8),
                const Text('今日行程',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8D6E63),
                        letterSpacing: 1,
                        fontSize: 16)),
              ]),
            )),
            ...schedules.map((event) => staggered(_buildScheduleItem(event))),
            const SizedBox(height: 10),
          ],

          // --- Todo Section ---
          if (uncompletedTodos.isNotEmpty || completedTodos.isNotEmpty) ...[
            staggered(Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                const Icon(Icons.check_box_outlined,
                    size: 20, color: Color(0xFF8D6E63)),
                const SizedBox(width: 8),
                const Text('待辦事項',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8D6E63),
                        letterSpacing: 1,
                        fontSize: 16)),
              ]),
            )),
            ...uncompletedTodos
                .map((item) => staggered(_buildTodoItem(item, isPast))),
            if (completedTodos.isNotEmpty) ...[
              staggered(const Padding(
                padding: EdgeInsets.only(top: 15, bottom: 8),
                child: Text('已完成',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
              )),
              ...completedTodos
                  .map((item) => staggered(_buildTodoItem(item, isPast))),
            ],
          ],
          const SizedBox(height: 100), // bottom padding for floating nav bar
        ]);
  }

  Widget _buildScheduleItem(Map<String, dynamic> event) {
    return GestureDetector(
        onTap: () => _showEditScheduleDialog(event),
        onLongPress: () {
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                      title: const Text('刪除行程'),
                      content: Text('確定要刪除「${event['title']}」嗎？'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('取消')),
                        ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _deleteSchedule(event['id']);
                            },
                            child: const Text('確定刪除'))
                      ]));
        },
        child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
                color: Color(event['color']).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Color(event['color']).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6))
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                )),
            child: Row(children: [
              SizedBox(
                  width: 95,
                  child: Text(event['time'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87))),
              Expanded(
                  child: Text(event['title'],
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.black87))),
              const Icon(Icons.edit_rounded, size: 18, color: Colors.black38)
            ])));
  }

  Widget _buildTodoItem(Map<String, dynamic> item, bool isPast) {
    bool done = item['isDone'];
    return GestureDetector(
        onTap: () async {
          try {
            // If it's done, we can always un-done (undo).
            // If it's not done and it's past, we lock it.
            if (isPast && !done) return;

            final db = await DatabaseHelper.instance.database;
            bool newDone = !done;
            // Use current time for done_at to ensure it matches current date key
            String? doneAt = newDone ? DateTime.now().toIso8601String() : null;

            int count = await db.update(
                'todos', {'done': newDone ? 1 : 0, 'done_at': doneAt},
                where: 'id = ?', whereArgs: [int.parse(item['id'])]);

            debugPrint(
                'Todo Toggle: ID ${item['id']}, New Status: $newDone, Updated: $count');
            await _loadData();
          } catch (e) {
            debugPrint('勾選待辦時出錯: $e');
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('操作失敗: $e')));
            }
          }
        },
        child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
                color: done
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: done ? Colors.transparent : Colors.white,
                    width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: done ? 0.02 : 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? const Color(0xFF8D6E63) : Colors.transparent,
                  border: Border.all(
                    color: done ? const Color(0xFF8D6E63) : Colors.grey,
                    width: 1.5,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 15),
              Expanded(
                  child: Text(item['title'],
                      style: TextStyle(
                          fontSize: 14,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done ? Colors.grey.shade500 : Colors.black87,
                          fontWeight:
                              done ? FontWeight.normal : FontWeight.w500))),
              if (isPast && !done)
                const Icon(Icons.lock, size: 14, color: Colors.grey)
            ])));
  }

  // 新增：編輯行程對話框 (修改自 _showManualAddDialog)
  void _showEditScheduleDialog(Map<String, dynamic> event) {
    TextEditingController titleController =
        TextEditingController(text: event['title']);
    // 解析原本的時間
    String timeRange = event['time'];
    String startPart = timeRange.split('~')[0];
    String endPart = timeRange.split('~')[1];
    TimeOfDay pickedStartTime = TimeOfDay(
        hour: int.parse(startPart.split(':')[0]),
        minute: int.parse(startPart.split(':')[1]));
    TimeOfDay pickedEndTime = TimeOfDay(
        hour: int.parse(endPart.split(':')[0]),
        minute: int.parse(endPart.split(':')[1]));

    final List<int> vibrantColors = [
      0xFFFFCC80,
      0xFF90CAF9,
      0xFFA5D6A7,
      0xFFF48FB1,
      0xFFCE93D8,
      0xFF80CBC4,
    ];
    int selectedColor = event['color'];
    // 確保選中的顏色在清單中，若不在（如初始資料）則預設第一個
    if (!vibrantColors.contains(selectedColor)) {
      selectedColor = vibrantColors[0];
    }

    // 解析行程原本的日期區間（格式 YYYY-MM-DD）
    DateTime pickedStartDate =
        DateTime.tryParse(event['start_date'] as String? ?? '') ??
            DateTime.tryParse(event['date'] as String? ?? '') ??
            _selectedDate;
    DateTime pickedEndDate =
        DateTime.tryParse(event['end_date'] as String? ?? '') ??
            DateTime.tryParse(event['date'] as String? ?? '') ??
            _selectedDate;

    bool isMultiDay = (pickedStartDate.year != pickedEndDate.year ||
        pickedStartDate.month != pickedEndDate.month ||
        pickedStartDate.day != pickedEndDate.day);

    StateSetter? dialogSetState;
    Future<void> selectTime(bool isStart) async {
      final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: isStart ? pickedStartTime : pickedEndTime);
      if (picked != null) {
        dialogSetState!(() {
          if (isStart) {
            pickedStartTime = picked;
          } else {
            pickedEndTime = picked;
          }
        });
      }
    }

    String formatTime(TimeOfDay time) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('編輯行程'),
                content: StatefulBuilder(builder: (context, setDialogState) {
                  dialogSetState = setDialogState;
                  return SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: titleController,
                          decoration: const InputDecoration(labelText: '行程名稱')),
                      const SizedBox(height: 16),
                      // ── 跨日行程切換 ──
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('跨日行程',
                            style:
                                TextStyle(fontSize: 13, color: Colors.black87)),
                        value: isMultiDay,
                        activeThumbColor: const Color(0xFF8D6E63),
                        onChanged: (val) {
                          setDialogState(() {
                            isMultiDay = val;
                            if (!isMultiDay) {
                              pickedEndDate = pickedStartDate;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      if (!isMultiDay) ...[
                        const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('行程日期',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey))),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: pickedStartDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              locale: const Locale('zh', 'TW'),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                pickedStartDate = picked;
                                pickedEndDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              const Icon(Icons.calendar_today,
                                  size: 16, color: Color(0xFF8D6E63)),
                              const SizedBox(width: 8),
                              Text(
                                '${pickedStartDate.year}/${pickedStartDate.month.toString().padLeft(2, '0')}/${pickedStartDate.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ]),
                          ),
                        ),
                      ] else ...[
                        // ── 日期區間選擇 ──
                        const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('行程日期區間',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey))),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: pickedStartDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                    locale: const Locale('zh', 'TW'),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      pickedStartDate = picked;
                                      if (pickedEndDate
                                          .isBefore(pickedStartDate)) {
                                        pickedEndDate = pickedStartDate;
                                      }
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.calendar_today,
                                        size: 16, color: Color(0xFF8D6E63)),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${pickedStartDate.year}/${pickedStartDate.month.toString().padLeft(2, '0')}/${pickedStartDate.day.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ]),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('至'),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: pickedEndDate,
                                    firstDate: pickedStartDate,
                                    lastDate: DateTime(2030),
                                    locale: const Locale('zh', 'TW'),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      pickedEndDate = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.calendar_today,
                                        size: 16, color: Color(0xFF8D6E63)),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${pickedEndDate.year}/${pickedEndDate.month.toString().padLeft(2, '0')}/${pickedEndDate.day.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('選擇顏色標籤',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey))),
                      const SizedBox(height: 8),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: vibrantColors
                              .map((c) => GestureDetector(
                                  onTap: () =>
                                      setDialogState(() => selectedColor = c),
                                  child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                          color: Color(c),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: selectedColor == c
                                                  ? Colors.black87
                                                  : Colors.transparent,
                                              width: 2)))))
                              .toList()),
                      const SizedBox(height: 20),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                                icon: const Icon(Icons.access_time, size: 16),
                                label: Text(formatTime(pickedStartTime)),
                                onPressed: () => selectTime(true)),
                            const Text('~'),
                            TextButton.icon(
                                icon: const Icon(Icons.access_time, size: 16),
                                label: Text(formatTime(pickedEndTime)),
                                onPressed: () => selectTime(false))
                          ])
                    ]),
                  );
                }),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8D6E63),
                          foregroundColor: Colors.white),
                      onPressed: () {
                        if (titleController.text.isEmpty) return;
                        String range =
                            "${formatTime(pickedStartTime)}~${formatTime(pickedEndTime)}";
                        _editSchedule(
                          event['id'],
                          range,
                          titleController.text,
                          selectedColor,
                          startDate: pickedStartDate,
                          endDate: pickedEndDate,
                        );
                        Navigator.pop(ctx);
                      },
                      child: const Text('儲存修改'))
                ]));
  }

  // --- 2. 題庫系統 (測驗/題庫/個人) ---
  Widget _buildQuestionBankTab() {
    return QuestionListPage(
      currentUser: widget.currentUser,
      allSubjects: allSubjects,
      subjectChapters: subjectChapters,
    );
  }

  // --- 手動新增行程 (含 Padding 修正) ---
  void _showManualAddDialog() {
    TextEditingController titleController = TextEditingController();
    int selectedType = 0;
    TimeOfDay pickedStartTime = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay pickedEndTime = const TimeOfDay(hour: 11, minute: 0);
    DateTime pickedStartDate = _selectedDate;
    DateTime pickedEndDate = _selectedDate;
    bool isMultiDay = false;
    StateSetter? dialogSetState;
    Future<void> selectTime(bool isStart) async {
      final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: isStart ? pickedStartTime : pickedEndTime);
      if (picked != null) {
        dialogSetState!(() {
          if (isStart) {
            pickedStartTime = picked;
          } else {
            pickedEndTime = picked;
          }
        });
      }
    }

    String formatTime(TimeOfDay time) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    final List<int> vibrantColors = [
      0xFFFFCC80, // 亮橙
      0xFF90CAF9, // 亮藍
      0xFFA5D6A7, // 嫩綠
      0xFFF48FB1, // 嫩粉
      0xFFCE93D8, // 柔紫
      0xFF80CBC4, // 青蔥
    ];
    int selectedColor = vibrantColors[0];

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('手動新增項目'),
                content: StatefulBuilder(builder: (context, setDialogState) {
                  dialogSetState = setDialogState;
                  return SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: titleController,
                          decoration: const InputDecoration(labelText: '標題名稱')),
                      const SizedBox(height: 20),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ChoiceChip(
                                label: const Text('時間行程'),
                                selected: selectedType == 0,
                                selectedColor: const Color(0xFFD7CCC8),
                                onSelected: (v) =>
                                    setDialogState(() => selectedType = 0)),
                            const SizedBox(width: 10),
                            ChoiceChip(
                                label: const Text('待辦事項'),
                                selected: selectedType == 1,
                                selectedColor: const Color(0xFFD7CCC8),
                                onSelected: (v) =>
                                    setDialogState(() => selectedType = 1))
                          ]),
                      if (selectedType == 0) ...[
                        const SizedBox(height: 15),
                        const Align(
                            alignment: Alignment.centerLeft,
                            child: Text('選擇顏色標籤',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey))),
                        const SizedBox(height: 8),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: vibrantColors
                                .map((c) => GestureDetector(
                                    onTap: () =>
                                        setDialogState(() => selectedColor = c),
                                    child: Container(
                                        width: 20, // Reduced from 24
                                        height: 20, // Reduced from 24
                                        decoration: BoxDecoration(
                                            color: Color(c),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: selectedColor == c
                                                    ? Colors.black87
                                                    : Colors.transparent,
                                                width: 2)))))
                                .toList()),
                        const SizedBox(height: 15),
                        // ── 跨日行程切換 ──
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('跨日行程',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.black87)),
                          value: isMultiDay,
                          activeThumbColor: const Color(0xFF8D6E63),
                          onChanged: (val) {
                            setDialogState(() {
                              isMultiDay = val;
                              if (!isMultiDay) {
                                pickedEndDate = pickedStartDate;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        if (!isMultiDay) ...[
                          const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('行程日期',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey))),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: pickedStartDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                                locale: const Locale('zh', 'TW'),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  pickedStartDate = picked;
                                  pickedEndDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(children: [
                                const Icon(Icons.calendar_today,
                                    size: 16, color: Color(0xFF8D6E63)),
                                const SizedBox(width: 8),
                                Text(
                                  '${pickedStartDate.year}/${pickedStartDate.month.toString().padLeft(2, '0')}/${pickedStartDate.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ]),
                            ),
                          ),
                        ] else ...[
                          // ── 日期區間選擇 ──
                          const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('行程日期區間',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey))),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: ctx,
                                      initialDate: pickedStartDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                      locale: const Locale('zh', 'TW'),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        pickedStartDate = picked;
                                        if (pickedEndDate
                                            .isBefore(pickedStartDate)) {
                                          pickedEndDate = pickedStartDate;
                                        }
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(children: [
                                      const Icon(Icons.calendar_today,
                                          size: 16, color: Color(0xFF8D6E63)),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${pickedStartDate.year}/${pickedStartDate.month.toString().padLeft(2, '0')}/${pickedStartDate.day.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ]),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('至'),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: ctx,
                                      initialDate: pickedEndDate,
                                      firstDate: pickedStartDate,
                                      lastDate: DateTime(2030),
                                      locale: const Locale('zh', 'TW'),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        pickedEndDate = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(children: [
                                      const Icon(Icons.calendar_today,
                                          size: 16, color: Color(0xFF8D6E63)),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${pickedEndDate.year}/${pickedEndDate.month.toString().padLeft(2, '0')}/${pickedEndDate.day.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 15),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton.icon(
                                  icon: const Icon(Icons.access_time, size: 16),
                                  label: Text(formatTime(pickedStartTime)),
                                  onPressed: () => selectTime(true)),
                              const Text('~'),
                              TextButton.icon(
                                  icon: const Icon(Icons.access_time, size: 16),
                                  label: Text(formatTime(pickedEndTime)),
                                  onPressed: () => selectTime(false))
                            ])
                      ]
                    ]),
                  );
                }),
                actions: [
                  ElevatedButton(
                      onPressed: () {
                        if (titleController.text.isEmpty) return;
                        if (selectedType == 0) {
                          String range =
                              "${formatTime(pickedStartTime)}~${formatTime(pickedEndTime)}";
                          _addSchedule(
                              range, titleController.text, selectedColor,
                              startDate: pickedStartDate,
                              endDate:
                                  isMultiDay ? pickedEndDate : pickedStartDate);
                        } else {
                          _addTodo(titleController.text);
                        }
                        Navigator.pop(ctx);
                      },
                      child: const Text('確認加入'))
                ]));
  }

  // ── 貼文編輯（僅貼文作者可操作）───────────────────────────────
  void _editPost(Map<String, dynamic> p) async {
    final controller = TextEditingController(text: p['content']);
    String selectedType = p['postType'] ?? 'text';
    Uint8List? currentImageBlob = p['media_blob'] as Uint8List?;
    bool imageChanged = false;

    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('編輯貼文', style: TextStyle(fontSize: 16)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('貼文類型',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildEditTypeChip(
                                '📝  學習筆記',
                                'note',
                                selectedType,
                                (val) =>
                                    setDialogState(() => selectedType = val)),
                            const SizedBox(width: 8),
                            _buildEditTypeChip(
                                '💭  心情文章',
                                'mood',
                                selectedType,
                                (val) =>
                                    setDialogState(() => selectedType = val)),
                            const SizedBox(width: 8),
                            _buildEditTypeChip(
                                '📄  分享資料',
                                'doc',
                                selectedType,
                                (val) =>
                                    setDialogState(() => selectedType = val)),
                            const SizedBox(width: 8),
                            _buildEditTypeChip(
                                '💬  一般貼文',
                                'text',
                                selectedType,
                                (val) =>
                                    setDialogState(() => selectedType = val)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text('內容',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      TextField(
                        controller: controller,
                        maxLines: null,
                        decoration:
                            const InputDecoration(hintText: '修改貼文內容...'),
                      ),
                      const SizedBox(height: 15),
                      const Text('圖片',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      if (currentImageBlob != null)
                        Stack(
                          children: [
                            Container(
                              height: 150,
                              width: 150,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: MemoryImage(currentImageBlob!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    currentImageBlob = null;
                                    imageChanged = true;
                                  });
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () async {
                            final ImagePicker picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                              maxWidth: 1024,
                              maxHeight: 1024,
                              imageQuality: 85,
                            );
                            if (image != null) {
                              final bytes = await image.readAsBytes();
                              setDialogState(() {
                                currentImageBlob = bytes;
                                imageChanged = true;
                              });
                            }
                          },
                          icon: const Icon(Icons.add_a_photo, size: 18),
                          label: const Text('新增圖片'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8D6E63),
                            side: const BorderSide(color: Color(0xFF8D6E63)),
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消',
                          style: TextStyle(color: Colors.grey))),
                  TextButton(
                      onPressed: () {
                        if (controller.text.isEmpty &&
                            currentImageBlob == null) {
                          return;
                        }
                        Navigator.pop(ctx, {
                          'content': controller.text,
                          'type': selectedType,
                          'media_blob': currentImageBlob,
                          'imageChanged': imageChanged,
                        });
                      },
                      child: const Text('儲存',
                          style: TextStyle(color: Color(0xFF8D6E63)))),
                ],
              );
            }));

    if (result != null && mounted) {
      try {
        final db = await DatabaseHelper.instance.database;
        final postId = int.tryParse(p['id'].toString()) ?? p['id'];
        Map<String, dynamic> updateData = {
          'content': result['content'],
          'type': result['type'],
          'is_edited': 1,
        };
        if (result['imageChanged']) {
          updateData['media_blob'] = result['media_blob'];
        }
        debugPrint('====== _editPost database update start ======');
        debugPrint(
            'Target post ID: $postId (Original: ${p['id']}, Type: ${postId.runtimeType})');
        debugPrint('Update data: $updateData');

        final rowsAffected = await db
            .update('posts', updateData, where: 'id = ?', whereArgs: [postId]);

        debugPrint('Rows affected: $rowsAffected');
        if (rowsAffected == 0) {
          debugPrint(
              'WARNING: No rows were updated! Checking if post exists in DB...');
          final check =
              await db.query('posts', where: 'id = ?', whereArgs: [postId]);
          debugPrint('Post query check result: $check');
        }

        await _loadData();
        debugPrint(
            '====== _editPost database update end and _loadData() called ======');
      } catch (e, stack) {
        debugPrint('ERROR in _editPost: $e');
        debugPrint(stack.toString());
      }
    }
  }

  Widget _buildEditTypeChip(String label, String type, String selectedType,
      Function(String) onSelected) {
    final isSelected = selectedType == type;
    return GestureDetector(
      onTap: () => onSelected(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF8D6E63) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: isSelected ? const Color(0xFF8D6E63) : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _deletePost(Map<String, dynamic> p) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('刪除貼文', style: TextStyle(fontSize: 16)),
              content: const Text('確定要刪除這篇貼文嗎？刪除後無法復原。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child:
                        const Text('取消', style: TextStyle(color: Colors.grey))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child:
                        const Text('刪除', style: TextStyle(color: Colors.red))),
              ],
            ));
    if (confirm == true && mounted) {
      final db = await DatabaseHelper.instance.database;
      final postId = int.tryParse(p['id'].toString()) ?? p['id'];
      await db.delete('posts', where: 'id = ?', whereArgs: [postId]);
      await _loadData();
    }
  }
  // ───────────────────────────────────────────────────────────────

  // ── 預設插圖選擇器 ─────────────────────────────────────────────────

  Future<void> _pickAvatarFromLocal() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        await _saveAvatar(
            blob: result.files.single.bytes!, colorIdx: _userAvatarColor);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('頭像已更新')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('選取圖片失敗，請再試一次')));
      }
    }
  }

  Future<void> _saveAvatar({required int colorIdx, Uint8List? blob}) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'users',
        {'avatar_color': colorIdx, 'avatar_blob': blob, 'avatar_selected': 1},
        where: 'id = ?',
        whereArgs: [widget.currentUser['id']],
      );
      if (mounted) {
        setState(() {
          _userAvatarColor = colorIdx;
          _userAvatarBlob = blob;
          _userAvatarSelected = true;
        });
        // 重新載入資料，讓社群貼文的頭像也同步更新
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ 頭像已更新！'), duration: Duration(seconds: 2)));
        }
      }
    } catch (e) {
      debugPrint('儲存頭像失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('頭像儲存失敗，請再試一次')));
      }
    }
  }
  // ───────────────────────────────────────────────────────────────

  // --- 社群分頁邏輯已移至 main_screen_social_tab.part.dart ---

  // --- 個人資料頁面 (已移至 main_screen_profile_tab.part.dart) ---

  // --- 功能彈窗 ---
  void _showUnifiedAvatarPicker() {
    bool showPresets = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setSheet) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
                if (!showPresets) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      children: [
                        Text('更新大頭貼',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('選擇你喜歡的方式展現個人風格',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  _buildPickerOption(
                    icon: Icons.photo_library_rounded,
                    label: '從相簿選擇',
                    subtitle: '選取你裝置中的精彩圖片',
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAvatarFromLocal();
                    },
                  ),
                  _buildPickerOption(
                    icon: Icons.camera_alt_rounded,
                    label: '拍照',
                    subtitle: '立即捕捉最真實的瞬間',
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ImagePicker picker = ImagePicker();
                      final XFile? image =
                          await picker.pickImage(source: ImageSource.camera);
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        await _saveAvatar(
                            colorIdx: _userAvatarColor, blob: bytes);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('頭像已更新')));
                        }
                      }
                    },
                  ),
                  _buildPickerOption(
                    icon: Icons.face_rounded,
                    label: '使用內建插圖',
                    subtitle: '選擇可愛的預設角色與表情',
                    onTap: () {
                      setSheet(() => showPresets = true);
                    },
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 20, 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                          onPressed: () => setSheet(() => showPresets = false),
                        ),
                        const Text('選擇內建插圖',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 280,
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: kPresetAvatars.length,
                      itemBuilder: (_, i) {
                        final preset = kPresetAvatars[i];
                        return InkWell(
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _saveAvatar(colorIdx: i, blob: null);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('頭像已更新')));
                            }
                          },
                          child: Column(
                            children: [
                              buildAvatar(
                                usePreset: true,
                                colorIdx: i,
                                radius: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(preset['label'] as String,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF8D6E63).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF8D6E63), size: 24),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
      onTap: onTap,
    );
  }

  void _showEditBioDialog() {
    final controller = TextEditingController(text: _userBio);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('編輯個人簡介'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
              hintText: '介紹一下自己吧...', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8D6E63),
                foregroundColor: Colors.white),
            onPressed: () async {
              final newBio = controller.text.trim();
              Navigator.pop(ctx);
              await _updateBio(newBio);
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateBio(String newBio) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'users',
      {'bio': newBio},
      where: 'id = ?',
      whereArgs: [widget.currentUser['id']],
    );
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('簡介已更新')));
  }

  void _showFontSizeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('選擇字體大小'),
        children: [
          _buildFontSizeOption(ctx, '較小', 0.9),
          _buildFontSizeOption(ctx, '標準', 1.0),
          _buildFontSizeOption(ctx, '較大', 1.1),
        ],
      ),
    );
  }

  Widget _buildFontSizeOption(BuildContext ctx, String label, double factor) {
    return SimpleDialogOption(
      onPressed: () async {
        Navigator.pop(ctx);
        setState(() => _fontSizeFactor = factor);
        await _updatePersonalization();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label,
            style: TextStyle(
                fontWeight: _fontSizeFactor == factor
                    ? FontWeight.bold
                    : FontWeight.normal)),
      ),
    );
  }

  void _showThemeColorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('選擇主題顏色'),
        children: [
          _buildThemeOption(ctx, '經典暖棕 (預設)', 0, const Color(0xFF8D6E63)),
          _buildThemeOption(ctx, '孔雀藍', 1, Colors.blueGrey),
          _buildThemeOption(ctx, '森林綠', 2, Colors.teal),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
      BuildContext ctx, String label, int idx, Color color) {
    return SimpleDialogOption(
      onPressed: () async {
        Navigator.pop(ctx);
        setState(() => _themeColorIdx = idx);
        await _updatePersonalization();
      },
      child: Row(
        children: [
          Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontWeight: _themeColorIdx == idx
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ],
      ),
    );
  }

  Future<void> _updatePersonalization() async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'users',
      {
        'font_size_factor': _fontSizeFactor,
        'theme_color_idx': _themeColorIdx,
        'is_dark_mode': _isDarkMode ? 1 : 0,
        'calendar_view_mode': _calendarViewMode,
      },
      where: 'id = ?',
      whereArgs: [widget.currentUser['id']],
    );
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('偏好設定已儲存')));
    }
  }

  void _showEditNicknameDialog() {
    // 讓使用者隨時可更換暱稱

    final controller = TextEditingController(text: _displayName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('更改暱稱'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '請輸入新的暱稱'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8D6E63),
                foregroundColor: Colors.white),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              Navigator.pop(ctx);
              await _updateNickname(newName);
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateNickname(String newName) async {
    final db = await DatabaseHelper.instance.database;
    final nowStr = DateTime.now().toIso8601String();
    await db.update(
      'users',
      {
        'display_name': newName,
        'username': newName, // 同步更新帳號，確保登入時可用新名稱
        'nickname_updated_at': nowStr
      },
      where: 'id = ?',
      whereArgs: [widget.currentUser['id']],
    );
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('暱稱已更新')));
    }
  }

  void _showEmailVerificationFlow() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email 驗證'),
        content: Text(_isEmailVerified ? '您的 Email 已驗證成功！' : '點擊下方按鈕發送驗證信。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          if (!_isEmailVerified)
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(ctx);
                final db = await DatabaseHelper.instance.database;
                await db.update('users', {'is_email_verified': 1},
                    where: 'id = ?', whereArgs: [widget.currentUser['id']]);
                await _loadData();
                navigator.pop();
                messenger.showSnackBar(const SnackBar(content: Text('驗證成功！')));
              },
              child: const Text('發送驗證信'),
            ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除帳號', style: TextStyle(color: Colors.red)),
        content: const Text(
            '您確定要刪除帳號嗎？\n\n帳號將進入 30 天的緩衝期。在 30 天內重新登入即可取消刪除並復原帳號，超過 30 天則將永久刪除所有資料且無法恢復。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = await DatabaseHelper.instance.database;
              await db.update(
                'users',
                {'deleted_at': DateTime.now().toIso8601String()},
                where: 'id = ?',
                whereArgs: [widget.currentUser['id']],
              );
              if (!mounted) return;
              widget.onLogout();
            },
            child: const Text('確認刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    if (widget.currentUser['is_google'] == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('您已透過 Google 登入，無須修改密碼')),
      );
      return;
    }
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改密碼'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: oldCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '目前的密碼')),
            TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新的密碼')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('密碼已修改')));
            },
            child: const Text('確認修改'),
          ),
        ],
      ),
    );
  }

  // ─── 我的貼文 ────────────────────────────────────────────────
  void _showMyPostsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          appBar: AppBar(
            title: const Text('我的貼文'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0.5,
          ),
          body: _buildMyPostsList(),
        ),
      ),
    );
  }

  Widget _buildMyPostsList() {
    final currentUserId = widget.currentUser['id'];
    final myPosts =
        socialPosts.where((p) => p['userId'] == currentUserId).toList();

    if (myPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('尚未發布任何貼文',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
            const SizedBox(height: 8),
            Text('前往社群分享你的學習心得吧！',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ],
        ),
      );
    }

    final typeIconMap = {
      'note': Icons.sticky_note_2_outlined,
      'mood': Icons.sentiment_satisfied_alt_outlined,
      'share': Icons.share_outlined,
      'text': Icons.chat_bubble_outline,
    };
    final typeNameMap = {
      'note': '筆記',
      'mood': '心情',
      'share': '分享',
      'text': '一般',
    };

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: myPosts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final post = myPosts[i];
        final postType = post['postType'] as String? ?? 'text';
        final icon = typeIconMap[postType] ?? Icons.chat_bubble_outline;
        final typeName = typeNameMap[postType] ?? '一般';
        final primaryColor = Theme.of(context).primaryColor;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 12, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(typeName,
                            style: TextStyle(
                                fontSize: 11,
                                color: primaryColor,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(post['time'] as String? ?? '',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                post['content'] as String? ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.favorite_border,
                      size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('${post['likes'] ?? 0}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(width: 16),
                  Icon(Icons.chat_bubble_outline,
                      size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('${post['replies'] ?? 0}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── 測驗歷史 ────────────────────────────────────────────────
  void _showQuizHistoryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => _QuizHistoryPage(
          currentUserId: widget.currentUser['id'] as String,
          onViewWrongQuestions: _showWrongQuestionsDialog,
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showAiDiagnosisSheet() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          _sheetStateSetter = setSheetState;

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (ctx, sc) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAF8F6), // Warm background
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title Area
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF8D6E63), Color(0xFFD7CCC8)],
                              ).createShader(bounds),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'AI 學習診斷報告',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4E342E),
                              ),
                            ),
                          ],
                        ),
                        if (!_isDiagnosing && _diagnosisResult != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _diagnosisResult!.isAiGenerated
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFEFEBE9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _diagnosisResult!.isAiGenerated
                                    ? const Color(0xFFA5D6A7)
                                    : const Color(0xFFD7CCC8),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _diagnosisResult!.isAiGenerated
                                      ? Icons.bolt
                                      : Icons.settings_applications,
                                  size: 14,
                                  color: _diagnosisResult!.isAiGenerated
                                      ? Colors.green.shade700
                                      : Colors.brown,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _diagnosisResult!.isAiGenerated
                                      ? 'AI 智慧生成'
                                      : '本地規則分析',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _diagnosisResult!.isAiGenerated
                                        ? Colors.green.shade700
                                        : Colors.brown,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),

                  // Body
                  Expanded(
                    child: _isDiagnosing
                        ? (_streamedDiagnosisText.isEmpty
                            ? _buildLoadingState() // 第一個 chunk 還沒來：轉圈
                            : _buildStreamingState()) // 逐字顯示串流文字
                        : (_diagnosisResult == null
                            ? _buildErrorState()
                            : _buildReportContent(sc)),
                  ),

                  // Bottom Actions
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFF8D6E63)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              _sheetStateSetter = null;
                              Navigator.pop(context);
                            },
                            child: const Text('關閉',
                                style: TextStyle(
                                    color: Color(0xFF8D6E63),
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        if (!_isDiagnosing && _lastQuizWrongIds.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: const Color(0xFF8D6E63),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                _sheetStateSetter = null;
                                Navigator.pop(context);
                                _showWrongQuestionsDialog(_lastQuizWrongIds);
                              },
                              child: Text(
                                  '開始複習錯題 (${_lastQuizWrongIds.length})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) {
      _sheetStateSetter = null;
    });
  }

  /// 第一個 chunk 還沒來：顯示具體進度條動畫 (非卡死 95% 版本)
  Widget _buildLoadingState() {
    return const _DiagnosisLoadingProgress();
  }

  /// 串流進行中：逐字顯示已到達的文字（ListView.builder + 打字機效果）
  Widget _buildStreamingState() {
    // 將累積文字依行展開
    final lines = _streamedDiagnosisText.split('\n');
    return Column(
      children: [
        // 頂部轉圈提示列
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFFFFF8F5),
          child: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D6E63)),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'AI 導師正在產出診斷內容...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.brown.shade400,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        // 逐行顯示串流文字
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            itemCount: lines.length,
            itemBuilder: (ctx, i) {
              final line = lines[i];
              final isHeader = line.startsWith('[') && line.endsWith(']');
              final isBullet = line.trimLeft().startsWith('•');
              return Padding(
                padding: EdgeInsets.only(
                  bottom: isHeader ? 4 : 3,
                  top: isHeader && i > 0 ? 12 : 0,
                ),
                child: Text(
                  line,
                  style: TextStyle(
                    fontSize: isHeader ? 13.5 : 13,
                    fontWeight: isHeader ? FontWeight.w700 : FontWeight.normal,
                    color: isHeader
                        ? const Color(0xFF6D4C41)
                        : (isBullet ? Colors.black87 : Colors.grey.shade700),
                    height: 1.55,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            const Text(
              '無法生成診斷報告',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              '可能因為未取得有效的測驗資訊。請嘗試重新測驗。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent(ScrollController sc) {
    final report = _diagnosisResult!;

    return ListView(
      controller: sc,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        if (!report.isAiGenerated)
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: Builder(builder: (context) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.currentUser['id'] == 'u4'
                      ? const Color(0xFFFFF3E0)
                      : const Color(0xFFFFFDE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.currentUser['id'] == 'u4'
                        ? const Color(0xFFFFE0B2)
                        : const Color(0xFFFFF59D),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      widget.currentUser['id'] == 'u4'
                          ? Icons.lock_outline
                          : Icons.info_outline,
                      color: widget.currentUser['id'] == 'u4'
                          ? const Color(0xFFF57C00)
                          : const Color(0xFFFBC02D),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.currentUser['id'] == 'u4'
                                ? '登入解鎖 AI 智慧報告'
                                : '目前內建 AI 額度已達上限',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: widget.currentUser['id'] == 'u4'
                                  ? const Color(0xFFE65100)
                                  : const Color(0xFFF57F17),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.currentUser['id'] == 'u4'
                                ? '訪客帳戶目前不支援 AI 智慧診斷功能。立即註冊或登入正式帳號，即可啟用由 Gemini 生成的客製化學習診斷與複習建議！'
                                : '目前測試金鑰為所有使用者共享，今日免費額度已耗盡。系統已自動切換為「本地規則分析」報告，造成不便敬請見諒！',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF5D4037),
                                height: 1.4),
                          ),
                          if (widget.currentUser['id'] == 'u4') ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _changePage(4, '個人檔案');
                              },
                              child: const Text(
                                '立即去登入/註冊 ➔',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE65100)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),

        // 1. 本次摘要
        FadeInUp(
          duration: const Duration(milliseconds: 500),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8D6E63), Color(0xFF795548)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8D6E63).withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '學習診斷摘要',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  report.summary,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. 待加強單元 (弱項)
        FadeInUp(
          duration: const Duration(milliseconds: 600),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        color: Colors.orange.shade800, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '待加強單元 (弱項)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.orange.shade900),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (report.weaknesses.isEmpty)
                  Text('無特別明顯弱項',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500))
                else
                  ...report.weaknesses.map((weak) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ',
                                style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                weak,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade800,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. AI 學習建議
        FadeInUp(
          duration: const Duration(milliseconds: 700),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb, color: Color(0xFFFBC02D), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'AI 導師複習建議',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF4E342E)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  report.suggestion,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade800, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 4. 溫馨鼓勵
        FadeInUp(
          duration: const Duration(milliseconds: 800),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFEBE9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD7CCC8)),
            ),
            child: Row(
              children: [
                const Text(
                  '💬',
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '"${report.encouragement}"',
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5D4037),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showWrongQuestionsDialog(List<dynamic> wrongIds) async {
    if (wrongIds.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final placeholders = wrongIds.map((_) => '?').join(', ');
    final rows = await db.rawQuery(
      'SELECT * FROM questions WHERE id IN ($placeholders)',
      wrongIds,
    );
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, sc) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  Icon(Icons.error_outline,
                      color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text('錯題複習（${rows.length} 題）',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('找不到對應的題目資料'))
                    : ListView.separated(
                        controller: sc,
                        padding: const EdgeInsets.all(16),
                        separatorBuilder: (_, __) => const Divider(height: 24),
                        itemCount: rows.length,
                        itemBuilder: (ctx, i) {
                          final q = rows[i];
                          final options =
                              jsonDecode(q['options'] as String) as List;
                          final correctIdx = int.parse(q['answer'] as String);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Q${i + 1}．${q['text']}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      height: 1.5)),
                              const SizedBox(height: 8),
                              ...List.generate(options.length, (oi) {
                                final isCorrect = oi == correctIdx;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isCorrect
                                        ? Colors.green.shade50
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isCorrect
                                        ? Border.all(
                                            color: Colors.green.shade300)
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      if (isCorrect)
                                        Icon(Icons.check_circle,
                                            size: 16,
                                            color: Colors.green.shade600),
                                      if (!isCorrect)
                                        Icon(Icons.radio_button_unchecked,
                                            size: 16,
                                            color: Colors.grey.shade400),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(options[oi].toString(),
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: isCorrect
                                                      ? Colors.green.shade700
                                                      : Colors.black87))),
                                    ],
                                  ),
                                );
                              }),
                              if (q['explanation'] != null &&
                                  (q['explanation'] as String).isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.amber.shade200),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.lightbulb_outline,
                                          size: 16,
                                          color: Colors.amber.shade700),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          q['explanation'] as String,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.amber.shade900,
                                              height: 1.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 測驗歷史頁面 ---
class _QuizHistoryPage extends StatefulWidget {
  final String currentUserId;
  final void Function(List<dynamic> wrongIds) onViewWrongQuestions;
  const _QuizHistoryPage(
      {required this.currentUserId, required this.onViewWrongQuestions});
  @override
  State<_QuizHistoryPage> createState() => _QuizHistoryPageState();
}

class _QuizHistoryPageState extends State<_QuizHistoryPage> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT * FROM quiz_results
      WHERE user_id = ?
      ORDER BY timestamp DESC
    ''', [widget.currentUserId]);
    if (mounted) {
      setState(() {
        _records = rows.map((r) => Map<String, dynamic>.from(r)).toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('測驗歷史'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('尚無測驗或學習紀錄',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: _records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final r = _records[i];
                    final int total = (r['total'] as num?)?.toInt() ?? 0;
                    final int correct = (r['correct'] as num?)?.toInt() ?? 0;
                    final int durationSec =
                        (r['duration_seconds'] as num?)?.toInt() ?? 0;
                    final String tsStr = r['timestamp'] as String? ?? '';
                    final DateTime? ts = DateTime.tryParse(tsStr);
                    final String timeLabel = ts != null
                        ? '${ts.year}/${ts.month.toString().padLeft(2, '0')}/${ts.day.toString().padLeft(2, '0')} '
                            '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
                        : tsStr;
                    final int mins = durationSec ~/ 60;
                    final int secs = durationSec % 60;
                    final String durationLabel =
                        mins > 0 ? '$mins 分 $secs 秒' : '$secs 秒';

                    final bool isQuizRecord = total > 0;
                    List<dynamic> wrongIds = [];
                    try {
                      final raw = r['wrong_question_ids'];
                      if (raw != null && (raw as String).isNotEmpty) {
                        wrongIds = jsonDecode(raw);
                      }
                    } catch (_) {}

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isQuizRecord
                                      ? primaryColor.withValues(alpha: 0.1)
                                      : Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isQuizRecord
                                          ? Icons.quiz_outlined
                                          : Icons.menu_book_outlined,
                                      size: 12,
                                      color: isQuizRecord
                                          ? primaryColor
                                          : Colors.teal.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isQuizRecord ? '測驗模式' : '自主學習瀏覽',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isQuizRecord
                                            ? primaryColor
                                            : Colors.teal.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(timeLabel,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (isQuizRecord) ...[
                            Row(
                              children: [
                                _statChip(Icons.check_circle_outline,
                                    '$correct/$total 題', Colors.green.shade600),
                                const SizedBox(width: 12),
                                _statChip(
                                    Icons.star_outline,
                                    '${total > 0 ? ((correct / total) * 100).round() : 0} 分',
                                    primaryColor),
                                const SizedBox(width: 12),
                                _statChip(Icons.timer_outlined, durationLabel,
                                    Colors.orange.shade600),
                              ],
                            ),
                            if (wrongIds.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: () =>
                                    widget.onViewWrongQuestions(wrongIds),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.replay_outlined,
                                          size: 14, color: Colors.red.shade600),
                                      const SizedBox(width: 6),
                                      Text('錯題複習（${wrongIds.length} 題）',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red.shade700,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ] else ...[
                            _statChip(Icons.timer_outlined,
                                '自主瀏覽 $durationLabel', Colors.teal.shade600),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// --- 貼文發佈頁面 ---
class CreatePostPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final VoidCallback onPosted;
  const CreatePostPage(
      {super.key, required this.currentUser, required this.onPosted});
  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _contentController = TextEditingController();
  XFile? _selectedImageX;
  String? _selectedFileName;
  String? _postType;
  bool _isSubmitting = false;
  DateTime? _scheduledAt; // 定時發佈時間

  void _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image != null && mounted) {
      setState(() => _selectedImageX = image);
    }
  }

  void _showFileTypeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text('選擇附件類型',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE8F5E9),
                    child: Icon(Icons.sticky_note_2_outlined,
                        color: Colors.green)),
                title: const Text('學習筆記 (.txt)'),
                subtitle: const Text('上傳純文字筆記'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFileWithType(['txt']);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE3F2FD),
                    child:
                        Icon(Icons.description_outlined, color: Colors.blue)),
                title: const Text('Word 文件 (.doc / .docx)'),
                subtitle: const Text('上傳 Word 格式報告'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFileWithType(['doc', 'docx']);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child:
                        Icon(Icons.picture_as_pdf_outlined, color: Colors.red)),
                title: const Text('PDF 文件 (.pdf)'),
                subtitle: const Text('上傳 PDF 格式檔案'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFileWithType(['pdf']);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _pickFileWithType(List<String> extensions) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
      );
      if (result != null && mounted) {
        setState(() => _selectedFileName = result.files.single.name);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已附加檔案：$_selectedFileName')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('選取檔案失敗，請再試一次')));
      }
    }
  }

  /// 選擇排程時間
  Future<void> _pickScheduleTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(2030),
      locale: const Locale('zh', 'TW'),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!),
    );
    if (time == null || !mounted) return;
    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submitPost() async {
    if (_contentController.text.isEmpty && _selectedImageX == null) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final userId = widget.currentUser['id'];
      Uint8List? blobData;
      if (_selectedImageX != null) {
        blobData = await _selectedImageX!.readAsBytes();
      }

      // 建立 attached_data
      final Map<String, dynamic> attachedMap = {};
      if (_selectedFileName != null) {
        attachedMap['file_name'] = _selectedFileName;
      }
      if (_scheduledAt != null) {
        attachedMap['scheduled_at'] =
            '${_scheduledAt!.year}-${_scheduledAt!.month.toString().padLeft(2, '0')}-${_scheduledAt!.day.toString().padLeft(2, '0')} ${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')}';
      }

      final newId = await db.insert('posts', {
        'user_id': userId,
        'content': _contentController.text,
        'type': _postType ?? (blobData != null ? 'image' : 'text'),
        'media_blob': blobData,
        'attached_data': jsonEncode(attachedMap),
        'created_at': DateTime.now().toIso8601String(),
      });

      if ((widget.currentUser['username'] ?? '') == '訪客') {
        (widget.currentUser['session_post_ids'] as Set<int>?)?.add(newId);
      }

      widget.onPosted();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(_scheduledAt != null ? '⏰ 已設定排程，將於指定時間發佈！' : '🎉 貼文發佈成功！'),
          backgroundColor: const Color(0xFF8D6E63),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      debugPrint("Error submitting post: $e");
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('發佈失敗: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayName = widget.currentUser['display_name'] ??
        widget.currentUser['username'] ??
        '我';
    final String hintText = _postType == 'note'
        ? '寫下你的學習筆記，記錄每一次成長...'
        : _postType == 'mood'
            ? '今天心情怎麼樣呢？說出來和大家分享吧！'
            : '有什麼想和大家說的嗎？';

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消',
              style: TextStyle(color: Colors.grey, fontSize: 15)),
        ),
        leadingWidth: 60,
        title: const Text('發表新貼文',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _contentController.text.isEmpty
                      ? Colors.grey.shade300
                      : const Color(0xFF8D6E63),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_scheduledAt != null ? '排程' : '發佈',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade100, height: 1),
        ),
      ),
      body: Column(
        children: [
          // ── 主要編輯區 ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 用戶資訊列
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      buildAvatar(
                        blob: null,
                        colorIdx: getAvatarColorIdx(displayName),
                        initial: displayName.substring(0, 1),
                        radius: 20,
                        usePreset: false,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87)),
                          // 排程提示
                          if (_scheduledAt != null)
                            Text(
                              '⏰ ${_scheduledAt!.year}-${_scheduledAt!.month.toString().padLeft(2, '0')}-${_scheduledAt!.day.toString().padLeft(2, '0')} ${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')} 發布',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500),
                            )
                          else
                            const Text('公開發布',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 貼文類型標籤
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _buildTypeChip('📝 學習筆記', 'note',
                          selectedColor: const Color(0xFF4CAF50),
                          bgColor: const Color(0xFFE8F5E9)),
                      const SizedBox(width: 8),
                      _buildTypeChip('💭 心情文章', 'mood',
                          selectedColor: const Color(0xFF9C27B0),
                          bgColor: const Color(0xFFF3E5F5)),
                      const SizedBox(width: 8),
                      _buildTypeChip('📄 分享資料', 'doc',
                          selectedColor: const Color(0xFF2196F3),
                          bgColor: const Color(0xFFE3F2FD)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  // 文字輸入區
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    autofocus: true,
                    style: const TextStyle(
                        fontSize: 17, height: 1.55, color: Colors.black87),
                    decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400, fontSize: 17),
                        border: InputBorder.none),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  // 已選圖片預覽
                  if (_selectedImageX != null) ...[
                    Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(_selectedImageX!.path),
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImageX = null),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                  ],
                  // 已選檔案顯示
                  if (_selectedFileName != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade100)),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.description_outlined,
                              size: 16, color: Colors.blue),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(_selectedFileName!,
                                style: const TextStyle(
                                    fontSize: 13, color: Colors.blue))),
                        GestureDetector(
                          onTap: () => setState(() => _selectedFileName = null),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.grey),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // 排程顯示（可點擊清除）
                  if (_scheduledAt != null) ...[
                    GestureDetector(
                      onTap: () => setState(() => _scheduledAt = null),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade200)),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.schedule,
                                size: 16, color: Colors.orange),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('定時發布',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange)),
                                Text(
                                  '${_scheduledAt!.year}-${_scheduledAt!.month.toString().padLeft(2, '0')}-${_scheduledAt!.day.toString().padLeft(2, '0')} ${_scheduledAt!.hour.toString().padLeft(2, '0')}:${_scheduledAt!.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.deepOrange),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.close,
                              size: 16, color: Colors.orange),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),

          // ── 底部工具列 ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                  top: BorderSide(color: Colors.grey.shade100, width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    // 附加圖片
                    _buildToolBtn(
                      icon: Icons.image_outlined,
                      label: '圖片',
                      color: const Color(0xFF8D6E63),
                      onTap: _isSubmitting ? null : _pickImage,
                    ),
                    // 附加文件
                    _buildToolBtn(
                      icon: Icons.attach_file,
                      label: '文件',
                      color: Colors.blue,
                      onTap: _isSubmitting ? null : _showFileTypeSheet,
                    ),
                    // 定時發布
                    _buildToolBtn(
                      icon: Icons.schedule,
                      label: _scheduledAt != null ? '修改時間' : '定時發布',
                      color: Colors.orange,
                      onTap: _isSubmitting ? null : _pickScheduleTime,
                      isActive: _scheduledAt != null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolBtn({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isActive ? color : color.withValues(alpha: 0.7),
                size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: isActive ? color : Colors.grey.shade600,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(
    String label,
    String type, {
    Color selectedColor = const Color(0xFF8D6E63),
    Color bgColor = const Color(0xFFF5F0EE),
  }) {
    final bool isSelected = _postType == type;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      child: GestureDetector(
        onTap: () => setState(() => _postType = isSelected ? null : type),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
              color: isSelected ? selectedColor : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? selectedColor : Colors.grey.shade200,
                width: 1.2,
              )),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }
}

// --- 3. 額外頁面 ---
class PostReplyPage extends StatefulWidget {
  final Map<String, dynamic> originalPost;
  final Map<String, dynamic> currentUser;
  final String? autoTypeMessage;
  final int? targetCommentId;
  final String? targetCommentName;
  final VoidCallback? onAutoTypeDone;

  const PostReplyPage({
    super.key,
    required this.originalPost,
    required this.currentUser,
    this.autoTypeMessage,
    this.targetCommentId,
    this.targetCommentName,
    this.onAutoTypeDone,
  });

  @override
  State<PostReplyPage> createState() => _PostReplyPageState();
}

class _PostReplyPageState extends State<PostReplyPage> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  int? _replyToId;
  String _replyToName = '';
  final Set<int> _expandedCommentIds = {};

  /// 留言排序方式: '所有留言'(ASC)、'由新到舊'(DESC)、'最相關'(依回覆數)
  String _commentSort = '所有留言';

  @override
  void initState() {
    super.initState();
    _loadComments();
    if (widget.targetCommentId != null) {
      _replyToId = widget.targetCommentId;
      _replyToName = widget.targetCommentName ?? '';
    }
    if (widget.autoTypeMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startAutoTyping();
      });
    }
  }

  void _startAutoTyping() async {
    String msg = widget.autoTypeMessage!;
    for (int i = 0; i < msg.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() {
        _commentController.text = msg.substring(0, i + 1);
      });
    }
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    _submitComment();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('代理人已為您自動輸入並送出！')));
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      Navigator.pop(context);
      if (widget.onAutoTypeDone != null) {
        widget.onAutoTypeDone!();
      }
    }
  }

  Future<void> _loadComments() async {
    final db = await DatabaseHelper.instance.database;
    final postId = int.tryParse(widget.originalPost['id'].toString()) ??
        widget.originalPost['id'];
    final data = await db.query('comments',
        where: 'post_id = ?', whereArgs: [postId], orderBy: 'created_at ASC');

    List<Map<String, dynamic>> loaded = [];
    for (var c in data) {
      final user =
          await db.query('users', where: 'id = ?', whereArgs: [c['user_id']]);
      final String name =
          user.isNotEmpty ? user.first['display_name'] as String : '未知用戶';
      // 載入留言者頭像資料
      final int avatarColor =
          user.isNotEmpty ? ((user.first['avatar_color'] as int?) ?? 0) : 0;
      final Uint8List? avatarBlob =
          user.isNotEmpty ? user.first['avatar_blob'] as Uint8List? : null;
      final int avatarSelected =
          user.isNotEmpty ? ((user.first['avatar_selected'] as int?) ?? 0) : 0;

      loaded.add({
        ...c,
        'userId': c['user_id'],
        'author': name,
        'authorAvatarColor': avatarColor,
        'authorAvatarBlob': avatarBlob,
        'authorAvatarSelected': avatarSelected,
        'time': formatRelativeTime(c['created_at'])
      });
    }

    setState(() => _comments = loaded);
  }

  // 重複的 _formatRelativeTime 已移除

  void _submitComment() async {
    if (_commentController.text.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final userId = widget.currentUser['id'];

    final newId = await db.insert('comments', {
      'post_id': widget.originalPost['id'],
      'user_id': userId,
      'text': _commentController.text,
      'parent_id': _replyToId ?? 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    if ((widget.currentUser['username'] ?? '') == '訪客') {
      (widget.currentUser['session_comment_ids'] as Set<int>?)?.add(newId);
    }

    if (_replyToId != null) {
      _expandedCommentIds.add(_replyToId!);
      try {
        final replyToComment = _comments
            .firstWhere((c) => int.tryParse(c['id'].toString()) == _replyToId);
        final pid = int.tryParse(replyToComment['parent_id'].toString()) ?? 0;
        if (pid != 0) {
          _expandedCommentIds.add(pid);
        }
      } catch (_) {}
    }

    _commentController.clear();
    setState(() {
      _replyToId = null;
      _replyToName = '';
    });
    _loadComments();
  }

  void _deleteComment(int commentId) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('刪除留言', style: TextStyle(fontSize: 16)),
              content: const Text('確定要刪除這則留言嗎？'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child:
                        const Text('取消', style: TextStyle(color: Colors.grey))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child:
                        const Text('刪除', style: TextStyle(color: Colors.red))),
              ],
            ));

    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('comments', where: 'id = ?', whereArgs: [commentId]);
      _loadComments();
    }
  }

  void _editComment(int commentId, String currentText) async {
    final editController = TextEditingController(text: currentText);
    final newText = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('編輯留言', style: TextStyle(fontSize: 16)),
              content: TextField(
                controller: editController,
                maxLines: null,
                decoration: const InputDecoration(hintText: '修改您的留言...'),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child:
                        const Text('取消', style: TextStyle(color: Colors.grey))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, editController.text),
                    child: const Text('儲存',
                        style: TextStyle(color: Color(0xFF8D6E63)))),
              ],
            ));

    if (newText != null && newText.isNotEmpty && newText != currentText) {
      final db = await DatabaseHelper.instance.database;
      await db.update('comments', {'text': newText},
          where: 'id = ?', whereArgs: [commentId]);
      _loadComments();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group comments by parent_id
    Map<int, List<Map<String, dynamic>>> rootComments = {};
    for (var c in _comments) {
      int pid = int.tryParse(c['parent_id'].toString()) ?? 0;
      rootComments.putIfAbsent(pid, () => []).add(c);
    }

    // 將根留言依選定的排序方式排序
    List<Map<String, dynamic>> rootList = List.from(rootComments[0] ?? []);
    switch (_commentSort) {
      case '由新到舊':
        rootList.sort((a, b) {
          final ta =
              DateTime.tryParse(a['created_at'].toString()) ?? DateTime(0);
          final tb =
              DateTime.tryParse(b['created_at'].toString()) ?? DateTime(0);
          return tb.compareTo(ta);
        });
        break;
      case '最相關':
        rootList.sort((a, b) {
          final idA = int.tryParse(a['id'].toString()) ?? 0;
          final idB = int.tryParse(b['id'].toString()) ?? 0;
          final ra = rootComments[idA]?.length ?? 0;
          final rb = rootComments[idB]?.length ?? 0;
          return rb.compareTo(ra);
        });
        break;
      default:
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('留言討論',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87)),
            Text('${_comments.length} 則留言',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade100, height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── 留言列表 ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  // 原始貼文 header
                  _buildPostHeader(),
                  // 分隔線與留言計數
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: Colors.grey.shade200, height: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '${_comments.length} 則留言',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                            child: Divider(
                                color: Colors.grey.shade200, height: 1)),
                      ],
                    ),
                  ),
                  // 留言排序選項
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        for (final label in ['所有留言', '由新到舊', '最相關'])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _commentSort = label),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _commentSort == label
                                      ? const Color(0xFF8D6E63)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _commentSort == label
                                        ? const Color(0xFF8D6E63)
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Text(label,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: _commentSort == label
                                            ? Colors.white
                                            : Colors.grey.shade600,
                                        fontWeight: _commentSort == label
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_comments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 40, color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            Text('還沒有人留言，快搶沙發！',
                                style: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ...rootList.map((c) => _buildCommentTree(c, rootComments)),
                ],
              ),
            ),

            // ── 正在回覆提示列 ──
            if (_replyToId != null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F0),
                  border: Border(
                      top: BorderSide(
                          color: Colors.orange.shade200, width: 1.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '正在回覆 $_replyToName',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _replyToId = null;
                        _replyToName = '';
                      }),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),

            // ── 輸入區 ──
            if (widget.currentUser['id'] == 'u4')
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      top: BorderSide(color: Colors.grey.shade100, width: 1)),
                ),
                child:
                    const Text('訪客無法留言喔', style: TextStyle(color: Colors.grey)),
              )
            else
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      top: BorderSide(color: Colors.grey.shade100, width: 1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 120),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _commentController,
                          maxLines: null,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: _replyToId != null
                                ? '回覆 $_replyToName...'
                                : '說說你的想法...',
                            hintStyle: TextStyle(
                                color: Colors.grey.shade400, fontSize: 14),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _submitComment,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF8D6E63),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
    final author = widget.originalPost['author'] ?? '?';
    final postType = widget.originalPost['postType'] as String?;
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            buildAvatar(
                blob: widget.originalPost['authorAvatarBlob'] as Uint8List?,
                colorIdx: (widget.originalPost['authorAvatarColor'] as int?) ??
                    getAvatarColorIdx(author),
                initial: author.substring(0, 1),
                radius: 18,
                usePreset:
                    (widget.originalPost['authorAvatarSelected'] as int? ??
                                0) ==
                            1 &&
                        widget.originalPost['authorAvatarBlob'] == null),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(author,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87)),
                  Row(children: [
                    Text(widget.originalPost['time'],
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 11)),
                    if (postType != null &&
                        kPostTypeLabel.containsKey(postType)) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF5F0EE),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(kPostTypeLabel[postType]!,
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF8D6E63))),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Text(widget.originalPost['content'],
              style: const TextStyle(
                  fontSize: 15, height: 1.5, color: Colors.black87)),
          if (widget.originalPost['media_blob'] != null ||
              (widget.originalPost['media'] != null &&
                  widget.originalPost['media'].toString().isNotEmpty)) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: widget.originalPost['media_blob'] != null
                  ? Image.memory(widget.originalPost['media_blob'] as Uint8List,
                      height: 180, width: double.infinity, fit: BoxFit.cover)
                  : Image.network(widget.originalPost['media'] as String,
                      height: 180, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentTree(
      Map<String, dynamic> comment, Map<int, List<Map<String, dynamic>>> group,
      {int depth = 0}) {
    final int commentId = int.tryParse(comment['id'].toString()) ?? 0;
    List<Map<String, dynamic>> sub = group[commentId] ?? [];

    bool isExpanded =
        (sub.length == 1) || _expandedCommentIds.contains(commentId);
    final double leftPadding = depth < 3 ? 32.0 : 0.0;
    final double lineMargin = depth < 3 ? 14.0 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSingleComment(comment, isSub: depth > 0),
        if (sub.isNotEmpty) ...[
          if (sub.length >= 2 && !isExpanded)
            Padding(
              padding:
                  EdgeInsets.only(left: leftPadding + 8.0, bottom: 8, top: 2),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _expandedCommentIds.add(commentId);
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.subdirectory_arrow_right_rounded,
                          size: 13,
                          color:
                              const Color(0xFF8D6E63).withValues(alpha: 0.8)),
                      const SizedBox(width: 6),
                      Text(
                        '查看 ${sub.length} 則回覆...',
                        style: const TextStyle(
                          color: Color(0xFF8D6E63),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 14, color: Color(0xFF8D6E63)),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: EdgeInsets.only(left: lineMargin),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade200, width: 1.5),
                  ),
                ),
                padding: const EdgeInsets.only(left: 18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...sub.map(
                        (sc) => _buildCommentTree(sc, group, depth: depth + 1)),
                    if (sub.length >= 2) ...[
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _expandedCommentIds.remove(commentId);
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.keyboard_arrow_up_rounded,
                                  size: 14, color: Color(0xFF8D6E63)),
                              SizedBox(width: 4),
                              Text(
                                '收合回覆',
                                style: TextStyle(
                                  color: Color(0xFF8D6E63),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSingleComment(Map<String, dynamic> c, {bool isSub = false}) {
    final author = (c['author'] ?? '?') as String;
    final bool isOwn = c['userId'] == widget.currentUser['id'];
    final bool isGuest = (widget.currentUser['username'] ?? '') == '訪客';
    final bool canEdit = isOwn &&
        (!isGuest ||
            ((widget.currentUser['session_comment_ids'] as Set<int>?)
                    ?.contains(c['id']) ??
                false));

    return Container(
      margin: EdgeInsets.only(bottom: isSub ? 8 : 12, top: isSub ? 2 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildAvatar(
              blob: c['authorAvatarBlob'] as Uint8List?,
              colorIdx:
                  (c['authorAvatarColor'] as int?) ?? getAvatarColorIdx(author),
              initial: author.substring(0, 1),
              radius: isSub ? 11 : 14,
              usePreset: (c['authorAvatarSelected'] as int? ?? 0) == 1 &&
                  c['authorAvatarBlob'] == null),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 名稱 + 時間列
                Row(
                  children: [
                    Flexible(
                      child: Text(author,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSub ? 12 : 13,
                              color: Colors.black87)),
                    ),
                    const SizedBox(width: 6),
                    Text(c['time'],
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                    const Spacer(),
                    // 編輯/刪除（自己的留言）
                    if (canEdit) ...[
                      GestureDetector(
                        onTap: () => _editComment(c['id'], c['text']),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.edit_outlined,
                              size: 14, color: Colors.grey.shade400),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _deleteComment(c['id']),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.delete_outline,
                              size: 14, color: Colors.grey.shade400),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // 留言內容氣泡
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        isOwn ? const Color(0xFFFFF8F0) : Colors.grey.shade50,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(4),
                      topRight: const Radius.circular(14),
                      bottomLeft: const Radius.circular(14),
                      bottomRight: const Radius.circular(14),
                    ),
                    border: Border.all(
                      color:
                          isOwn ? Colors.orange.shade100 : Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    c['text'],
                    style: TextStyle(
                        fontSize: isSub ? 12 : 13,
                        color: Colors.black87,
                        height: 1.45),
                  ),
                ),
                // 回覆按鈕
                if (!isOwn || isGuest)
                  Padding(
                    padding: const EdgeInsets.only(top: 5, left: 4),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _replyToId = c['id'];
                        _replyToName = author;
                      }),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.reply_rounded,
                              size: 13, color: Color(0xFF8D6E63)),
                          SizedBox(width: 3),
                          Text('回覆',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8D6E63),
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuestionDiscussionPage extends StatelessWidget {
  final Map<String, dynamic> questionData;
  const QuestionDiscussionPage({super.key, required this.questionData});
  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> replies = [
      {'author': '李同學', 'time': '1小時前', 'content': '這題考的是資料庫的三層架構吧？'},
      {'author': '陳助教', 'time': '30分鐘前', 'content': '沒錯，樹狀結構屬於階層式，不是關聯式喔！'}
    ];
    return Scaffold(
        backgroundColor: Colors.white,
        appBar:
            AppBar(title: const Text('題目討論區', style: TextStyle(fontSize: 16))),
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Q: ${questionData['question']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      Text(
                          '正確答案：${questionData['options'][questionData['answerIndex']]}',
                          style: const TextStyle(
                              color: Colors.green, fontWeight: FontWeight.bold))
                    ])),
            const Divider(height: 30),
            const Text('討論留言',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 10),
            ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: replies.length,
                itemBuilder: (c, i) => Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                              radius: 15,
                              backgroundColor: Colors.grey.shade200,
                              child: Text(replies[i]['author'][0])),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Row(children: [
                                  Text(replies[i]['author'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  const SizedBox(width: 8),
                                  Text(replies[i]['time'],
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 11))
                                ]),
                                const SizedBox(height: 3),
                                Text(replies[i]['content'],
                                    style: const TextStyle(fontSize: 13))
                              ]))
                        ])))
          ])),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade100))),
              child: Row(children: [
                const Expanded(
                    child: TextField(
                        decoration: InputDecoration(
                            hintText: '參與討論...',
                            filled: true,
                            fillColor: Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                                borderSide: BorderSide.none)))),
                const SizedBox(width: 8),
                TextButton(
                    onPressed: () {},
                    child: const Text('送出',
                        style: TextStyle(color: Color(0xFF8D6E63))))
              ]))
        ])));
  }
}

class _OrganizeNotePickerWidget extends StatefulWidget {
  final Function(String) onSelected;
  final String? userId;
  const _OrganizeNotePickerWidget({required this.onSelected, this.userId});
  @override
  State<_OrganizeNotePickerWidget> createState() =>
      _OrganizeNotePickerWidgetState();
}

class _OrganizeNotePickerWidgetState extends State<_OrganizeNotePickerWidget> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    // Filter by userId to prevent showing other users' notes
    final userId = widget.userId;
    var notes = NotesDatabase.notes
        .where((n) =>
            (userId == null || n.userId == userId) && n.title.contains(_search))
        .toList();

    return Container(
        margin: const EdgeInsets.only(bottom: 14, left: 16, right: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
            ]),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                  hintText: '搜尋筆記標題...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0)),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          if (notes.isEmpty)
            Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.note_outlined,
                        size: 36, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text(_search.isEmpty ? '您還沒有任何筆記' : '找不到「$_search」相關筆記',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                )),
          ...notes.take(6).map((n) => ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D6E63).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.article_outlined,
                      color: Color(0xFF8D6E63), size: 20),
                ),
                title: Text(n.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: Text(n.category,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                trailing: Icon(Icons.chevron_right,
                    size: 18, color: Colors.grey.shade400),
                onTap: () => widget.onSelected(n.title),
              )),
          const SizedBox(height: 4),
        ]));
  }
}

class _OrganizedNoteResultWidget extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onReplace;
  final VoidCallback onSaveNew;
  final VoidCallback onImport;

  const _OrganizedNoteResultWidget({
    required this.data,
    required this.onReplace,
    required this.onSaveNew,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final noteTitle = data['selected_note_title'] as String? ?? '';
    final points = (data['points'] as List?)?.cast<String>() ?? [];
    final actions = (data['actions'] as List?)?.cast<String>() ?? [];
    final isAi = data['isAiGenerated'] as bool? ?? false;

    // Colour constants
    const brown = Color(0xFF6D4C41);
    const lightBrown = Color(0xFF8D6E63);
    const tealAccent = Color(0xFF00897B);

    Widget buildChip(String label, Color bg, Color fg) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
      );
    }

    Widget buildPointRow(String text, int idx) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2, right: 8),
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: lightBrown.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: Text('${idx + 1}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: lightBrown,
                      fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, height: 1.5, color: Color(0xFF3E2723))),
            )
          ],
        ),
      );
    }

    Widget buildActionRow(String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 4, right: 8),
              child:
                  Icon(Icons.check_circle_outline, size: 15, color: tealAccent),
            ),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, height: 1.5, color: Color(0xFF004D40))),
            )
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14, left: 10, right: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: lightBrown.withValues(alpha: 0.25), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6D4C41), Color(0xFF8D6E63)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    noteTitle,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                buildChip(
                    isAi ? 'Gemini AI' : '本地摘要',
                    isAi
                        ? Colors.white.withValues(alpha: 0.22)
                        : Colors.orange.withValues(alpha: 0.25),
                    Colors.white),
              ],
            ),
          ),

          // ── Warning/Hint if Local Fallback ──
          if (!isAi)
            Builder(builder: (context) {
              final now = DateTime.now();
              int secondsLeft = 0;
              if (AiDiagnosisService.nextAvailableTime != null &&
                  AiDiagnosisService.nextAvailableTime!.isAfter(now)) {
                secondsLeft = AiDiagnosisService.nextAvailableTime!
                    .difference(now)
                    .inSeconds;
              }
              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: const Color(0xFFFFFDE7),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 14, color: Color(0xFFFBC02D)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        secondsLeft > 0
                            ? 'AI 額度已達上限，現已切換為本地大綱整理（預計 $secondsLeft 秒後恢復）'
                            : 'AI 服務繁忙，已暫時切換為本地大綱整理',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF5D4037),
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              );
            }),

          // ── Points section ──
          if (points.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: lightBrown.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          children: [
                            Text('📌', style: TextStyle(fontSize: 12)),
                            SizedBox(width: 4),
                            Text('重點摘要',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: lightBrown)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...points
                      .asMap()
                      .entries
                      .map((e) => buildPointRow(e.value, e.key)),
                ],
              ),
            ),

          // ── Divider ──
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.grey.shade200, height: 1),
            ),

          // ── Actions section ──
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: tealAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🎯', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 4),
                        Text('行動建議',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: tealAccent)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...actions.map(buildActionRow),
                ],
              ),
            ),

          // ── Buttons ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add_to_photos, size: 15),
                    label: const Text('附加至原筆記', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: brown,
                        side: const BorderSide(color: lightBrown),
                        padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: onReplace,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.note_add, size: 15),
                    label: const Text('存為新筆記', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: brown,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: onSaveNew,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiLoadingTipWidget extends StatefulWidget {
  const _AiLoadingTipWidget();

  @override
  State<_AiLoadingTipWidget> createState() => _AiLoadingTipWidgetState();
}

class _AiLoadingTipWidgetState extends State<_AiLoadingTipWidget> {
  Timer? _timer;
  late String _currentTip;
  int _secondsLeft = 0;

  final List<String> _tips = [
    'AI 整理能幫您快速抓出筆記的核心重點！',
    '整理完後，您可以將摘要直接附加到原筆記中！',
    '有條理的筆記有助於大腦更深層地建立知識連結喔！',
    '利用 AI 摘要後，搭配題目測驗，學習效果會更好！',
    '每隔段時間重新檢視筆記，是克服遺忘曲線的最佳方法！',
  ];

  @override
  void initState() {
    super.initState();
    _currentTip = _tips[DateTime.now().millisecond % _tips.length];
    _updateSecondsLeft();
    if (_secondsLeft > 0) {
      _startTimer();
    }
  }

  void _updateSecondsLeft() {
    final now = DateTime.now();
    if (AiDiagnosisService.nextAvailableTime != null &&
        AiDiagnosisService.nextAvailableTime!.isAfter(now)) {
      _secondsLeft =
          AiDiagnosisService.nextAvailableTime!.difference(now).inSeconds;
    } else {
      _secondsLeft = 0;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _updateSecondsLeft();
        if (_secondsLeft <= 0) {
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _updateSecondsLeft();
    final bool isRateLimited = _secondsLeft > 0;
    final String icon = isRateLimited ? '⏳' : '💡';
    final String text = isRateLimited
        ? 'AI 目前繁忙，預計於 $_secondsLeft 秒後恢復。將暫以本地算法大綱整理...'
        : _currentTip;

    final Color bgColor =
        isRateLimited ? const Color(0xFFFFF3E0) : const Color(0xFFFFFDE7);
    final Color borderColor =
        isRateLimited ? const Color(0xFFFFE0B2) : const Color(0xFFFFF59D);
    final Color textColor =
        isRateLimited ? const Color(0xFFE65100) : const Color(0xFFF57F17);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosisLoadingProgress extends StatefulWidget {
  const _DiagnosisLoadingProgress();

  @override
  State<_DiagnosisLoadingProgress> createState() =>
      _DiagnosisLoadingProgressState();
}

class _DiagnosisLoadingProgressState extends State<_DiagnosisLoadingProgress> {
  double _value = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        if (_value < 0.92) {
          // 前段：以更溫和的步幅前進 (每 100ms 跑 1.5%，約 6 秒跑到 92%)
          // 這與 AI 生成首字元的時間 (TTFT) 更為貼合
          _value += 0.015;
          if (_value > 0.92) _value = 0.92;
        } else {
          // 後段：極慢速逼近 99.9% (每次增加剩餘空間的 3%，使增長更平滑)
          _value += (0.999 - _value) * 0.03;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int step = (_value * 4).ceil();
    if (step > 4) step = 4;
    if (step < 1) step = 1;

    String loadingText = '';
    switch (step) {
      case 1:
        loadingText = '資料彙整中... (1/4)';
        break;
      case 2:
        loadingText = '分析答錯概念... (2/4)';
        break;
      case 3:
        loadingText = '深度診斷運算中... (3/4)';
        break;
      case 4:
        loadingText = '生成個人化建議... (4/4)';
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: FadeInUp(
          duration: const Duration(milliseconds: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 進度條外框與內層填充
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _value.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD7CCC8), Color(0xFF8D6E63)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 動態文字與百分比
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loadingText,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4E342E),
                          ),
                        ),
                        Text(
                          '${(_value * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF8D6E63),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                '系統正在為您量身打造專屬報告，請稍候...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteSummaryLoadingBubble extends StatefulWidget {
  const _NoteSummaryLoadingBubble();

  @override
  State<_NoteSummaryLoadingBubble> createState() =>
      _NoteSummaryLoadingBubbleState();
}

class _NoteSummaryLoadingBubbleState extends State<_NoteSummaryLoadingBubble> {
  double _value = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        if (_value < 0.90) {
          _value += 0.03;
          if (_value > 0.90) _value = 0.90;
        } else {
          _value += (0.999 - _value) * 0.05;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8D6E63).withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    '代理人正在為您整理筆記...',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4E342E),
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${(_value * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8D6E63),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD7CCC8), Color(0xFF8D6E63)],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _AiLoadingTipWidget(),
          ],
        ),
      ),
    );
  }
}
