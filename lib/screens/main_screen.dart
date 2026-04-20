import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database_helper.dart';

class MainScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final Future<void> Function() onLogout;
  const MainScreen(
      {super.key, required this.currentUser, required this.onLogout});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // 預設進題庫
  String _appBarTitle = "題庫";

  // --- 資料庫區 ---
  // 使用真實今天（只取年月日，去掉時分秒）
  late final DateTime _simulatedToday;
  late DateTime _selectedDate;
  late DateTime _calendarMonth;
  late PageController _calendarPageController;
  late PageController _timelinePageController;

  bool _isLoading = true;

  Map<String, List<Map<String, dynamic>>> allSchedules = {};
  List<Map<String, dynamic>> allTodos = [];
  List<Map<String, dynamic>> socialPosts = [];
  List<Map<String, dynamic>> questionBank = [];

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
  int _remainingSeconds = 1800;
  final ScrollController _quizScrollController = ScrollController();

  bool _showStudyAnswers = false;
  String _studySearchQuery = "";
  String _studySubject = "全部";
  int _personalFilterIndex = 0;
  String? _selectedFolder;

  List<Map<String, dynamic>> chatLogs = [
    {'isAI': true, 'text': 'Sharon，全系統功能已回歸！測驗精靈與資料夾管理都已就緒。✨', 'isCard': false}
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
    _loadData();
  }

  String _formatRelativeTime(dynamic timeStr) {
    if (timeStr == null) return '';
    try {
      DateTime dt = DateTime.parse(timeStr.toString());
      Duration diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return '剛剛';
      if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
      if (diff.inHours < 24) return '${diff.inHours} 小時前';
      if (diff.inDays < 30) return '${diff.inDays} 天前';
      return '${dt.month}/${dt.day}';
    } catch (e) {
      return timeStr.toString();
    }
  }

  Future<void> _loadData() async {
    try {
      final db = await DatabaseHelper.instance.database;
      // One-time cleanup for Sharon's legacy data if it persists locally
      await db.delete('comments', where: 'user_id = ?', whereArgs: ['u1']);
      await db.delete('posts', where: 'user_id = ?', whereArgs: ['u1']);
      
      final currentUserId = widget.currentUser['id'];
      debugPrint("--- Social Loading Diagnostic ---");
      debugPrint("Current User ID: $currentUserId");

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

      // Fetch posts
      final postsdb = await db.query('posts', orderBy: 'created_at DESC');
      List<Map<String, dynamic>> pList = [];
      for (var p in postsdb) {
        final u =
            await db.query('users', where: 'id = ?', whereArgs: [p['user_id']]);
        String author =
            u.isNotEmpty ? u.first['display_name'] as String : '未知用戶';

        final likesCount = await db.query('post_likes',
            where: 'post_id = ? AND user_id = ?',
            whereArgs: [p['id'], currentUserId]);
        final resCount = await db.rawQuery(
            'SELECT COUNT(*) as c FROM comments WHERE post_id = ?', [p['id']]);
        int replies = (resCount.first['c'] as int?) ?? 0;

        Map<String, dynamic> attached = jsonDecode((p['attached_data'] as String?) ?? '{}');
        Uint8List? blobData = p['media_blob'] as Uint8List?;
        if (blobData != null) {
          debugPrint("Post ${p['id']} has BLOB data. Size: ${blobData.length} bytes");
        } else if (attached['media_url'] != null) {
          debugPrint("Post ${p['id']} has URL/Base64 data.");
        }

        pList.add({
          'id': p['id'],
          'userId': p['user_id'],
          'author': author,
          'time': _formatRelativeTime(p['created_at']),
          'content': p['content'],
          'isLiked': likesCount.isNotEmpty,
          'likes': p['likes'] ?? 0,
          'replies': replies,
          'media': attached['media_url'],
        });
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

      setState(() {
        allSchedules = schedulesMap;
        allTodos = todosList;
        socialPosts = pList;
        questionBank = qList;
        _isLoading = false;
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
    _quizScrollController.dispose();
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _quizStep == 2
          ? null
          : AppBar(
              title: _currentIndex == 0
                  ? TextButton(
                      onPressed: _showMonthYearPicker,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text("${_calendarMonth.year}年 ${_calendarMonth.month}月",
                            style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                                fontWeight: FontWeight.bold)),
                        const Icon(Icons.arrow_drop_down, color: Colors.black)
                      ]))
                  : Text(_appBarTitle,
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black)),
              backgroundColor: Colors.white,
              elevation: 0,
              actions: [
                  IconButton(
                      icon: const Icon(Icons.logout, color: Colors.black87),
                      onPressed: _showLogoutDialog)
                ]),
      drawer: Drawer(
          child: SafeArea(
              child: ListView(children: [
        const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text('系統選單',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8D6E63)))),
        ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('日曆行程'),
            onTap: () {
              _changePage(0, '日曆行程');
              Navigator.pop(context);
            }),
        ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('題庫'),
            onTap: () {
              _changePage(1, '題庫');
              Navigator.pop(context);
            }),
        ListTile(
            leading: const Icon(Icons.forum),
            title: const Text('社群'),
            onTap: () {
              _changePage(2, '社群');
              Navigator.pop(context);
            }),
        ListTile(
            leading: const Icon(Icons.account_circle),
            title: const Text('社群檔案'),
            onTap: () {
              _changePage(3, '社群檔案');
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
            _buildProfileTab()
          ])),
          if (_currentIndex != 1 || _quizStep == 0) _buildAIChatBar(),
        ]),
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
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(
                  color: Color(0xFFFAFAFA),
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
                    const Text('AI 代理人助理',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8D6E63),
                            fontSize: 16)),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: chatLogs.length,
                        itemBuilder: (context, i) {
                          var msg = chatLogs[i];
                          if (msg['isCard'] == true) {
                            return _buildConfirmationCard(
                                msg['pendingData'], setModalState);
                          }
                          return Align(
                            alignment: msg['isAI']
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                  color: msg['isAI']
                                      ? Colors.white
                                      : const Color(0xFFD7CCC8),
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
                                  style: const TextStyle(fontSize: 14)),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16,
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

  void _handleAISubmit(String input, TextEditingController controller,
      StateSetter setModalState) {
    if (input.trim().isEmpty) return;
    String text = input.trim();
    controller.clear();
    if (text.contains('日曆') || text.contains('行程')) {
      Navigator.pop(context);
      _changePage(0, '日曆行程');
      setState(() => chatLogs
          .add({'isAI': true, 'text': '沒問題，已為您跳轉至日曆！', 'isCard': false}));
    } else if (text.contains('題庫') || text.contains('測驗')) {
      Navigator.pop(context);
      _changePage(1, '題庫');
      setState(() =>
          chatLogs.add({'isAI': true, 'text': '切換至題庫系統！', 'isCard': false}));
    } else if (text.contains('社群')) {
      Navigator.pop(context);
      _changePage(2, '社群');
      setState(() =>
          chatLogs.add({'isAI': true, 'text': '好的，帶您去社群！', 'isCard': false}));
    } else if (text.contains('檔案')) {
      Navigator.pop(context);
      _changePage(3, '社群檔案');
      setState(() =>
          chatLogs.add({'isAI': true, 'text': '已打開社群檔案！', 'isCard': false}));
    } else {
      setModalState(() {
        chatLogs.add({'isAI': false, 'text': text});
        chatLogs.add({
          'isAI': true,
          'text': '收到！請問確認要將此項目真正加入系統嗎？',
          'isCard': true,
          'pendingData': {
            'title': text,
            'time': '14:00~15:00',
            'color': 0xFFFFCC80
          }
        });
      });
    }
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
                Icon(Icons.auto_awesome, color: Color(0xFF8D6E63), size: 20),
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
    return LayoutBuilder(builder: (context, constraints) {
      double itemWidth = (constraints.maxWidth - 40 - 48) / 7;
      // 增加高度比例 (40 -> 50)，避免內容過多造成溢出
      double childAspectRatio = itemWidth / 50.0;
      if (childAspectRatio <= 0.1) childAspectRatio = 0.1;

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
                                  : Colors.transparent,
                              border: Border.all(
                                  color: isSel
                                      ? const Color(0xFF8D6E63)
                                      : Colors.grey.shade100)),
                          child: Center(
                              child: Text('$d',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSel
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSel
                                          ? Colors.white
                                          : Colors.black87)))),
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
                      color: Colors.black.withOpacity(0.05), blurRadius: 4)
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
            
            int count = await db.update('todos', {'done': newDone ? 1 : 0, 'done_at': doneAt},
                where: 'id = ?', whereArgs: [int.parse(item['id'])]);
            
            debugPrint('Todo Toggle: ID ${item['id']}, New Status: $newDone, Updated: $count');
            await _loadData();
          } catch (e) {
            debugPrint('勾選待辦時出錯: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('操作失敗: $e'))
              );
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
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                          color: done ? Colors.grey.shade500 : Colors.black87,
                          fontWeight: done ? FontWeight.normal : FontWeight.w500))),
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
  Widget _buildStudyMode() {
    List<Map<String, dynamic>> filtered = questionBank
        .where((q) =>
            q['question'].contains(_studySearchQuery) &&
            (_studySubject == '全部' || q['subject'] == _studySubject))
        .toList();
    return Column(children: [
      Container(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TextField(
                onChanged: (v) => setState(() => _studySearchQuery = v),
                decoration: InputDecoration(
                    hintText: '搜尋題目...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                  child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                          children: ['全部', '資訊管理', '國文', '數學']
                              .map((s) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                      label: Text(s,
                                          style: const TextStyle(fontSize: 11)),
                                      selected: _studySubject == s,
                                      onSelected: (v) =>
                                          setState(() => _studySubject = s))))
                              .toList()))),
              Row(children: [
                const Text('答案', style: TextStyle(fontSize: 12)),
                Switch(
                    value: _showStudyAnswers,
                    activeColor: const Color(0xFF8D6E63),
                    onChanged: (v) => setState(() => _showStudyAnswers = v))
              ]),
            ])
          ])),
      Expanded(
          child: ListView.builder(
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
                        border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFE8EAF6),
                                    borderRadius: BorderRadius.circular(5)),
                                child: Text(q['subject'],
                                    style: const TextStyle(fontSize: 11))),
                            const Spacer(),
                            Text('出題：${q['author']}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey))
                          ]),
                          const SizedBox(height: 10),
                          Text(q['question'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          if (_showStudyAnswers)
                            Text(
                                ' Ans: ${q['options'].isNotEmpty ? q['options'][q['answerIndex']] : "無"}',
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold)),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                TextButton.icon(
                                    icon: Icon(
                                        q['isFavorite']
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 18,
                                        color: Colors.redAccent),
                                    label: Text('收藏',
                                        style: TextStyle(
                                            color: q['isFavorite']
                                                ? Colors.redAccent
                                                : Colors.grey)),
                                    onPressed: () => setState(() =>
                                        q['isFavorite'] = !q['isFavorite'])),
                                TextButton.icon(
                                    icon: const Icon(Icons.forum_outlined,
                                        size: 18, color: Colors.grey),
                                    label: const Text('討論',
                                        style: TextStyle(color: Colors.grey)),
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                QuestionDiscussionPage(
                                                    questionData: q)))),
                              ])
                        ]));
              }))
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

  // --- 3. 社群 & 檔案 (Threads 風格) ---
  Widget _buildSocialTab() => Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
                onTap: _showCreatePostScreen,
                child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.grey.shade200)),
                    child: Row(children: [
                      const CircleAvatar(
                          radius: 15,
                          backgroundColor: Color(0xFFD7CCC8),
                          child: Icon(Icons.person, color: Colors.white, size: 18)),
                      const SizedBox(width: 12),
                      const Expanded(
                          child: Text('分享學習心得...',
                              style: TextStyle(color: Colors.grey))),
                      const Icon(Icons.image_outlined, color: Colors.grey),
                    ])))),
        Expanded(
            child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: socialPosts.length,
                itemBuilder: (ctx, i) => _buildPostItem(socialPosts[i])))
      ]);

  void _showCreatePostScreen() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePostPage(
      currentUser: widget.currentUser,
      onPosted: _loadData,
    )));
  }
  Widget _buildProfileTab() => DefaultTabController(
      length: 2,
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(25),
            child: Row(children: [
              const CircleAvatar(
                  radius: 35,
                  backgroundColor: Color(0xFFD7CCC8),
                  child: Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 20),
              Text(widget.currentUser['display_name'] ?? '使用者',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold))
            ])),
        const TabBar(
            indicatorColor: Color(0xFF8D6E63),
            labelColor: Color(0xFF8D6E63),
            tabs: [Tab(text: '發佈'), Tab(text: '收藏')]),
        Expanded(
            child: TabBarView(children: [
          ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 1,
              itemBuilder: (ctx, i) => _buildPostItem(socialPosts[0])),
          const Center(child: Text('尚無收藏'))
        ]))
      ]));

  Widget _buildPostItem(Map<String, dynamic> p) => Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CircleAvatar(
            backgroundColor: Color(0xFFD7CCC8),
            child: Icon(Icons.person, color: Colors.white, size: 18)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(p['author'],
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Text(p['time'],
                style: const TextStyle(color: Colors.grey, fontSize: 12))
          ]),
          const SizedBox(height: 5),
          Text(p['content']),
          if ((p['media_blob'] != null) || (p['media'] != null && p['media'].toString().isNotEmpty)) ...[
            const SizedBox(height: 10),
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (p['media_blob'] != null)
                    ? Image.memory(
                        p['media_blob'],
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                      )
                    : (p['media'].toString().startsWith('data:image'))
                        ? Builder(builder: (context) {
                            try {
                              String base64Str = p['media'].toString().split(',').last.replaceAll('\n', '').replaceAll('\r', '');
                              return Image.memory(
                                base64Decode(base64Str),
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                              );
                            } catch (e) {
                              return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
                            }
                          })
                        : (p['media'].toString().startsWith('http') || kIsWeb)
                            ? Image.network(
                                p['media'],
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                              )
                            : Image.file(
                                File(p['media']),
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                              ),
              ),
            ),
          ],
          Row(children: [
            IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                    p['isLiked'] ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: p['isLiked'] ? Colors.redAccent : Colors.grey),
                onPressed: () => _toggleLike(p)),
            const SizedBox(width: 4),
            Text('${p['likes']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 20),
            IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.mode_comment_outlined, size: 20, color: Colors.grey),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PostReplyPage(
                          originalPost: p,
                          currentUser: widget.currentUser,
                        )))),
            const SizedBox(width: 4),
            Text('${p['replies']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])
        ]))
      ]));

  Future<void> _toggleLike(Map<String, dynamic> p) async {
    final db = await DatabaseHelper.instance.database;
    final currentUserId = widget.currentUser['id'];
    int currentLikes = p['likes'] ?? 0;

    if (p['isLiked']) {
      await db.delete('post_likes', where: 'post_id = ? AND user_id = ?', whereArgs: [p['id'], currentUserId]);
      currentLikes = (currentLikes > 0) ? currentLikes - 1 : 0;
      await db.execute('UPDATE posts SET likes = ? WHERE id = ?', [currentLikes, p['id']]);
    } else {
      await db.insert('post_likes', {'post_id': p['id'], 'user_id': currentUserId});
      currentLikes = currentLikes + 1;
      await db.execute('UPDATE posts SET likes = ? WHERE id = ?', [currentLikes, p['id']]);
    }
    _loadData();
  }
}

// --- 貼文發佈頁面 ---
class CreatePostPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final VoidCallback onPosted;
  const CreatePostPage({super.key, required this.currentUser, required this.onPosted});
  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _contentController = TextEditingController();
  XFile? _selectedImageX;
  String? _selectedFileName;
  bool _isSubmitting = false;

  void _pickImage() async {
    final ImagePicker picker = ImagePicker();
    // Limit size to 1024px and use 85% quality to ensure DB stability and upload success
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _selectedImageX = image);
    }
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() => _selectedFileName = result.files.single.name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已選取檔案：$_selectedFileName'))
      );
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
        debugPrint("Image processed for storage. Size: ${blobData.length} bytes");
      }

      await db.insert('posts', {
        'user_id': userId,
        'content': _contentController.text,
        'type': blobData != null ? 'image' : 'text',
        'media_blob': blobData,
        'attached_data': jsonEncode({
          'file_name': _selectedFileName
        }),
        'created_at': DateTime.now().toIso8601String(),
      });

      widget.onPosted();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Error submitting post: $e");
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('發佈失敗: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('新增貼文', style: TextStyle(fontSize: 16)),
          actions: [
            TextButton(
                onPressed: _isSubmitting ? null : _submitPost,
                child: Text(_isSubmitting ? '處理中...' : '發佈',
                    style: TextStyle(
                        color: _isSubmitting ? Colors.grey : const Color(0xFF8D6E63), 
                        fontWeight: FontWeight.bold)))
          ],
        ),
        body: Stack(children: [
          Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Expanded(
                    child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  decoration: const InputDecoration(
                      hintText: '想分享什麼呢？', border: InputBorder.none),
                )),
                if (_selectedImageX != null)
                  Stack(children: [
                    Container(
                      constraints: const BoxConstraints(maxHeight: 250),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(_selectedImageX!.path, fit: BoxFit.contain)
                              : Image.file(File(_selectedImageX!.path), fit: BoxFit.contain)),
                    ),
                    Positioned(
                        right: 5,
                        top: 5,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImageX = null),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black.withOpacity(0.5),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ))
                  ]),
                if (_selectedFileName != null)...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Row(children: [
                      const Icon(Icons.attach_file, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_selectedFileName!, style: const TextStyle(fontSize: 12))),
                      GestureDetector(
                        onTap: () => setState(() => _selectedFileName = null),
                        child: const Icon(Icons.close, size: 16, color: Colors.grey),
                      )
                    ]),
                  )
                ],
                const Divider(),
                Row(children: [
                  IconButton(
                      icon: const Icon(Icons.image_outlined, color: Colors.grey),
                      onPressed: _isSubmitting ? null : _pickImage),
                  IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.grey),
                      onPressed: _isSubmitting ? null : _pickFile),
                ])
              ])),
          if (_isSubmitting)
            const Center(child: CircularProgressIndicator(color: Color(0xFF8D6E63)))
        ]));
  }
}

// --- 3. 額外頁面 ---
class PostReplyPage extends StatefulWidget {
  final Map<String, dynamic> originalPost;
  final Map<String, dynamic> currentUser;
  const PostReplyPage({super.key, required this.originalPost, required this.currentUser});
  @override
  State<PostReplyPage> createState() => _PostReplyPageState();
}

class _PostReplyPageState extends State<PostReplyPage> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  int? _replyToId;
  String _replyToName = '';

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    final db = await DatabaseHelper.instance.database;
    final data = await db.query('comments',
        where: 'post_id = ?',
        whereArgs: [widget.originalPost['id']],
        orderBy: 'created_at ASC');

    List<Map<String, dynamic>> loaded = [];
    for (var c in data) {
      final user = await db.query('users', where: 'id = ?', whereArgs: [c['user_id']]);
      String name = user.isNotEmpty ? user.first['display_name'] as String : '未知用戶';
      loaded.add({
        ...c,
        'userId': c['user_id'],
        'author': name,
        'time': _formatRelativeTime(c['created_at'])
      });
    }

    setState(() => _comments = loaded);
  }

  String _formatRelativeTime(dynamic timeStr) {
    if (timeStr == null) return '';
    try {
      DateTime dt = DateTime.parse(timeStr.toString());
      Duration diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return '剛剛';
      if (diff.inMinutes < 60) return '${diff.inMinutes} 分鐘前';
      if (diff.inHours < 24) return '${diff.inHours} 小時前';
      if (diff.inDays < 30) return '${diff.inDays} 天前';
      return '${dt.month}/${dt.day}';
    } catch (e) {
      return timeStr.toString();
    }
  }

  void _submitComment() async {
    if (_commentController.text.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    final userId = widget.currentUser['id'];

    await db.insert('comments', {
      'post_id': widget.originalPost['id'],
      'user_id': userId,
      'text': _commentController.text,
      'parent_id': _replyToId ?? 0,
      'created_at': DateTime.now().toIso8601String(),
    });

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
                    child: const Text('取消', style: TextStyle(color: Colors.grey))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('刪除', style: TextStyle(color: Colors.red))),
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
                    child: const Text('取消', style: TextStyle(color: Colors.grey))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, editController.text),
                    child: const Text('儲存', style: TextStyle(color: Color(0xFF8D6E63)))),
              ],
            ));

    if (newText != null && newText.isNotEmpty && newText != currentText) {
      final db = await DatabaseHelper.instance.database;
      await db.update('comments', {'text': newText}, where: 'id = ?', whereArgs: [commentId]);
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

    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('文章回覆', style: TextStyle(fontSize: 16))),
        body: SafeArea(
            child: Column(children: [
          Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
            _buildPostHeader(),
            const Divider(),
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('精彩回覆',
                    style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold))),
            if (_comments.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('還沒有人回覆，快來沙發吧！', style: TextStyle(color: Colors.grey, fontSize: 13)),
              )),
            ...rootComments[0]?.map((c) => _buildCommentTree(c, rootComments)) ?? []
          ])),
          
          if (_replyToId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade100,
              child: Row(children: [
                Text('正在回覆 ${_replyToName}:', style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63))),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() { _replyToId = null; _replyToName = ''; }),
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
                            hintText: _replyToId != null ? '寫下你的見解...' : '留個言吧...',
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none)))),
                const SizedBox(width: 8),
                TextButton(
                    onPressed: _submitComment,
                    child: const Text('發佈',
                        style: TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.bold)))
              ]))
        ])));
  }

  Widget _buildPostHeader() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const CircleAvatar(
          backgroundColor: Color(0xFFD7CCC8),
          child: Icon(Icons.person, color: Colors.white, size: 18)),
      const SizedBox(width: 12),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(widget.originalPost['author'],
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Text(widget.originalPost['time'],
              style: const TextStyle(color: Colors.grey, fontSize: 12))
        ]),
        const SizedBox(height: 8),
        Text(widget.originalPost['content'], style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 12)
      ]))
    ]);
  }

  Widget _buildCommentTree(Map<String, dynamic> comment, Map<int, List<Map<String, dynamic>>> group) {
    List<Map<String, dynamic>> sub = group[comment['id']] ?? [];
    return Column(children: [
      _buildSingleComment(comment),
      ...sub.map((sc) => Padding(
        padding: const EdgeInsets.only(left: 40),
        child: _buildSingleComment(sc, isSub: true),
      ))
    ]);
  }

  Widget _buildSingleComment(Map<String, dynamic> c, {bool isSub = false}) {
    return Container(
        margin: const EdgeInsets.only(bottom: 12, top: 4),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                  radius: isSub ? 12 : 15,
                  backgroundColor: Colors.grey.shade200,
                  child: Text(c['author'][0], style: TextStyle(fontSize: isSub ? 10 : 12))),
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
                      if (c['userId'] == widget.currentUser['id']) ...[
                        GestureDetector(
                          onTap: () => _editComment(c['id'], c['text']),
                          child: const Icon(Icons.edit_outlined, size: 14, color: Colors.grey),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () => _deleteComment(c['id']),
                          child: const Icon(Icons.delete_outline, size: 14, color: Colors.grey),
                        ),
                      ] else if (!isSub)
                        GestureDetector(
                          onTap: () => setState(() {
                            _replyToId = c['id'];
                            _replyToName = c['author'];
                          }),
                          child: const Text('回覆', style: TextStyle(fontSize: 11, color: Color(0xFF8D6E63))),
                        )
                    ]),
                    const SizedBox(height: 4),
                    Text(c['text'], style: TextStyle(fontSize: isSub ? 12 : 13)),
                  ]))
            ]));
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
