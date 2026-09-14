import 'package:flutter/material.dart';
import '../services/membership_service.dart';
import 'vip_badge_widget.dart';

class PointRechargeDialog extends StatefulWidget {
  final String userId;
  final String? defaultTab; // 'points' or 'tiers'
  final Color? primaryColor;
  final VoidCallback? onSuccess;

  const PointRechargeDialog({
    super.key,
    required this.userId,
    this.defaultTab = 'points',
    this.primaryColor,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String userId,
    String? defaultTab,
    Color? primaryColor,
    VoidCallback? onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PointRechargeDialog(
        userId: userId,
        defaultTab: defaultTab,
        primaryColor: primaryColor ?? Theme.of(context).primaryColor,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<PointRechargeDialog> createState() => _PointRechargeDialogState();
}

class _PointRechargeDialogState extends State<PointRechargeDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedPointPackageIdx = 1; // Default 300 points
  int _selectedTierPackageIdx = 1;  // Default Gold VIP

  bool _isProcessing = false;
  bool _isSuccess = false;
  String _processingMessage = '正在呼叫支付驗證...';

  final List<Map<String, dynamic>> _pointPackages = const [
    {'name': '體驗點數包', 'points': 100, 'price': 30, 'tag': ''},
    {'name': '熱門超值包', 'points': 300, 'price': 90, 'tag': '最熱門'},
    {'name': '尊享巨量包', 'points': 600, 'price': 160, 'tag': '省 20%'},
    {'name': '無憂大禮包', 'points': 1500, 'price': 360, 'tag': '超值 7 折'},
  ];

  final List<Map<String, dynamic>> _tierPackages = const [
    {'tier': 'silver', 'name': '白銀 VIP', 'days': 30, 'price': 99, 'bonus': 50, 'tag': '小試身手'},
    {'tier': 'gold', 'name': '黃金 VIP', 'days': 30, 'price': 199, 'bonus': 150, 'tag': '強烈推薦'},
    {'tier': 'diamond', 'name': '鑽石 VIP', 'days': 30, 'price': 390, 'bonus': 500, 'tag': '無限專享'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.defaultTab == 'tiers' ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleSimulatedPayment() async {
    setState(() {
      _isProcessing = true;
      _isSuccess = false;
      _processingMessage = '正在進行安全驗證與 Apple/Google 憑證核對...';
    });

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    setState(() {
      _processingMessage = '交易處理中，正在入帳點數...';
    });

    try {
      if (_tabController.index == 0) {
        // 儲值點數包
        final pkg = _pointPackages[_selectedPointPackageIdx];
        await MembershipService.instance.simulatedPurchasePoints(
          userId: widget.userId,
          pointsAmount: pkg['points'] as int,
          priceTwd: (pkg['price'] as int).toDouble(),
          packageName: pkg['name'] as String,
        );
      } else {
        // 升級會員
        final pkg = _tierPackages[_selectedTierPackageIdx];
        await MembershipService.instance.simulatedUpgradeTier(
          userId: widget.userId,
          targetTier: pkg['tier'] as String,
          durationDays: pkg['days'] as int,
          priceTwd: (pkg['price'] as int).toDouble(),
          bonusPoints: pkg['bonus'] as int,
        );
      }

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _isSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      widget.onSuccess?.call();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('模擬交易失敗: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final themeColor = widget.primaryColor ?? Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 2)
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 頂部抓手條
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              if (_isProcessing) ...[
                const SizedBox(height: 30),
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _processingMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '（模擬沙盒環境，未進行實際扣款）',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 30),
              ] else if (_isSuccess) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 64,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '交易成功！權益已即時生效',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '已自動更新您的點數餘額與 VIP 階級權益 🎉',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(height: 24),
              ] else ...[
                // 標題列
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: isDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.bolt, color: themeColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '儲值與 VIP 會員訂閱',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                          ),
                          Text(
                            '解鎖 AI 全效診斷與無限對話',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 分頁按鈕
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: themeColor,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: themeColor,
                    unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: '⚡ 點數儲值包'),
                      Tab(text: '👑 VIP 會員方案'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  height: 220,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // 點數儲值包卡片列表
                      ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pointPackages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (ctx, idx) {
                          final pkg = _pointPackages[idx];
                          final isSelected = _selectedPointPackageIdx == idx;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedPointPackageIdx = idx),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 135,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? themeColor.withValues(alpha: isDark ? 0.2 : 0.1)
                                    : (isDark ? const Color(0xFF2C2C34) : Colors.white),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? themeColor : (isDark ? Colors.white12 : Colors.grey[300]!),
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: themeColor.withValues(alpha: 0.25),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if ((pkg['tag'] as String).isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6F00),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        pkg['tag'] as String,
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  else
                                    const SizedBox(height: 18),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${pkg['points']} 點',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFE65100),
                                    ),
                                  ),
                                  Text(
                                    pkg['name'] as String,
                                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'NT\$ ${pkg['price']}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? const Color(0xFF4E342E) : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // VIP 會員方案卡片列表
                      ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _tierPackages.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (ctx, idx) {
                          final pkg = _tierPackages[idx];
                          final isSelected = _selectedTierPackageIdx == idx;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedTierPackageIdx = idx),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 145,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFF3E5F5) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF8E24AA) : Colors.grey[300]!,
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF8E24AA).withValues(alpha: 0.25),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  VipBadgeWidget(
                                    tierCode: pkg['tier'] as String,
                                    fontSize: 10,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    pkg['name'] as String,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4A148C),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '首升贈 ${pkg['bonus']} 點',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFFD81B60), fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'NT\$ ${pkg['price']} /月',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? const Color(0xFF4A148C) : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 立即支付按鈕 (模擬 Apple / Google Pay 樣式)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _handleSimulatedPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1E1E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock, size: 18, color: Colors.white70),
                        SizedBox(width: 8),
                        Text(
                          '模擬安全結帳 (Tap to Pay)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
