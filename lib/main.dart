import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD7CCC8), surface: const Color(0xFFFAFAFA)),
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
  Widget build(BuildContext context) => _currentUser == null ? LoginScreen(onLogin: _login) : MainScreen(userName: _currentUser!, onLogout: _logout);
}

class LoginScreen extends StatelessWidget {
  final Function(String) onLogin;
  const LoginScreen({super.key, required this.onLogin});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 60, color: Color(0xFFD7CCC8)),
            const SizedBox(height: 20),
            const Text('歡迎回來', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 40),
            _btn('登入 Sharon', const Color(0xFFE8EAF6), () => onLogin('Sharon')),
            const SizedBox(height: 20),
            _btn('登入 訪客', const Color(0xFFF1F8E9), () => onLogin('訪客')),
          ],
        ),
      ),
    );
  }
  Widget _btn(String t, Color c, VoidCallback f) => ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: c, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)), onPressed: f, child: Text(t, style: const TextStyle(color: Colors.black87)));
}

// --- 2. 主架構 ---
class MainScreen extends StatefulWidget {
  final String userName;
  final VoidCallback onLogout;
  const MainScreen({super.key, required this.userName, required this.onLogout});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // 預設進題庫
  String _appBarTitle = "題庫";

  // --- 資料庫區 ---
  DateTime _simulatedToday = DateTime(2026, 3, 30); 
  DateTime _selectedDate = DateTime(2026, 3, 30);
  DateTime _calendarMonth = DateTime(2026, 3, 1);
  late PageController _calendarPageController;
  late PageController _timelinePageController;

  Map<String, List<Map<String, dynamic>>> allSchedules = {
    '2026-03-30': [{'time': '09:10~12:00', 'title': '專題討論會議', 'color': 0xFFFFE082}],
  };
  List<Map<String, dynamic>> allTodos = [
    {'id': '1', 'title': '確認 AutoCAD 圓角圖層', 'isDone': false, 'doneDate': null},
  ];
  List<Map<String, dynamic>> socialPosts = [
    {'id': 1, 'author': 'Sharon', 'time': '10分鐘前', 'content': '準備來寫 Flutter 專題啦🚀', 'likes': 12, 'replies': 3, 'isLiked': true},
  ];

  List<String> allSubjects = ['資訊管理', '作業系統', '國文', '數學', '微積分'];
  Map<String, List<String>> subjectChapters = {
    '資訊管理': ['第一章 資訊系統簡介', '第二章 資料庫管理'],
    '國文': ['師說', '出師表'],
    '數學': ['面積', '機率'],
  };

  List<Map<String, dynamic>> questionBank = [
    {'id': 'q1', 'subject': '資訊管理', 'chapter': '第二章 資料庫管理', 'difficulty': '中', 'type': '單選題', 'question': '下列何者不是關聯式資料庫的特性？', 'options': ['支援 SQL 語法', '具備 ACID 特性', '採用樹狀結構存放', '資料以二維表格呈現'], 'answerIndex': 2, 'explanation': '樹狀結構屬於階層式資料庫，而非關聯式。', 'isFavorite': true, 'author': '陳教授', 'replies': 2, 'isWrong': true},
    {'id': 'q2', 'subject': '國文', 'chapter': '師說', 'difficulty': '易', 'type': '單選題', 'question': '《師說》的作者是誰？', 'options': ['柳宗元', '韓愈', '歐陽脩', '蘇軾'], 'answerIndex': 1, 'explanation': '韓愈倡導古文運動，作《師說》。', 'isFavorite': false, 'author': 'Sharon', 'replies': 0, 'isWrong': false},
    {'id': 'q3', 'subject': '數學', 'chapter': '面積', 'difficulty': '易', 'type': '單選題', 'question': '長方形長5寬4，面積為何？', 'options': ['18', '20', '25', '9'], 'answerIndex': 1, 'explanation': '5x4=20', 'isFavorite': false, 'author': '系統', 'replies': 0, 'isWrong': true},
  ];

  // --- 狀態控制區 ---
  int _quizStep = 0; 
  String _quizSelectedSubject = "";
  List<String> _quizSelectedChapters = [];
  Map<String, Map<String, int>> _quizPickedCounts = { '單選題': {'易': 0, '中': 0, '難': 0}, '是非題': {'易': 0, '中': 0, '難': 0}, '申論題': {'易': 0, '中': 0, '難': 0} };
  Map<String, Map<String, int>> _availableCounts = {};
  List<Map<String, dynamic>> _currentQuizQuestions = [];
  Map<int, int> _userAnswers = {}; 
  Timer? _quizTimer;
  int _remainingSeconds = 1800;
  final ScrollController _quizScrollController = ScrollController();

  bool _showStudyAnswers = false;
  String _studySearchQuery = "";
  String _studySubject = "全部";
  int _personalFilterIndex = 0; 
  String? _selectedFolder; 

  List<Map<String, dynamic>> chatLogs = [{'isAI': true, 'text': 'Sharon，全系統功能已回歸！測驗精靈與資料夾管理都已就緒。✨', 'isCard': false}];

  @override
  void initState() {
    super.initState();
    _calendarPageController = PageController(initialPage: 12);
    _timelinePageController = PageController(initialPage: 1000);
  }

  @override
  void dispose() { _quizTimer?.cancel(); _quizScrollController.dispose(); super.dispose(); }

  // ==========================================
  // 【重要修復】: 將漏掉的日曆與核心切換方法補回
  // ==========================================
  void _changePage(int index, String title) { setState(() { _currentIndex = index; _appBarTitle = title; _resetQuiz(); _selectedFolder = null; }); }
  
  void _resetQuiz() { setState(() { _quizStep = 0; _quizSelectedSubject = ""; _quizSelectedChapters.clear(); _quizTimer?.cancel(); _userAnswers.clear(); }); }

  // 補回：日曆點擊日期時的同步跳轉
  void _syncDate(DateTime date, {bool fromCalendar = false}) {
    setState(() => _selectedDate = date); 
    if (fromCalendar) {
      _timelinePageController.jumpToPage(1000 + date.difference(_simulatedToday).inDays);
    }
  }

  // 補回：手動新增行程
  void _addSchedule(String timeRange, String title, int color) { 
    setState(() { 
      String key = _selectedDate.toString().split(' ')[0]; 
      (allSchedules[key] ??= []).add({'time': timeRange, 'title': title, 'color': color}); 
      allSchedules[key]!.sort((a, b) => a['time'].toString().compareTo(b['time'].toString())); 
    }); 
  }

  // 補回：手動新增待辦事項
  void _addTodo(String title) { 
    setState(() => allTodos.add({'id': DateTime.now().millisecondsSinceEpoch.toString(), 'title': title, 'isDone': false, 'doneDate': null})); 
  }

  // --- 測驗精靈邏輯 ---
  void _calculateAvailableQuestions() {
    _availableCounts = { '單選題': {'易': 0, '中': 0, '難': 0}, '是非題': {'易': 0, '中': 0, '難': 0}, '申論題': {'易': 0, '中': 0, '難': 0} };
    _quizPickedCounts = { '單選題': {'易': 0, '中': 0, '難': 0}, '是非題': {'易': 0, '中': 0, '難': 0}, '申論題': {'易': 0, '中': 0, '難': 0} };
    for (var q in questionBank) {
      if (q['subject'] != _quizSelectedSubject) continue;
      if (_quizSelectedChapters.isNotEmpty && !_quizSelectedChapters.contains(q['chapter'])) continue;
      if (_availableCounts.containsKey(q['type']) && _availableCounts[q['type']]!.containsKey(q['difficulty'])) {
        _availableCounts[q['type']]![q['difficulty']] = _availableCounts[q['type']]![q['difficulty']]! + 1;
      }
    }
  }

  void _generateQuizPaper() {
    _currentQuizQuestions.clear();
    List<Map<String, dynamic>> scopeQs = questionBank.where((q) => q['subject'] == _quizSelectedSubject && (_quizSelectedChapters.isEmpty || _quizSelectedChapters.contains(q['chapter']))).toList();
    _quizPickedCounts.forEach((type, diffs) {
      diffs.forEach((diff, count) {
        if (count > 0) {
          var matched = scopeQs.where((q) => q['type'] == type && q['difficulty'] == diff).toList();
          matched.shuffle(); _currentQuizQuestions.addAll(matched.take(count));
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
      appBar: _quizStep == 2 ? null : AppBar(title: Text(_currentIndex == 0 ? "${_calendarMonth.year}年 ${_calendarMonth.month}月" : _appBarTitle, style: const TextStyle(fontSize: 16)), backgroundColor: Colors.white, elevation: 0, actions: [IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout)]),
      drawer: Drawer(child: SafeArea(child: ListView(children: [
        const Padding(padding: EdgeInsets.all(20.0), child: Text('系統選單', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8D6E63)))),
        ListTile(leading: const Icon(Icons.calendar_month), title: const Text('日曆行程'), onTap: () { _changePage(0, '日曆行程'); Navigator.pop(context); }),
        ListTile(leading: const Icon(Icons.menu_book), title: const Text('題庫'), onTap: () { _changePage(1, '題庫'); Navigator.pop(context); }), 
        ListTile(leading: const Icon(Icons.forum), title: const Text('社群'), onTap: () { _changePage(2, '社群'); Navigator.pop(context); }), 
        ListTile(leading: const Icon(Icons.account_circle), title: const Text('社群檔案'), onTap: () { _changePage(3, '社群檔案'); Navigator.pop(context); }),
      ]))),
      body: SafeArea(
        child: Column(children: [
          Expanded(child: IndexedStack(index: _currentIndex, children: [_buildCalendarTab(), _buildQuestionBankTab(), _buildSocialTab(), _buildProfileTab()])),
          if (_currentIndex != 1 || _quizStep == 0) _buildAIChatBar(),
        ]),
      ),
    );
  }

  // --- AI 助理全螢幕面板 ---
  void _openChatModal() {
    TextEditingController modalController = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9, 
              decoration: const BoxDecoration(color: Color(0xFFFAFAFA), borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
              child: SafeArea(
                child: Column(
                  children: [
                    Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                    const Text('AI 代理人助理', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8D6E63), fontSize: 16)),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16), itemCount: chatLogs.length,
                        itemBuilder: (context, i) {
                          var msg = chatLogs[i];
                          if (msg['isCard'] == true) return _buildConfirmationCard(msg['pendingData'], setModalState);
                          return Align(
                            alignment: msg['isAI'] ? Alignment.centerLeft : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(color: msg['isAI'] ? Colors.white : const Color(0xFFD7CCC8), borderRadius: BorderRadius.circular(18), boxShadow: msg['isAI'] ? [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)] : []),
                              child: Text(msg['text'], style: const TextStyle(fontSize: 14)),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 20),
                      child: Row(
                        children: [
                          Expanded(child: TextField(
                            controller: modalController,
                            decoration: InputDecoration(hintText: '去題庫 / 看日曆 / 加行程...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20)),
                            onSubmitted: (v) => _handleAISubmit(v, modalController, setModalState),
                          )),
                          const SizedBox(width: 8),
                          CircleAvatar(backgroundColor: const Color(0xFF8D6E63), child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: () => _handleAISubmit(modalController.text, modalController, setModalState))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  void _handleAISubmit(String input, TextEditingController controller, StateSetter setModalState) {
    if (input.trim().isEmpty) return;
    String text = input.trim();
    controller.clear();
    if (text.contains('日曆') || text.contains('行程')) { Navigator.pop(context); _changePage(0, '日曆行程'); setState(() => chatLogs.add({'isAI': true, 'text': '沒問題，已為您跳轉至日曆！', 'isCard': false})); } 
    else if (text.contains('題庫') || text.contains('測驗')) { Navigator.pop(context); _changePage(1, '題庫'); setState(() => chatLogs.add({'isAI': true, 'text': '切換至題庫系統！', 'isCard': false})); } 
    else if (text.contains('社群')) { Navigator.pop(context); _changePage(2, '社群'); setState(() => chatLogs.add({'isAI': true, 'text': '好的，帶您去社群！', 'isCard': false})); } 
    else if (text.contains('檔案')) { Navigator.pop(context); _changePage(3, '社群檔案'); setState(() => chatLogs.add({'isAI': true, 'text': '已打開社群檔案！', 'isCard': false})); } 
    else { setModalState(() { chatLogs.add({'isAI': false, 'text': text}); chatLogs.add({'isAI': true, 'text': '收到！請問確認要將此項目真正加入系統嗎？', 'isCard': true, 'pendingData': {'title': text, 'time': '14:00~15:00', 'color': 0xFFFFCC80}}); }); }
  }

  Widget _buildConfirmationCard(Map<String, dynamic> data, StateSetter setModalState) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF8D6E63), width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [Icon(Icons.report_problem_outlined, color: Colors.amber), SizedBox(width: 8), Text('User 確認操作', style: TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 12), Text('📌 項目：${data['title']}', style: const TextStyle(fontSize: 15)), Text('⏰ 時間：${data['time']}', style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => setModalState(() => chatLogs.add({'isAI': true, 'text': '好的，已取消。', 'isCard': false})), child: const Text('取消', style: TextStyle(color: Colors.redAccent))),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8D6E63), foregroundColor: Colors.white), onPressed: () { _addSchedule(data['time'], data['title'], data['color']); setModalState(() => chatLogs.add({'isAI': true, 'text': '✅ 已加入行程！', 'isCard': false})); }, child: const Text('確認加入'))
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAIChatBar() => GestureDetector(onTap: _openChatModal, child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]), child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(30)), child: const Row(children: [Icon(Icons.auto_awesome, color: Color(0xFF8D6E63), size: 20), SizedBox(width: 10), Text('去社群 / 加行程...', style: TextStyle(color: Colors.grey, fontSize: 14))]))));

  // --- 1. 日曆行程 (含待辦) ---
  Widget _buildCalendarTab() => SingleChildScrollView(child: Column(children: [
    SizedBox(height: 330, child: PageView.builder(controller: _calendarPageController, onPageChanged: (i) => setState(() => _calendarMonth = DateTime(2026, 3 + (i - 12), 1)), itemBuilder: (ctx, i) => _buildMonthGrid(DateTime(2026, 3 + (i - 12), 1)))),
    Padding(padding: const EdgeInsets.fromLTRB(25, 0, 15, 0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("${_selectedDate.month}/${_selectedDate.day} 行程", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8D6E63))), IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFFD7CCC8), size: 30), onPressed: _showManualAddDialog)])),
    SizedBox(height: 450, child: PageView.builder(controller: _timelinePageController, onPageChanged: (i) { DateTime newDate = _simulatedToday.add(Duration(days: i - 1000)); if (newDate.day != _selectedDate.day) _syncDate(newDate); }, itemBuilder: (ctx, i) => _buildUnifiedDayEvents(_simulatedToday.add(Duration(days: i - 1000))))),
  ]));

  Widget _buildMonthGrid(DateTime date) {
    int empty = DateTime(date.year, date.month, 1).weekday - 1; int days = DateTime(date.year, date.month + 1, 0).day;
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Row(children: ['一','二','三','四','五','六','日'].map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))))).toList())),
      GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 20), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8), itemCount: empty + days, itemBuilder: (ctx, i) {
        if (i < empty) return const SizedBox(); int d = i - empty + 1; bool isSel = _selectedDate.day == d && _selectedDate.month == date.month && _selectedDate.year == date.year;
        return GestureDetector(onTap: () => _syncDate(DateTime(date.year, date.month, d), fromCalendar: true), child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: isSel ? const Color(0xFF8D6E63) : Colors.transparent, border: Border.all(color: Colors.grey.shade100)), child: Center(child: Text('$d', style: TextStyle(fontSize: 14, color: isSel ? Colors.white : Colors.black87)))));
      })
    ]);
  }

  Widget _buildUnifiedDayEvents(DateTime targetDate) {
    String dateKey = targetDate.toString().split(' ')[0]; String simTodayKey = _simulatedToday.toString().split(' ')[0]; bool isPast = targetDate.isBefore(_simulatedToday);
    List<Map<String, dynamic>> schedules = allSchedules[dateKey] ?? [];
    List<Map<String, dynamic>> displayTodos = allTodos.where((todo) { if (todo['isDone']) return todo['doneDate'] == dateKey; return !isPast; }).toList();
    if (schedules.isEmpty && displayTodos.isEmpty) return const Padding(padding: EdgeInsets.only(top: 20), child: Center(child: Text('本日尚無行程與待辦', style: TextStyle(color: Colors.grey))));
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 25), physics: const NeverScrollableScrollPhysics(), children: [
      ...displayTodos.map((item) => GestureDetector(onTap: () { if (isPast) return; setState(() { item['isDone'] = !item['isDone']; item['doneDate'] = item['isDone'] ? simTodayKey : null; }); }, child: Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)), child: Row(children: [Icon(item['isDone'] ? Icons.check_circle : Icons.radio_button_unchecked, color: item['isDone'] ? const Color(0xFF8D6E63) : Colors.grey, size: 20), const SizedBox(width: 15), Expanded(child: Text(item['title'], style: TextStyle(decoration: item['isDone'] ? TextDecoration.lineThrough : null, color: item['isDone'] ? Colors.grey : Colors.black87))), if (isPast) const Icon(Icons.lock, size: 14, color: Colors.grey)])))),
      ...schedules.map((event) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Color(event['color']), borderRadius: BorderRadius.circular(15)), child: Row(children: [SizedBox(width: 95, child: Text(event['time'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))), Expanded(child: Text(event['title']))]))),
    ]);
  }

  // --- 2. 題庫系統 (測驗/題庫/個人) ---
  Widget _buildQuestionBankTab() {
    if (_quizStep >= 2) return _buildQuizTakingOrResult();
    return DefaultTabController(length: 3, child: Column(children: [
      const TabBar(indicatorColor: Color(0xFF8D6E63), labelColor: Color(0xFF8D6E63), unselectedLabelColor: Colors.grey, tabs: [Tab(text: '測驗'), Tab(text: '題庫'), Tab(text: '個人題庫')]),
      Expanded(child: TabBarView(physics: const NeverScrollableScrollPhysics(), children: [_buildQuizWizard(), _buildStudyMode(), _buildPersonalMode()]))
    ]));
  }

  // 測驗精靈 (Step 0 & 1)
  Widget _buildQuizWizard() => Column(children: [
    Container(color: const Color(0xFFFAFAFA), padding: const EdgeInsets.symmetric(vertical: 15), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _quizStepNode(0, '1.範圍'), _quizStepLine(), _quizStepNode(1, '2.挑題'), _quizStepLine(), _quizStepNode(2, '3.測驗'),
    ])),
    Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _quizStep == 0 ? _buildQuizStep0() : _buildQuizStep1())),
    _buildQuizFooter(),
  ]);

  Widget _quizStepNode(int s, String t) => Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: _quizStep >= s ? const Color(0xFF8D6E63) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _quizStep >= s ? const Color(0xFF8D6E63) : Colors.grey.shade300)), child: Text(t, style: TextStyle(color: _quizStep >= s ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)));
  Widget _quizStepLine() => Container(width: 25, height: 2, color: Colors.grey.shade300);

  Widget _buildQuizStep0() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('選擇出題範圍', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF8D6E63))),
      const SizedBox(height: 15),
      Autocomplete<String>(optionsBuilder: (v) => v.text.isEmpty ? allSubjects : allSubjects.where((s) => s.contains(v.text)), onSelected: (s) => setState(() { _quizSelectedSubject = s; _quizSelectedChapters.clear(); }), fieldViewBuilder: (ctx, ctrl, focus, onSub) { if (_quizSelectedSubject.isNotEmpty && ctrl.text.isEmpty) ctrl.text = _quizSelectedSubject; return TextField(controller: ctrl, focusNode: focus, decoration: InputDecoration(hintText: '搜尋科目...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: const Color(0xFFF5F5F5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))); }),
    ])),
    if (_quizSelectedSubject.isNotEmpty) ...[
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('範圍篩選 (章節)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF8D6E63))),
        const SizedBox(height: 10),
        ...(subjectChapters[_quizSelectedSubject] ?? []).map((chap) => CheckboxListTile(title: Text(chap), value: _quizSelectedChapters.contains(chap), activeColor: const Color(0xFF8D6E63), controlAffinity: ListTileControlAffinity.leading, dense: true, onChanged: (v) => setState(() { v! ? _quizSelectedChapters.add(chap) : _quizSelectedChapters.remove(chap); }))),
      ]))
    ]
  ]);

  Widget _buildQuizStep1() {
    List<Widget> typeCards = [];
    _availableCounts.forEach((type, diffs) {
      if (diffs.values.any((c) => c > 0)) {
        typeCards.add(Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade100)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: ['易', '中', '難'].map((lv) => _buildPickCounter(lv, type, _availableCounts[type]![lv]!)).toList()),
        ])));
      }
    });
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('已選範圍：$_quizSelectedSubject', style: const TextStyle(color: Colors.grey, fontSize: 13)), const SizedBox(height: 10), if(typeCards.isEmpty) const Text('此範圍無題目可挑選', style: TextStyle(color: Colors.grey)), ...typeCards]);
  }

  Widget _buildPickCounter(String diff, String type, int avail) => Column(children: [
    Text(diff, style: TextStyle(fontSize: 12, color: avail > 0 ? Colors.black54 : Colors.grey.shade300)),
    const SizedBox(height: 5),
    Row(children: [
      GestureDetector(onTap: () => setState(() { if (_quizPickedCounts[type]![diff]! > 0) _quizPickedCounts[type]![diff] = _quizPickedCounts[type]![diff]! - 1; }), child: Icon(Icons.remove_circle_outline, color: avail > 0 ? Colors.grey : Colors.grey.shade200)),
      const SizedBox(width: 8), Text('${_quizPickedCounts[type]![diff]} / $avail', style: TextStyle(fontSize: 13, color: avail > 0 ? Colors.black : Colors.grey.shade300)),
      const SizedBox(width: 8), GestureDetector(onTap: () => setState(() { if (_quizPickedCounts[type]![diff]! < avail) _quizPickedCounts[type]![diff] = _quizPickedCounts[type]![diff]! + 1; }), child: Icon(Icons.add_circle_outline, color: avail > 0 ? const Color(0xFF8D6E63) : Colors.grey.shade200)),
    ])
  ]);

  Widget _buildQuizFooter() => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    _quizStep == 0 ? const SizedBox(width: 80) : OutlinedButton(onPressed: () => setState(() => _quizStep = 0), child: const Text('上一步')),
    ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8D6E63), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30)), onPressed: () {
      if (_quizStep == 0 && _quizSelectedSubject.isNotEmpty) { _calculateAvailableQuestions(); setState(() => _quizStep = 1); }
      else if (_quizStep == 1) { _generateQuizPaper(); setState(() { _userAnswers.clear(); for(int i=0; i<_currentQuizQuestions.length; i++) _userAnswers[i] = -1; _remainingSeconds = 1800; _quizStep = 2; }); _startTimer(); }
    }, child: Text(_quizStep == 0 ? '下一步' : '開始測驗')),
  ]));

  void _startTimer() { _quizTimer = Timer.periodic(const Duration(seconds: 1), (t) { if (_remainingSeconds > 0) setState(() => _remainingSeconds--); else { t.cancel(); setState(() => _quizStep = 3); } }); }

  Widget _buildQuizTakingOrResult() {
    if (_quizStep == 3) return _buildQuizResult();
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(title: Text('剩餘 ${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.redAccent, fontSize: 16)), automaticallyImplyLeading: false, actions: [TextButton(onPressed: () { _quizTimer?.cancel(); setState(() => _quizStep = 3); }, child: const Text('交卷', style: TextStyle(color: Color(0xFF8D6E63), fontWeight: FontWeight.bold)))]),
      body: Column(children: [
        Expanded(child: ListView.builder(controller: _quizScrollController, padding: const EdgeInsets.all(20), itemCount: _currentQuizQuestions.length, itemBuilder: (ctx, i) {
          var q = _currentQuizQuestions[i];
          return Container(margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Q${i+1}. ${q['question']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            ...List.generate(q['options'].length, (idx) => RadioListTile(title: Text(q['options'][idx]), value: idx, groupValue: _userAnswers[i], onChanged: (v) => setState(() => _userAnswers[i] = v as int), activeColor: const Color(0xFF8D6E63), contentPadding: EdgeInsets.zero, dense: true))
          ]));
        })),
        Container(height: 60, color: Colors.white, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), itemCount: _currentQuizQuestions.length, itemBuilder: (ctx, i) => GestureDetector(onTap: () => _quizScrollController.animateTo(i * 300.0, duration: const Duration(milliseconds: 300), curve: Curves.linear), child: Container(width: 40, margin: const EdgeInsets.all(10), decoration: BoxDecoration(color: _userAnswers[i] == -1 ? Colors.grey.shade100 : const Color(0xFF8D6E63), borderRadius: BorderRadius.circular(8)), child: Center(child: Text('${i+1}', style: TextStyle(color: _userAnswers[i] == -1 ? Colors.black : Colors.white, fontWeight: FontWeight.bold))))))),
      ]),
    );
  }

  Widget _buildQuizResult() {
    int correctCount = 0;
    for (int i = 0; i < _currentQuizQuestions.length; i++) { if (_currentQuizQuestions[i]['type'] != '申論題' && _userAnswers[i] == _currentQuizQuestions[i]['answerIndex']) correctCount++; }
    int score = _currentQuizQuestions.isEmpty ? 0 : ((correctCount / _currentQuizQuestions.length) * 100).round();
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Center(child: Text('測驗完成', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      Center(child: Text('得分：$score', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF8D6E63)))),
      const SizedBox(height: 20), ElevatedButton(onPressed: _resetQuiz, child: const Text('回測驗首頁')),
      const Divider(height: 40),
      const Text('詳解區', style: TextStyle(fontWeight: FontWeight.bold)),
      ...List.generate(_currentQuizQuestions.length, (i) {
        var q = _currentQuizQuestions[i];
        return Container(margin: const EdgeInsets.only(bottom: 15, top: 10), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${i+1}. ${q['question']}'), const SizedBox(height: 8),
          Text('正確答案：${q['options'].isNotEmpty ? q['options'][q['answerIndex']] : "無"}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          const Divider(), Text('【解析】${q['explanation']}', style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
        ]));
      }),
    ]);
  }

  // 刷題模式
  Widget _buildStudyMode() {
    List<Map<String, dynamic>> filtered = questionBank.where((q) => q['question'].contains(_studySearchQuery) && (_studySubject == '全部' || q['subject'] == _studySubject)).toList();
    return Column(children: [
      Container(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(onChanged: (v) => setState(() => _studySearchQuery = v), decoration: InputDecoration(hintText: '搜尋題目...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: const Color(0xFFF5F5F5), border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none))),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['全部', '資訊管理', '國文', '數學'].map((s) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(s, style: const TextStyle(fontSize: 11)), selected: _studySubject == s, onSelected: (v) => setState(() => _studySubject = s)))).toList()))),
          Row(children: [const Text('答案', style: TextStyle(fontSize: 12)), Switch(value: _showStudyAnswers, activeColor: const Color(0xFF8D6E63), onChanged: (v) => setState(() => _showStudyAnswers = v))]),
        ])
      ])),
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: filtered.length, itemBuilder: (ctx, i) {
        var q = filtered[i];
        return Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFE8EAF6), borderRadius: BorderRadius.circular(5)), child: Text(q['subject'], style: const TextStyle(fontSize: 11))), const Spacer(), Text('出題：${q['author']}', style: const TextStyle(fontSize: 11, color: Colors.grey))]),
          const SizedBox(height: 10), Text(q['question'], style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 10),
          if (_showStudyAnswers) Text(' Ans: ${q['options'].isNotEmpty ? q['options'][q['answerIndex']] : "無"}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            TextButton.icon(icon: Icon(q['isFavorite'] ? Icons.favorite : Icons.favorite_border, size: 18, color: Colors.redAccent), label: Text('收藏', style: TextStyle(color: q['isFavorite'] ? Colors.redAccent : Colors.grey)), onPressed: () => setState(() => q['isFavorite'] = !q['isFavorite'])),
            TextButton.icon(icon: const Icon(Icons.forum_outlined, size: 18, color: Colors.grey), label: const Text('討論', style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuestionDiscussionPage(questionData: q)))),
          ])
        ]));
      }))
    ]);
  }

  // 個人題庫 (資料夾)
  Widget _buildPersonalMode() {
    if (_selectedFolder != null) {
      List<Map<String, dynamic>> folderQuestions = questionBank.where((q) {
        if (_personalFilterIndex == 0) return q['isWrong'] == true && q['subject'] == _selectedFolder;
        if (_personalFilterIndex == 1) return (q['author'] == widget.userName || q['author'] == 'Sharon') && q['subject'] == _selectedFolder;
        if (_personalFilterIndex == 2) return q['isFavorite'] == true && q['subject'] == _selectedFolder;
        return false;
      }).toList();
      return Column(children: [
        AppBar(title: Text(_selectedFolder!), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedFolder = null))),
        Expanded(child: folderQuestions.isEmpty ? const Center(child: Text('資料夾空空的')) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: folderQuestions.length, itemBuilder: (ctx, i) {
          var q = folderQuestions[i];
          return Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q['question'], style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 10),
            if (q['type'] != '申論題') ...List.generate(q['options'].length, (idx) => Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)), child: Text(q['options'][idx]))),
          ]));
        }))
      ]);
    }
    
    Map<String, int> folderCounts = {};
    for (var q in questionBank) {
      bool match = false;
      if (_personalFilterIndex == 0 && q['isWrong'] == true) match = true;
      if (_personalFilterIndex == 1 && (q['author'] == widget.userName || q['author'] == 'Sharon')) match = true;
      if (_personalFilterIndex == 2 && q['isFavorite'] == true) match = true;
      if (match) folderCounts[q['subject']] = (folderCounts[q['subject']] ?? 0) + 1;
    }

    return Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_pChip('錯題', 0, Icons.close), _pChip('新增', 1, Icons.add), _pChip('收藏', 2, Icons.favorite_border)])),
      if (_personalFilterIndex == 1) Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8D6E63), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)), icon: const Icon(Icons.add), label: const Text('新增題目'), onPressed: _showAddQuestionDialog)),
      Expanded(child: folderCounts.isEmpty ? const Center(child: Text('目前沒有資料喔', style: TextStyle(color: Colors.grey))) : ListView(padding: const EdgeInsets.all(16), children: folderCounts.entries.map((entry) => GestureDetector(onTap: () => setState(() => _selectedFolder = entry.key), child: Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]), child: Row(children: [const Icon(Icons.folder, color: Color(0xFFD7CCC8), size: 40), const SizedBox(width: 15), Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), Text('${entry.value} 題', style: const TextStyle(color: Colors.grey)), const Icon(Icons.chevron_right, color: Colors.grey)])))).toList()))
    ]);
  }
  Widget _pChip(String l, int i, IconData ic) => ChoiceChip(label: Row(children: [Icon(ic, size: 14), const SizedBox(width: 4), Text(l)]), selected: _personalFilterIndex == i, selectedColor: const Color(0xFFD7CCC8), onSelected: (v) => setState(() => _personalFilterIndex = i));

  void _showAddQuestionDialog() {
    String selectedSubject = '資訊管理'; String selectedType = '單選題';
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('新增題目'), content: StatefulBuilder(builder: (context, setDialogState) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('1. 科目'), DropdownButton<String>(isExpanded: true, value: selectedSubject, items: allSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setDialogState(() => selectedSubject = v!)),
        const SizedBox(height: 15), const Text('2. 題型'), Row(children: ['單選題', '是非題'].map((t) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(t), selected: selectedType == t, onSelected: (v) => setDialogState(() => selectedType = t)))).toList()),
        const SizedBox(height: 15), const TextField(decoration: InputDecoration(hintText: '請輸入題目...')),
      ]);
    }), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8D6E63), foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx), child: const Text('新增'))]));
  }

  // --- 手動新增行程 (含 Padding 修正) ---
  void _showManualAddDialog() {
    TextEditingController titleController = TextEditingController(); int _selectedType = 0; TimeOfDay pickedStartTime = const TimeOfDay(hour: 10, minute: 0); TimeOfDay pickedEndTime = const TimeOfDay(hour: 11, minute: 0); StateSetter? _dialogSetState;
    Future<void> _selectTime(bool isStart) async { final TimeOfDay? picked = await showTimePicker(context: context, initialTime: isStart ? pickedStartTime : pickedEndTime); if (picked != null) { _dialogSetState!(() { if (isStart) { pickedStartTime = picked; } else { pickedEndTime = picked; } }); } }
    String _formatTime(TimeOfDay time) { final h = time.hour.toString().padLeft(2, '0'); final m = time.minute.toString().padLeft(2, '0'); return '$h:$m'; }
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('手動新增項目'), content: StatefulBuilder(builder: (context, setDialogState) { _dialogSetState = setDialogState; return Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: titleController, decoration: const InputDecoration(labelText: '標題名稱')), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.center, children: [ChoiceChip(label: const Text('時間行程'), selected: _selectedType == 0, selectedColor: const Color(0xFFD7CCC8), onSelected: (v) => setDialogState(() => _selectedType = 0)), const SizedBox(width: 10), ChoiceChip(label: const Text('待辦事項'), selected: _selectedType == 1, selectedColor: const Color(0xFFD7CCC8), onSelected: (v) => setDialogState(() => _selectedType = 1))]), if (_selectedType == 0) ...[const SizedBox(height: 15), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [TextButton.icon(icon: const Icon(Icons.access_time, size: 16), label: Text(_formatTime(pickedStartTime)), onPressed: () => _selectTime(true)), const Text('~'), TextButton.icon(icon: const Icon(Icons.access_time, size: 16), label: Text(_formatTime(pickedEndTime)), onPressed: () => _selectTime(false))])]]); }), actions: [ElevatedButton(onPressed: (){ if (titleController.text.isEmpty) return; if (_selectedType == 0) { String range = "${_formatTime(pickedStartTime)}~${_formatTime(pickedEndTime)}"; _addSchedule(range, titleController.text, 0xFFFFCC80); } else { _addTodo(titleController.text); } Navigator.pop(ctx); }, child: const Text('確認加入'))]));
  }

  // --- 3. 社群 & 檔案 (Threads 風格) ---
  Widget _buildSocialTab() => ListView.builder(padding: const EdgeInsets.all(16), itemCount: socialPosts.length, itemBuilder: (ctx, i) => _buildPostItem(socialPosts[i]));
  Widget _buildProfileTab() => DefaultTabController(length: 2, child: Column(children: [
    Padding(padding: const EdgeInsets.all(25), child: Row(children: [const CircleAvatar(radius: 35, backgroundColor: Color(0xFFD7CCC8), child: Icon(Icons.person, color: Colors.white)), const SizedBox(width: 20), Text(widget.userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))])),
    const TabBar(indicatorColor: Color(0xFF8D6E63), labelColor: Color(0xFF8D6E63), tabs: [Tab(text: '發佈'), Tab(text: '收藏')]),
    Expanded(child: TabBarView(children: [ListView.builder(padding: const EdgeInsets.all(16), itemCount: 1, itemBuilder: (ctx, i) => _buildPostItem(socialPosts[0])), const Center(child: Text('尚無收藏'))]))
  ]));

  Widget _buildPostItem(Map<String, dynamic> p) => Container(margin: const EdgeInsets.only(bottom: 20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const CircleAvatar(backgroundColor: Color(0xFFD7CCC8), child: Icon(Icons.person, color: Colors.white, size: 18)),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text(p['author'], style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 10), Text(p['time'], style: const TextStyle(color: Colors.grey, fontSize: 12))]),
      const SizedBox(height: 5), Text(p['content']),
      Row(children: [IconButton(icon: Icon(p['isLiked'] ? Icons.favorite : Icons.favorite_border, size: 18, color: p['isLiked'] ? Colors.redAccent : Colors.grey), onPressed: (){}), IconButton(icon: const Icon(Icons.mode_comment_outlined, size: 18), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostReplyPage(originalPost: p))))])
    ]))
  ]));
}

// --- 3. 額外頁面 ---
class PostReplyPage extends StatelessWidget {
  final Map<String, dynamic> originalPost;
  const PostReplyPage({super.key, required this.originalPost});
  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> replies = [{'author': '李同學', 'time': '1小時前', 'content': '加油！推一個'}, {'author': '陳助教', 'time': '30分鐘前', 'content': '排序逻辑我发系上群組囉'}];
    return Scaffold(backgroundColor: Colors.white, appBar: AppBar(title: const Text('文章回覆', style: TextStyle(fontSize: 16))), body: SafeArea(child: Column(children: [Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const CircleAvatar(backgroundColor: Color(0xFFD7CCC8), child: Icon(Icons.person, color: Colors.white, size: 18)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(originalPost['author'], style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 10), Text(originalPost['time'], style: const TextStyle(color: Colors.grey, fontSize: 12))]), const SizedBox(height: 5), Text(originalPost['content'], style: const TextStyle(fontSize: 15)), const SizedBox(height: 12)]))]), const Divider(), const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('最新回覆', style: TextStyle(color: Colors.grey, fontSize: 13))), ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: replies.length, itemBuilder: (c, i) => Container(margin: const EdgeInsets.only(bottom: 15), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(radius: 15, backgroundColor: Colors.grey.shade200, child: Text(replies[i]['author'][0])), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(replies[i]['author'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(width: 8), Text(replies[i]['time'], style: const TextStyle(color: Colors.grey, fontSize: 11))]), Text(replies[i]['content'], style: const TextStyle(fontSize: 13))]))])))])), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade100))), child: Row(children: [const Expanded(child: TextField(decoration: InputDecoration(hintText: '回覆...', filled: true, fillColor: Color(0xFFF5F5F5), border: OutlineInputBorder(borderSide: BorderSide.none)))), const SizedBox(width: 8), TextButton(onPressed: (){}, child: const Text('發佈', style: TextStyle(color: Color(0xFF8D6E63))))]))])));
  }
}

class QuestionDiscussionPage extends StatelessWidget {
  final Map<String, dynamic> questionData;
  const QuestionDiscussionPage({super.key, required this.questionData});
  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> replies = [{'author': '李同學', 'time': '1小時前', 'content': '這題考的是資料庫的三層架構吧？'}, {'author': '陳助教', 'time': '30分鐘前', 'content': '沒錯，樹狀結構屬於階層式，不是關聯式喔！'}];
    return Scaffold(backgroundColor: Colors.white, appBar: AppBar(title: const Text('題目討論區', style: TextStyle(fontSize: 16))), body: SafeArea(child: Column(children: [Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Q: ${questionData['question']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 10), Text('正確答案：${questionData['options'][questionData['answerIndex']]}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))])), const Divider(height: 30), const Text('討論留言', style: TextStyle(color: Colors.grey, fontSize: 13)), const SizedBox(height: 10), ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: replies.length, itemBuilder: (c, i) => Container(margin: const EdgeInsets.only(bottom: 15), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(radius: 15, backgroundColor: Colors.grey.shade200, child: Text(replies[i]['author'][0])), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(replies[i]['author'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(width: 8), Text(replies[i]['time'], style: const TextStyle(color: Colors.grey, fontSize: 11))]), const SizedBox(height: 3), Text(replies[i]['content'], style: const TextStyle(fontSize: 13))]))])))])), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade100))), child: Row(children: [const Expanded(child: TextField(decoration: InputDecoration(hintText: '參與討論...', filled: true, fillColor: Color(0xFFF5F5F5), border: OutlineInputBorder(borderSide: BorderSide.none)))), const SizedBox(width: 8), TextButton(onPressed: (){}, child: const Text('送出', style: TextStyle(color: Color(0xFF8D6E63))))]))])));
  }
}