import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  static const _databaseName = 'record_my_time.db';
  static const _databaseVersion = 11;

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
          await db.execute('ALTER TABLE todo_items ADD COLUMN updated_at TEXT');
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
        if (oldVersion < 8) {
          await _createFileLibraryTables(db);
        }
        if (oldVersion < 9) {
          await _addFileTagUpdatedAt(db);
        }
        if (oldVersion < 10) {
          await _addFileTagSortOrder(db);
        }
        if (oldVersion < 11) {
          await _addFileAiTitleGeneratedAt(db);
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
        ai_title_generated_at TEXT,
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

    await _createFileLibraryTables(db);
  }

  Future<void> _createFileLibraryTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS file_items (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        kind TEXT NOT NULL,
        mime_type TEXT NOT NULL DEFAULT '',
        original_url TEXT NOT NULL DEFAULT '',
        local_path TEXT NOT NULL DEFAULT '',
        markdown_path TEXT NOT NULL DEFAULT '',
        plain_text_preview TEXT NOT NULL DEFAULT '',
        size_bytes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        archived_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS file_tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _addFileTagUpdatedAt(db);
    await _addFileTagSortOrder(db);
    await _addFileAiTitleGeneratedAt(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS file_item_tags (
        file_item_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (file_item_id, tag_id),
        FOREIGN KEY (file_item_id) REFERENCES file_items(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES file_tags(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _addFileTagUpdatedAt(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(file_tags)');
    final hasUpdatedAt = columns.any(
      (column) => column['name'] == 'updated_at',
    );
    if (!hasUpdatedAt) {
      await db.execute(
        "ALTER TABLE file_tags ADD COLUMN updated_at TEXT NOT NULL DEFAULT ''",
      );
    }
    await db.execute(
      "UPDATE file_tags SET updated_at = created_at WHERE updated_at = ''",
    );
  }

  Future<void> _addFileTagSortOrder(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(file_tags)');
    final hasSortOrder = columns.any(
      (column) => column['name'] == 'sort_order',
    );
    if (!hasSortOrder) {
      await db.execute(
        'ALTER TABLE file_tags ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
      );
    }
    final rows = await db.query(
      'file_tags',
      columns: ['id'],
      orderBy: 'name COLLATE NOCASE ASC, created_at ASC',
    );
    final batch = db.batch();
    for (var index = 0; index < rows.length; index++) {
      batch.update(
        'file_tags',
        {'sort_order': index},
        where: 'id = ? AND sort_order = 0',
        whereArgs: [rows[index]['id']],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _addFileAiTitleGeneratedAt(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(file_items)');
    final hasAiTitleGeneratedAt = columns.any(
      (column) => column['name'] == 'ai_title_generated_at',
    );
    if (!hasAiTitleGeneratedAt) {
      await db.execute(
        'ALTER TABLE file_items ADD COLUMN ai_title_generated_at TEXT',
      );
    }
  }
}
