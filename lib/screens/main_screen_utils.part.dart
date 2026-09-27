// lib/screens/main_screen_utils.part.dart
part of 'main_screen.dart';

// Utility helpers extracted from MainScreen state
extension _MainScreenStateUtils on _MainScreenState {
  int _getTopicMemberCount(String topicId) {
    if (_topicMemberCounts.containsKey(topicId)) {
      return _topicMemberCounts[topicId] ??
          (_userJoinedTopicIds.contains(topicId) ? 1 : 0);
    }
    return _userJoinedTopicIds.contains(topicId) ? 1 : 0;
  }

  int _getTopicPostCount(String topicId) {
    return _topicPostCounts[topicId] ?? 0;
  }

  void _scrollToTopSocialFeed() {
    if (_socialFeedScrollController.hasClients) {
      _socialFeedScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }
}
