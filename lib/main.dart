import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'database/database_helper.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/notes_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: "assets/keys.env");
  } catch (e) {
    debugPrint('Warning: Could not load assets/keys.env file: $e');
  }
  
  try {
    await Firebase.initializeApp();
    await PushNotificationService().initialize();
  } catch (e) {
    debugPrint('Warning: Firebase initialization failed. Please ensure google-services.json / GoogleService-Info.plist is configured. Error: $e');
  }
  runApp(const MyApp());
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFD7CCC8),
            surface: const Color(0xFFFAFAFA)),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'TW'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'TW'),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Map<String, dynamic>? _currentUser;
  bool _isInitializing = true; // APP 啟動時先顯示載入動畫

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  /// APP 啟動時，從資料庫讀取是否有已登入的使用者
  Future<void> _checkAutoLogin() async {
    try {
      final user = await DatabaseHelper.instance.getLoggedInUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('Auto-login check failed: $e');
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  /// 登入成功時，寫入資料庫並更新 UI
  void _login(Map<String, dynamic> user) {
    // 訪客帳號不持久化，正式帳號寫入 DB
    if (user['id'] != 'u4') {
      DatabaseHelper.instance.setLoggedInUser(user['id'].toString());
    }
    setState(() => _currentUser = user);
  }

  /// 登出時，清除資料庫的登入標記
  Future<void> _logout() async {
    if (_currentUser != null) {
      final userId = _currentUser!['id']?.toString() ?? '';
      if (userId == 'u4') {
        // 訪客帳號登出時，清除訪客資料
        try {
          await DatabaseHelper.instance.clearVisitorData();
          NotesDatabase.notes.removeWhere((note) => note.userId == 'u4');
          NotesDatabase.categories = ['全部', '未分類', '學習', '工作', '生活'];
          debugPrint('訪客資料已完整清除');
        } catch (e) {
          debugPrint('清除訪客資料失敗: $e');
        }
      } else {
        // 正式帳號登出，清除 DB 中的登入標記
        await DatabaseHelper.instance.clearLoggedInUser(userId);
      }
    }
    setState(() => _currentUser = null);
  }

  @override
  Widget build(BuildContext context) {
    // 啟動初始化中 — 顯示精簡的啟動畫面
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF8F6),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF8D6E63),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8D6E63).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 24),
              const Text(
                'YeBang 家教',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4E342E),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D6E63)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _currentUser == null
        ? LoginScreen(onLogin: _login)
        : MainScreen(currentUser: _currentUser!, onLogout: _logout);
  }
}
