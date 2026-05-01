import '../models/session.dart';
import 'database_helper.dart';

class SessionRepository {
  final _helper = DatabaseHelper();

  Future<int> insert(Session session) async {
    final db = await _helper.database;
    return db.insert('sessions', session.toMap());
  }

  Future<void> update(Session session) async {
    final db = await _helper.database;
    await db.update('sessions', session.toMap(), where: 'id = ?', whereArgs: [session.id]);
  }

  Future<void> delete(int id) async {
    final db = await _helper.database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  Future<Session?> getById(int id) async {
    final db = await _helper.database;
    final rows = await db.query('sessions', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Session.fromMap(rows.first);
  }

  Future<List<Session>> getAll() async {
    final db = await _helper.database;
    final rows = await db.query('sessions', orderBy: 'created_at DESC');
    return rows.map(Session.fromMap).toList();
  }
}
