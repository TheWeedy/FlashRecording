import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/time_event.dart';
import 'todo_persistence.dart';
import 'local_database.dart';

class PersistenceService {
  static const String _legacyEventsKey = 'events';
  static const String _legacyBackupKey = 'events_legacy_backup';
  static const String _migrationDoneKey = 'events_migration_done';
  static const String _todoLinkBackfillDoneKey = 'todo_link_backfill_done';

  Future<List<TimeEvent>> loadEvents() async {
    await _migrateLegacyEventsIfNeeded();
    await _backfillLegacyTodoLinksIfNeeded();

    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'time_events',
      orderBy: 'added_at DESC',
    );

    if (rows.isNotEmpty) {
      return rows
          .map(
            (row) => TimeEvent.fromJson({
              'id': row['id'],
              'hours': row['hours'],
              'minutes': row['minutes'],
              'description': row['description'],
              'note': row['note'],
              'addedAt': row['added_at'],
              'type': row['type'],
              'linkedTodoId': row['linked_todo_id'],
              'linkedTodoTitle': row['linked_todo_title'],
              'recordMode': row['record_mode'],
            }),
          )
          .toList();
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_legacyEventsKey) ?? '[]';
    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList
        .map((e) => TimeEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveEvents(List<TimeEvent> events) async {
    final db = await LocalDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.delete('time_events');
      final batch = txn.batch();
      for (final event in events) {
        batch.insert('time_events', {
          'id': event.id,
          'hours': event.hours,
          'minutes': event.minutes,
          'description': event.description,
          'note': event.note,
          'added_at': event.addedAt.toIso8601String(),
          'type': event.type.name,
          'linked_todo_id': event.linkedTodoId,
          'linked_todo_title': event.linkedTodoTitle,
          'record_mode': event.recordMode.name,
        });
      }
      await batch.commit(noResult: true);
    });

    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString(_legacyEventsKey, jsonString);
  }

  Future<void> _migrateLegacyEventsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationDoneKey) == true) {
      return;
    }

    final db = await LocalDatabase.instance.database;
    final existingCount = await _queryEventCount(db);
    if (existingCount > 0) {
      await prefs.setBool(_migrationDoneKey, true);
      return;
    }

    final legacyJson = prefs.getString(_legacyEventsKey);
    if (legacyJson == null || legacyJson.trim().isEmpty || legacyJson == '[]') {
      await prefs.setBool(_migrationDoneKey, true);
      return;
    }

    final List<dynamic> jsonList = jsonDecode(legacyJson) as List<dynamic>;
    final legacyEvents = jsonList
        .map((e) => TimeEvent.fromJson(e as Map<String, dynamic>))
        .toList();

    if (legacyEvents.isEmpty) {
      await prefs.setBool(_migrationDoneKey, true);
      return;
    }

    await prefs.setString(_legacyBackupKey, legacyJson);

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final event in legacyEvents) {
        batch.insert('time_events', {
          'id': event.id,
          'hours': event.hours,
          'minutes': event.minutes,
          'description': event.description,
          'note': event.note,
          'added_at': event.addedAt.toIso8601String(),
          'type': event.type.name,
          'linked_todo_id': event.linkedTodoId,
          'linked_todo_title': event.linkedTodoTitle,
          'record_mode': event.recordMode.name,
        });
      }
      await batch.commit(noResult: true);
    });

    final migratedCount = await _queryEventCount(db);
    if (migratedCount == legacyEvents.length) {
      await prefs.setBool(_migrationDoneKey, true);
    }
  }

  Future<void> _backfillLegacyTodoLinksIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_todoLinkBackfillDoneKey) == true) {
      return;
    }

    final db = await LocalDatabase.instance.database;
    final batch = db.batch();

    for (final entry in TodoPersistenceService.seedTodos.entries) {
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

    await db.rawUpdate('''
      UPDATE time_events
      SET
        linked_todo_id = CASE type
          WHEN 'work' THEN 'system-work'
          WHEN 'study' THEN 'system-study'
          WHEN 'play' THEN 'system-play'
          ELSE linked_todo_id
        END,
        linked_todo_title = CASE type
          WHEN 'work' THEN '工作'
          WHEN 'study' THEN '学习'
          WHEN 'play' THEN '娱乐'
          ELSE linked_todo_title
        END
      WHERE linked_todo_id IS NULL OR linked_todo_title IS NULL
    ''');

    await prefs.setBool(_todoLinkBackfillDoneKey, true);
  }

  Future<int> _queryEventCount(Database db) async {
    final result = await db.rawQuery('SELECT COUNT(*) AS count FROM time_events');
    if (result.isEmpty) {
      return 0;
    }

    final value = result.first['count'];
    if (value is int) {
      return value;
    }

    return int.tryParse('$value') ?? 0;
  }
}
