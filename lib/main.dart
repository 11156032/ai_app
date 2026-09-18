import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'database/database_helper.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/notes_screen.dart';
import 'widgets/common_widgets.dart';
import 'services/app_theme_service.dart';
import 'services/app_locale_service.dart';

import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 鎖定手機直向顯示，避免旋轉造成畫面溢位與排版錯亂（商業 App 標準做法）
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 捕獲並日誌記錄 Flutter 渲染與非同步錯誤，杜絕任何紅屏 (Red Screen) 發生
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🚨 [Flutter Error Handled] ${details.exception}');
    debugPrint('🚨 [Stack Trace]\n${details.stack}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('🚨 [ErrorWidget Blocked] ${details.exception}');
    return const SizedBox.shrink();
  };

  try {
    await dotenv.load(fileName: "assets/keys.env");
  } catch (e) {
    debugPrint('Warning: Could not load assets/keys.env file: $e');
  }

  // 立即啟動 UI 渲染，避免原生 Splash 畫面卡死
  runApp(const MyApp());

  // 非同步進行 Firebase 與推播服務初始化，配置逾時保護
  _initFirebaseAndNotifications();
}

Future<void> _initFirebaseAndNotifications() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 4));
    await PushNotificationService()
        .initialize()
        .timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint(
        'Warning: Firebase / PushNotification initialization deferred or failed: $e');
  }
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
    return ValueListenableBuilder<int>(
      valueListenable: AppThemeService.themeColorIdxNotifier,
      builder: (context, themeIdx, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppThemeService.isDarkModeNotifier,
          builder: (context, isDark, _) {
            return ValueListenableBuilder<String>(
              valueListenable: AppLocaleService.currentLanguageNotifier,
              builder: (context, currentLang, _) {
                final localeParts = currentLang.split('_');
                final locale = Locale(
                  localeParts[0],
                  localeParts.length > 1 ? localeParts[1] : '',
                );

                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  scrollBehavior: AppScrollBehavior(),
                  theme: AppThemeService.createThemeData(
                    themeIdx: themeIdx,
                    isDark: isDark,
                  ),
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('zh', 'TW'),
                    Locale('en', 'US'),
                    Locale('ja', 'JP'),
                    Locale('ko', 'KR'),
                  ],
                  locale: locale,
                  home: const AuthWrapper(),
                );
              },
            );
          },
        );
      },
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
      final user = await DatabaseHelper.instance
          .getLoggedInUser()
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      if (user != null) {
        final themeIdx = (user['theme_color_idx'] as int?) ?? 0;
        final isDark = (user['is_dark_mode'] as int? ?? 0) == 1;
        final fontFactor =
            (user['font_size_factor'] as num?)?.toDouble() ?? 1.0;
        AppThemeService.syncFromUser(
          themeColorIdx: themeIdx,
          isDark: isDark,
          fontFactor: fontFactor,
        );
        if (user['language'] != null) {
          AppLocaleService.setLanguage(user['language'].toString());
        }
      }
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
    final themeIdx = (user['theme_color_idx'] as int?) ?? 0;
    final isDark = (user['is_dark_mode'] as int? ?? 0) == 1;
    final fontFactor = (user['font_size_factor'] as num?)?.toDouble() ?? 1.0;
    AppThemeService.syncFromUser(
      themeColorIdx: themeIdx,
      isDark: isDark,
      fontFactor: fontFactor,
    );
    if (user['language'] != null) {
      AppLocaleService.setLanguage(user['language'].toString());
    }

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
              const YeBangAppLogo(
                size: 76,
                showOrbitRings: true,
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
