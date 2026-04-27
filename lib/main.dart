import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

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
            surface: const Color(0xFFFAFAFA)),
        useMaterial3: true,
      ),
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

  void _login(Map<String, dynamic> user) =>
      setState(() => _currentUser = user);

  Future<void> _logout() async {
    if (_currentUser != null && _currentUser!['id'] == 'u4') {
      try {
        final db = await DatabaseHelper.instance.database;
        await db.delete('calendar_events', where: 'user_id = ?', whereArgs: ['u4']);
        await db.delete('todos', where: 'user_id = ?', whereArgs: ['u4']);
        debugPrint('訪客資料已清除');
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
