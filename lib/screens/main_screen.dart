import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart';
import '../widgets/common_widgets.dart';
import '../services/ai_intent_service.dart';

part 'main_screen_profile_tab.part.dart';
part 'main_screen_social_tab.part.dart';
part 'main_screen_activity_tab.part.dart';

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

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; // 預設進日曆
  String _appBarTitle = "日曆行程";

  // --- 資料庫區 ---
  // 使用真實今天（只取年月日，去掉時分秒）
  late final DateTime _simulatedToday;
  late DateTime _selectedDate;
  late DateTime _calendarMonth;
  late PageController _calendarPageController;
  late PageController _timelinePageController;

  bool _isLoading = true;
  Uint8List? _userAvatarBlob;
  int _userAvatarColor = 0;
  bool _userAvatarSelected = false;
  String? _userBio;
  double _fontSizeFactor = 1.0;
  int _themeColorIdx = 0;
  bool _isDarkMode = false;
  String _socialFilter = '全部'; // 社群貼文分類筛選狀態
  DateTime? _nicknameUpdatedAt;
  bool _isEmailVerified = false;
  String? _displayName;

  Map<String, List<Map<String, dynamic>>> allSchedules = {};
  List<Map<String, dynamic>> allTodos = [];
  List<Map<String, dynamic>> socialPosts = [];
  List<Map<String, dynamic>> scheduledPosts = [];
  List<Map<String, dynamic>> questionBank = [];
  final ScrollController _chatScrollController = ScrollController();
  final ScrollController _profileScrollController = ScrollController();

  List<String> allSubjects = ['資訊管理', '作業系統', '國文', '數學', '微積分'];
  Map<String, List<String>> subjectChapters = {
    '資訊管理': ['第一章 資訊系統簡介', '第二章 資料庫管理'],
    '國文': ['師說', '出師表'],
    '數學': ['面積', '機率'],
  };

  // --- 狀態控制區 ---
  int _quizStep = 0;
  String _quizSelectedSubject = "";
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

  int _remainingSeconds = 1800;
  final ScrollController _quizScrollController = ScrollController();

  bool _showStudyAnswers = false;
  String _studySearchQuery = "";
  String _studySubject = "全部";
  int _personalFilterIndex = 0;
  String? _selectedFolder;
  String? _selectedSubjectForStudy; // 新增：追蹤題庫中選擇的科目

  String _aiFlowState = 'none';
  Map<String, dynamic> _aiFlowData = {};
  bool get _isAiReplyingFlow => _aiFlowState == 'replying';
  set _isAiReplyingFlow(bool value) {
    _aiFlowState = value ? 'replying' : 'none';
  }

  int _aiReplyPostIndex = 0;
  List<Map<String, dynamic>> _aiPendingReplyPosts = [];

  List<Map<String, dynamic>> chatLogs = [
    {
      'isAI': true,
      'text':
          '哈囉👋 我是你的專屬 AI 代理人！很高興為您服務。😊\n\n我可以協助您管理行程、發佈貼文、回覆留言以及調整個人設定。您可以隨時輸入「幫助」或點擊下方功能來了解更多！',
      'isCard': false
    },
    {'isAI': true, 'text': '', 'isCard': false, 'widgetType': 'help_options'}
  ];

  @override
  void initState() {
    super.initState();
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
      Map<String, List<Map<String, dynamic>>> schedulesMap = {};
      for (var s in schedulesList) {
        String date = (s['start_time'] as String).split(' ')[0];
        String startHr =
            (s['start_time'] as String).split(' ')[1].substring(0, 5);
        String endHr = (s['end_time'] as String).split(' ')[1].substring(0, 5);
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
        schedulesMap.putIfAbsent(date, () => []).add({
          'id': s['id'],
          'time': '$startHr~$endHr',
          'title': s['title'],
          'color': colorVal
        });
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
            if (sTime != null) {
              // 確保兩者都在同一個時區（本地）進行比較
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
      DateTime? nicknameUpdatedAt;
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
        if (userRows.first['nickname_updated_at'] != null) {
          nicknameUpdatedAt = DateTime.tryParse(
              userRows.first['nickname_updated_at'].toString());
        }
        isEmailVerified =
            (userRows.first['is_email_verified'] as int? ?? 0) == 1;
      }

      setState(() {
        allSchedules = schedulesMap;
        allTodos = todosList;
        socialPosts = pList;
        scheduledPosts = sList;
        questionBank = qList;
        _isLoading = false;
        _userAvatarBlob = userAvatar;
        _userAvatarColor = userAvatarColor;
        _userAvatarSelected = userAvatarSelected == 1;
        _nicknameUpdatedAt = nicknameUpdatedAt;
        _isEmailVerified = isEmailVerified;
        _displayName = displayName;

        // 個人化設定：安全處理資料類型並觸發 UI 更新
        if (userRows.isNotEmpty) {
          _userBio = userRows.first['bio'] as String?;
          _fontSizeFactor =
              ((userRows.first['font_size_factor'] ?? 1.0) as num).toDouble();
          _themeColorIdx = (userRows.first['theme_color_idx'] ?? 0) as int;
          _isDarkMode = (userRows.first['is_dark_mode'] ?? 0) == 1;
          debugPrint(
              'Theme Loaded: _themeColorIdx=$_themeColorIdx, _isDarkMode=$_isDarkMode');
        }
      });
    } catch (e) {
      print('載入資料庫發生錯誤: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _quizTimer?.cancel();
    _scheduleTimer?.cancel();
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
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
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
                await db.update(
                    'posts',
                    {
                      'content': newContent,
                      'attached_data': newAttached,
                    },
                    where: 'id = ?',
                    whereArgs: [sp['id']]);
                Navigator.pop(ctx);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isScheduled ? 'AI 代理人已為您完成貼文排程！' : '貼文已立即發佈！')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已取消收藏')),
      );
    } else {
      await db.insert('post_bookmarks', {
        'post_id': postId,
        'user_id': userId,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已收藏貼文')),
      );
    }
    await _loadData();
  }

  // 補回：手動新增行程
  void _addSchedule(String timeRange, String title, int color) async {
    try {
      final db = await DatabaseHelper.instance.database;
      String key = _selectedDate.toString().split(' ')[0];
      String startStr = "$key ${timeRange.split('~')[0]}:00";
      String endStr = "$key ${timeRange.split('~')[1]}:00";
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
  void _editSchedule(int id, String timeRange, String title, int color) async {
    try {
      final db = await DatabaseHelper.instance.database;
      String key = _selectedDate.toString().split(' ')[0];
      String startStr = "$key ${timeRange.split('~')[0]}:00";
      String endStr = "$key ${timeRange.split('~')[1]}:00";
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
          !_quizSelectedChapters.contains(q['chapter'])) continue;
      if (_availableCounts.containsKey(q['type']) &&
          _availableCounts[q['type']]!.containsKey(q['difficulty'])) {
        _availableCounts[q['type']]![q['difficulty']] =
            _availableCounts[q['type']]![q['difficulty']]! + 1;
      }
    }
  }

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
          secondary: primaryColor.withOpacity(0.8),
        ),
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(_fontSizeFactor),
        ),
        child: Builder(builder: (context) {
          return Scaffold(
            backgroundColor: _isDarkMode ? Colors.black87 : Colors.white,
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
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold)),
                              const Icon(Icons.arrow_drop_down,
                                  color: Colors.black)
                            ]))
                        : Text(_appBarTitle,
                            style: const TextStyle(
                                fontSize: 16, color: Colors.black)),
                    backgroundColor: Colors.white,
                    elevation: 0,
                    actions: [
                        if (_currentIndex == 0)
                          IconButton(
                              icon: const Icon(Icons.today,
                                  color: Colors.black87),
                              onPressed: _returnToToday,
                              tooltip: '回到今日'),
                        IconButton(
                            icon:
                                const Icon(Icons.logout, color: Colors.black87),
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
                  leading: Icon(Icons.groups_rounded,
                      color: Theme.of(context).primaryColor),
                  title: const Text('社群'),
                  onTap: () {
                    _changePage(2, '社群');
                    Navigator.pop(context);
                  }),
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
            ]))),
            body: SafeArea(
              child: Column(children: [
                Expanded(
                    child: IndexedStack(index: _currentIndex, children: [
                  _buildCalendarTab(),
                  _buildQuestionBankTab(),
                  _buildSocialTab(),
                  _buildSocialActivityTab(),
                  _buildPersonalProfileTab(context)
                ])),
                if (_currentIndex != 1 || _quizStep == 0) _buildAIChatBar(),
              ]),
            ),
          );
        }),
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
                          const Text('AI 代理人助理',
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
                                        '好的，已為您重啟對話！😊\n我是您的 AI 代理人，請問今天有什麼我可以幫您的嗎？',
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
                                margin:
                                    const EdgeInsets.only(bottom: 12, left: 40),
                                alignment: Alignment.centerLeft,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.calendar_today,
                                      size: 18),
                                  label: const Text('選擇日期與時間'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF8D6E63),
                                      elevation: 1,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20))),
                                  onPressed: () async {
                                    DateTime? date = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime(2030),
                                      locale: const Locale('zh', 'TW'),
                                    );
                                    if (date != null && mounted) {
                                      TimeOfDay? time = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.now(),
                                      );
                                      if (time != null && mounted) {
                                        String timeStr =
                                            "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                                        String dateTimeStr =
                                            "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $timeStr";
                                        _handleAISubmit(dateTimeStr,
                                            modalController, setModalState);
                                      }
                                    }
                                  },
                                ));
                          }
                          if (msg['widgetType'] == 'color_picker') {
                            List<Map<String, dynamic>> colors = [
                              {'name': '紅色', 'color': const Color(0xFFE57373)},
                              {'name': '藍色', 'color': const Color(0xFF64B5F6)},
                              {'name': '綠色', 'color': const Color(0xFF81C784)},
                              {'name': '黃色', 'color': const Color(0xFFFFD54F)},
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

                          if (msg['widgetType'] == 'help_options') {
                            final options = [
                              {'n': '1', 'l': '📅 新增日曆行程', 'v': '新增行程'},
                              {'n': '2', 'l': '📝 發佈社群貼文', 'v': '發佈貼文'},
                              {'n': '3', 'l': '💬 回覆社群留言', 'v': '回覆哪些留言'},
                              {'n': '4', 'l': '👤 修改個人資料', 'v': '個人檔案'},
                              {'n': '5', 'l': '🎨 切換佈景主題', 'v': '切換主題'},
                              {'n': '6', 'l': '📋 跳轉題庫測驗', 'v': '題庫'},
                            ];
                            return Container(
                                margin: const EdgeInsets.only(
                                    bottom: 12, left: 40, right: 10),
                                child: Column(
                                  children: options
                                      .map((opt) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 8),
                                            child: InkWell(
                                              onTap: () => _handleAISubmit(
                                                  opt['v']!,
                                                  modalController,
                                                  setModalState),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 10),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color:
                                                          Colors.grey.shade200),
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.02),
                                                        blurRadius: 4,
                                                        offset:
                                                            const Offset(0, 2))
                                                  ],
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 24,
                                                      height: 24,
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                                0xFF8D6E63)
                                                            .withOpacity(0.1),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Center(
                                                          child: Text(opt['n']!,
                                                              style: const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Color(
                                                                      0xFF8D6E63),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold))),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(opt['l']!,
                                                        style: const TextStyle(
                                                            fontSize: 14,
                                                            color:
                                                                Colors.black87,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w500)),
                                                    const Spacer(),
                                                    Icon(Icons.chevron_right,
                                                        size: 16,
                                                        color: Colors
                                                            .grey.shade400),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ));
                          }

                          if (msg['widgetType'] == 'post_type_picker') {
                            List<String> types = ['一般', '學習筆記', '心情文章', '分享資料'];
                            return Container(
                                margin:
                                    const EdgeInsets.only(bottom: 12, left: 40),
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8,
                                  children: types
                                      .map((t) => GestureDetector(
                                            onTap: () {
                                              _handleAISubmit(
                                                  t,
                                                  modalController,
                                                  setModalState);
                                            },
                                            child: Chip(
                                              label: Text(t),
                                              backgroundColor: Colors.white,
                                              side: const BorderSide(
                                                  color: Color(0xFF8D6E63),
                                                  width: 1),
                                            ),
                                          ))
                                      .toList(),
                                ));
                          }

                          if (msg['widgetType'] == 'confirm_post') {
                            var pData = msg['pendingData'] ?? {};
                            return Container(
                                margin: const EdgeInsets.only(
                                    bottom: 12, left: 40, right: 10),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                        color: const Color(0xFF8D6E63),
                                        width: 1.5)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(children: [
                                        Icon(Icons.schedule_send,
                                            color: Colors.blueAccent),
                                        SizedBox(width: 8),
                                        Text('待發佈排程確認',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))
                                      ]),
                                      const SizedBox(height: 12),
                                      Text('分類：${pData['type']}',
                                          style: const TextStyle(fontSize: 14)),
                                      Text('內容：${pData['content']}',
                                          style: const TextStyle(fontSize: 14)),
                                      Text('排程時間：${pData['time']}',
                                          style: const TextStyle(fontSize: 14)),
                                      const SizedBox(height: 18),
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                                onPressed: () =>
                                                    _handleAISubmit(
                                                        '取消',
                                                        modalController,
                                                        setModalState),
                                                child: const Text('捨棄',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.redAccent))),
                                            const SizedBox(width: 8),
                                            OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        const Color(
                                                            0xFF8D6E63)),
                                                onPressed: () => _publishAIPost(
                                                    pData, false),
                                                child: const Text('立即發佈')),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF8D6E63),
                                                    foregroundColor:
                                                        Colors.white),
                                                onPressed: () =>
                                                    _publishAIPost(pData, true),
                                                child: const Text('確認排程'))
                                          ])
                                    ]));
                          }

                          if (msg['text'] == null || msg['text'].isEmpty)
                            return const SizedBox();

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
                                                .withOpacity(0.03),
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
                                                  onTap: () {
                                                    Navigator.pop(ctx);
                                                    modalController.text =
                                                        msg['text'];
                                                    setModalState(() {
                                                      _aiFlowState =
                                                          msg['stateAtTime'] ??
                                                              'none';
                                                    });
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                            const SnackBar(
                                                                content: Text(
                                                                    '已帶入輸入框，請修改後重新發送以更正內容')));
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
                              child: TextField(
                            controller: modalController,
                            decoration: InputDecoration(
                                hintText: '去題庫 / 看日曆 / 加行程...',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                    borderSide: BorderSide.none),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 20)),
                            onSubmitted: (v) => _handleAISubmit(
                                v, modalController, setModalState),
                          )),
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
    if (result.intent == UserIntent.none && result.suggestionLabel == null)
      return false;

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
        // 觸發發文流程
        updateLogs(() {
          chatLogs.add(
              {'isAI': false, 'text': userInput, 'stateAtTime': _aiFlowState});
          _aiFlowState = 'adding_post_content';
          _aiFlowData = {};
          chatLogs.add({
            'isAI': true,
            'text': '好的，我們來發佈一則新的貼文吧！📝\n請問貼文的內容是什麼？',
            'isCard': false
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
            'text': '我很樂意幫您新增行程！📅\n首先，請問這個行程的標題是什麼？',
            'isCard': false
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
          // 檢查是否已回覆過此留言
          final replies = await db.query('comments',
              where: 'parent_id = ? AND user_id = ?',
              whereArgs: [c['id'], widget.currentUser['id']]);
          if (replies.isNotEmpty) continue;

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

    // 僅在非任務流程中處理快捷指令與對話
    if (_aiFlowState == 'none') {
      // 數字快捷指令處理 (1-6)
      if (RegExp(r'^[1-6]$').hasMatch(text)) {
        String command = "";
        String featureName = "";
        switch (text) {
          case '1':
            command = "新增行程";
            featureName = "新增行程";
            break;
          case '2':
            command = "發佈貼文";
            featureName = "發佈社群貼文";
            break;
          case '3':
            command = "回覆哪些留言";
            featureName = "回覆社群留言";
            break;
          case '4':
            command = "個人檔案";
            featureName = "個人檔案";
            break;
          case '5':
            command = "切換主題";
            featureName = "切換佈景主題";
            break;
          case '6':
            command = "題庫";
            featureName = "跳轉題庫測驗";
            break;
          case '7':
            command = "社群動態";
            featureName = "我的發佈與收藏";
            break;
        }
        if (command.isNotEmpty) {
          setModalState(() {
            chatLogs.add({'isAI': false, 'text': text});
            chatLogs.add({
              'isAI': true,
              'text': '好的，沒問題！這就為您處理「$featureName」',
              'isCard': false
            });
            _scrollToBottom();
          });
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _handleAISubmit(command, controller, setModalState);
            }
          });
          return;
        }
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
            'text': '嗨！很高興見到你！😊 我是你的 AI 代理人助手，隨時準備好為你服務。今天有什麼我可以幫你的嗎？',
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
          chatLogs.add({
            'isAI': true,
            'text': '您可以點擊上方選項，或直接輸入對應的數字。想做什麼都儘管跟我說吧！✨',
            'isCard': false
          });
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

      Future.delayed(const Duration(milliseconds: 600), () {
        Navigator.push(
            context,
            MaterialPageRoute(
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
                    }))).then((_) => _loadData());
      });
      return;
    }

    if (_aiFlowState == 'adding_event_title') {
      _aiFlowData['title'] = text;
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'adding_event_date';
        chatLogs.add({
          'isAI': true,
          'text': '收到了，行程標題為「$text」。\n請選擇行程的日期與時間：',
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

    if (_aiFlowState == 'adding_event_date') {
      _aiFlowData['start_date'] = text;
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'adding_event_end_time';
        chatLogs.add({
          'isAI': true,
          'text': '好的，開始時間為「$text」。\n接著請選擇行程的「結束時間」：',
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

    if (_aiFlowState == 'adding_event_end_time') {
      _aiFlowData['end_date'] = text;
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'adding_event_color';
        chatLogs.add({
          'isAI': true,
          'text': '結束時間為「$text」。\n最後，請選擇行程標籤顏色：',
          'isCard': false
        });
        chatLogs.add({
          'isAI': true,
          'text': '',
          'isCard': false,
          'widgetType': 'color_picker'
        });
        _scrollToBottom();
      });
      return;
    }

    if (_aiFlowState == 'adding_event_color') {
      String colorStr = text;
      int colorValue = 0xFF8D6E63;
      if (colorStr.contains('紅')) colorValue = 0xFFE57373;
      if (colorStr.contains('藍')) colorValue = 0xFF64B5F6;
      if (colorStr.contains('綠')) colorValue = 0xFF81C784;
      if (colorStr.contains('黃')) colorValue = 0xFFFFD54F;

      _aiFlowData['color'] = colorValue;

      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        chatLogs
            .add({'isAI': true, 'text': '沒問題！正在為您加入行程...', 'isCard': false});
        _scrollToBottom();
      });

      Navigator.pop(context);
      _changePage(0, '日曆行程');

      Future.delayed(const Duration(milliseconds: 600), () async {
        final db = await DatabaseHelper.instance.database;
        String startStr = _aiFlowData['start_date'];
        String endStr = _aiFlowData['end_date'];

        if (startStr.length <= 16) startStr = "$startStr:00";
        if (endStr.length <= 16) endStr = "$endStr:00";

        await db.insert('calendar_events', {
          'user_id': widget.currentUser['id'],
          'title': _aiFlowData['title'],
          'start_time': startStr,
          'end_time': endStr,
          'color': '0x${(_aiFlowData['color'] as int).toRadixString(16)}',
        });
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('AI 代理人已為您成功加入行程！')));
        }
      });
      _aiFlowState = 'none';
      return;
    }

    if (_aiFlowState == 'adding_post_content') {
      _aiFlowData['content'] = text;
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'adding_post_type';
        chatLogs.add({
          'isAI': true,
          'text': '收到了！請問這篇貼文是什麼類型？\n(一般, 學習筆記, 心情文章, 分享資料)',
          'isCard': false,
          'widgetType': 'post_type_picker'
        });
        _scrollToBottom();
      });
      return;
    }

    if (_aiFlowState == 'adding_post_type') {
      _aiFlowData['type'] = text;
      setModalState(() {
        chatLogs
            .add({'isAI': false, 'text': text, 'stateAtTime': _aiFlowState});
        _aiFlowState = 'adding_post_time';
        chatLogs.add({
          'isAI': true,
          'text': '好的，類型已設定為「$text」。🏷️\n請問這篇貼文要什麼時候發佈？\n(可以直接點擊下方按鈕選取時間)',
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
        setModalState(() {
          chatLogs.add({
            'isAI': true,
            'text': '✅ 貼文已成功發佈！您可以在「社群動態」中查看。',
            'isCard': false
          });
        });
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
            '抱歉，我還在學習中，不太明白您的意思... 😅\n但我可以幫您處理行程、貼文、或是修改個人設定！您可以輸入「幫助」來看看我能做什麼。',
        'isCard': false,
        'widgetType': 'help_options'
      });
      _scrollToBottom();
    });
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
                color: Colors.black.withOpacity(0.05),
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
            height: 330,
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
                                      ? const Color(0xFFF5E6E6)
                                      : Colors.transparent),
                              border: Border.all(
                                  color: isSel
                                      ? const Color(0xFF8D6E63)
                                      : (isToday
                                          ? Colors.redAccent.withOpacity(0.5)
                                          : Colors.grey.shade100))),
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
                                              : Colors.black87))))),
                      // 行程標記：改用膠囊型色條 (Pills)，外觀更現代且色彩鮮明
                      if (dayEvents.isNotEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.only(top: 2, left: 4, right: 4),
                          child: Wrap(
                            spacing: 2,
                            runSpacing: 2,
                            alignment: WrapAlignment.center,
                            children: [
                              ...dayEvents.take(3).map((e) => Container(
                                    width: 8,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: Color(
                                          e['color'] as int? ?? 0xFF8D6E63),
                                    ),
                                  )),
                              if (dayEvents.length > 3)
                                Text('+${dayEvents.length - 3}',
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
    String nowKey = DateTime.now().toString().split(' ')[0];
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

    return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        children: [
          // --- Itinerary Section ---
          if (schedules.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                const Icon(Icons.event_note,
                    size: 18, color: Color(0xFF8D6E63)),
                const SizedBox(width: 8),
                const Text('今日行程',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8D6E63),
                        fontSize: 15)),
              ]),
            ),
            ...schedules.map((event) => _buildScheduleItem(event)),
            const SizedBox(height: 10),
          ],

          // --- Todo Section ---
          if (uncompletedTodos.isNotEmpty || completedTodos.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                const Icon(Icons.check_box_outlined,
                    size: 18, color: Color(0xFF8D6E63)),
                const SizedBox(width: 8),
                const Text('待辦事項',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8D6E63),
                        fontSize: 15)),
              ]),
            ),
            ...uncompletedTodos.map((item) => _buildTodoItem(item, isPast)),
            if (completedTodos.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 10, bottom: 5),
                child: Text('已完成',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold)),
              ),
              ...completedTodos.map((item) => _buildTodoItem(item, isPast)),
            ],
          ],
          const SizedBox(height: 50), // bottom padding
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
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Color(event['color']),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4)
                ]),
            child: Row(children: [
              SizedBox(
                  width: 95,
                  child: Text(event['time'],
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13))),
              Expanded(
                  child: Text(event['title'],
                      style: const TextStyle(fontWeight: FontWeight.w500))),
              const Icon(Icons.edit, size: 16, color: Colors.black38)
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
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: done ? const Color(0xFFF5F5F5) : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                    color: done ? Colors.transparent : Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(done ? 0.01 : 0.03),
                      blurRadius: 4)
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

    StateSetter? dialogSetState;
    Future<void> selectTime(bool isStart) async {
      final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: isStart ? pickedStartTime : pickedEndTime);
      if (picked != null) {
        dialogSetState!(() {
          if (isStart)
            pickedStartTime = picked;
          else
            pickedEndTime = picked;
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
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: '行程名稱')),
                    const SizedBox(height: 20),
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
                        if (titleController.text.isEmpty) return;
                        String range =
                            "${formatTime(pickedStartTime)}~${formatTime(pickedEndTime)}";
                        _editSchedule(event['id'], range, titleController.text,
                            selectedColor);
                        Navigator.pop(ctx);
                      },
                      child: const Text('儲存修改'))
                ]));
  }

  // --- 2. 題庫系統 (測驗/題庫/個人) ---
  Widget _buildQuestionBankTab() {
    if (_quizStep >= 2) return _buildQuizTakingOrResult();
    return DefaultTabController(
        length: 3,
        child: Column(children: [
          const TabBar(
              indicatorColor: Color(0xFF8D6E63),
              labelColor: Color(0xFF8D6E63),
              unselectedLabelColor: Colors.grey,
              tabs: [Tab(text: '測驗'), Tab(text: '題庫'), Tab(text: '個人題庫')]),
          Expanded(
              child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                _buildQuizWizard(),
                _buildStudyMode(),
                _buildPersonalMode()
              ]))
        ]));
  }

  // 測驗精靈 (Step 0 & 1)
  Widget _buildQuizWizard() => Column(children: [
        Container(
            color: const Color(0xFFFAFAFA),
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _quizStepNode(0, '1.範圍'),
              _quizStepLine(),
              _quizStepNode(1, '2.挑題'),
              _quizStepLine(),
              _quizStepNode(2, '3.測驗'),
            ])),
        Expanded(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _quizStep == 0 ? _buildQuizStep0() : _buildQuizStep1())),
        _buildQuizFooter(),
      ]);

  Widget _quizStepNode(int s, String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
          color: _quizStep >= s ? const Color(0xFF8D6E63) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: _quizStep >= s
                  ? const Color(0xFF8D6E63)
                  : Colors.grey.shade300)),
      child: Text(t,
          style: TextStyle(
              color: _quizStep >= s ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 13)));
  Widget _quizStepLine() =>
      Container(width: 25, height: 2, color: Colors.grey.shade300);

  Widget _buildQuizStep0() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('選擇出題範圍',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8D6E63))),
              const SizedBox(height: 15),
              Autocomplete<String>(
                  optionsBuilder: (v) => v.text.isEmpty
                      ? allSubjects
                      : allSubjects.where((s) => s.contains(v.text)),
                  onSelected: (s) => setState(() {
                        _quizSelectedSubject = s;
                        _quizSelectedChapters.clear();
                      }),
                  fieldViewBuilder: (ctx, ctrl, focus, onSub) {
                    if (_quizSelectedSubject.isNotEmpty && ctrl.text.isEmpty) {
                      ctrl.text = _quizSelectedSubject;
                    }
                    return TextField(
                        controller: ctrl,
                        focusNode: focus,
                        decoration: InputDecoration(
                            hintText: '搜尋科目...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none)));
                  }),
            ])),
        if (_quizSelectedSubject.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('範圍篩選 (章節)',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8D6E63))),
                    const SizedBox(height: 10),
                    ...(subjectChapters[_quizSelectedSubject] ?? [])
                        .map((chap) => CheckboxListTile(
                            title: Text(chap),
                            value: _quizSelectedChapters.contains(chap),
                            activeColor: const Color(0xFF8D6E63),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            onChanged: (v) => setState(() {
                                  v!
                                      ? _quizSelectedChapters.add(chap)
                                      : _quizSelectedChapters.remove(chap);
                                }))),
                  ]))
        ]
      ]);

  Widget _buildQuizStep1() {
    List<Widget> typeCards = [];
    _availableCounts.forEach((type, diffs) {
      if (diffs.values.any((c) => c > 0)) {
        typeCards.add(Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade100)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['易', '中', '難']
                      .map((lv) => _buildPickCounter(
                          lv, type, _availableCounts[type]![lv]!))
                      .toList()),
            ])));
      }
    });
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('已選範圍：$_quizSelectedSubject',
          style: const TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 10),
      if (typeCards.isEmpty)
        const Text('此範圍無題目可挑選', style: TextStyle(color: Colors.grey)),
      ...typeCards
    ]);
  }

  Widget _buildPickCounter(String diff, String type, int avail) =>
      Column(children: [
        Text(diff,
            style: TextStyle(
                fontSize: 12,
                color: avail > 0 ? Colors.black54 : Colors.grey.shade300)),
        const SizedBox(height: 5),
        Row(children: [
          GestureDetector(
              onTap: () => setState(() {
                    if (_quizPickedCounts[type]![diff]! > 0) {
                      _quizPickedCounts[type]![diff] =
                          _quizPickedCounts[type]![diff]! - 1;
                    }
                  }),
              child: Icon(Icons.remove_circle_outline,
                  color: avail > 0 ? Colors.grey : Colors.grey.shade200)),
          const SizedBox(width: 8),
          Text('${_quizPickedCounts[type]![diff]} / $avail',
              style: TextStyle(
                  fontSize: 13,
                  color: avail > 0 ? Colors.black : Colors.grey.shade300)),
          const SizedBox(width: 8),
          GestureDetector(
              onTap: () => setState(() {
                    if (_quizPickedCounts[type]![diff]! < avail) {
                      _quizPickedCounts[type]![diff] =
                          _quizPickedCounts[type]![diff]! + 1;
                    }
                  }),
              child: Icon(Icons.add_circle_outline,
                  color: avail > 0
                      ? const Color(0xFF8D6E63)
                      : Colors.grey.shade200)),
        ])
      ]);

  Widget _buildQuizFooter() => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _quizStep == 0
            ? const SizedBox(width: 80)
            : OutlinedButton(
                onPressed: () => setState(() => _quizStep = 0),
                child: const Text('上一步')),
        ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8D6E63),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30)),
            onPressed: () {
              if (_quizStep == 0 && _quizSelectedSubject.isNotEmpty) {
                _calculateAvailableQuestions();
                setState(() => _quizStep = 1);
              } else if (_quizStep == 1) {
                _generateQuizPaper();
                setState(() {
                  _userAnswers.clear();
                  for (int i = 0; i < _currentQuizQuestions.length; i++) {
                    _userAnswers[i] = -1;
                  }
                  _remainingSeconds = 1800;
                  _quizStep = 2;
                });
                _startTimer();
              }
            },
            child: Text(_quizStep == 0 ? '下一步' : '開始測驗')),
      ]));

  void _startTimer() {
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        t.cancel();
        setState(() => _quizStep = 3);
      }
    });
  }

  Widget _buildQuizTakingOrResult() {
    if (_quizStep == 3) return _buildQuizResult();
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
          title: Text(
              '剩餘 ${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
                onPressed: () {
                  _quizTimer?.cancel();
                  setState(() => _quizStep = 3);
                },
                child: const Text('交卷',
                    style: TextStyle(
                        color: Color(0xFF8D6E63), fontWeight: FontWeight.bold)))
          ]),
      body: Column(children: [
        Expanded(
            child: ListView.builder(
                controller: _quizScrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _currentQuizQuestions.length,
                itemBuilder: (ctx, i) {
                  var q = _currentQuizQuestions[i];
                  return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 10)
                          ]),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Q${i + 1}. ${q['question']}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            ...List.generate(
                                q['options'].length,
                                (idx) => RadioListTile(
                                    title: Text(q['options'][idx]),
                                    value: idx,
                                    groupValue: _userAnswers[i],
                                    onChanged: (v) => setState(
                                        () => _userAnswers[i] = v as int),
                                    activeColor: const Color(0xFF8D6E63),
                                    contentPadding: EdgeInsets.zero,
                                    dense: true))
                          ]));
                })),
        Container(
            height: 60,
            color: Colors.white,
            child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: _currentQuizQuestions.length,
                itemBuilder: (ctx, i) => GestureDetector(
                    onTap: () => _quizScrollController.animateTo(i * 300.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.linear),
                    child: Container(
                        width: 40,
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: _userAnswers[i] == -1
                                ? Colors.grey.shade100
                                : const Color(0xFF8D6E63),
                            borderRadius: BorderRadius.circular(8)),
                        child: Center(
                            child: Text('${i + 1}',
                                style: TextStyle(
                                    color: _userAnswers[i] == -1
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.bold))))))),
      ]),
    );
  }

  Widget _buildQuizResult() {
    int correctCount = 0;
    for (int i = 0; i < _currentQuizQuestions.length; i++) {
      if (_currentQuizQuestions[i]['type'] != '申論題' &&
          _userAnswers[i] == _currentQuizQuestions[i]['answerIndex']) {
        correctCount++;
      }
    }
    int score = _currentQuizQuestions.isEmpty
        ? 0
        : ((correctCount / _currentQuizQuestions.length) * 100).round();
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Center(
          child: Text('測驗完成',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      Center(
          child: Text('得分：$score',
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8D6E63)))),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: _resetQuiz, child: const Text('回測驗首頁')),
      const Divider(height: 40),
      const Text('詳解區', style: TextStyle(fontWeight: FontWeight.bold)),
      ...List.generate(_currentQuizQuestions.length, (i) {
        var q = _currentQuizQuestions[i];
        return Container(
            margin: const EdgeInsets.only(bottom: 15, top: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade100)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${i + 1}. ${q['question']}'),
              const SizedBox(height: 8),
              Text(
                  '正確答案：${q['options'].isNotEmpty ? q['options'][q['answerIndex']] : "無"}',
                  style: const TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
              const Divider(),
              Text('【解析】${q['explanation']}',
                  style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
            ]));
      }),
    ]);
  }

  // 刷題模式
  // 刷題模式 - 分層結構 (科目資料夾 → 題目列表)
  Widget _buildStudyMode() {
    // 第一層：科目資料夾列表
    if (_selectedSubjectForStudy == null) {
      // 收集所有科目
      Set<String> subjects = {};
      for (var q in questionBank) {
        subjects.add(q['subject'] as String);
      }
      List<String> subjectList = subjects.toList();
      
      // 計算每個科目的題數
      Map<String, int> subjectCounts = {};
      for (var subject in subjectList) {
        subjectCounts[subject] = questionBank.where((q) => q['subject'] == subject).length;
      }

      return Column(children: [
        // 頂部搜尋
        Container(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _studySearchQuery = v),
            decoration: InputDecoration(
              hintText: '搜尋科目...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // 科目卡片網格
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemCount: subjectList.length,
            itemBuilder: (ctx, i) {
              String subject = subjectList[i];
              int count = subjectCounts[subject] ?? 0;
              
              return GestureDetector(
                onTap: () => setState(() => _selectedSubjectForStudy = subject),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8D6E63).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.library_books,
                            size: 32,
                            color: Color(0xFF8D6E63),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        subject,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$count 道題目',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ]);
    }

    // 第二層：科目內的題目列表
    List<Map<String, dynamic>> filtered = questionBank
        .where((q) =>
            q['subject'] == _selectedSubjectForStudy &&
            q['question'].contains(_studySearchQuery))
        .toList();

    return Column(children: [
      // 返回按鈕 & 搜尋
      Container(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF8D6E63)),
              onPressed: () => setState(() {
                _selectedSubjectForStudy = null;
                _studySearchQuery = "";
              }),
            ),
            Expanded(
              child: Text(
                _selectedSubjectForStudy ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8D6E63),
                ),
              ),
            ),
            Row(children: [
              const Text('答案', style: TextStyle(fontSize: 12)),
              Switch(
                value: _showStudyAnswers,
                activeColor: const Color(0xFF8D6E63),
                onChanged: (v) => setState(() => _showStudyAnswers = v),
              ),
            ]),
          ]),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _studySearchQuery = v),
            decoration: InputDecoration(
              hintText: '搜尋題目...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ]),
      ),
      // 題目列表
      Expanded(
        child: filtered.isEmpty
            ? const Center(
              child: Text('此科目無題目', style: TextStyle(color: Colors.grey)),
            )
            : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                var q = filtered[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EAF6),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            q['subject'],
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '出題：${q['author']}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Text(
                        q['question'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      if (_showStudyAnswers)
                        Text(
                          'Ans: ${q['options'].isNotEmpty ? q['options'][q['answerIndex']] : "無"}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          TextButton.icon(
                            icon: Icon(
                              q['isFavorite']
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                            label: Text(
                              '收藏',
                              style: TextStyle(
                                color: q['isFavorite']
                                    ? Colors.redAccent
                                    : Colors.grey,
                              ),
                            ),
                            onPressed: () => setState(
                              () => q['isFavorite'] = !q['isFavorite'],
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.edit_outlined,
                              size: 18,
                              color: Colors.grey,
                            ),
                            label: const Text('作答',
                              style: TextStyle(color: Colors.grey),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    QuestionPracticePage(
                                      questionData: q,
                                    ),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.forum_outlined,
                              size: 18,
                              color: Colors.grey,
                            ),
                            label: const Text('討論',
                              style: TextStyle(color: Colors.grey),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    QuestionDiscussionPage(
                                      questionData: q,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      ),
    ]);
  }

  // 個人題庫 (資料夾)
  Widget _buildPersonalMode() {
    if (_selectedFolder != null) {
      List<Map<String, dynamic>> folderQuestions = questionBank.where((q) {
        if (_personalFilterIndex == 0) {
          return q['isWrong'] == true && q['subject'] == _selectedFolder;
        }
        if (_personalFilterIndex == 1) {
          return q['author'] == widget.currentUser['display_name'] &&
              q['subject'] == _selectedFolder;
        }
        if (_personalFilterIndex == 2) {
          return q['isFavorite'] == true && q['subject'] == _selectedFolder;
        }
        return false;
      }).toList();
      return Column(children: [
        AppBar(
            title: Text(_selectedFolder!),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedFolder = null))),
        Expanded(
            child: folderQuestions.isEmpty
                ? const Center(child: Text('資料夾空空的'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: folderQuestions.length,
                    itemBuilder: (ctx, i) {
                      var q = folderQuestions[i];
                      return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade200)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(q['question'],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                if (q['type'] != '申論題')
                                  ...List.generate(
                                      q['options'].length,
                                      (idx) => Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 6),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          child: Text(q['options'][idx]))),
                              ]));
                    }))
      ]);
    }

    Map<String, int> folderCounts = {};
    for (var q in questionBank) {
      bool match = false;
      if (_personalFilterIndex == 0 && q['isWrong'] == true) match = true;
      if (_personalFilterIndex == 1 &&
          q['author'] == widget.currentUser['display_name']) match = true;
      if (_personalFilterIndex == 2 && q['isFavorite'] == true) match = true;
      if (match) {
        folderCounts[q['subject']] = (folderCounts[q['subject']] ?? 0) + 1;
      }
    }

    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(16),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _pChip('錯題', 0, Icons.close),
            _pChip('新增', 1, Icons.add),
            _pChip('收藏', 2, Icons.favorite_border)
          ])),
      if (_personalFilterIndex == 1)
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8D6E63),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45)),
                icon: const Icon(Icons.add),
                label: const Text('新增題目'),
                onPressed: _showAddQuestionDialog)),
      Expanded(
          child: folderCounts.isEmpty
              ? const Center(
                  child: Text('目前沒有資料喔', style: TextStyle(color: Colors.grey)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: folderCounts.entries
                      .map((entry) => GestureDetector(
                          onTap: () =>
                              setState(() => _selectedFolder = entry.key),
                          child: Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.02),
                                        blurRadius: 5)
                                  ]),
                              child: Row(children: [
                                const Icon(Icons.folder,
                                    color: Color(0xFFD7CCC8), size: 40),
                                const SizedBox(width: 15),
                                Expanded(
                                    child: Text(entry.key,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold))),
                                Text('${entry.value} 題',
                                    style: const TextStyle(color: Colors.grey)),
                                const Icon(Icons.chevron_right,
                                    color: Colors.grey)
                              ]))))
                      .toList()))
    ]);
  }

  Widget _pChip(String l, int i, IconData ic) => ChoiceChip(
      label: Row(
          children: [Icon(ic, size: 14), const SizedBox(width: 4), Text(l)]),
      selected: _personalFilterIndex == i,
      selectedColor: const Color(0xFFD7CCC8),
      onSelected: (v) => setState(() => _personalFilterIndex = i));

  void _showAddQuestionDialog() {
    String selectedSubject = '資訊管理';
    String selectedType = '單選題';
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('新增題目'),
                content: StatefulBuilder(builder: (context, setDialogState) {
                  return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('1. 科目'),
                        DropdownButton<String>(
                            isExpanded: true,
                            value: selectedSubject,
                            items: allSubjects
                                .map((s) =>
                                    DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedSubject = v!)),
                        const SizedBox(height: 15),
                        const Text('2. 題型'),
                        Row(
                            children: ['單選題', '是非題']
                                .map((t) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                        label: Text(t),
                                        selected: selectedType == t,
                                        onSelected: (v) => setDialogState(
                                            () => selectedType = t))))
                                .toList()),
                        const SizedBox(height: 15),
                        const TextField(
                            decoration: InputDecoration(hintText: '請輸入題目...')),
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
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('新增'))
                ]));
  }

  // --- 手動新增行程 (含 Padding 修正) ---
  void _showManualAddDialog() {
    TextEditingController titleController = TextEditingController();
    int selectedType = 0;
    TimeOfDay pickedStartTime = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay pickedEndTime = const TimeOfDay(hour: 11, minute: 0);
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
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: '標題名稱')),
                    const SizedBox(height: 20),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
                  ]);
                }),
                actions: [
                  ElevatedButton(
                      onPressed: () {
                        if (titleController.text.isEmpty) return;
                        if (selectedType == 0) {
                          String range =
                              "${formatTime(pickedStartTime)}~${formatTime(pickedEndTime)}";
                          _addSchedule(
                              range, titleController.text, selectedColor);
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
      final db = await DatabaseHelper.instance.database;
      Map<String, dynamic> updateData = {
        'content': result['content'],
        'type': result['type'],
        'is_edited': 1,
      };
      if (result['imageChanged']) {
        updateData['media_blob'] = result['media_blob'];
      }
      await db
          .update('posts', updateData, where: 'id = ?', whereArgs: [p['id']]);
      await _loadData();
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
      await db.delete('posts', where: 'id = ?', whereArgs: [p['id']]);
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ 頭像已更新！'), duration: Duration(seconds: 2)));
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
          color: const Color(0xFF8D6E63).withOpacity(0.1),
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
    // 移除了 24 小時更改限制，讓使用者隨時可更換暱稱

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
                final db = await DatabaseHelper.instance.database;
                await db.update('users', {'is_email_verified': 1},
                    where: 'id = ?', whereArgs: [widget.currentUser['id']]);
                await _loadData();
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('驗證成功！')));
                }
              },
              child: const Text('發送驗證信'),
            ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
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

  void _showMyCollectionsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: const Text('我的收藏')),
          body: _buildCollectionsList(),
        ),
      ),
    );
  }

  Widget _buildCollectionsList() {
    final List<Map<String, dynamic>> collections =
        questionBank.where((q) => q['isFavorite'] == true).toList();
    if (collections.isEmpty) return const Center(child: Text('尚無收藏項目'));
    return ListView.builder(
      itemCount: collections.length,
      itemBuilder: (ctx, i) => ListTile(
        leading: const Icon(Icons.quiz_outlined, color: Color(0xFF8D6E63)),
        title: Text(collections[i]['question']),
        subtitle: Text(collections[i]['subject']),
        trailing: const Icon(Icons.chevron_right),
      ),
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

      final newId = await db.insert('posts', {
        'user_id': userId,
        'content': _contentController.text,
        'type': _postType ?? (blobData != null ? 'image' : 'text'),
        'media_blob': blobData,
        'attached_data': jsonEncode({'file_name': _selectedFileName}),
        'created_at': DateTime.now().toIso8601String(),
      });

      if ((widget.currentUser['username'] ?? '') == '訪客') {
        (widget.currentUser['session_post_ids'] as Set<int>?)?.add(newId);
      }

      widget.onPosted();
      if (mounted) Navigator.pop(context);
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
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('新增貼文',
              style: TextStyle(fontSize: 16, color: Colors.black87)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                  onPressed: _isSubmitting ? null : _submitPost,
                  style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF8D6E63),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20))),
                  child: Text(_isSubmitting ? '處理中...' : '發佈',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14))),
            )
          ],
        ),
        body: Stack(children: [
          Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 貼文類型標籤列
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _buildTypeChip('📝  學習筆記', 'note'),
                        const SizedBox(width: 8),
                        _buildTypeChip('💭  心情文章', 'mood'),
                        const SizedBox(width: 8),
                        _buildTypeChip('📄  分享資料', 'doc'),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                        child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                          hintText: _postType == 'note'
                              ? '寫下你的學習筆記...'
                              : _postType == 'mood'
                                  ? '今天的心情是...'
                                  : '想分享什麼呢？',
                          border: InputBorder.none),
                    )),
                    // 已選圖片預覽
                    if (_selectedImageX != null)
                      Stack(children: [
                        Container(
                          constraints: const BoxConstraints(
                              maxHeight: 200, maxWidth: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.shade50,
                          ),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(File(_selectedImageX!.path),
                                  fit: BoxFit.cover)),
                        ),
                        Positioned(
                            right: 5,
                            top: 5,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _selectedImageX = null;
                              }),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.black.withOpacity(0.5),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 16),
                              ),
                            ))
                      ]),
                    // 已選檔案顯示
                    if (_selectedFileName != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(children: [
                          const Icon(Icons.attach_file,
                              size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_selectedFileName!,
                                  style: const TextStyle(fontSize: 12))),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _selectedFileName = null),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.grey),
                          )
                        ]),
                      )
                    ],
                    const Divider(height: 24),
                    // 底部工具列
                    Row(children: [
                      const Text('附加：',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: '附加圖片',
                        child: IconButton(
                            icon: const Icon(Icons.image_outlined,
                                color: Color(0xFF8D6E63)),
                            onPressed: _isSubmitting ? null : _pickImage),
                      ),
                      Tooltip(
                        message: '附加文件（筆記/Word/PDF）',
                        child: IconButton(
                            icon: const Icon(Icons.attach_file,
                                color: Color(0xFF8D6E63)),
                            onPressed:
                                _isSubmitting ? null : _showFileTypeSheet),
                      ),
                    ])
                  ])),
          if (_isSubmitting)
            const Center(
                child: CircularProgressIndicator(color: Color(0xFF8D6E63)))
        ]));
  }

  Widget _buildTypeChip(String label, String type) {
    final bool isSelected = _postType == type;
    return GestureDetector(
      onTap: () => setState(() => _postType = isSelected ? null : type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF8D6E63) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
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
        .showSnackBar(const SnackBar(content: Text('AI 代理人已為您自動輸入並送出！')));
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
    final data = await db.query('comments',
        where: 'post_id = ?',
        whereArgs: [widget.originalPost['id']],
        orderBy: 'created_at ASC');

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
      int pid = c['parent_id'] as int;
      rootComments.putIfAbsent(pid, () => []).add(c);
    }

    // 將根留言依們選定的排序方式排序
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
          final ra = rootComments[a['id'] as int]?.length ?? 0;
          final rb = rootComments[b['id'] as int]?.length ?? 0;
          return rb.compareTo(ra); // 回覆數多的排在前面
        });
        break;
      default:
        break; // '所有留言': 預設由舊到新 ASC
    }

    return Scaffold(
        backgroundColor: Colors.white,
        appBar:
            AppBar(title: const Text('文章回覆', style: TextStyle(fontSize: 16))),
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
            _buildPostHeader(),
            const Divider(),
            // ─ 留言排序選項
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _commentSort == label
                                      ? Colors.white
                                      : Colors.grey.shade700,
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
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('還沒有人回覆，快來沙發吧！',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              )),
            ...rootList.map((c) => _buildCommentTree(c, rootComments))
          ])),
          if (_replyToId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(children: [
                Text('正在回覆 ${_replyToName}:',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF8D6E63))),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    _replyToId = null;
                    _replyToName = '';
                  }),
                  child: const Icon(Icons.close, size: 14, color: Colors.grey),
                )
              ]),
            ),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade100))),
              child: Row(children: [
                Expanded(
                    child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                            hintText:
                                _replyToId != null ? '寫下你的見解...' : '留個言吧...',
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none)))),
                const SizedBox(width: 8),
                TextButton(
                    onPressed: _submitComment,
                    child: const Text('發佈',
                        style: TextStyle(
                            color: Color(0xFF8D6E63),
                            fontWeight: FontWeight.bold)))
              ]))
        ])));
  }

  Widget _buildPostHeader() {
    final author = widget.originalPost['author'] ?? '?';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      buildAvatar(
          blob: widget.originalPost['authorAvatarBlob'] as Uint8List?,
          colorIdx: (widget.originalPost['authorAvatarColor'] as int?) ??
              getAvatarColorIdx(author),
          initial: author.substring(0, 1),
          radius: 18,
          usePreset:
              (widget.originalPost['authorAvatarSelected'] as int? ?? 0) == 1 &&
                  widget.originalPost['authorAvatarBlob'] == null),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(widget.originalPost['author'],
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Text(widget.originalPost['time'],
              style: const TextStyle(color: Colors.grey, fontSize: 12))
        ]),
        const SizedBox(height: 8),
        Text(widget.originalPost['content'],
            style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 12)
      ]))
    ]);
  }

  Widget _buildCommentTree(
      Map<String, dynamic> comment, Map<int, List<Map<String, dynamic>>> group,
      {int depth = 0}) {
    List<Map<String, dynamic>> sub = group[comment['id']] ?? [];
    return Column(children: [
      _buildSingleComment(comment, isSub: depth > 0),
      ...sub.map((sc) => Padding(
            padding: EdgeInsets.only(
                left: depth < 3 ? 30.0 : 0.0), // 遞迴縮排，最多縮排3層避免過度向右擠壓
            child: _buildCommentTree(sc, group, depth: depth + 1),
          ))
    ]);
  }

  Widget _buildSingleComment(Map<String, dynamic> c, {bool isSub = false}) {
    final author = (c['author'] ?? '?') as String;
    return Container(
        margin: const EdgeInsets.only(bottom: 12, top: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          buildAvatar(
              blob: c['authorAvatarBlob'] as Uint8List?,
              colorIdx:
                  (c['authorAvatarColor'] as int?) ?? getAvatarColorIdx(author),
              initial: author.substring(0, 1),
              radius: isSub ? 12 : 15,
              usePreset: (c['authorAvatarSelected'] as int? ?? 0) == 1 &&
                  c['authorAvatarBlob'] == null),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text(c['author'],
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSub ? 12 : 13)),
                  const SizedBox(width: 8),
                  Text(c['time'],
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  const Spacer(),
                  if (c['userId'] == widget.currentUser['id'] &&
                      ((widget.currentUser['username'] ?? '') != '訪客' ||
                          ((widget.currentUser['session_comment_ids']
                                      as Set<int>?)
                                  ?.contains(c['id']) ??
                              false))) ...[
                    GestureDetector(
                      onTap: () => _editComment(c['id'], c['text']),
                      child: const Icon(Icons.edit_outlined,
                          size: 14, color: Colors.grey),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _deleteComment(c['id']),
                      child: const Icon(Icons.delete_outline,
                          size: 14, color: Colors.grey),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (c['userId'] != widget.currentUser['id'] ||
                      (widget.currentUser['username'] ?? '') == '訪客')
                    GestureDetector(
                      onTap: () => setState(() {
                        // 直接將該留言設為 parent_id，形成多層樹狀結構
                        _replyToId = c['id'];
                        _replyToName = c['author'];
                      }),
                      child: const Text('回覆',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF8D6E63))),
                    )
                ]),
                const SizedBox(height: 4),
                Text(c['text'], style: TextStyle(fontSize: isSub ? 12 : 13)),
              ]))
        ]));
  }
}

// 題目作答頁面
class QuestionPracticePage extends StatefulWidget {
  final Map<String, dynamic> questionData;
  const QuestionPracticePage({super.key, required this.questionData});

  @override
  State<QuestionPracticePage> createState() => _QuestionPracticePageState();
}

class _QuestionPracticePageState extends State<QuestionPracticePage> {
  int? _selectedAnswerIndex;
  bool _showResult = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.questionData;
    final options = (q['options'] as List?)?.cast<String>() ?? [];
    final correctIndex = q['answerIndex'] as int?;
    final explanation = q['explanation'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('題目作答'),
        backgroundColor: const Color(0xFF8D6E63),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 題目
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '科目：${q['subject']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    q['question'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 選項
            const Text(
              '請選擇答案：',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...List.generate(
              options.length,
              (i) => GestureDetector(
                onTap: _showResult ? null : () {
                  setState(() {
                    _selectedAnswerIndex = i;
                    _showResult = true;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedAnswerIndex == i
                        ? (_showResult
                            ? (i == correctIndex
                                ? Colors.green.shade100
                                : Colors.red.shade100)
                            : const Color(0xFF8D6E63).withOpacity(0.1))
                        : Colors.white,
                    border: Border.all(
                      color: _selectedAnswerIndex == i
                          ? (_showResult
                              ? (i == correctIndex ? Colors.green : Colors.red)
                              : const Color(0xFF8D6E63))
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        String.fromCharCode(65 + i), // A, B, C, D
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _selectedAnswerIndex == i
                              ? (_showResult
                                  ? (i == correctIndex
                                      ? Colors.green
                                      : Colors.red)
                                  : const Color(0xFF8D6E63))
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          options[i],
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedAnswerIndex == i
                                ? Colors.black87
                                : Colors.black,
                          ),
                        ),
                      ),
                      if (_showResult && i == correctIndex)
                        const Icon(Icons.check_circle, color: Colors.green),
                      if (_showResult &&
                          _selectedAnswerIndex == i &&
                          i != correctIndex)
                        const Icon(Icons.close, color: Colors.red),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 結果顯示
            if (_showResult)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedAnswerIndex == correctIndex
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedAnswerIndex == correctIndex
                              ? Icons.check_circle
                              : Icons.close,
                          color: _selectedAnswerIndex == correctIndex
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedAnswerIndex == correctIndex
                                    ? '✓ 答對了！'
                                    : '✗ 答錯了',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedAnswerIndex == correctIndex
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              if (_selectedAnswerIndex != correctIndex)
                                Text(
                                  '正確答案：${String.fromCharCode(65 + (correctIndex ?? 0))}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '解釋：',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    explanation,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => setState(() {
                        _selectedAnswerIndex = null;
                        _showResult = false;
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8D6E63),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('重新作答'),
                    ),
                  ),
                ],
              ),
            if (!_showResult && _selectedAnswerIndex != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _showResult = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8D6E63),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('顯示答案與解釋'),
                ),
              ),
          ],
        ),
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
