import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  static const _databaseName = 'record_my_time.db';
  static const _databaseVersion = 7;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasesPath = await getDatabasesPath();
    final databasePath = p.join(databasesPath, _databaseName);

    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE todo_items (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              metric_type TEXT NOT NULL,
              progress_value INTEGER NOT NULL DEFAULT 0,
              is_system INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              archived_at TEXT
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE time_events ADD COLUMN linked_todo_id TEXT',
          );
          await db.execute(
            'ALTER TABLE time_events ADD COLUMN linked_todo_title TEXT',
          );
          await db.execute(
            "ALTER TABLE time_events ADD COLUMN record_mode TEXT NOT NULL DEFAULT 'duration'",
          );
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE notes (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              delta_json TEXT NOT NULL,
              plain_text_preview TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              archived_at TEXT
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE todo_items ADD COLUMN color_value INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE todo_items ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 7) {
          await db.execute(
            'ALTER TABLE time_events ADD COLUMN updated_at TEXT',
          );
          await db.execute(
            'UPDATE time_events SET updated_at = added_at WHERE updated_at IS NULL',
          );
          await db.execute(
            'ALTER TABLE todo_items ADD COLUMN updated_at TEXT',
          );
          await db.execute(
            'UPDATE todo_items SET updated_at = created_at WHERE updated_at IS NULL',
          );
          await db.execute('''
            CREATE TABLE deleted_records (
              record_key TEXT PRIMARY KEY,
              entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL,
              deleted_at TEXT NOT NULL
            )
          ''');
        }
      },
    );

    return _database!;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE time_events (
        id TEXT PRIMARY KEY,
        hours INTEGER NOT NULL,
        minutes INTEGER NOT NULL,
        description TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        added_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        type TEXT NOT NULL,
        linked_todo_id TEXT,
        linked_todo_title TEXT,
        record_mode TEXT NOT NULL DEFAULT 'duration'
      )
    ''');

    await db.execute('''
      CREATE TABLE todo_items (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        metric_type TEXT NOT NULL,
        progress_value INTEGER NOT NULL DEFAULT 0,
        is_system INTEGER NOT NULL DEFAULT 0,
        color_value INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        archived_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        delta_json TEXT NOT NULL,
        plain_text_preview TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        archived_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE deleted_records (
        record_key TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        deleted_at TEXT NOT NULL
      )
    ''');
  }
}
