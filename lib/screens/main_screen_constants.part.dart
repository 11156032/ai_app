// lib/screens/main_screen_constants.part.dart
part of 'main_screen.dart';

// ── 社群貼文相關常量 (移至頂層以便分片檔案存取) ──
const Map<String, String?> kSocialFilterMap = {
  '全部': null,
  '📝 学习笔记': 'note',
  '💭 心情文章': 'mood',
  '📄 分享资料': 'doc',
  '📦 学习 Pack': 'learning_pack',
};

const Map<String, String> kPostTypeLabel = {
  'note': '📝 学习笔记',
  'mood': '💭 心情文章',
  'doc': '📄 分享资料',
};
