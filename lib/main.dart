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

// --- 1. 登入系統 (訪客按鈕已補回) ---
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
            const Text('歡迎回來，請選擇帳號', style: TextStyle(fontSize: 18, color: Colors.grey)),
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

// --- 2. 主功能畫面 (高度與對齊優化) ---
class MainScreen extends StatefulWidget {
  final String userName;
  final VoidCallback onLogout;
  const MainScreen({super.key, required this.userName, required this.onLogout});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _chatController = TextEditingController();
  DateTime _selectedDate = DateTime(2026, 3, 30);
  DateTime _calendarMonth = DateTime(2026, 3, 1);
  late PageController _calendarPageController;
  late PageController _timelinePageController;

  Map<String, List<Map<String, dynamic>>> allSchedules = {
    '2026-03-30': [
      {'time': '00:00~07:00', 'title': '睡覺', 'color': 0xFFCFD8DC},
      {'time': '09:10~12:00', 'title': '專題會議', 'color': 0xFFFFE082},
      {'time': '12:00~13:30', 'title': '吃飯', 'color': 0xFFB2EBF2},
    ],
  };

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

  void _syncDate(DateTime date, {bool fromCalendar = false}) {
    setState(() => _selectedDate = date);
    if (fromCalendar) {
      _timelinePageController.jumpToPage(1000 + date.difference(DateTime(2026, 3, 30)).inDays);
    }
  }

  // 修改：增加預留高度，確保 6 排絕對不溢出
  double _getCalendarHeight() {
    int firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1).weekday;
    int days = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    int rows = ((firstDay - 1 + days) / 7).ceil();
    return (rows * 50.0) + 60.0; // 增加基礎值與倍率
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("${_calendarMonth.year}年 ${_calendarMonth.month}月 - ${widget.userName}", style: const TextStyle(fontSize: 16)),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: widget.onLogout)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 62, // 微調比例，給上半部更多空間
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height: _getCalendarHeight(),
                      child: PageView.builder(
                        controller: _calendarPageController,
                        onPageChanged: (i) => setState(() => _calendarMonth = DateTime(2026, 3 + (i - 12), 1)),
                        itemBuilder: (context, i) => _buildMonthGrid(DateTime(2026, 3 + (i - 12), 1)),
                      ),
                    ),
                    _buildTimelineHeader(),
                    SizedBox(
                      height: 400,
                      child: PageView.builder(
                        controller: _timelinePageController,
                        onPageChanged: (i) {
                          DateTime newDate = DateTime(2026, 3, 30).add(Duration(days: i - 1000));
                          if (newDate.day != _selectedDate.day) _syncDate(newDate);
                        },
                        itemBuilder: (context, i) {
                          DateTime targetDate = DateTime(2026, 3, 30).add(Duration(days: i - 1000));
                          return _buildDayEvents(targetDate);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
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
      padding: const EdgeInsets.fromLTRB(25, 10, 15, 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("${_selectedDate.month}/${_selectedDate.day} 行程明細", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8D6E63))),
          IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFFD7CCC8), size: 30), onPressed: _showAddDialog),
        ],
      ),
    );
  }

  Widget _buildMonthGrid(DateTime date) {
    int empty = DateTime(date.year, date.month, 1).weekday - 1;
    int days = DateTime(date.year, date.month + 1, 0).day;
    return Column(
      children: [
        // 修正：使用 Expanded 確保星期標頭與下方網格精準對齊
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Row(
            children: ['一','二','三','四','五','六','日'].map((d) => Expanded(
              child: Center(child: Text(d, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold))),
            )).toList(),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7, 
            mainAxisSpacing: 8, 
            crossAxisSpacing: 8,
          ),
          itemCount: empty + days,
          itemBuilder: (context, i) {
            if (i < empty) return const SizedBox();
            int d = i - empty + 1;
            bool isSel = _selectedDate.day == d && _selectedDate.month == date.month && _selectedDate.year == date.year;
            return GestureDetector(
              onTap: () => _syncDate(DateTime(date.year, date.month, d), fromCalendar: true),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle, 
                  color: isSel ? const Color(0xFF8D6E63) : Colors.transparent, 
                  border: Border.all(color: Colors.grey.shade100)
                ),
                child: Center(child: Text('$d', style: TextStyle(fontSize: 12, color: isSel ? Colors.white : Colors.black87))),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDayEvents(DateTime date) {
    String key = date.toString().split(' ')[0];
    List<Map<String, dynamic>> events = allSchedules[key] ?? [];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.isEmpty ? 1 : events.length,
      itemBuilder: (context, i) {
        if (events.isEmpty) return const Padding(padding: EdgeInsets.only(top: 20), child: Center(child: Text('本日尚無行程', style: TextStyle(color: Colors.grey))));
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Color(events[i]['color']), borderRadius: BorderRadius.circular(15)),
          child: Row(children: [
            SizedBox(width: 95, child: Text(events[i]['time'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            Expanded(child: Text(events[i]['title'])),
          ]),
        );
      },
    );
  }

  Widget _buildChatSection() {
    return Container(
      color: const Color(0xFFFAFAFA),
      child: Column(children: [
        const Expanded(child: Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text('哈囉!歡迎回來')))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 15), child: Row(children: [
          Expanded(child: TextField(decoration: InputDecoration(hintText: 'AI代理人...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)))),
          const SizedBox(width: 8),
          const CircleAvatar(backgroundColor: Color(0xFF8D6E63), child: Icon(Icons.send, color: Colors.white, size: 18)),
        ])),
      ]),
    );
  }

  void _showAddDialog() {
    String t = '', h = '';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('新增行程'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(onChanged: (v)=>t=v, decoration: const InputDecoration(labelText: '活動名稱')),
        TextField(onChanged: (v)=>h=v, decoration: const InputDecoration(hintText: '00:00~00:00', labelText: '時間')),
      ]),
      actions: [ElevatedButton(onPressed: (){ _addSchedule(h, t, 0xFFFFCC80); Navigator.pop(ctx); }, child: const Text('加入'))],
    ));
  }
}