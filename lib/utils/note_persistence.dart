import 'package:sqflite/sqflite.dart';

import '../models/note_item.dart';
import 'cloud_sync_service.dart';
import 'deleted_record_service.dart';
import 'local_database.dart';

class NotePersistenceService {
  final DeletedRecordService _deletedRecordService = DeletedRecordService();

  Future<List<NoteItem>> loadActiveNotes() async {
    return _loadNotes(archived: false);
  }

  Future<List<NoteItem>> loadArchivedNotes() async {
    return _loadNotes(archived: true);
  }

  Future<void> upsertNote(NoteItem note) async {
    final db = await LocalDatabase.instance.database;
    await db.insert(
      'notes',
      {
        'id': note.id,
        'title': note.title,
        'delta_json': note.deltaJson,
        'plain_text_preview': note.plainTextPreview,
        'created_at': note.createdAt.toIso8601String(),
        'updated_at': note.updatedAt.toIso8601String(),
        'archived_at': note.archivedAt?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _deletedRecordService.clearDeletion(
      entityType: DeletedRecordService.entityNote,
      entityId: note.id,
    );
    CloudSyncService.instance.scheduleSync();
  }

  Future<void> archiveNote(String id) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'notes',
      {
        'archived_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    CloudSyncService.instance.scheduleSync();
  }

  Future<void> restoreNote(String id) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'notes',
      {
        'archived_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    CloudSyncService.instance.scheduleSync();
  }

  Future<void> deleteNotes(Iterable<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final db = await LocalDatabase.instance.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(
      'notes',
      where: 'id IN ($placeholders)',
      whereArgs: ids.toList(),
    );
    for (final id in ids) {
      await _deletedRecordService.recordDeletion(
        entityType: DeletedRecordService.entityNote,
        entityId: id,
      );
    }
    CloudSyncService.instance.scheduleSync();
  }

  Future<List<NoteItem>> _loadNotes({required bool archived}) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'notes',
      where: archived ? 'archived_at IS NOT NULL' : 'archived_at IS NULL',
      orderBy: 'updated_at DESC',
    );

    return rows
        .map(
          (row) => NoteItem(
            id: row['id'] as String,
            title: row['title'] as String,
            deltaJson: row['delta_json'] as String,
            plainTextPreview: row['plain_text_preview'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
            updatedAt: DateTime.parse(row['updated_at'] as String),
            archivedAt: row['archived_at'] == null
                ? null
                : DateTime.parse(row['archived_at'] as String),
          ),
        )
        .toList();
  }
}
