import '../models/rifle.dart';
import 'database_helper.dart';

class RifleRepository {
  final _helper = DatabaseHelper();

  Future<int> insert(Rifle rifle) async {
    final db = await _helper.database;
    return db.insert('rifles', rifle.toMap());
  }

  Future<void> update(Rifle rifle) async {
    final db = await _helper.database;
    await db.update('rifles', rifle.toMap(), where: 'id = ?', whereArgs: [rifle.id]);
  }

  Future<void> delete(int id) async {
    final db = await _helper.database;
    await db.delete('rifles', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Rifle>> getAll() async {
    final db = await _helper.database;
    final rows = await db.query('rifles', orderBy: 'name ASC');
    return rows.map(Rifle.fromMap).toList();
  }
}
