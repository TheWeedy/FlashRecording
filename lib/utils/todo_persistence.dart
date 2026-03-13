import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../models/todo_item.dart';
import 'local_database.dart';

class TodoPersistenceService {
  static const seedTodos = {
    'system-work': _SeedTodo('工作', 0xFF3B82F6),
    'system-study': _SeedTodo('学习', 0xFF22C55E),
    'system-play': _SeedTodo('娱乐', 0xFFF97316),
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
    int colorValue = 0xFF14B8A6,
  }) async {
    final db = await LocalDatabase.instance.database;
    await db.insert('todo_items', {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'title': title,
      'metric_type': 'duration',
      'progress_value': 0,
      'is_system': 0,
      'color_value': colorValue,
      'created_at': DateTime.now().toIso8601String(),
      'archived_at': null,
    });
  }

  Future<void> updateTodoColor({
    required String id,
    required int colorValue,
  }) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'todo_items',
      {
        'color_value': colorValue,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, Color>> loadTodoColorMap() async {
    await _ensureSeedTodos();
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'todo_items',
      columns: ['id', 'color_value'],
    );
    return {
      for (final row in rows)
        row['id'] as String: Color(_asInt(row['color_value'])),
    };
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
        t.color_value,
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
        t.color_value,
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
    final colorValue = _asInt(row['color_value']) == 0
        ? 0xFF14B8A6
        : _asInt(row['color_value']);
    return TodoItem(
      id: row['id'] as String,
      title: row['title'] as String,
      isSystem: (row['is_system'] as int) == 1,
      colorValue: colorValue,
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
          'title': entry.value.title,
          'metric_type': 'duration',
          'progress_value': 0,
          'is_system': 1,
          'color_value': entry.value.colorValue,
          'created_at': DateTime.fromMillisecondsSinceEpoch(0)
              .toIso8601String(),
          'archived_at': null,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      batch.update(
        'todo_items',
        {
          'title': entry.value.title,
          'color_value': entry.value.colorValue,
        },
        where: 'id = ?',
        whereArgs: [entry.key],
      );
    }

    batch.rawUpdate(
      '''
      UPDATE todo_items
      SET color_value = ?
      WHERE is_system = 0 AND color_value = 0
      ''',
      [0xFF14B8A6],
    );

    await batch.commit(noResult: true);
  }
}

class _SeedTodo {
  final String title;
  final int colorValue;

  const _SeedTodo(this.title, this.colorValue);
}
