import 'package:sqflite/sqflite.dart';

import 'local_database.dart';

class DeletedRecordService {
  static const entityTimeEvent = 'time_event';
  static const entityTodoItem = 'todo_item';
  static const entityNote = 'note';

  Future<void> recordDeletion({
    required String entityType,
    required String entityId,
    DateTime? deletedAt,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await LocalDatabase.instance.database;
    final at = deletedAt ?? DateTime.now();
    await db.insert(
      'deleted_records',
      {
        'record_key': '$entityType:$entityId',
        'entity_type': entityType,
        'entity_id': entityId,
        'deleted_at': at.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearDeletion({
    required String entityType,
    required String entityId,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await LocalDatabase.instance.database;
    await db.delete(
      'deleted_records',
      where: 'record_key = ?',
      whereArgs: ['$entityType:$entityId'],
    );
  }
}
