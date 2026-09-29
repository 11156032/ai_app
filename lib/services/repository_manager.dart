import '../repositories/note_repository.dart';
import '../repositories/local/sqlite_note_repository.dart';

class RepositoryManager {
  RepositoryManager._internal();
  static final RepositoryManager instance = RepositoryManager._internal();

  /// 💡 組員未來完成雲端實作後，只需將此開關改為 true 即可全面切換至雲端！
  static const bool useCloudDatabase = false;

  late final NoteRepository noteRepository;

  void initialize() {
    if (useCloudDatabase) {
      // noteRepository = CloudNoteRepository(); // 未來組員完成雲端實作後填入此處
      noteRepository = SqliteNoteRepository();
    } else {
      noteRepository = SqliteNoteRepository();
    }
  }
}
