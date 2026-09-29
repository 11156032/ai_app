import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'database/database_helper.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/maintenance_screen.dart';
import 'widgets/common_widgets.dart';
import 'widgets/app_update_dialog.dart';
import 'services/app_theme_service.dart';
import 'services/app_locale_service.dart';
import 'services/app_config_service.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/push_notification_service.dart';
import 'services/repository_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Repository 倉儲層（支援未來一鍵切換雲端/本地資料庫）
  RepositoryManager.instance.initialize();

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

  // 非同步進行 Firebase、Remote Config 與推播服務初始化，配置逾時保護
  _initFirebaseAndNotifications();
}

Future<void> _initFirebaseAndNotifications() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 4));
    await AppConfigService.instance
        .initialize()
        .timeout(const Duration(seconds: 4));
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
                  title: 'YeBang 家教',
                  debugShowCheckedModeBanner: false,
                  scrollBehavior: AppScrollBehavior(),
                  builder: (context, child) {
                    final mq = MediaQuery.of(context);
                    // 針對 Web 端在行動裝置（iOS/Android Safari/Chrome）缺少原生頂部安全區域（Status Bar）的情況進行智慧補償
                    final isMobileWeb = kIsWeb &&
                        (defaultTargetPlatform == TargetPlatform.iOS ||
                            defaultTargetPlatform == TargetPlatform.android);
                    final safeTop = isMobileWeb &&
                            mq.padding.top == 0 &&
                            mq.size.width < 600
                        ? (defaultTargetPlatform == TargetPlatform.iOS
                            ? 44.0
                            : 24.0)
                        : mq.padding.top;
                    final safeBottom = isMobileWeb &&
                            mq.padding.bottom == 0 &&
                            mq.size.width < 600
                        ? (defaultTargetPlatform == TargetPlatform.iOS
                            ? 20.0
                            : 0.0)
                        : mq.padding.bottom;

                    final effectiveMq = mq.copyWith(
                      padding: mq.padding
                          .copyWith(top: safeTop, bottom: safeBottom),
                      viewPadding: mq.viewPadding
                          .copyWith(top: safeTop, bottom: safeBottom),
                    );

                    return MediaQuery(
                      data: effectiveMq,
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (event) {
                          // 點擊空白處時立即平滑收起鍵盤，避免 iOS 留下未關閉焦點造成跳動
                          final focus = FocusManager.instance.primaryFocus;
                          if (focus != null && focus.hasFocus) {
                            focus.unfocus();
                          }
                        },
                        child: child ?? const SizedBox.shrink(),
                      ),
                    );
                  },
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
  bool _hasCheckedUpdate = false;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  /// APP 啟動時，從資料庫讀取是否有已登入的使用者，並確保開屏動畫流暢銜接
  Future<void> _checkAutoLogin() async {
    final stopwatch = Stopwatch()..start();
    try {
      // 確保 Remote Config 已完成初步載入
      await AppConfigService.instance
          .initialize()
          .timeout(const Duration(seconds: 3), onTimeout: () {});

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
        _checkUpdatePrompt();
      }
    } catch (e) {
      debugPrint('Auto-login check failed: $e');
      final elapsed = stopwatch.elapsedMilliseconds;
      if (elapsed < 650) {
        await Future.delayed(Duration(milliseconds: 650 - elapsed));
      }
      if (mounted) {
        setState(() => _isInitializing = false);
        _checkUpdatePrompt();
      }
    }
  }

  void _checkUpdatePrompt() {
    if (_hasCheckedUpdate) return;
    _hasCheckedUpdate = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 若處於維護中，維護畫面優先
      if (AppConfigService.instance.isMaintenance) return;

      final updateType = AppConfigService.instance.updateType;
      if (updateType == AppUpdateType.none) return;

      final isForce = updateType == AppUpdateType.force;
      final targetVersion = isForce
          ? AppConfigService.instance.minVersion
          : AppConfigService.instance.latestVersion;

      AppUpdateDialog.show(
        context,
        isForceUpdate: isForce,
        currentVersion: AppConfigService.instance.currentAppVersion,
        targetVersion: targetVersion,
        updateUrl: AppConfigService.instance.updateUrl,
      );
    });
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
    return ValueListenableBuilder<bool>(
      valueListenable: AppConfigService.instance.isMaintenanceNotifier,
      builder: (context, isMaintenance, _) {
        if (isMaintenance) {
          return MaintenanceScreen(
            onResolved: () {
              setState(() {});
              _checkUpdatePrompt();
            },
          );
        }

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
      },
    );
  }
}

/// 進入 APP 的絲滑質感品牌開屏畫面
class _SmoothAppSplash extends StatefulWidget {
  const _SmoothAppSplash({super.key});

  @override
  State<_SmoothAppSplash> createState() => _SmoothAppSplashState();
}

class _SmoothAppSplashState extends State<_SmoothAppSplash>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _slideAnimation = Tween<double>(begin: 14.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
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
      backgroundColor: const Color(0xFFFAF7F4),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFAF7F4),
              Color(0xFFF3EDE8),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 品牌 Logo 搭配柔和幾何光暈，展現高階質感
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF9CCC65).withValues(alpha: 0.16),
                              blurRadius: 36,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: const Color(0xFF4DD0E1).withValues(alpha: 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const YeBangAppLogo(
                          size: 114,
                          showOrbitRings: false,
                        ),
                      ),
                      const SizedBox(height: 30),
                      // 品牌主標題：溫潤深褐色，適度字距呈現高級感
                      const Text(
                        'YeBang 家教',
                        style: TextStyle(
                          fontSize: 25.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3E2723),
                          letterSpacing: 2.0,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // 副標題：優雅灰褐色搭配加大字距
                      const Text(
                        '智慧陪伴 • 卓越學習',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8D6E63),
                          letterSpacing: 3.2,
                        ),
                      ),
                      const SizedBox(height: 42),
                      // 膠囊質感細微進度條
                      SizedBox(
                        width: 130,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: const LinearProgressIndicator(
                            minHeight: 3.2,
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
