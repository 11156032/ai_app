import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'database/database_helper.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/notes_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: "assets/keys.env");
  } catch (e) {
    debugPrint('Warning: Could not load assets/keys.env file: $e');
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

  void _login(Map<String, dynamic> user) => setState(() => _currentUser = user);

  Future<void> _logout() async {
    if (_currentUser != null && _currentUser!['id'] == 'u4') {
      try {
        await DatabaseHelper.instance.clearVisitorData();

        // 清除記憶體中的訪客筆記與重置分類
        NotesDatabase.notes.removeWhere((note) => note.userId == 'u4');
        NotesDatabase.categories = ['全部', '未分類', '學習', '工作', '生活'];

        debugPrint('訪客資料已完整清除');
      } catch (e) {
        debugPrint('清除訪客資料失敗: $e');
      }
    }
    setState(() => _currentUser = null);
  }

  @override
  Widget build(BuildContext context) => _currentUser == null
      ? LoginScreen(onLogin: _login)
      : MainScreen(currentUser: _currentUser!, onLogout: _logout);
}
