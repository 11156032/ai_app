import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'database/database_helper.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

void main() => runApp(const MyApp());

final GoogleSignIn googleSignIn = GoogleSignIn(
  clientId: '789026077383-i60srf9lqr1gmcv48801umce3vfgecv8.apps.googleusercontent.com',
);
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
  StreamSubscription? _googleAuthSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeGoogleEvents();
  }

  void _subscribeGoogleEvents() {
    _googleAuthSubscription?.cancel();
    _googleAuthSubscription = googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      if (account != null && _currentUser == null) {
        _processGoogleUser(account);
      }
    });
    googleSignIn.signInSilently();
  }

  Future<void> _processGoogleUser(GoogleSignInAccount googleUser) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db
          .query('users', where: 'email = ?', whereArgs: [googleUser.email]);

      if (!mounted) return;

      if (res.isNotEmpty) {
        // 已有帳號 → 直接登入
        showDialog(
            barrierDismissible: false,
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text('登入成功'),
                    content: Text('歡迎回來，${res.first['display_name']}！👋'),
                    actions: [
                      TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _login(Map<String, dynamic>.from(res.first));
                          },
                          child: const Text('進入系統'))
                    ]));
      } else {
        // 新用戶 → 自動建立帳號
        String newId = 'u_${DateTime.now().millisecondsSinceEpoch}';
        String newUsername = googleUser.email.split('@').first;

        await db.insert('users', {
          'id': newId,
          'username': newUsername,
          'email': googleUser.email,
          'hashed_password': 'GOOGLE_AUTH_USER',
          'display_name': googleUser.displayName ?? newUsername,
        });

        final newUserRes =
            await db.query('users', where: 'id = ?', whereArgs: [newId]);

        if (!mounted) return;
        showDialog(
            barrierDismissible: false,
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text('歡迎加入！'),
                    content: Text(
                        '您的帳號已建立，${googleUser.displayName ?? newUsername}，歡迎使用所有功能！🎉'),
                    actions: [
                      TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _login(Map<String, dynamic>.from(newUserRes.first));
                          },
                          child: const Text('進入系統'))
                    ]));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登入時發生問題，請稍後再試')));
    }
  }

  void _login(Map<String, dynamic> user) =>
      setState(() => _currentUser = user);

  Future<void> _logout() async {
    // 若是訪客登出，先清除其在資料庫留下的所有資料
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

    _googleAuthSubscription?.cancel();
    try {
      await googleSignIn.signOut();
    } catch (_) {}
    setState(() => _currentUser = null);
    // 登出後重新訂閱，確保下次按鈕點擊仍能觸發
    _subscribeGoogleEvents();
  }

  @override
  void dispose() {
    _googleAuthSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _currentUser == null
      ? LoginScreen(onLogin: _login)
      : MainScreen(currentUser: _currentUser!, onLogout: _logout);
}
