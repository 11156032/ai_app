import 'package:flutter/material.dart';
import '../../services/app_locale_service.dart';

/// 顯示多國語言選擇彈窗
void showLanguageDialog({
  required BuildContext context,
  required String currentLanguage,
  required Color primaryColor,
  required ValueChanged<String> onSelected,
}) {
  showDialog(
    context: context,
    builder: (ctx) => LanguageDialog(
      currentLanguage: currentLanguage,
      primaryColor: primaryColor,
      onSelected: onSelected,
    ),
  );
}

/// 語言選擇 Dialog
class LanguageDialog extends StatelessWidget {
  final String currentLanguage;
  final Color primaryColor;
  final ValueChanged<String> onSelected;

  const LanguageDialog({
    super.key,
    required this.currentLanguage,
    required this.primaryColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.language_rounded, color: primaryColor),
          const SizedBox(width: 10),
          Text(AppLocaleService.tr('settings_language', currentLanguage)),
        ],
      ),
      children: [
        _buildOption(context, '🇹🇼 繁體中文 (預設)', AppLocaleService.zhTW),
        _buildOption(context, '🇯🇵 日本語 (Japanese)', AppLocaleService.ja),
        _buildOption(context, '🇰🇷 한국어 (Korean)', AppLocaleService.ko),
      ],
    );
  }

  Widget _buildOption(BuildContext context, String label, String langCode) {
    final bool isSelected = currentLanguage == langCode;

    return SimpleDialogOption(
      onPressed: () {
        Navigator.pop(context);
        onSelected(langCode);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? primaryColor : null,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: primaryColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
