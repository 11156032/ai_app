import 'package:flutter/material.dart';

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

// ==========================================
// --- 1. 登入系統 ---
// ==========================================
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
    return _currentUser == null ? LoginScreen(onLogin: _login) : MainScreen(userName: _currentUser!, onLogout: _logout);
  }
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
            _btn('登入 Sharon 的行事曆', const Color(0xFFE8EAF6), () => onLogin('Sharon')),
            const SizedBox(height: 20),
            _btn('登入 訪客 的行事曆', const Color(0xFFF1F8E9), () => onLogin('訪客')),
          ],
        ),
      ),
    );
  }
  Widget _btn(String t, Color c, VoidCallback f) => ElevatedButton(
    style: ElevatedButton.styleFrom(backgroundColor: c, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
    onPressed: f, child: Text(t, style: const TextStyle(color: Colors.black87)),
  );
}

// ==========================================
// --- 2. 主架構 ---
// ==========================================
class MainScreen extends StatefulWidget {
  final String userName;
  final VoidCallback onLogout;
  const MainScreen({super.key, required this.userName, required this.onLogout});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; 
  String _appBarTitle = "日曆行程";

  // --- 日期狀態 ---
  DateTime _simulatedToday = DateTime(2026, 3, 30); 
  DateTime _selectedDate = DateTime(2026, 3, 30);
  DateTime _calendarMonth = DateTime(2026, 3, 1);
  late PageController _calendarPageController;
  late PageController _timelinePageController;

  Map<String, List<Map<String, dynamic>>> allSchedules = {
    '2026-03-30': [
      {'time': '09:10~12:00', 'title': '專題討論會議', 'color': 0xFFFFE082},
      {'time': '19:00~20:00', 'title': '洗澡/放鬆時間', 'color': 0xFFB2EBF2},
    ],
  };

  List<Map<String, dynamic>> allTodos = [
    {'id': '1', 'title': '確認 AutoCAD 圓角圖層', 'isDone': false, 'doneDate': null},
    {'id': '2', 'title': '繳交專題企劃書 (草稿)', 'isDone': true, 'doneDate': '2026-03-30'},
  ];

  List<Map<String, dynamic>> socialPosts = [
    {'id': 1, 'author': 'Sharon', 'time': '10分鐘前', 'content': '今天天氣超好！準備來寫 Flutter 專題啦🚀', 'likes': 12, 'replies': 3, 'isLiked': true},
    {'id': 2, 'author': '林同學', 'time': '2小時前', 'content': '有人懂這個 00:00 格式怎麼排序嗎？搞死我了', 'likes': 5, 'replies': 8, 'isLiked': false},
  ];

  List<Map<String, dynamic>> chatLogs = [
    {'isAI': true, 'text': '晚安！輸入「去社群」或「看日曆」可以直接切換畫面，或是告訴我你想加入什麼行程。✨', 'isCard': false},
  ];

  @override
  void initState() {
    super.initState();
    _calendarPageController = PageController(initialPage: 12);
    _timelinePageController = PageController(initialPage: 1000);
  }

  void _addSchedule(String timeRange, String title, int color) {
    setState(() {
      String key = _selectedDate.toString().split(' ')[0];
      (allSchedules[key] ??= []).add({'time': timeRange, 'title': title, 'color': color});
      allSchedules[key]!.sort((a, b) => a['time'].toString().compareTo(b['time'].toString()));
    });
  }

  void _addTodo(String title) {
    setState(() {
      allTodos.add({'id': DateTime.now().millisecondsSinceEpoch.toString(), 'title': title, 'isDone': false, 'doneDate': null});
    });
  }

  void _syncDate(DateTime date, {bool fromCalendar = false}) {
    setState(() => _selectedDate = date);
    if (fromCalendar) {
      _timelinePageController.jumpToPage(1000 + date.difference(_simulatedToday).inDays);
    }
  }

  void _changePage(int index, String title) {
    setState(() {
      _currentIndex = index;
      _appBarTitle = title;
    });
  }

  // ==========================================
  // --- AI 助理全螢幕面板 ---
  // ==========================================
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
              decoration: const BoxDecoration(color: Color(0xFFFAFAFA), borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
              child: SafeArea(
                child: Column(
                  children: [
                    Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                    const Text('AI 代理人助理', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8D6E63), fontSize: 16)),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: chatLogs.length,
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
                            decoration: InputDecoration(hintText: '去社群 / 看日曆 / 幫我加行程...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20)),
                            onSubmitted: (v) => _handleAISubmit(v, modalController, setModalState),
                          )),
                          const SizedBox(width: 8),
                          CircleAvatar(backgroundColor: const Color(0xFF8D6E63), child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white, size: 20), 
                            onPressed: () => _handleAISubmit(modalController.text, modalController, setModalState)
                          )),
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

  // --- 【新增】AI 智慧導航與防呆處理 ---
  void _handleAISubmit(String input, TextEditingController controller, StateSetter setModalState) {
    if (input.trim().isEmpty) return;
    String text = input.trim();
    controller.clear();

    // 判斷是否為導航指令
    if (text.contains('日曆') || text.contains('行程')) {
      Navigator.pop(context); // 關閉對話框
      _changePage(0, '日曆行程');
      setState(() => chatLogs.add({'isAI': true, 'text': '沒問題，已為您跳轉至日曆！', 'isCard': false}));
    } else if (text.contains('社群') || text.contains('文章')) {
      Navigator.pop(context); 
      _changePage(1, '社群');
      setState(() => chatLogs.add({'isAI': true, 'text': '好的，帶您去看看社群新動態！', 'isCard': false}));
    } else if (text.contains('檔案') || text.contains('個人')) {
      Navigator.pop(context); 
      _changePage(2, '社群檔案');
      setState(() => chatLogs.add({'isAI': true, 'text': '已為您打開社群檔案！', 'isCard': false}));
    } else {
      // 普通加行程指令
      setModalState(() {
        chatLogs.add({'isAI': false, 'text': text});
        chatLogs.add({
          'isAI': true, 'text': '收到！我整理好了項目，請問確認要將此行程真正加入系統嗎？這是一項正式操作。', 'isCard': true,
          'pendingData': {'title': text, 'time': '14:00~15:00', 'color': 0xFFFFCC80}
        });
      });
    }
  }

  Widget _buildConfirmationCard(Map<String, dynamic> data, StateSetter setModalState) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10), padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF8D6E63), width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [Icon(Icons.report_problem_outlined, color: Colors.amber), SizedBox(width: 8), Text('User 確認操作', style: TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height: 12),
          Text('📌 項目：${data['title']}', style: const TextStyle(fontSize: 15)),
          Text('⏰ 時間：${data['time']}', style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => setModalState(() => chatLogs.add({'isAI': true, 'text': '好的，已為您取消操作。', 'isCard': false})), child: const Text('取消', style: TextStyle(color: Colors.redAccent))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8D6E63), foregroundColor: Colors.white),
                onPressed: () {
                  _addSchedule(data['time'], data['title'], data['color']);
                  setModalState(() => chatLogs.add({'isAI': true, 'text': '✅ 已將項目調整進 "${_selectedDate.month}/${_selectedDate.day}" 的系統中！', 'isCard': false}));
                },
                child: const Text('確認調整'),
              )
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? "${_calendarMonth.year}年 ${_calendarMonth.month}月" : _appBarTitle, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.white, elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.black54), onPressed: widget.onLogout),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFFFAFAFA),
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('系統選單', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8D6E63))),
              ),
              ListTile(leading: const Icon(Icons.calendar_month), title: const Text('日曆行程'), onTap: () { _changePage(0, '日曆行程'); Navigator.pop(context); }),
              ListTile(leading: const Icon(Icons.forum_outlined), title: const Text('社群'), onTap: () { _changePage(1, '社群'); Navigator.pop(context); }), 
              ListTile(leading: const Icon(Icons.account_circle_outlined), title: const Text('社群檔案'), onTap: () { _changePage(2, '社群檔案'); Navigator.pop(context); }),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildCalendarTab(), 
                  _buildSocialTab(),   
                  _buildProfileTab(),  
                ],
              ),
            ),
            // --- 底部常駐對話輸入 ---
            GestureDetector(
              onTap: _openChatModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(30)),
                  child: const Row(children: [Icon(Icons.auto_awesome, color: Color(0xFF8D6E63), size: 20), SizedBox(width: 10), Text('去社群 / 看日曆 / 加行程...', style: TextStyle(color: Colors.grey, fontSize: 14))]),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 視圖 1: 日曆行程 (拔掉槓槓 + 改名)
  // ==========================================
  Widget _buildCalendarTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            height: 330, 
            child: PageView.builder(
              controller: _calendarPageController,
              onPageChanged: (i) => setState(() => _calendarMonth = DateTime(2026, 3 + (i - 12), 1)),
              itemBuilder: (context, i) => _buildMonthGrid(DateTime(2026, 3 + (i - 12), 1)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(25, 0, 15, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 【第二點】改成「行程」
                Text("${_selectedDate.month}/${_selectedDate.day} 行程", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8D6E63))),
                IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFFD7CCC8), size: 30), onPressed: _showManualAddDialog),
              ],
            ),
          ),
          // 【第三點】拔掉中間破壞畫面的 Divider，讓 Todo 跟行程更像一家人
          SizedBox(
            height: 450,
            child: PageView.builder(
              controller: _timelinePageController,
              onPageChanged: (i) {
                DateTime newDate = _simulatedToday.add(Duration(days: i - 1000));
                if (newDate.day != _selectedDate.day) _syncDate(newDate);
              },
              itemBuilder: (context, i) => _buildUnifiedDayEvents(_simulatedToday.add(Duration(days: i - 1000))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(DateTime date) {
    int empty = DateTime(date.year, date.month, 1).weekday - 1;
    int days = DateTime(date.year, date.month + 1, 0).day;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: ['一','二','三','四','五','六','日'].map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold))))).toList()),
        ),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
          itemCount: empty + days,
          itemBuilder: (context, i) {
            if (i < empty) return const SizedBox();
            int d = i - empty + 1;
            bool isSel = _selectedDate.day == d && _selectedDate.month == date.month && _selectedDate.year == date.year;
            return GestureDetector(
              onTap: () => _syncDate(DateTime(date.year, date.month, d), fromCalendar: true),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: isSel ? const Color(0xFF8D6E63) : Colors.transparent, border: Border.all(color: Colors.grey.shade100)),
                child: Center(child: Text('$d', style: TextStyle(fontSize: 14, color: isSel ? Colors.white : Colors.black87))),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildUnifiedDayEvents(DateTime targetDate) {
    String dateKey = targetDate.toString().split(' ')[0];
    String simTodayKey = _simulatedToday.toString().split(' ')[0];
    bool isPast = targetDate.isBefore(_simulatedToday);

    List<Map<String, dynamic>> schedules = allSchedules[dateKey] ?? [];
    List<Map<String, dynamic>> displayTodos = allTodos.where((todo) {
      if (todo['isDone']) return todo['doneDate'] == dateKey;
      if (isPast) return false; 
      return true; 
    }).toList();

    if (schedules.isEmpty && displayTodos.isEmpty) {
      return const Padding(padding: EdgeInsets.only(top: 20), child: Center(child: Text('本日尚無行程與待辦', style: TextStyle(color: Colors.grey))));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        ...displayTodos.map((item) {
          bool readOnly = isPast; 
          return GestureDetector(
            onTap: () {
              if (readOnly) return; 
              setState(() {
                item['isDone'] = !item['isDone'];
                item['doneDate'] = item['isDone'] ? simTodayKey : null; 
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
              child: Row(children: [
                Icon(item['isDone'] ? Icons.check_circle : Icons.radio_button_unchecked, color: item['isDone'] ? const Color(0xFF8D6E63) : Colors.grey, size: 20),
                const SizedBox(width: 15),
                Expanded(child: Text(item['title'], style: TextStyle(decoration: item['isDone'] ? TextDecoration.lineThrough : null, color: item['isDone'] ? Colors.grey : Colors.black87, fontSize: 14))),
                if (readOnly) const Icon(Icons.lock_outline, size: 14, color: Colors.grey)
              ]),
            ),
          );
        }).toList(),
        
        ...schedules.map((event) => Container(
          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Color(event['color']), borderRadius: BorderRadius.circular(15)),
          child: Row(children: [
            SizedBox(width: 95, child: Text(event['time'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            Expanded(child: Text(event['title'], style: const TextStyle(fontSize: 14))),
          ]),
        )).toList(),
      ],
    );
  }

  void _showManualAddDialog() {
    TextEditingController titleController = TextEditingController();
    int _selectedType = 0; 
    TimeOfDay pickedStartTime = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay pickedEndTime = const TimeOfDay(hour: 11, minute: 0);
    StateSetter? _dialogSetState;

    Future<void> _selectTime(bool isStart) async {
      final TimeOfDay? picked = await showTimePicker(context: context, initialTime: isStart ? pickedStartTime : pickedEndTime, helpText: isStart ? '選擇時間' : '選擇時間');
      if (picked != null) {
        _dialogSetState!(() { if (isStart) { pickedStartTime = picked; } else { pickedEndTime = picked; } });
      }
    }

    String _formatTime(TimeOfDay time) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('手動新增項目'),
      content: StatefulBuilder(builder: (context, setDialogState) {
        _dialogSetState = setDialogState;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleController, decoration: const InputDecoration(labelText: '標題名稱', hintText: '例如: 繳交報告')),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(label: const Text('時間行程'), selected: _selectedType == 0, selectedColor: const Color(0xFFD7CCC8), onSelected: (v) => setDialogState(() => _selectedType = 0)),
              const SizedBox(width: 10),
              ChoiceChip(label: const Text('待辦事項'), selected: _selectedType == 1, selectedColor: const Color(0xFFD7CCC8), onSelected: (v) => setDialogState(() => _selectedType = 1)),
            ],
          ),
          if (_selectedType == 0) ...[
            const SizedBox(height: 15),
            const Align(alignment: Alignment.centerLeft, child: Text('設定時間區間', style: TextStyle(color: Colors.grey))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(icon: const Icon(Icons.access_time, size: 16), label: Text(_formatTime(pickedStartTime)), onPressed: () => _selectTime(true)),
                const Text('~'),
                TextButton.icon(icon: const Icon(Icons.access_time, size: 16), label: Text(_formatTime(pickedEndTime)), onPressed: () => _selectTime(false)),
              ],
            )
          ]
        ]);
      }),
      actions: [
        ElevatedButton(onPressed: (){ 
          if (titleController.text.isEmpty) return;
          if (_selectedType == 0) {
            String range = "${_formatTime(pickedStartTime)}~${_formatTime(pickedEndTime)}";
            _addSchedule(range, titleController.text, 0xFFFFCC80); 
          } else { _addTodo(titleController.text); }
          Navigator.pop(ctx); 
        }, child: const Text('確認加入')),
      ],
    ));
  }

  // ==========================================
  // 視圖 2: 社群
  // ==========================================
  Widget _buildSocialTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: socialPosts.length,
      itemBuilder: (context, i) => _buildPostItem(socialPosts[i]),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CircleAvatar(backgroundColor: Color(0xFFD7CCC8), child: Icon(Icons.person, color: Colors.white, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Text(post['author'], style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 10), Text(post['time'], style: const TextStyle(color: Colors.grey, fontSize: 12))]),
            const SizedBox(height: 5),
            Text(post['content']),
            const SizedBox(height: 12),
            Row(children: [
              IconButton(icon: Icon(post['isLiked'] ? Icons.favorite : Icons.favorite_border, size: 18, color: post['isLiked'] ? Colors.redAccent : Colors.grey), onPressed: () {}),
              Text('${post['likes']}'),
              const SizedBox(width: 20),
              // 【第一點】回覆按鈕加回來啦！
              IconButton(icon: const Icon(Icons.mode_comment_outlined, size: 18, color: Colors.grey), onPressed: () => _openReplyPage(post)), 
              Text('${post['replies']}'),
            ]),
          ],
        ))
      ]),
    );
  }

  void _openReplyPage(Map<String, dynamic> post) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PostReplyPage(originalPost: post)));
  }

  // ==========================================
  // 視圖 3: 社群檔案
  // ==========================================
  Widget _buildProfileTab() {
    return DefaultTabController(
      length: 2, 
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(25),
            child: Row(children: [
              const CircleAvatar(radius: 35, backgroundColor: Color(0xFFD7CCC8), child: Icon(Icons.person, size: 35, color: Colors.white)),
              const SizedBox(width: 20),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('Flutter 新手村村長 ✨', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ]),
            ]),
          ),
          const TabBar(indicatorColor: Color(0xFF8D6E63), labelColor: Color(0xFF8D6E63), unselectedLabelColor: Colors.grey, tabs: [Tab(text: '我的發佈'), Tab(text: '喜歡的文章')]),
          Expanded(
            child: TabBarView(children: [
              ListView.builder(padding: const EdgeInsets.all(16), itemCount: 1, itemBuilder: (c, i) => _buildPostItem(socialPosts[0])),
              ListView.builder(padding: const EdgeInsets.all(16), itemCount: 1, itemBuilder: (c, i) => _buildPostItem(socialPosts[0])),
            ]),
          )
        ],
      ),
    );
  }
}

// ==========================================
// --- 社群文章回覆頁面 (成功復活！) ---
// ==========================================
class PostReplyPage extends StatelessWidget {
  final Map<String, dynamic> originalPost;
  const PostReplyPage({super.key, required this.originalPost});

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> replies = [
      {'author': '李同學', 'time': '1小時前', 'content': '加油！推一個'},
      {'author': '陳助教', 'time': '30分鐘前', 'content': '排序逻辑我发系上群組囉'},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('文章回覆', style: TextStyle(fontSize: 16))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildOriginalPostHeader(originalPost),
                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('最新回覆', style: TextStyle(color: Colors.grey, fontSize: 13))),
                  ListView.builder(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    itemCount: replies.length,
                    itemBuilder: (c, i) => _buildReplyItem(replies[i]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade100))),
              child: Row(children: [
                const Expanded(child: TextField(decoration: InputDecoration(hintText: '回覆...', filled: true, fillColor: Color(0xFFF5F5F5), border: OutlineInputBorder(borderSide: BorderSide.none)))),
                const SizedBox(width: 8),
                TextButton(onPressed: (){}, child: const Text('發佈', style: TextStyle(color: Color(0xFF8D6E63)))),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOriginalPostHeader(Map<String, dynamic> post) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CircleAvatar(backgroundColor: Color(0xFFD7CCC8), child: Icon(Icons.person, color: Colors.white, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Text(post['author'], style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 10), Text(post['time'], style: const TextStyle(color: Colors.grey, fontSize: 12))]),
            const SizedBox(height: 5),
            Text(post['content'], style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
          ],
        ))
      ]);
  }

  Widget _buildReplyItem(Map<String, dynamic> reply) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 15, backgroundColor: Colors.grey.shade200, child: Text(reply['author'][0])),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Text(reply['author'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(width: 8), Text(reply['time'], style: const TextStyle(color: Colors.grey, fontSize: 11))]),
            Text(reply['content'], style: const TextStyle(fontSize: 13)),
          ],
        ))
      ]),
    );
  }
}