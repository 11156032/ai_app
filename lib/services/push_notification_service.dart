import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("收到背景推播: ${message.messageId}");
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();

  factory PushNotificationService() {
    return _instance;
  }

  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      // 註冊背景處理器
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 設定前景顯示選項（讓 App 開著時也能跳出系統通知橫幅與聲音）
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 請求通知權限
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('使用者已授權推播通知');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('使用者已授權臨時推播通知');
      } else {
        debugPrint('使用者拒絕或尚未授權推播通知');
      }

      // 取得 FCM Token，後續可傳送至後端以便進行指定裝置的推播
      String? token = await _fcm.getToken();
      debugPrint('FCM Token: $token');

      // 註冊 Token 更新事件
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token 更新: $newToken');
      });

      // 預設訂閱全站廣播頻道 all_users
      await _fcm.subscribeToTopic('all_users');
      debugPrint('已成功訂閱全站推播 (all_users)');

      // 處理前景接收到的通知
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('前景收到推播: ${message.notification?.title} - ${message.notification?.body}');
      });

      _initialized = true;
    } catch (e) {
      debugPrint('FCM 初始化失敗: $e');
    }
  }

  /// 啟用或停用推播通知功能
  Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      if (enabled) {
        await _fcm.subscribeToTopic('all_users');
        debugPrint('已訂閱系統推播 (all_users)');
      } else {
        await _fcm.unsubscribeFromTopic('all_users');
        debugPrint('已取消訂閱系統推播 (all_users)');
      }
    } catch (e) {
      debugPrint('設定推播狀態失敗: $e');
    }
  }
}
