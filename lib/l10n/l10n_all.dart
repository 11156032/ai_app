import 'l10n_ai.dart';
import 'l10n_auth.dart';
import 'l10n_main.dart';
import 'l10n_misc.dart';
import 'l10n_notes.dart';
import 'l10n_profile.dart';
import 'l10n_quiz.dart';
import 'l10n_social.dart';
import 'l10n_widgets.dart';

/// 所有功能模組的翻譯對照表
const Map<String, Map<String, String>> l10nAll = {
  ...l10nAi,
  ...l10nAuth,
  ...l10nMain,
  ...l10nMisc,
  ...l10nNotes,
  ...l10nProfile,
  ...l10nQuiz,
  ...l10nSocial,
  ...l10nWidgets,
};
