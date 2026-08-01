import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'readings.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE readings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            site_id TEXT,
            value REAL,
            lat REAL,
            lng REAL,
            timestamp TEXT,
            photo_path TEXT,
            sync_status TEXT DEFAULT 'pending_sync',
            had_mismatch INTEGER DEFAULT 0,
            capture_hash TEXT,
            previous_hash TEXT
          )
        ''');
      },
    );
  }

  static Future<int> insertReading(Map<String, dynamic> reading) async {
    final db = await database;
    return db.insert('readings', reading);
  }

  static Future<List<Map<String, dynamic>>> getAllReadings() async {
    final db = await database;
    return db.query('readings', orderBy: 'id DESC');
  }

  static Future<List<Map<String, dynamic>>> getPendingReadings() async {
    final db = await database;
    return db.query('readings', where: "sync_status = 'pending_sync'");
  }

  static Future<void> markSynced(int id) async {
    final db = await database;
    await db.update('readings', {'sync_status': 'synced'},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<String?> getLatestHash() async {
    final db = await database;
    final result = await db.query('readings', orderBy: 'id DESC', limit: 1);
    if (result.isEmpty) return null;
    return result.first['capture_hash'] as String?;
  }
}