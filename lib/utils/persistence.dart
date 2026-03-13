import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/time_event.dart';
import 'local_database.dart';

class PersistenceService {
  static const String _legacyEventsKey = 'events';
  static const String _legacyBackupKey = 'events_legacy_backup';
  static const String _migrationDoneKey = 'events_migration_done';

  Future<List<TimeEvent>> loadEvents() async {
    await _migrateLegacyEventsIfNeeded();

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
        });
      }
      await batch.commit(noResult: true);
    });

    final migratedCount = await _queryEventCount(db);
    if (migratedCount == legacyEvents.length) {
      await prefs.setBool(_migrationDoneKey, true);
    }
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
