import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:baqati/models/package_event.dart';

/// Owns the SQLite connection, replacing the Kotlin's Room `AppDatabase`.
///
/// A [Database] can be injected directly, which lets tests point this at an
/// in-memory database without touching the filesystem.
class AppDatabase {
  AppDatabase({Database? database}) : _database = database;

  Database? _database;

  static const String _fileName = 'baqati.db';
  static const int _version = 1;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final String path = p.join(await getDatabasesPath(), _fileName);
    return openDatabase(path, version: _version, onCreate: onCreate);
  }

  /// Creates the schema.
  ///
  /// Exposed so tests can apply it to an in-memory database.
  static Future<void> onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${PackageEvent.tableName} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        minutes INTEGER,
        sms INTEGER,
        megabytes REAL,
        expiry_timestamp INTEGER,
        cost REAL,
        balance REAL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        source_hash TEXT
      )
    ''');

    // PORT-FIX: the Kotlin had no dedupe key of any kind, so every inbox sync
    // re-inserted the same carrier messages as fresh rows and history grew
    // duplicates without bound. SQLite permits multiple NULLs in a UNIQUE
    // index, which is exactly the behavior wanted here — manually-entered
    // events carry a NULL source_hash and must never collide with each other.
    await db.execute(
      'CREATE UNIQUE INDEX idx_events_source_hash '
      'ON ${PackageEvent.tableName}(source_hash)',
    );

    await db.execute(
      'CREATE INDEX idx_events_timestamp '
      'ON ${PackageEvent.tableName}(timestamp DESC)',
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
