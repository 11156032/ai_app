import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ai_app/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.setTestDbPath(':memory:');
  });

  group('Group 4-Digit Code & QR Code / Invite Tests', () {
    test('1. Create group generates 4-digit numeric code and token', () async {
      final groupId = await DatabaseHelper.instance.createGroup(
        name: '4碼測試群組',
        description: '測試 4 碼加入碼與 QR Code',
        iconEmoji: '🧪',
        type: 'public',
        ownerId: 'u1',
        joinRequiresApproval: false,
        tags: ['測試', '4碼'],
      );

      final group = await DatabaseHelper.instance.getGroupById(groupId);
      expect(group, isNotNull);
      expect(group!['name'], equals('4碼測試群組'));

      final code = group['invite_code']?.toString();
      expect(code, isNotNull);
      expect(code!.length, equals(4));
      expect(int.tryParse(code), isNotNull);
      expect(int.parse(code) >= 1000 && int.parse(code) <= 9999, isTrue);

      final token = group['invite_token']?.toString();
      expect(token, isNotNull);
      expect(token!.isNotEmpty, isTrue);
    });

    test('2. Query group by 4-digit code, token, and deep link URL', () async {
      final groupId = await DatabaseHelper.instance.createGroup(
        name: '高等數學研習社',
        description: '數學愛好者專用',
        iconEmoji: '📐',
        type: 'public',
        ownerId: 'u1',
        joinRequiresApproval: false,
      );

      final group = await DatabaseHelper.instance.getGroupById(groupId);
      final code = group!['invite_code'].toString();
      final token = group['invite_token'].toString();

      // A. 透過 4 碼數字查詢
      final byCode = await DatabaseHelper.instance.getGroupByInviteCode(code);
      expect(byCode, isNotNull);
      expect(byCode!['id'], equals(groupId));
      expect(byCode['name'], equals('高等數學研習社'));

      // B. 透過 token 查詢
      final byToken = await DatabaseHelper.instance.getGroupByInviteCode(token);
      expect(byToken, isNotNull);
      expect(byToken!['id'], equals(groupId));

      // C. 透過相容方法 getGroupByToken 查詢 4 碼
      final byLegacy = await DatabaseHelper.instance.getGroupByToken(code);
      expect(byLegacy, isNotNull);
      expect(byLegacy!['id'], equals(groupId));

      // D. 透過完整 URL 查詢 (app://join?code=XXXX&token=...)
      final url = 'app://join?code=$code&token=$token&ref=u1&type=auto';
      final byUrl = await DatabaseHelper.instance.getGroupByInviteCode(url);
      expect(byUrl, isNotNull);
      expect(byUrl!['id'], equals(groupId));
    });

    test('3. Regenerate 4-digit code and token invalidates previous code', () async {
      final groupId = await DatabaseHelper.instance.createGroup(
        name: '物理實驗小組',
        description: '量子力學研討',
        iconEmoji: '🔬',
        type: 'public',
        ownerId: 'u1',
        joinRequiresApproval: false,
      );

      final initialGroup = await DatabaseHelper.instance.getGroupById(groupId);
      final oldCode = initialGroup!['invite_code'].toString();
      final oldToken = initialGroup['invite_token'].toString();

      // 重新生成
      final newMap = await DatabaseHelper.instance.regenerateInviteTokenAndCode(groupId);
      final newCode = newMap['code']!;
      final newToken = newMap['token']!;

      expect(newCode.length, equals(4));
      expect(newCode, isNot(equals(oldCode)));
      expect(newToken, isNot(equals(oldToken)));

      // 舊 4 碼應無法查詢
      final queryOldCode = await DatabaseHelper.instance.getGroupByInviteCode(oldCode);
      expect(queryOldCode, isNull);

      // 新 4 碼應能正確查到
      final queryNewCode = await DatabaseHelper.instance.getGroupByInviteCode(newCode);
      expect(queryNewCode, isNotNull);
      expect(queryNewCode!['id'], equals(groupId));
    });

    test('4. Join public group vs private group workflow', () async {
      // 公開群組直接加入
      final publicGroupId = await DatabaseHelper.instance.createGroup(
        name: '全民英語角',
        description: '自由練習口說',
        iconEmoji: '🗣️',
        type: 'public',
        ownerId: 'u1',
        joinRequiresApproval: false,
      );

      // u2 透過 4 碼加入公開群組
      final pubGroup = await DatabaseHelper.instance.getGroupById(publicGroupId);
      final pubCode = pubGroup!['invite_code'].toString();
      final targetPubGroup = await DatabaseHelper.instance.getGroupByInviteCode(pubCode);
      expect(targetPubGroup, isNotNull);

      await DatabaseHelper.instance.joinGroup(publicGroupId, 'u2', isPending: false);
      final m2 = await DatabaseHelper.instance.getGroupMembership(publicGroupId, 'u2');
      expect(m2, isNotNull);
      expect(m2!['status'], equals('active'));

      final updatedPub = await DatabaseHelper.instance.getGroupById(publicGroupId);
      expect(updatedPub!['member_count'], equals(2));

      // 私人群組申請加入
      final privateGroupId = await DatabaseHelper.instance.createGroup(
        name: '秘密考題研究會',
        description: '私人群組須審核',
        iconEmoji: '🔒',
        type: 'private',
        ownerId: 'u1',
        joinRequiresApproval: true,
      );

      final privGroup = await DatabaseHelper.instance.getGroupById(privateGroupId);
      final privCode = privGroup!['invite_code'].toString();
      final targetPriv = await DatabaseHelper.instance.getGroupByInviteCode(privCode);
      expect(targetPriv, isNotNull);

      await DatabaseHelper.instance.joinGroup(privateGroupId, 'u2', isPending: true);
      final mPriv = await DatabaseHelper.instance.getGroupMembership(privateGroupId, 'u2');
      expect(mPriv, isNotNull);
      expect(mPriv!['status'], equals('pending'));

      // 審核通過
      await DatabaseHelper.instance.approveGroupRequest(privateGroupId, 'u2', true);
      final mApproved = await DatabaseHelper.instance.getGroupMembership(privateGroupId, 'u2');
      expect(mApproved!['status'], equals('active'));

      final updatedPriv = await DatabaseHelper.instance.getGroupById(privateGroupId);
      expect(updatedPriv!['member_count'], equals(2));
    });

    test('5. Disabled or Expired invite code cannot be joined', () async {
      final groupId = await DatabaseHelper.instance.createGroup(
        name: '短期衝刺營',
        description: '即將關閉的群組',
        iconEmoji: '⚡',
        type: 'public',
        ownerId: 'u1',
        joinRequiresApproval: false,
      );

      final group = await DatabaseHelper.instance.getGroupById(groupId);
      final code = group!['invite_code'].toString();

      // 關閉邀請
      await DatabaseHelper.instance.setInviteLinkActive(groupId, false);
      final queryInactive = await DatabaseHelper.instance.getGroupByInviteCode(code);
      expect(queryInactive, isNull);

      // 重新開啟
      await DatabaseHelper.instance.setInviteLinkActive(groupId, true);
      final queryActive = await DatabaseHelper.instance.getGroupByInviteCode(code);
      expect(queryActive, isNotNull);

      // 設定過期時間為昨天
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await DatabaseHelper.instance.setTokenExpiry(groupId, yesterday);
      final queryExpired = await DatabaseHelper.instance.getGroupByInviteCode(code);
      expect(queryExpired, isNull);
    });
  });
}
