import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum AppUpdateType {
  none,
  optional,
  force,
}

class AppConfigService {
  AppConfigService._internal();
  static final AppConfigService instance = AppConfigService._internal();

  FirebaseRemoteConfig? _remoteConfig;

  // 狀態監聽器
  final ValueNotifier<bool> isMaintenanceNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> maintenanceMsgNotifier = ValueNotifier<String>('');
  final ValueNotifier<AppUpdateType> updateTypeNotifier =
      ValueNotifier<AppUpdateType>(AppUpdateType.none);

  String _currentAppVersion = '1.0.0';
  String _minVersion = '1.0.0';
  String _latestVersion = '1.0.0';
  String _updateUrl = '';
  String _maintenanceMsg =
      '伺服器目前正在進行例行升級與維護，預計稍後恢復，感謝您的耐心等待！';

  bool get isMaintenance => isMaintenanceNotifier.value;
  String get maintenanceMsg => maintenanceMsgNotifier.value;
  String get currentAppVersion => _currentAppVersion;
  String get minVersion => _minVersion;
  String get latestVersion => _latestVersion;
  String get updateUrl => _updateUrl;
  AppUpdateType get updateType => updateTypeNotifier.value;

  /// 初始化 Remote Config 並拉取遠端最新參數
  Future<void> initialize() async {
    try {
      // 取得本地安裝之 App 實際版本號
      final packageInfo = await PackageInfo.fromPlatform();
      _currentAppVersion = packageInfo.version;
      debugPrint('📱 [AppConfigService] 本地 App 版本: $_currentAppVersion');
    } catch (e) {
      debugPrint('⚠️ [AppConfigService] 無法取得 PackageInfo: $e');
    }

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // 配置快取策略：開發除錯模式設為 0 秒（即時反映），生產環境設為 10 分鐘
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(minutes: 10),
      ));

      // 設定預設值（離線或初次載入之兜底）
      await _remoteConfig!.setDefaults(<String, dynamic>{
        'is_maintenance': false,
        'maintenance_msg': _maintenanceMsg,
        'min_version': _currentAppVersion,
        'latest_version': _currentAppVersion,
        'update_url': '',
      });

      // 拉取並啟用最新配置
      await _remoteConfig!.fetchAndActivate().timeout(
            const Duration(seconds: 4),
            onTimeout: () => false,
          );

      _syncFromRemoteConfig();
    } catch (e) {
      debugPrint('⚠️ [AppConfigService] Firebase Remote Config 初始化失敗: $e');
      _syncFromRemoteConfig();
    }
    _applyDemoRemote();
  }

  // TODO(demo): 影片錄製用，錄完即移除。Web 建置加 --dart-define=DEMO_REMOTE=true，
  // 網址帶 ?demo_remote=maint|optional|force 模擬 Remote Config 的維護與更新狀態。
  static const bool _kDemoRemote = bool.fromEnvironment('DEMO_REMOTE');
  void _applyDemoRemote() {
    if (!_kDemoRemote) return;
    final mode = Uri.base.queryParameters['demo_remote'];
    final p = _currentAppVersion.split('+').first.split('.');
    final major = int.tryParse(p.first) ?? 1;
    final minor = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    if (mode == 'maint') {
      isMaintenanceNotifier.value = true;
      maintenanceMsgNotifier.value = _maintenanceMsg;
    } else if (mode == 'optional') {
      _latestVersion = '$major.${minor + 1}.0';
    } else if (mode == 'force') {
      _minVersion = '${major + 1}.0.0';
      _latestVersion = _minVersion;
    } else {
      return;
    }
    _evaluateUpdateType();
  }

  /// 重新檢查最新狀態（用於維護頁面點擊「重新檢查」按鈕）
  Future<bool> recheck() async {
    try {
      if (_remoteConfig != null) {
        await _remoteConfig!.fetchAndActivate().timeout(
              const Duration(seconds: 4),
              onTimeout: () => false,
            );
        _syncFromRemoteConfig();
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ [AppConfigService] 重新整理失敗: $e');
    }
    return false;
  }

  void _syncFromRemoteConfig() {
    if (_remoteConfig != null) {
      final isMaint = _remoteConfig!.getBool('is_maintenance');
      final msg = _remoteConfig!.getString('maintenance_msg');
      final minVer = _remoteConfig!.getString('min_version');
      final latestVer = _remoteConfig!.getString('latest_version');
      final url = _remoteConfig!.getString('update_url');

      _minVersion = minVer.isNotEmpty ? minVer : _currentAppVersion;
      _latestVersion = latestVer.isNotEmpty ? latestVer : _currentAppVersion;
      _updateUrl = url;
      _maintenanceMsg = msg.isNotEmpty ? msg : _maintenanceMsg;

      isMaintenanceNotifier.value = isMaint;
      maintenanceMsgNotifier.value = _maintenanceMsg;

      // 檢查版本更新類型
      _evaluateUpdateType();

      debugPrint(
          '🔍 [AppConfigService] 同步成功 ➜ is_maintenance: $isMaint | min_version: $_minVersion | latest_version: $_latestVersion | update_url: $_updateUrl');
    }
  }

  void _evaluateUpdateType() {
    // 若處於維護狀態，維護優先
    if (isMaintenance) {
      updateTypeNotifier.value = AppUpdateType.none;
      return;
    }

    // 當前版本 < 最低版本 ➜ 強制更新 (Force Update)
    if (_isVersionLower(_currentAppVersion, _minVersion)) {
      updateTypeNotifier.value = AppUpdateType.force;
      return;
    }

    // 最低版本 <= 當前版本 < 最新版本 ➜ 建議更新 (Optional Update)
    if (_isVersionLower(_currentAppVersion, _latestVersion)) {
      updateTypeNotifier.value = AppUpdateType.optional;
      return;
    }

    updateTypeNotifier.value = AppUpdateType.none;
  }

  /// 語意化版本號比對 (Semantic Version Comparison)
  /// 若 v1 < v2 則返回 true
  bool _isVersionLower(String v1, String v2) {
    try {
      // 去除 build number 例如 '1.8.0+1' ➜ '1.8.0'
      final cleanV1 = v1.split('+').first.trim();
      final cleanV2 = v2.split('+').first.trim();

      final parts1 =
          cleanV1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final parts2 =
          cleanV2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;

      for (int i = 0; i < maxLen; i++) {
        final num1 = i < parts1.length ? parts1[i] : 0;
        final num2 = i < parts2.length ? parts2[i] : 0;

        if (num1 < num2) return true;
        if (num1 > num2) return false;
      }
      return false; // 兩者相等
    } catch (_) {
      return false;
    }
  }
}
