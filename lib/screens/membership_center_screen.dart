import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../services/membership_service.dart';
import '../widgets/vip_badge_widget.dart';
import '../widgets/point_recharge_dialog.dart';

class MembershipCenterScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  final Color? primaryColor;

  const MembershipCenterScreen({
    super.key,
    required this.currentUser,
    this.primaryColor,
  });

  @override
  State<MembershipCenterScreen> createState() => _MembershipCenterScreenState();
}

class _MembershipCenterScreenState extends State<MembershipCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _currentTier = 'free';
  String? _expiresAtIso;
  int _pointsBalance = 100;
  bool _hasClaimedToday = false;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMembershipData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMembershipData() async {
    setState(() => _isLoading = true);
    final userId = widget.currentUser['id'].toString();

    try {
      final tier = await MembershipService.instance.getEffectiveTier(userId);
      final info = await DatabaseHelper.instance.getUserMembershipInfo(userId);
      final claimed = await MembershipService.instance.hasClaimedDailyBonusToday(userId);
      final txs = await DatabaseHelper.instance.getPointTransactions(userId, limit: 50);

      if (mounted) {
        setState(() {
          _currentTier = tier;
          _expiresAtIso = info['membership_expires_at'] as String?;
          _pointsBalance = info['points_balance'] as int? ?? 100;
          _hasClaimedToday = claimed;
          _transactions = txs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading membership data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _claimDailyBonus() async {
    final userId = widget.currentUser['id'].toString();
    try {
      final bonus = await MembershipService.instance.claimDailyBonus(userId);
      if (!mounted) return;

      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), 
          content: Text('🎉 每日簽到成功！獲得 +$bonus 點數'),
          backgroundColor: const Color(0xFF4CAF50),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadMembershipData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(
        SnackBar(duration: const Duration(milliseconds: 1500), 
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openRechargeDialog([String defaultTab = 'points']) {
    final themeColor = widget.primaryColor ?? Theme.of(context).primaryColor;
    PointRechargeDialog.show(
      context,
      userId: widget.currentUser['id'].toString(),
      defaultTab: defaultTab,
      primaryColor: themeColor,
      onSuccess: () => _loadMembershipData(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tierInfo = MembershipService.tiers[_currentTier] ?? MembershipService.tiers['free']!;
    final themeColor = widget.primaryColor ?? Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF141416) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'VIP 會員與點數中心',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : const Color(0xFF1F2937)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMembershipData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. VIP 尊榮會員卡 (VIP Member Card)
                    _buildVipMemberCard(tierInfo, themeColor, isDark),

                    const SizedBox(height: 20),

                    // 2. 每日簽到領點數 Banner
                    _buildDailyCheckInBanner(tierInfo, themeColor, isDark),

                    const SizedBox(height: 24),

                    // 3. 功能頁籤 (特權對比 vs 點數交易明細)
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            indicatorColor: themeColor,
                            indicatorWeight: 3,
                            labelColor: themeColor,
                            unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            tabs: const [
                              Tab(text: '👑 会員特權比較'),
                              Tab(text: '📜 點數變動紀錄'),
                            ],
                          ),
                          SizedBox(
                            height: 480,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildPerksComparisonTab(themeColor, isDark),
                                _buildTransactionsTab(isDark),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  /// 建立尊榮 VIP 會員卡片
  Widget _buildVipMemberCard(MembershipTierInfo tierInfo, Color themeColor, bool isDark) {
    List<Color> cardGradient;
    switch (tierInfo.code) {
      case 'diamond':
        cardGradient = const [Color(0xFF311B92), Color(0xFF512DA8), Color(0xFF00838F)];
        break;
      case 'gold':
        cardGradient = const [Color(0xFF4A3600), Color(0xFF8D6E00), Color(0xFFFF8F00)];
        break;
      case 'silver':
        cardGradient = const [Color(0xFF263238), Color(0xFF37474F), Color(0xFF78909C)];
        break;
      case 'free':
      default:
        final hsl = HSLColor.fromColor(themeColor);
        final c1 = hsl.withLightness((hsl.lightness * (isDark ? 0.35 : 0.45)).clamp(0.08, 0.8)).toColor();
        final c2 = hsl.withLightness((hsl.lightness * (isDark ? 0.65 : 0.75)).clamp(0.15, 0.85)).toColor();
        final c3 = themeColor;
        cardGradient = [c1, c2, c3];
        break;
    }

    final displayName = widget.currentUser['display_name'] ?? widget.currentUser['username'] ?? '使用者';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cardGradient.first.withValues(alpha: isDark ? 0.5 : 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 頂部列：姓名與 Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    radius: 20,
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _expiresAtIso != null && _expiresAtIso!.isNotEmpty
                            ? 'VIP 到期日: ${_expiresAtIso!.split('T')[0]}'
                            : '永久基本會員',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              VipBadgeWidget(tierCode: _currentTier, fontSize: 12),
            ],
          ),

          const SizedBox(height: 24),

          // 點數餘額與快速儲值
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '當前可用點數 (Tokens)',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Color(0xFFFFD54F), size: 28),
                      const SizedBox(width: 4),
                      Text(
                        '$_pointsBalance',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Pts',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _openRechargeDialog('points'),
                icon: const Icon(Icons.add_shopping_cart, size: 16, color: Color(0xFF3E2723)),
                label: const Text(
                  '購買點數',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 每日簽到領點數 Banner
  Widget _buildDailyCheckInBanner(MembershipTierInfo tierInfo, Color themeColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeColor.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.calendar_today_rounded, color: themeColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '每日登入獎勵',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '當前階級每日可領 +${tierInfo.dailyBonus} 點數',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _hasClaimedToday ? null : _claimDailyBonus,
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasClaimedToday ? (isDark ? Colors.white12 : Colors.grey[300]) : themeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text(
              _hasClaimedToday ? '今日已領' : '立即簽到',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _hasClaimedToday ? (isDark ? Colors.white38 : Colors.grey.shade600) : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 會員特權比較表 Tab
  Widget _buildPerksComparisonTab(Color themeColor, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'VIP 會員權益對比矩陣',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        Table(
          border: TableBorder.all(
            color: isDark ? Colors.white12 : Colors.grey[300]!,
            width: 1,
            borderRadius: BorderRadius.circular(12),
          ),
          columnWidths: const {
            0: FlexColumnWidth(1.4),
            1: FlexColumnWidth(1.0),
            2: FlexColumnWidth(1.0),
            3: FlexColumnWidth(1.0),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey[100]),
              children: [
                Padding(padding: const EdgeInsets.all(8), child: Text('權益項目', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87))),
                Padding(padding: const EdgeInsets.all(8), child: Text('普通', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white70 : Colors.black87))),
                const Padding(padding: EdgeInsets.all(8), child: Text('黃金', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFFF8F00)))),
                const Padding(padding: EdgeInsets.all(8), child: Text('鑽石', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF7E57C2)))),
              ],
            ),
            _buildTableRow('AI 詢問點數折扣', '原價 (1.0x)', '8 折 (0.8x)', '5 折半價', isDark),
            _buildTableRow('每日簽到點數', '+10 Pts', '+50 Pts', '+100 Pts', isDark),
            _buildTableRow('AI 診斷詳細報告', '基本款', '完整深度', 'VIP 無限速', isDark),
            _buildTableRow('專屬身份徽章', '普通灰色', '金色光澤', '鑽石流光', isDark),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _openRechargeDialog('tiers'),
            icon: const Icon(Icons.star_rounded, color: Colors.white),
            label: const Text(
              '★ 立即升級 VIP 方案',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildTableRow(String perk, String v1, String v2, String v3, bool isDark) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(8), child: Text(perk, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))),
        Padding(padding: const EdgeInsets.all(8), child: Text(v1, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54))),
        Padding(padding: const EdgeInsets.all(8), child: Text(v2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF8F00)))),
        Padding(padding: const EdgeInsets.all(8), child: Text(v3, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7E57C2)))),
      ],
    );
  }

  /// 點數交易歷史明細 Tab
  Widget _buildTransactionsTab(bool isDark) {
    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: isDark ? Colors.white38 : Colors.grey),
            const SizedBox(height: 12),
            Text('尚無點數變動紀錄', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, idx) {
        final tx = _transactions[idx];
        final amount = tx['amount'] as int? ?? 0;
        final isPositive = amount > 0;
        final dateStr = tx['created_at'] != null
            ? DateFormat('MM/dd HH:mm').format(DateTime.parse(tx['created_at'] as String))
            : '';

        return ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: isPositive ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
            child: Icon(
              isPositive ? Icons.add_circle : Icons.remove_circle,
              color: isPositive ? const Color(0xFF4CAF50) : const Color(0xFFEF5350),
              size: 22,
            ),
          ),
          title: Text(
            tx['description'] as String? ?? '點數異動',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          trailing: Text(
            isPositive ? '+$amount Pts' : '$amount Pts',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
            ),
          ),
        );
      },
    );
  }
}
