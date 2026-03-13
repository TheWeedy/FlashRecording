import 'package:sqflite/sqflite.dart';

import '../models/todo_item.dart';
import 'local_database.dart';

class TodoPersistenceService {
  static const seedTodos = {
    'system-work': '工作',
    'system-study': '学习',
    'system-play': '娱乐',
  };

  Future<List<TodoItem>> loadActiveTodos() async {
    await _ensureSeedTodos();
    return _loadTodos(archived: false);
  }

  Future<List<TodoItem>> loadArchivedTodos() async {
    await _ensureSeedTodos();
    return _loadTodos(archived: true);
  }

  Future<List<TodoItem>> loadAvailableTagTodos() async {
    await _ensureSeedTodos();
    return _loadTodos(archived: false);
  }

  Future<void> createTodo({
    required String title,
  }) async {
    final db = await LocalDatabase.instance.database;
    await db.insert('todo_items', {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'title': title,
      'metric_type': 'duration',
      'progress_value': 0,
      'is_system': 0,
      'created_at': DateTime.now().toIso8601String(),
      'archived_at': null,
    });
  }

  Future<void> archiveTodo(String id) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'todo_items',
      {
        'archived_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND is_system = 0',
      whereArgs: [id],
    );
  }

  Future<void> restoreTodo(String id) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'todo_items',
      {
        'archived_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<TodoItem?> findTodoById(String id) async {
    await _ensureSeedTodos();
    final db = await LocalDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        t.id,
        t.title,
        t.is_system,
        t.created_at,
        t.archived_at,
        COUNT(e.id) AS total_count,
        COALESCE(
          SUM(
            CASE
              WHEN e.record_mode = 'count' THEN 0
              ELSE (e.hours * 60) + e.minutes
            END
          ),
          0
        ) AS total_duration_minutes
      FROM todo_items t
      LEFT JOIN time_events e ON e.linked_todo_id = t.id
      WHERE t.id = ?
      GROUP BY t.id, t.title, t.is_system, t.created_at, t.archived_at
      ''',
      [id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapRow(rows.first);
  }

  Future<List<TodoItem>> _loadTodos({required bool archived}) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        t.id,
        t.title,
        t.is_system,
        t.created_at,
        t.archived_at,
        COUNT(e.id) AS total_count,
        COALESCE(
          SUM(
            CASE
              WHEN e.record_mode = 'count' THEN 0
              ELSE (e.hours * 60) + e.minutes
            END
          ),
          0
        ) AS total_duration_minutes
      FROM todo_items t
      LEFT JOIN time_events e ON e.linked_todo_id = t.id
      WHERE ${archived ? 't.archived_at IS NOT NULL' : 't.archived_at IS NULL'}
      GROUP BY t.id, t.title, t.is_system, t.created_at, t.archived_at
      ORDER BY t.is_system DESC, t.created_at ASC
      ''',
    );

    return rows.map(_mapRow).toList();
  }

  TodoItem _mapRow(Map<String, Object?> row) {
    return TodoItem(
      id: row['id'] as String,
      title: row['title'] as String,
      isSystem: (row['is_system'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      archivedAt: row['archived_at'] == null
          ? null
          : DateTime.parse(row['archived_at'] as String),
      totalCount: _asInt(row['total_count']),
      totalDurationMinutes: _asInt(row['total_duration_minutes']),
    );
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  Future<void> _ensureSeedTodos() async {
    final db = await LocalDatabase.instance.database;
    final batch = db.batch();

    for (final entry in seedTodos.entries) {
      batch.insert(
        'todo_items',
        {
          'id': entry.key,
          'title': entry.value,
          'metric_type': 'duration',
          'progress_value': 0,
          'is_system': 1,
          'created_at': DateTime.fromMillisecondsSinceEpoch(0)
              .toIso8601String(),
          'archived_at': null,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    await batch.commit(noResult: true);
  }
}
