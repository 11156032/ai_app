import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel_v2',
    '高優先級系統推播',
    description: '用於發送重要活動與系統即時通知',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      // 註冊背景處理器
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 設定前景顯示選項 (iOS)
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 初始化本地通知套件（用於 Android 前景彈出系統橫幅）
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: DarwinInitializationSettings(),
      );

      await _localNotifications.initialize(initializationSettings);

      // 建立 Android 高優先級通知頻道
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

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

      // 取得 FCM Token
      String? token = await _fcm.getToken();
      debugPrint('FCM Token: $token');

      // 註冊 Token 更新事件
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token 更新: $newToken');
      });

      // 預設訂閱全站廣播頻道 all_users
      await _fcm.subscribeToTopic('all_users');
      debugPrint('已成功訂閱全站推播 (all_users)');

      // 處理前景接收到的通知（當 App 開著時，主動跳出本地系統橫幅通知）
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('前景收到推播: ${message.notification?.title} - ${message.notification?.body}');
        RemoteNotification? notification = message.notification;
        if (notification != null && !kIsWeb) {
          try {
            await _localNotifications.show(
              notification.hashCode,
              notification.title,
              notification.body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  _channel.id,
                  _channel.name,
                  channelDescription: _channel.description,
                  icon: '@mipmap/ic_launcher',
                  importance: Importance.max,
                  priority: Priority.high,
                  playSound: true,
                  enableVibration: true,
                ),
                iOS: const DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
            );
            debugPrint('成功觸發本地推播顯示');
          } catch (e) {
            debugPrint('本地推播顯示失敗: $e');
          }
        }
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
