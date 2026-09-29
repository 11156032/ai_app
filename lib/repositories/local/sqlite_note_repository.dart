import 'package:sqflite/sqflite.dart';
import '../../database/database_helper.dart';
import '../../models/note_model.dart';
import '../note_repository.dart';

class SqliteNoteRepository implements NoteRepository {
  @override
  Future<List<NoteModel>> getNotesByUser(String userId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'voice_notes',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => NoteModel.fromMap(r)).toList();
  }

  @override
  Future<void> saveNote(NoteModel note) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'voice_notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteNote(String noteId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'voice_notes',
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }
}
