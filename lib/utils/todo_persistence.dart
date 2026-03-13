import 'package:sqflite/sqflite.dart';

import '../models/todo_item.dart';
import 'local_database.dart';

class TodoPersistenceService {
  static const _seedIds = {
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

  Future<void> createTodo({
    required String title,
    required TodoMetricType metricType,
  }) async {
    final db = await LocalDatabase.instance.database;
    await db.insert('todo_items', {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'title': title,
      'metric_type': metricType.name,
      'progress_value': 0,
      'is_system': 0,
      'created_at': DateTime.now().toIso8601String(),
      'archived_at': null,
    });
  }

  Future<void> incrementTodo(TodoItem item, int amount) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'todo_items',
      {
        'progress_value': item.progressValue + amount,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
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

  Future<List<TodoItem>> _loadTodos({required bool archived}) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'todo_items',
      where: archived ? 'archived_at IS NOT NULL' : 'archived_at IS NULL',
      orderBy: 'is_system DESC, created_at ASC',
    );

    return rows.map(_mapRow).toList();
  }

  TodoItem _mapRow(Map<String, Object?> row) {
    return TodoItem(
      id: row['id'] as String,
      title: row['title'] as String,
      metricType: TodoMetricType.values.firstWhere(
        (value) => value.name == row['metric_type'],
      ),
      progressValue: row['progress_value'] as int,
      isSystem: (row['is_system'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      archivedAt: row['archived_at'] == null
          ? null
          : DateTime.parse(row['archived_at'] as String),
    );
  }

  Future<void> _ensureSeedTodos() async {
    final db = await LocalDatabase.instance.database;
    final batch = db.batch();

    for (final entry in _seedIds.entries) {
      batch.insert(
        'todo_items',
        {
          'id': entry.key,
          'title': entry.value,
          'metric_type': TodoMetricType.duration.name,
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
