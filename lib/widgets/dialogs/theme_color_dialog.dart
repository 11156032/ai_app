import 'package:flutter/material.dart';
import '../../services/app_locale_service.dart';

/// 顯示主題色調選擇彈窗
void showThemeColorDialog({
  required BuildContext context,
  required int currentThemeIdx,
  required String appLanguage,
  required ValueChanged<int> onSelected,
}) {
  showDialog(
    context: context,
    builder: (ctx) => ThemeColorDialog(
      currentThemeIdx: currentThemeIdx,
      appLanguage: appLanguage,
      onSelected: onSelected,
    ),
  );
}

/// 主題色彩選擇 Dialog
class ThemeColorDialog extends StatelessWidget {
  final int currentThemeIdx;
  final String appLanguage;
  final ValueChanged<int> onSelected;

  const ThemeColorDialog({
    super.key,
    required this.currentThemeIdx,
    required this.appLanguage,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(AppLocaleService.tr('settings_theme_color', appLanguage)),
      children: [
        _buildOption(
          context,
          AppLocaleService.tr('theme_color_0', appLanguage),
          0,
          const Color(0xFF8D6E63),
        ),
        _buildOption(
          context,
          AppLocaleService.tr('theme_color_1', appLanguage),
          1,
          const Color(0xFF6B8A96),
        ),
        _buildOption(
          context,
          AppLocaleService.tr('theme_color_2', appLanguage),
          2,
          const Color(0xFF8AA682),
        ),
        _buildOption(
          context,
          AppLocaleService.tr('theme_color_3', appLanguage),
          3,
          const Color(0xFFB57B94),
        ),
        _buildOption(
          context,
          AppLocaleService.tr('theme_color_4', appLanguage),
          4,
          const Color(0xFFC27D66),
        ),
      ],
    );
  }

  Widget _buildOption(
    BuildContext context,
    String label,
    int idx,
    Color color,
  ) {
    final bool isSelected = currentThemeIdx == idx;

    return SimpleDialogOption(
      onPressed: () {
        Navigator.pop(context);
        onSelected(idx);
      },
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
