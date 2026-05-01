import '../models/shot.dart';
import 'database_helper.dart';

class ShotRepository {
  final _helper = DatabaseHelper();

  Future<int> insert(Shot shot) async {
    final db = await _helper.database;
    return db.insert('shots', shot.toMap());
  }

  Future<List<Shot>> getBySession(int sessionId) async {
    final db = await _helper.database;
    final rows = await db.query(
      'shots',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'shot_number ASC',
    );
    return rows.map(Shot.fromMap).toList();
  }

  Future<void> updateThumbnail(int shotId, String thumbnailPath) async {
    final db = await _helper.database;
    await db.update(
      'shots',
      {'thumbnail_path': thumbnailPath},
      where: 'id = ?',
      whereArgs: [shotId],
    );
  }

  Future<void> deleteBySession(int sessionId) async {
    final db = await _helper.database;
    await db.delete('shots', where: 'session_id = ?', whereArgs: [sessionId]);
  }
}
