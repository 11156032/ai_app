// lib/screens/main_screen_timers.part.dart
part of 'main_screen.dart';

// Timer helpers extracted from MainScreen state
extension _MainScreenStateTimers on _MainScreenState {
  /// 清除所有與貼文相關的計時器
  void _clearPostTimers() {
    for (var t in _postTimers) {
      t.cancel();
    }
    _postTimers.clear();
  }
}
