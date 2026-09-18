import 'package:flutter/material.dart';

/// 應用程式全局主題服務（統一管理主題色彩、深色模式與字體縮放）
class AppThemeService {
  AppThemeService._();
  static final AppThemeService instance = AppThemeService._();

  static const List<Color> themeColors = [
    Color(0xFF8D6E63), // 0: 經典暖棕 (預設)
    Color(0xFF6B8A96), // 1: 孔雀藍 (霧霾藍)
    Color(0xFF8AA682), // 2: 森林綠 (鼠尾草綠)
    Color(0xFFB57B94), // 3: 暮櫻紫 (粉紫)
    Color(0xFFC27D66), // 4: 琥珀橙 (暖砂橘)
  ];

  static const List<String> themeColorNames = [
    '經典暖棕',
    '孔雀藍',
    '森林綠',
    '暮櫻紫',
    '琥珀橙',
  ];

  static final ValueNotifier<int> themeColorIdxNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<bool> isDarkModeNotifier =
      ValueNotifier<bool>(false);
  static final ValueNotifier<double> fontSizeFactorNotifier =
      ValueNotifier<double>(1.0);

  static int get currentThemeIdx => themeColorIdxNotifier.value;
  static bool get isDarkMode => isDarkModeNotifier.value;
  static double get fontSizeFactor => fontSizeFactorNotifier.value;

  static Color get primaryColor => getPrimaryColor(themeColorIdxNotifier.value);

  static Color getPrimaryColor(int idx) {
    if (idx >= 0 && idx < themeColors.length) {
      return themeColors[idx];
    }
    return themeColors[0];
  }

  static void setThemeColor(int idx) {
    if (idx >= 0 &&
        idx < themeColors.length &&
        themeColorIdxNotifier.value != idx) {
      themeColorIdxNotifier.value = idx;
    }
  }

  static void setDarkMode(bool isDark) {
    if (isDarkModeNotifier.value != isDark) {
      isDarkModeNotifier.value = isDark;
    }
  }

  static void setFontSizeFactor(double factor) {
    if (fontSizeFactorNotifier.value != factor) {
      fontSizeFactorNotifier.value = factor;
    }
  }

  static void syncFromUser({
    int? themeColorIdx,
    bool? isDark,
    double? fontFactor,
  }) {
    if (themeColorIdx != null) setThemeColor(themeColorIdx);
    if (isDark != null) setDarkMode(isDark);
    if (fontFactor != null) setFontSizeFactor(fontFactor);
  }

  static ThemeData createThemeData({
    required int themeIdx,
    required bool isDark,
    double fontFactor = 1.0,
  }) {
    final primary = getPrimaryColor(themeIdx);
    final baseTheme = isDark ? ThemeData.dark() : ThemeData.light();

    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: primary.withValues(alpha: 0.85),
      brightness: isDark ? Brightness.dark : Brightness.light,
      surface: isDark ? const Color(0xFF1E1E22) : const Color(0xFFFAFAFA),
    );

    return baseTheme.copyWith(
      primaryColor: primary,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF121214) : const Color(0xFFFAFAFA),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
