import 'package:flutter/material.dart';
import '../services/membership_service.dart';

class VipBadgeWidget extends StatelessWidget {
  final String tierCode;
  final double fontSize;
  final bool showLabelText;
  final VoidCallback? onTap;

  const VipBadgeWidget({
    super.key,
    required this.tierCode,
    this.fontSize = 11.0,
    this.showLabelText = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final info = MembershipService.tiers[tierCode.toLowerCase()] ??
        MembershipService.tiers['free']!;

    List<Color> gradientColors;
    IconData tierIcon;

    switch (info.code) {
      case 'diamond':
        gradientColors = const [Color(0xFF7E57C2), Color(0xFF5C6BC0), Color(0xFF26C6DA)];
        tierIcon = Icons.diamond;
        break;
      case 'gold':
        gradientColors = const [Color(0xFFFFD54F), Color(0xFFFFB300), Color(0xFFFF8F00)];
        tierIcon = Icons.workspace_premium;
        break;
      case 'silver':
        gradientColors = const [Color(0xFFB0BEC5), Color(0xFF78909C), Color(0xFF546E7A)];
        tierIcon = Icons.stars;
        break;
      case 'free':
      default:
        gradientColors = const [Color(0xFFA1887F), Color(0xFF8D6E63)];
        tierIcon = Icons.shield_outlined;
        break;
    }

    Widget content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.7,
        vertical: fontSize * 0.25,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: info.code != 'free'
            ? [
                BoxShadow(
                  color: gradientColors.last.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            tierIcon,
            size: fontSize * 1.25,
            color: Colors.white,
          ),
          if (showLabelText) ...[
            SizedBox(width: fontSize * 0.35),
            Text(
              info.name,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
                letterSpacing: 0.3,
                shadows: const [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  )
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: content,
      );
    }

    return content;
  }
}
