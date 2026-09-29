// lib/screens/main_screen_constants.part.dart
part of 'main_screen.dart';

// ── 社群貼文相關常量 (移至頂層以便分片檔案存取) ──
const Map<String, String?> kSocialFilterMap = {
  '全部': null,
  '📝 學習筆記': 'note',
  '💭 心情文章': 'mood',
  '📄 分享資料': 'doc',
  '📦 學習 Pack': 'learning_pack',
};

const Map<String, String> kPostTypeLabel = {
  'note': '📝 學習筆記',
  'mood': '💭 心情文章',
  'doc': '📄 分享資料',
  'learning_pack': '📦 學習 Pack',
};
