import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

class InsufficientPointsException implements Exception {
  final int requiredPoints;
  final int currentPoints;
  final String actionName;

  InsufficientPointsException({
    required this.requiredPoints,
    required this.currentPoints,
    required this.actionName,
  });

  @override
  String toString() =>
      '點數不足：$actionName 需要 $requiredPoints 點，當前剩餘 $currentPoints 點。';
}

class MembershipTierInfo {
  final String code;
  final String name;
  final String badgeLabel;
  final int dailyBonus;
  final double discountRate; // 1.0 = 原價, 0.9 = 9折
  final int badgeColorValue;
  final String description;

  const MembershipTierInfo({
    required this.code,
    required this.name,
    required this.badgeLabel,
    required this.dailyBonus,
    required this.discountRate,
    required this.badgeColorValue,
    required this.description,
  });
}

class MembershipService {
  MembershipService._();
  static final MembershipService instance = MembershipService._();

  static const Map<String, MembershipTierInfo> tiers = {
    'free': MembershipTierInfo(
      code: 'free',
      name: '普通會員',
      badgeLabel: 'FREE',
      dailyBonus: 10,
      discountRate: 1.0,
      badgeColorValue: 0xFF8D6E63, // 經典微棕
      description: '享受基本 AI 學習功能，每日簽到贈送 10 點',
    ),
    'silver': MembershipTierInfo(
      code: 'silver',
      name: '白銀 VIP',
      badgeLabel: 'SILVER',
      dailyBonus: 20,
      discountRate: 0.9,
      badgeColorValue: 0xFF78909C, // 白銀金屬藍灰
      description: 'AI 詢問點數享 9 折優惠，每日登入贈送 20 點',
    ),
    'gold': MembershipTierInfo(
      code: 'gold',
      name: '黃金 VIP',
      badgeLabel: 'GOLD',
      dailyBonus: 50,
      discountRate: 0.8,
      badgeColorValue: 0xFFFFB300, // 尊榮黃金琥珀
      description: 'AI 詢問點數享 8 折優惠，每日登入贈送 50 點',
    ),
    'diamond': MembershipTierInfo(
      code: 'diamond',
      name: '鑽石 VIP',
      badgeLabel: 'DIAMOND',
      dailyBonus: 100,
      discountRate: 0.5,
      badgeColorValue: 0xFF7E57C2, // 璀璨璀璨紫色/藍光
      description: 'AI 詢問點數享 5 折半價，每日登入贈送 100 點',
    ),
  };

  /// 取得使用者目前的生效階級（包含過期判斷）
  Future<String> getEffectiveTier(String userId) async {
    final info = await DatabaseHelper.instance.getUserMembershipInfo(userId);
    final rawTier = (info['membership_tier'] as String? ?? 'free').toLowerCase();
    final expiresIso = info['membership_expires_at'] as String?;

    if (rawTier == 'free' || expiresIso == null || expiresIso.isEmpty) {
      return rawTier;
    }

    try {
      final expiresAt = DateTime.parse(expiresIso);
      if (DateTime.now().isAfter(expiresAt)) {
        // 已過期，降級為 free
        await DatabaseHelper.instance.updateUserMembershipTier(userId, 'free', null);
        return 'free';
      }
    } catch (_) {}

    return rawTier;
  }

  /// 計算折抵後的實際點數需求
  int calculateDiscountedCost(String tierCode, int basePoints) {
    final tier = tiers[tierCode] ?? tiers['free']!;
    final calculated = (basePoints * tier.discountRate).round();
    return calculated < 1 ? 1 : calculated;
  }

  /// 檢查並扣除點數
  Future<int> deductPoints({
    required String userId,
    required String actionType,
    required int basePoints,
    required String description,
  }) async {
    final effectiveTier = await getEffectiveTier(userId);
    final finalCost = calculateDiscountedCost(effectiveTier, basePoints);
    final info = await DatabaseHelper.instance.getUserMembershipInfo(userId);
    final currentPoints = info['points_balance'] as int? ?? 0;

    if (currentPoints < finalCost) {
      throw InsufficientPointsException(
        requiredPoints: finalCost,
        currentPoints: currentPoints,
        actionName: description,
      );
    }

    final newPoints = currentPoints - finalCost;
    await DatabaseHelper.instance.updateUserPoints(userId, newPoints);
    await DatabaseHelper.instance.addPointTransaction(
      userId: userId,
      amount: -finalCost,
      type: actionType,
      description: '$description (消耗 $finalCost 點)',
    );

    debugPrint('PointDeduction: User $userId spent $finalCost points for $actionType. Balance: $newPoints');
    return finalCost;
  }

  /// 檢查今日是否已簽到
  Future<bool> hasClaimedDailyBonusToday(String userId) async {
    final info = await DatabaseHelper.instance.getUserMembershipInfo(userId);
    final lastClaimIso = info['last_daily_reward_at'] as String?;
    if (lastClaimIso == null || lastClaimIso.isEmpty) return false;

    try {
      final lastClaim = DateTime.parse(lastClaimIso);
      final now = DateTime.now();
      return lastClaim.year == now.year &&
          lastClaim.month == now.month &&
          lastClaim.day == now.day;
    } catch (_) {
      return false;
    }
  }

  /// 每日簽到領取點數
  Future<int> claimDailyBonus(String userId) async {
    final alreadyClaimed = await hasClaimedDailyBonusToday(userId);
    if (alreadyClaimed) {
      throw Exception('今日已完成簽到領取，明日再來吧！');
    }

    final effectiveTier = await getEffectiveTier(userId);
    final tierInfo = tiers[effectiveTier] ?? tiers['free']!;
    final bonusPoints = tierInfo.dailyBonus;

    final info = await DatabaseHelper.instance.getUserMembershipInfo(userId);
    final currentPoints = info['points_balance'] as int? ?? 0;
    final newPoints = currentPoints + bonusPoints;

    final nowIso = DateTime.now().toIso8601String();
    await DatabaseHelper.instance.updateUserPoints(userId, newPoints);
    await DatabaseHelper.instance.updateDailyRewardClaimed(userId, nowIso);
    await DatabaseHelper.instance.addPointTransaction(
      userId: userId,
      amount: bonusPoints,
      type: 'daily_reward',
      description: '每日簽到獎勵 (${tierInfo.name})',
    );

    return bonusPoints;
  }

  /// 模擬購買/儲值點數包
  Future<void> simulatedPurchasePoints({
    required String userId,
    required int pointsAmount,
    required double priceTwd,
    required String packageName,
  }) async {
    final info = await DatabaseHelper.instance.getUserMembershipInfo(userId);
    final currentPoints = info['points_balance'] as int? ?? 0;
    final newPoints = currentPoints + pointsAmount;

    await DatabaseHelper.instance.updateUserPoints(userId, newPoints);
    await DatabaseHelper.instance.addPointTransaction(
      userId: userId,
      amount: pointsAmount,
      type: 'recharge',
      description: '模擬儲值：$packageName (NT\$ ${priceTwd.toInt()})',
    );
  }

  /// 模擬升級會員方案
  Future<void> simulatedUpgradeTier({
    required String userId,
    required String targetTier,
    required int durationDays,
    required double priceTwd,
    int? bonusPoints,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(Duration(days: durationDays));

    await DatabaseHelper.instance.updateUserMembershipTier(
      userId,
      targetTier,
      expiresAt.toIso8601String(),
    );

    final tierInfo = tiers[targetTier] ?? tiers['free']!;
    await DatabaseHelper.instance.addPointTransaction(
      userId: userId,
      amount: 0,
      type: 'tier_upgrade',
      description: '模擬升級：${tierInfo.name} ($durationDays 天, NT\$ ${priceTwd.toInt()})',
    );

    // 如果升級附贈點數
    if (bonusPoints != null && bonusPoints > 0) {
      final info = await DatabaseHelper.instance.getUserMembershipInfo(userId);
      final currentPoints = info['points_balance'] as int? ?? 0;
      final newPoints = currentPoints + bonusPoints;
      await DatabaseHelper.instance.updateUserPoints(userId, newPoints);
      await DatabaseHelper.instance.addPointTransaction(
        userId: userId,
        amount: bonusPoints,
        type: 'recharge',
        description: '升級 VIP 禮包贈送點數',
      );
    }
  }
}
