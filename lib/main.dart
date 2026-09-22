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
  bool _isInitializing = true; // APP 啟動時先顯示精緻載入動畫

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  /// APP 啟動時，從資料庫讀取是否有已登入的使用者，並確保開屏動畫流暢銜接
  Future<void> _checkAutoLogin() async {
    final stopwatch = Stopwatch()..start();
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

      // 確保開屏畫面至少優雅停留 650ms，避免開屏快閃破綻
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 650) {
        await Future.delayed(Duration(milliseconds: 650 - elapsed));
      }

      if (mounted) {
        setState(() {
          _currentUser = user;
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('Auto-login check failed: $e');
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 650) {
        await Future.delayed(Duration(milliseconds: 650 - elapsed));
      }
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: _isInitializing
          ? const _SmoothAppSplash(key: ValueKey('app_splash'))
          : KeyedSubtree(
              key: ValueKey(_currentUser != null
                  ? 'main_${_currentUser!['id']}'
                  : 'login_screen'),
              child: _currentUser == null
                  ? LoginScreen(onLogin: _login)
                  : MainScreen(currentUser: _currentUser!, onLogout: _logout),
            ),
    );
  }
}

/// 進入 APP 的絲滑品牌開屏畫面
class _SmoothAppSplash extends StatefulWidget {
  const _SmoothAppSplash({super.key});

  @override
  State<_SmoothAppSplash> createState() => _SmoothAppSplashState();
}

class _SmoothAppSplashState extends State<_SmoothAppSplash>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F6),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFCFAF8),
              Color(0xFFF7F2EE),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8D6E63).withValues(alpha: 0.16),
                              blurRadius: 28,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const YeBangAppLogo(
                          size: 82,
                          showOrbitRings: true,
                        ),
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        'YeBang 家教',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3E2723),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '智慧陪伴 • 卓越學習',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF8D6E63).withValues(alpha: 0.85),
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: 110,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            minHeight: 2.8,
                            backgroundColor: Color(0xFFEFEBE9),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Color(0xFF8D6E63)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
