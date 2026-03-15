import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../models/todo_item.dart';
import 'cloud_sync_service.dart';
import 'local_database.dart';

class TodoPersistenceService {
  static const seedTodos = {
    'system-work': _SeedTodo('工作', 0xFF3B82F6, 0),
    'system-study': _SeedTodo('学习', 0xFF22C55E, 1),
    'system-play': _SeedTodo('娱乐', 0xFFF97316, 2),
  };

  Future<List<TodoItem>> loadActiveTodos() async {
    await _ensureSeedTodos();
    await _normalizeSortOrder();
    return _loadTodos(archived: false);
  }

  Future<List<TodoItem>> loadArchivedTodos() async {
    await _ensureSeedTodos();
    await _normalizeSortOrder();
    return _loadTodos(archived: true);
  }

  Future<List<TodoItem>> loadAvailableTagTodos() async {
    await _ensureSeedTodos();
    await _normalizeSortOrder();
    return _loadTodos(archived: false);
  }

  Future<void> createTodo({
    required String title,
    int colorValue = 0xFF14B8A6,
  }) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), -1) AS max_sort_order FROM todo_items',
    );
    final nextSortOrder = _asInt(rows.first['max_sort_order']) + 1;
    final now = DateTime.now().toIso8601String();
    await db.insert('todo_items', {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'title': title,
      'metric_type': 'duration',
      'progress_value': 0,
      'is_system': 0,
      'color_value': colorValue,
      'sort_order': nextSortOrder,
      'created_at': now,
      'updated_at': now,
      'archived_at': null,
    });
    CloudSyncService.instance.scheduleSync();
  }

  Future<void> updateTodoTitle({
    required String id,
    required String title,
  }) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'todo_items',
      {
        'title': title,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND is_system = 0',
      whereArgs: [id],
    );
    CloudSyncService.instance.scheduleSync();
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
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    CloudSyncService.instance.scheduleSync();
  }

  Future<void> updateTodoOrder(List<String> orderedIds) async {
    final db = await LocalDatabase.instance.database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (var index = 0; index < orderedIds.length; index++) {
      batch.update(
        'todo_items',
        {
          'sort_order': index,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [orderedIds[index]],
      );
    }
    await batch.commit(noResult: true);
    CloudSyncService.instance.scheduleSync();
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
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND is_system = 0',
      whereArgs: [id],
    );
    CloudSyncService.instance.scheduleSync();
  }

  Future<void> restoreTodo(String id) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'todo_items',
      {
        'archived_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    CloudSyncService.instance.scheduleSync();
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
      ORDER BY t.sort_order ASC, t.created_at ASC
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

  Future<void> _normalizeSortOrder() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'todo_items',
      columns: ['id'],
      orderBy: 'sort_order ASC, is_system DESC, created_at ASC',
    );
    final batch = db.batch();
    var hasChange = false;
    final now = DateTime.now().toIso8601String();
    for (var index = 0; index < rows.length; index++) {
      final id = rows[index]['id'] as String;
      final currentOrderRows = await db.query(
        'todo_items',
        columns: ['sort_order'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      final currentOrder = _asInt(currentOrderRows.first['sort_order']);
      if (currentOrder != index) {
        hasChange = true;
        batch.update(
          'todo_items',
          {
            'sort_order': index,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }
    if (hasChange) {
      await batch.commit(noResult: true);
    }
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
          'sort_order': entry.value.sortOrder,
          'created_at': DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
          'updated_at': DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
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
  final int sortOrder;

  const _SeedTodo(this.title, this.colorValue, this.sortOrder);
}
