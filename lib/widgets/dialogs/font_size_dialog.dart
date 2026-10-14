import 'package:flutter/material.dart';

/// 顯示字體大小選擇彈窗
void showFontSizeDialog({
  required BuildContext context,
  required double currentFactor,
  required Color primaryColor,
  required ValueChanged<double> onSelected,
}) {
  showDialog(
    context: context,
    builder: (ctx) => FontSizeDialog(
      currentFactor: currentFactor,
      primaryColor: primaryColor,
      onSelected: onSelected,
    ),
  );
}

/// 字體大小選擇 Dialog
class FontSizeDialog extends StatelessWidget {
  final double currentFactor;
  final Color primaryColor;
  final ValueChanged<double> onSelected;

  const FontSizeDialog({
    super.key,
    required this.currentFactor,
    required this.primaryColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('選擇字體大小'),
      children: [
        _buildOption(context, '標準 (預設)', 1.2, '範例文字 Aa'),
        _buildOption(context, '放大 (大)', 1.35, '範例文字 Aa'),
        _buildOption(context, '特大 (清晰)', 1.5, '範例文字 Aa'),
      ],
    );
  }

  Widget _buildOption(
    BuildContext context,
    String label,
    double factor,
    String sampleText,
  ) {
    final bool isSelected = (currentFactor - factor).abs() < 0.05;

    return SimpleDialogOption(
      onPressed: () {
        Navigator.pop(context);
        onSelected(factor);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? primaryColor : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? primaryColor : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sampleText,
                    textScaler: TextScaler.linear(factor),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
