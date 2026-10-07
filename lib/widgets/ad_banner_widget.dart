import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/membership_service.dart';
import '../services/app_locale_service.dart';

/// 贊助廣告極美彈出視窗 (Pop-up Template Dialog with Horizontal Swipe PageView)
class AdPopupDialog extends StatefulWidget {
  final VoidCallback? onAdDismissed;

  const AdPopupDialog({
    super.key,
    this.onAdDismissed,
  });

  static Future<void> show(BuildContext context, {String? userId}) async {
    // 高等級會員 (gold / diamond VIP) 自動享受免廣告尊榮服務
    if (userId != null && userId.isNotEmpty && userId != 'u4') {
      try {
        final tier = await MembershipService.instance.getEffectiveTier(userId);
        if (tier == 'gold' || tier == 'diamond') {
          debugPrint('尊榮 VIP 會員 ($tier)，免除廣告彈出');
          return;
        }
      } catch (e) {
        debugPrint('檢查會員等級失敗: $e');
      }
    }

    if (!context.mounted) return;

    return showDialog(
      context: context,
      builder: (ctx) => const AdPopupDialog(),
    );
  }

  @override
  State<AdPopupDialog> createState() => _AdPopupDialogState();
}

class _AdPopupDialogState extends State<AdPopupDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // 預設高品質模板廣告卡片資料 (可向左右左右滑動切換)
  final List<Map<String, dynamic>> _templateAds = [
    {
      'id': 1,
      'badge': tr('ad1_badge'),
      'title': tr('ad1_title'),
      'content': tr('ad1_content'),
      'sponsor': tr('ad1_sponsor'),
      'icon': Icons.auto_awesome_rounded,
      'link_url': 'https://example.com',
      'gradient': const LinearGradient(
        colors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'accentColor': const Color(0xFFE1BEE7),
    },
    {
      'id': 2,
      'badge': tr('ad2_badge'),
      'title': tr('ad2_title'),
      'content': tr('ad2_content'),
      'sponsor': tr('membership_center'),
      'icon': Icons.workspace_premium_rounded,
      'link_url': 'https://example.com',
      'gradient': const LinearGradient(
        colors: [Color(0xFFFF8F00), Color(0xFFFF6F00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'accentColor': const Color(0xFFFFECB3),
    },
    {
      'id': 3,
      'badge': tr('ad3_badge'),
      'title': tr('ad3_title'),
      'content': tr('ad3_content'),
      'sponsor': tr('ad3_sponsor'),
      'icon': Icons.explore_rounded,
      'link_url': 'https://example.com',
      'gradient': const LinearGradient(
        colors: [Color(0xFF00897B), Color(0xFF004D40)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'accentColor': const Color(0xFFB2DFDB),
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 24,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 340,
        height: 420,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // 1. 可左右滑動切換卡片的 PageView
              PageView.builder(
                controller: _pageController,
                itemCount: _templateAds.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final ad = _templateAds[index];
                  final gradient = ad['gradient'] as LinearGradient;
                  final badge = ad['badge'] as String;
                  final title = ad['title'] as String;
                  final content = ad['content'] as String;
                  final iconData = ad['icon'] as IconData;
                  final accentColor = ad['accentColor'] as Color;
                  final linkUrl = ad['link_url'] as String? ?? '';

                  return Container(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: BoxDecoration(
                      gradient: gradient,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 標籤 + 裝飾圖示
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(iconData,
                                      color: accentColor, size: 15),
                                  const SizedBox(width: 6),
                                  Text(
                                    badge,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 大標題
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.3,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 內文簡介
                        Text(
                          content,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.92),
                            height: 1.5,
                          ),
                        ),
                        const Spacer(),

                        // 動作按鈕 Row (主按鈕 了解詳情，關閉由右上角 X 鈕統一處理)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.arrow_forward_rounded,
                                    size: 16),
                                label: Text(
                                  tr('ad_learn_more'),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  elevation: 4,
                                  shadowColor: Colors.black38,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                                onPressed: () async {
                                  if (linkUrl.isNotEmpty) {
                                    final uri = Uri.parse(linkUrl);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
              ),

              // 2. 右上角質感 Glassmorphic 關閉 (X) 按鈕
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),

              // 3. 底部分頁分頁指示器 (Carousel Dots Indicator)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _templateAds.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentPage == index ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
