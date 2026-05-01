import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'shotlog.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE rifles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        caliber TEXT,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE bullets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        weight_gr REAL,
        caliber TEXT,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        ended_at TEXT,
        shot_count INTEGER DEFAULT 0,
        rifle_id INTEGER REFERENCES rifles(id),
        bullet_id INTEGER REFERENCES bullets(id),
        distance_m REAL,
        weather TEXT,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE shots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES sessions(id),
        shot_number INTEGER NOT NULL,
        detected_at TEXT NOT NULL,
        clip_path TEXT NOT NULL,
        shot_offset_ms INTEGER NOT NULL,
        thumbnail_path TEXT
      )
    ''');
  }
}
