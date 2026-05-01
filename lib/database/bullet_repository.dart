import '../models/bullet.dart';
import 'database_helper.dart';

class BulletRepository {
  final _helper = DatabaseHelper();

  Future<int> insert(Bullet bullet) async {
    final db = await _helper.database;
    return db.insert('bullets', bullet.toMap());
  }

  Future<void> update(Bullet bullet) async {
    final db = await _helper.database;
    await db.update('bullets', bullet.toMap(), where: 'id = ?', whereArgs: [bullet.id]);
  }

  Future<void> delete(int id) async {
    final db = await _helper.database;
    await db.delete('bullets', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Bullet>> getAll() async {
    final db = await _helper.database;
    final rows = await db.query('bullets', orderBy: 'name ASC');
    return rows.map(Bullet.fromMap).toList();
  }
}
