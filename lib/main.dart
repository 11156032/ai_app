import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD7CCC8),
          surface: const Color(0xFFFAFAFA),
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

// --- 1. 登入系統 ---
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _currentUser;
  void _login(String user) => setState(() => _currentUser = user);
  void _logout() => setState(() => _currentUser = null);

  @override
  Widget build(BuildContext context) {
    return _currentUser == null
        ? LoginScreen(onLogin: _login)
        : MainScreen(userName: _currentUser!, onLogout: _logout);
  }
}

class LoginScreen extends StatelessWidget {
  final Function(String) onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 60, color: Color(0xFFD7CCC8)),
            const SizedBox(height: 20),
            const Text('歡迎回來，請選擇帳號',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 40),
            _btn('登入 Sharon 的行事曆', const Color(0xFFE8EAF6),
                () => onLogin('Sharon')),
            const SizedBox(height: 20),
            _btn('登入 訪客 的行事曆', const Color(0xFFF1F8E9),
                () => onLogin('訪客')),
          ],
        ),
      ),
    );
  }

  Widget _btn(String t, Color c, VoidCallback f) => ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: c,
            padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
        onPressed: f,
        child: Text(t, style: const TextStyle(color: Colors.black87)),
      );
}

// --- 2. 主功能畫面 ---
class MainScreen extends StatefulWidget {
  final String userName;
  final VoidCallback onLogout;
  const MainScreen(
      {super.key, required this.userName, required this.onLogout});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  DateTime _selectedDate = DateTime(2026, 3, 30);
  DateTime _calendarMonth = DateTime(2026, 3, 1);

  // Calendar: page _calBase = March 2026
  static const int _calBase = 12;
  static const int _tlBase = 1000;
  static final DateTime _tlOrigin = DateTime(2026, 3, 30);
  static const int _calOriginYear = 2026;
  static const int _calOriginMonth = 3;

  late PageController _calendarPageController;
  late PageController _timelinePageController;

  // Guard flag: prevents calendar↔timeline ping-pong
  bool _isAnimating = false;

  List<Map<String, String>> _messages = [
    {'role': 'ai', 'text': '哈囉！歡迎回來！有什麼我可以幫你的嗎？☕'},
  ];

  Map<String, List<Map<String, dynamic>>> allSchedules = {
    '2026-03-30': [
      {'time': '00:00~07:00', 'title': '睡覺', 'color': 0xFFCFD8DC},
      {'time': '09:10~12:00', 'title': '專題會議', 'color': 0xFFFFE082},
      {'time': '12:00~13:30', 'title': '吃飯', 'color': 0xFFB2EBF2},
    ],
    '2026-03-31': [
      {'time': '10:00~11:00', 'title': '晨跑', 'color': 0xFFB2EBF2},
      {'time': '14:00~16:00', 'title': '線上課程', 'color': 0xFFFFE082},
    ],
    '2026-04-01': [
      {'time': '09:00~10:00', 'title': '讀書', 'color': 0xFFFFE082},
      {'time': '14:00~16:00', 'title': '圖書館', 'color': 0xFFCFD8DC},
    ],
  };

  @override
  void initState() {
    super.initState();
    _calendarPageController = PageController(initialPage: _calBase);
    _timelinePageController = PageController(initialPage: _tlBase);
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    _calendarPageController.dispose();
    _timelinePageController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _sortDay(String key) {
    allSchedules[key]
        ?.sort((a, b) => a['time'].toString().compareTo(b['time'].toString()));
  }

  void _addSchedule(String timeRange, String title, int color) {
    setState(() {
      final key = _dateKey(_selectedDate);
      (allSchedules[key] ??= [])
          .add({'time': timeRange, 'title': title, 'color': color});
      _sortDay(key);
    });
  }

  void _deleteSchedule(String key, int index) {
    setState(() => allSchedules[key]?.removeAt(index));
  }

  void _updateSchedule(
      String key, int index, String newTime, String newTitle) {
    setState(() {
      allSchedules[key]?[index]['time'] = newTime;
      allSchedules[key]?[index]['title'] = newTitle;
      _sortDay(key);
    });
  }

  // Syncs selected date and optionally animates timeline/calendar.
  void _syncDate(DateTime date, {bool fromCalendar = false}) {
    if (_isAnimating) return;

    final monthChanged = date.year != _calendarMonth.year ||
        date.month != _calendarMonth.month;

    setState(() {
      _selectedDate = date;
      if (monthChanged) {
        _calendarMonth = DateTime(date.year, date.month, 1);
      }
    });

    _isAnimating = true;

    if (fromCalendar) {
      // Tap on calendar → animate timeline to matching day
      final tlPage = _tlBase + date.difference(_tlOrigin).inDays;
      _timelinePageController
          .animateToPage(tlPage,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut)
          .then((_) => _isAnimating = false);
    } else if (monthChanged) {
      // Swipe timeline past month boundary → animate calendar to new month
      final calPage = _calBase +
          (date.year - _calOriginYear) * 12 +
          (date.month - _calOriginMonth);
      _calendarPageController
          .animateToPage(calPage,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut)
          .then((_) => _isAnimating = false);
    } else {
      _isAnimating = false;
    }
  }

  // Dynamic calendar height based on number of weeks in the month.
  double _getCalendarHeight() {
    final firstWeekday =
        DateTime(_calendarMonth.year, _calendarMonth.month, 1).weekday;
    final days =
        DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final rows = ((firstWeekday - 1 + days) / 7).ceil();
    return rows * 50.0 + 60.0;
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();
    setState(() => _messages.add({'role': 'user', 'text': text}));
    _scrollChatToBottom();

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(
          () => _messages.add({'role': 'ai', 'text': _generateAiReply(text)}));
      _scrollChatToBottom();
    });
  }

  String _generateAiReply(String input) {
    final key = _dateKey(_selectedDate);
    final count = (allSchedules[key] ?? []).length;
    if (input.contains('行程') || input.contains('安排')) {
      return '我幫你查了一下，${_selectedDate.month}/${_selectedDate.day} 共有 $count 個行程喔！';
    } else if (input.contains('你好') || input.contains('哈囉')) {
      return '你好！很高興認識你 😊 有什麼行程需要我幫你整理嗎？';
    } else if (input.contains('謝謝') || input.contains('感謝')) {
      return '不客氣！隨時都可以找我喔 ☕';
    } else if (input.contains('新增') || input.contains('加入')) {
      return '你可以點右上角的 ＋ 按鈕來新增行程喔！';
    }
    return '我理解了！目前為 MVP 展示模式，AI 功能將在後續版本擴充，敬請期待 ✨';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        title: Text(
          '${_calendarMonth.year}年 ${_calendarMonth.month}月  ·  ${widget.userName}',
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8D6E63)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF8D6E63)),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 上半部 60% — 月曆 + 行程
            Expanded(
              flex: 62,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 動態高度月曆
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height: _getCalendarHeight(),
                      child: PageView.builder(
                        controller: _calendarPageController,
                        onPageChanged: (i) => setState(() => _calendarMonth =
                            DateTime(_calOriginYear,
                                _calOriginMonth + (i - _calBase), 1)),
                        itemBuilder: (context, i) => _buildMonthGrid(DateTime(
                            _calOriginYear,
                            _calOriginMonth + (i - _calBase),
                            1)),
                      ),
                    ),
                    // 行程明細標頭（含新增按鈕）
                    _buildTimelineHeader(),
                    // 行程 PageView
                    SizedBox(
                      height: 340,
                      child: PageView.builder(
                        controller: _timelinePageController,
                        onPageChanged: (i) {
                          if (_isAnimating) return;
                          final newDate =
                              _tlOrigin.add(Duration(days: i - _tlBase));
                          final isSameDay =
                              newDate.year == _selectedDate.year &&
                                  newDate.month == _selectedDate.month &&
                                  newDate.day == _selectedDate.day;
                          if (!isSameDay) _syncDate(newDate);
                        },
                        itemBuilder: (context, i) => _buildDayEvents(
                            _tlOrigin.add(Duration(days: i - _tlBase))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            // 下半部 40% — AI 助理對話區
            Expanded(
              flex: 38,
              child: _buildChatSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 8, 10, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_selectedDate.month}/${_selectedDate.day} 行程明細',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF8D6E63)),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle,
                color: Color(0xFF8D6E63), size: 28),
            onPressed: _showAddDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(DateTime date) {
    final empty = DateTime(date.year, date.month, 1).weekday - 1;
    final days = DateTime(date.year, date.month + 1, 0).day;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Row(
            children: ['一', '二', '三', '四', '五', '六', '日']
                .map((d) => Expanded(
                      child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold))),
                    ))
                .toList(),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: empty + days,
          itemBuilder: (context, i) {
            if (i < empty) return const SizedBox();
            final d = i - empty + 1;
            final thisDay = DateTime(date.year, date.month, d);
            final isSel = _selectedDate.year == thisDay.year &&
                _selectedDate.month == thisDay.month &&
                _selectedDate.day == thisDay.day;
            final hasEvents =
                (allSchedules[_dateKey(thisDay)] ?? []).isNotEmpty;
            return GestureDetector(
              onTap: () => _syncDate(thisDay, fromCalendar: true),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isSel ? const Color(0xFF8D6E63) : Colors.transparent,
                  border: Border.all(color: Colors.grey.shade100),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4)
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text('$d',
                        style: TextStyle(
                            fontSize: 12,
                            color: isSel ? Colors.white : Colors.black87)),
                    if (hasEvents && !isSel)
                      Positioned(
                        bottom: 3,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFD7CCC8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDayEvents(DateTime date) {
    final key = _dateKey(date);
    final events = List<Map<String, dynamic>>.from(allSchedules[key] ?? []);

    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Center(
            child: Text('本日尚無行程',
                style: TextStyle(color: Colors.grey, fontSize: 13))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      physics: const BouncingScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, i) {
        final ev = events[i];
        return Dismissible(
          key: ValueKey('${key}_${ev['time']}_${ev['title']}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.redAccent.shade100,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          onDismissed: (_) => _deleteSchedule(key, i),
          child: GestureDetector(
            onTap: () => _showEditDialog(
                key, i, ev['time'] as String, ev['title'] as String,
                ev['color'] as int),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: Color(ev['color'] as int),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(ev['time'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Expanded(
                      child: Text(ev['title'] as String,
                          style: const TextStyle(fontSize: 13))),
                  const Icon(Icons.chevron_right,
                      color: Colors.black26, size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatSection() {
    return Container(
      color: const Color(0xFFFAFAFA),
      child: Column(
        children: [
          // 對話氣泡列表
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                final isAI = msg['role'] == 'ai';
                return Align(
                  alignment:
                      isAI ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    decoration: BoxDecoration(
                      color: isAI
                          ? Colors.white
                          : const Color(0xFFD7CCC8),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(14),
                        topRight: const Radius.circular(14),
                        bottomLeft: Radius.circular(isAI ? 0 : 14),
                        bottomRight: Radius.circular(isAI ? 14 : 0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(msg['text']!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isAI
                              ? Colors.black87
                              : const Color(0xFF4E342E),
                        )),
                  ),
                );
              },
            ),
          ),
          // 輸入框
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: '詢問 AI 助理...',
                      hintStyle: const TextStyle(
                          color: Colors.grey, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF8D6E63),
                    ),
                    child: const Icon(Icons.send,
                        color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 新增行程對話框（含顏色選擇器）
  void _showAddDialog() {
    String title = '';
    String timeRange = '';
    int selectedColor = 0xFFFFCC80;
    const colorOptions = [
      {'color': 0xFFCFD8DC, 'label': '灰藍'},
      {'color': 0xFFFFE082, 'label': '鵝黃'},
      {'color': 0xFFB2EBF2, 'label': '淺藍'},
      {'color': 0xFFFFCC80, 'label': '淺橘'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('新增行程',
              style:
                  TextStyle(fontSize: 16, color: Color(0xFF8D6E63))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (v) => title = v,
                decoration: InputDecoration(
                  labelText: '活動名稱',
                  labelStyle:
                      const TextStyle(color: Color(0xFF8D6E63)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => timeRange = v,
                decoration: InputDecoration(
                  labelText: '時間區間',
                  hintText: '09:00~10:00',
                  labelStyle:
                      const TextStyle(color: Color(0xFF8D6E63)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: colorOptions.map((opt) {
                  final isSelected =
                      selectedColor == (opt['color'] as int);
                  return GestureDetector(
                    onTap: () => setDialogState(
                        () => selectedColor = opt['color'] as int),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(opt['color'] as int),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF8D6E63)
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('取消', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8D6E63),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (title.isNotEmpty && timeRange.isNotEmpty) {
                  _addSchedule(timeRange, title, selectedColor);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('加入',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // 編輯行程對話框
  void _showEditDialog(
      String key, int index, String currentTime, String currentTitle,
      int currentColor) {
    String title = currentTitle;
    String timeRange = currentTime;
    final titleCtrl = TextEditingController(text: currentTitle);
    final timeCtrl = TextEditingController(text: currentTime);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('編輯行程',
            style: TextStyle(fontSize: 16, color: Color(0xFF8D6E63))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              onChanged: (v) => title = v,
              decoration: InputDecoration(
                labelText: '活動名稱',
                labelStyle:
                    const TextStyle(color: Color(0xFF8D6E63)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: timeCtrl,
              onChanged: (v) => timeRange = v,
              decoration: InputDecoration(
                labelText: '時間區間',
                hintText: '09:00~10:00',
                labelStyle:
                    const TextStyle(color: Color(0xFF8D6E63)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('取消', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8D6E63),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (title.isNotEmpty && timeRange.isNotEmpty) {
                _updateSchedule(key, index, timeRange, title);
                Navigator.pop(ctx);
              }
            },
            child: const Text('儲存',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((_) {
      titleCtrl.dispose();
      timeCtrl.dispose();
    });
  }
}