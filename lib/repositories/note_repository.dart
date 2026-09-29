import '../models/note_model.dart';

abstract class NoteRepository {
  Future<List<NoteModel>> getNotesByUser(String userId);
  Future<void> saveNote(NoteModel note);
  Future<void> deleteNote(String noteId);
}
