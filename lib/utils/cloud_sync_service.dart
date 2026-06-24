import 'dart:async';
import 'dart:convert';

import 'package:pocketbase/pocketbase.dart';
import 'package:sqflite/sqflite.dart';

import 'deleted_record_service.dart';
import 'local_database.dart';
import 'pocketbase_auth_service.dart';
import 'sync_settings_service.dart';

class CloudSyncException implements Exception {
  const CloudSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CloudSyncService {
  CloudSyncService._();

  static final CloudSyncService instance = CloudSyncService._();

  static const _collection = 'sync_records';
  static const _legacySnapshotEntityType = 'app_state';
  static const _legacySnapshotLocalId = 'full_snapshot';
  static const _timeEvent = DeletedRecordService.entityTimeEvent;
  static const _todoItem = DeletedRecordService.entityTodoItem;
  static const _note = DeletedRecordService.entityNote;
  static const _fileItem = DeletedRecordService.entityFileItem;
  static const _fileTag = DeletedRecordService.entityFileTag;
  static const _debounceDuration = Duration(seconds: 5);
  static const _minimumSyncInterval = Duration(seconds: 20);
  static const _retryDelay = Duration(seconds: 45);
  static const _maxPushBatchSize = 40;

  static const _entityTables = <String, _TableSpec>{
    _timeEvent: _TableSpec(
      table: 'time_events',
      timestampColumn: 'updated_at',
      orderBy: 'added_at DESC',
    ),
    _todoItem: _TableSpec(
      table: 'todo_items',
      timestampColumn: 'updated_at',
      orderBy: 'sort_order ASC, created_at ASC',
    ),
    _note: _TableSpec(
      table: 'notes',
      timestampColumn: 'updated_at',
      orderBy: 'updated_at DESC',
    ),
    _fileItem: _TableSpec(
      table: 'file_items',
      timestampColumn: 'updated_at',
      orderBy: 'updated_at DESC',
    ),
    _fileTag: _TableSpec(
      table: 'file_tags',
      timestampColumn: 'updated_at',
      orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
    ),
  };

  final SyncSettingsService _settingsService = SyncSettingsService();
  final PocketBaseAuthService _authService = PocketBaseAuthService();

  Timer? _debounceTimer;
  Future<bool>? _activeSync;
  bool _pendingSync = false;
  bool _forceNextSync = false;
  DateTime? _lastAttemptAt;

  void scheduleSync() {
    unawaited(_settingsService.markLocalDirty());
    _pendingSync = true;
    // Local edits should upload after the debounce window even if a pull just
    // ran; otherwise the minimum interval makes sync look stalled.
    _forceNextSync = true;
    _scheduleDrain(_debounceDuration);
  }

  Future<void> syncNow({bool force = false, bool throwOnError = false}) async {
    final activeSync = _activeSync;
    if (activeSync != null && !force && !throwOnError) {
      await activeSync.catchError((_) => false);
      return;
    }

    _pendingSync = true;
    _forceNextSync = _forceNextSync || force;
    _debounceTimer?.cancel();
    await _drainQueue(throwOnError: throwOnError);
  }

  Future<void> pushLocalRecordNow({
    required String entityType,
    required String localId,
  }) async {
    try {
      final settings = await _settingsService.load();
      if (!settings.isConfigured) {
        return;
      }

      final session = await _authService.loadSession(settings);
      if (!session.isLoggedIn || session.userId == null) {
        return;
      }

      final localRecords = await _loadLocalRecords();
      final local = localRecords['$entityType:$localId'];
      if (local == null) {
        return;
      }

      final pb = await _authService.createClient(settings.serverUrl);
      final remote = await _findRemoteRecord(pb, session.userId!, local);
      if (remote == null ||
          local.changedAt.isAfter(remote.changedAt) ||
          local.changedAt.isAtSameMomentAs(remote.changedAt) &&
              !_recordsHaveSameContent(local, remote)) {
        await _pushRecordWithConflictRecovery(
          pb,
          session.userId!,
          _PushJob(local, remote: remote),
        );
      }
    } catch (_) {
      // The queued sync remains dirty and will retry; this best-effort path
      // keeps recent note edits from waiting behind unrelated sync work.
    }
  }

  void _scheduleDrain(Duration delay) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      unawaited(_drainQueue());
    });
  }

  Future<void> _drainQueue({bool throwOnError = false}) async {
    if (_activeSync != null) {
      try {
        await _activeSync;
      } catch (_) {
        if (throwOnError) {
          rethrow;
        }
      }
      if (!_pendingSync && !_forceNextSync) {
        return;
      }
    }

    if (!_pendingSync && !_forceNextSync) {
      return;
    }

    final force = _forceNextSync;
    final lastAttemptAt = _lastAttemptAt;
    if (!force && lastAttemptAt != null) {
      final elapsed = DateTime.now().difference(lastAttemptAt);
      if (elapsed < _minimumSyncInterval) {
        _scheduleDrain(_minimumSyncInterval - elapsed);
        return;
      }
    }

    _pendingSync = false;
    _forceNextSync = false;
    _lastAttemptAt = DateTime.now();

    final activeSync = _runSingleSync(throwOnError: throwOnError);
    _activeSync = activeSync;
    var succeeded = false;
    Object? syncError;
    StackTrace? syncStackTrace;
    try {
      succeeded = await activeSync;
    } catch (error, stackTrace) {
      syncError = error;
      syncStackTrace = stackTrace;
    } finally {
      _activeSync = null;
    }

    if (_pendingSync || _forceNextSync) {
      _scheduleDrain(_debounceDuration);
    } else if (!succeeded && await _settingsService.isLocalDirty()) {
      _pendingSync = true;
      _scheduleDrain(_retryDelay);
    }

    if (syncError != null) {
      Error.throwWithStackTrace(syncError, syncStackTrace!);
    }
  }

  Future<bool> _runSingleSync({required bool throwOnError}) async {
    try {
      final settings = await _settingsService.load();
      if (!settings.isConfigured) {
        return true;
      }

      final session = await _authService.loadSession(settings);
      if (!session.isLoggedIn || session.userId == null) {
        return true;
      }

      final pb = await _authService.createClient(settings.serverUrl);
      final localRecords = await _loadLocalRecords();
      final remoteRecords = await _loadRemoteRecords(pb, session.userId!);
      final keys = <String>{...localRecords.keys, ...remoteRecords.keys};
      final recordsToPush = <_PushJob>[];
      var changedLocal = false;

      for (final key in keys) {
        final local = localRecords[key];
        final remote = remoteRecords[key];
        if (local == null && remote == null) {
          continue;
        }

        if (remote == null) {
          recordsToPush.add(_PushJob(local!));
          continue;
        }

        if (local == null) {
          await _applyRemoteRecord(remote);
          changedLocal = true;
          continue;
        }

        final localChangedAt = local.changedAt;
        final remoteChangedAt = remote.changedAt;
        if (localChangedAt.isAfter(remoteChangedAt)) {
          recordsToPush.add(_PushJob(local, remote: remote));
        } else if (remoteChangedAt.isAfter(localChangedAt)) {
          await _applyRemoteRecord(remote);
          changedLocal = true;
        } else if (!_recordsHaveSameContent(local, remote)) {
          recordsToPush.add(_PushJob(local, remote: remote));
        }
      }

      final changedRemote = recordsToPush.isNotEmpty;
      if (changedRemote) {
        await _pushRecords(pb, session.userId!, recordsToPush);
      }

      if (changedLocal) {
        await _normalizeTodoSortOrder();
      }
      if (changedLocal ||
          changedRemote ||
          await _settingsService.isLocalDirty()) {
        await _settingsService.clearLocalDirty();
      }
      return true;
    } on ClientException catch (error) {
      final mapped = _mapClientException(error);
      if (throwOnError) {
        throw mapped;
      }
      return false;
    } on CloudSyncException {
      if (throwOnError) {
        rethrow;
      }
      return false;
    } catch (error) {
      if (throwOnError) {
        throw CloudSyncException('Sync failed: $error');
      }
      return false;
    }
  }

  Future<Map<String, _SyncRecord>> _loadLocalRecords() async {
    final db = await LocalDatabase.instance.database;
    final records = <String, _SyncRecord>{};

    for (final entry in _entityTables.entries) {
      final rows = await db.query(
        entry.value.table,
        orderBy: entry.value.orderBy,
      );
      for (final row in rows) {
        final id = '${row['id'] ?? ''}';
        if (id.isEmpty) {
          continue;
        }
        final payload = await _payloadForRow(
          db: db,
          entityType: entry.key,
          row: row,
        );
        final updatedAt = _parseDate(
          row[entry.value.timestampColumn],
          fallback: _fallbackRowTimestamp(row),
        );
        final record = _SyncRecord(
          entityType: entry.key,
          localId: id,
          payload: payload,
          updatedAt: updatedAt,
        );
        records[record.key] = record;
      }
    }

    final deletedRows = await db.query('deleted_records');
    for (final row in deletedRows) {
      final entityType = '${row['entity_type'] ?? ''}';
      final entityId = '${row['entity_id'] ?? ''}';
      if (!_entityTables.containsKey(entityType) || entityId.isEmpty) {
        continue;
      }
      final deletedAt = _parseDate(row['deleted_at']);
      final record = _SyncRecord(
        entityType: entityType,
        localId: entityId,
        payload: const {},
        updatedAt: deletedAt,
        deletedAt: deletedAt,
      );
      final existing = records[record.key];
      if (existing == null || record.changedAt.isAfter(existing.changedAt)) {
        records[record.key] = record;
      }
    }

    return records;
  }

  Future<Map<String, dynamic>> _payloadForRow({
    required Database db,
    required String entityType,
    required Map<String, Object?> row,
  }) async {
    final payload = _normalizeRow(row);
    if (entityType == _fileItem) {
      payload['local_path'] = '';
      payload['markdown_path'] = '';
      payload['tag_ids'] = await _loadFileItemTagIds(db, '${row['id']}');
    }
    return payload;
  }

  Future<List<String>> _loadFileItemTagIds(Database db, String itemId) async {
    final rows = await db.query(
      'file_item_tags',
      columns: ['tag_id'],
      where: 'file_item_id = ?',
      whereArgs: [itemId],
      orderBy: 'tag_id ASC',
    );
    return rows.map((row) => '${row['tag_id']}').toList();
  }

  Future<Map<String, _RemoteSyncRecord>> _loadRemoteRecords(
    PocketBase pb,
    String userId,
  ) async {
    final rows = await pb
        .collection(_collection)
        .getFullList(filter: 'owner = "$userId"', sort: 'entity_type,local_id');
    final records = <String, _RemoteSyncRecord>{};
    RecordModel? legacySnapshot;

    for (final row in rows) {
      final entityType = '${row.data['entity_type'] ?? ''}';
      final localId = '${row.data['local_id'] ?? ''}';
      if (entityType == _legacySnapshotEntityType &&
          localId == _legacySnapshotLocalId) {
        legacySnapshot = row;
        continue;
      }
      if (!_entityTables.containsKey(entityType) || localId.isEmpty) {
        continue;
      }
      final record = _RemoteSyncRecord.fromRecord(row);
      records[record.key] = record;
    }

    if (records.isEmpty && legacySnapshot != null) {
      records.addAll(_recordsFromLegacySnapshot(legacySnapshot));
    }

    return records;
  }

  Map<String, _RemoteSyncRecord> _recordsFromLegacySnapshot(RecordModel row) {
    final payloadJson = '${row.data['payload_json'] ?? '{}'}';
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map) {
      return const {};
    }
    final snapshot = Map<String, dynamic>.from(decoded);
    final records = <String, _RemoteSyncRecord>{};
    final sections = {
      _timeEvent: 'time_events',
      _todoItem: 'todo_items',
      _note: 'notes',
    };
    for (final entry in sections.entries) {
      final rows = snapshot[entry.value];
      if (rows is! List) {
        continue;
      }
      for (final rawRow in rows.whereType<Map>()) {
        final payload = Map<String, dynamic>.from(rawRow);
        final id = '${payload['id'] ?? ''}';
        if (id.isEmpty) {
          continue;
        }
        final updatedAt = _parseDate(
          payload['updated_at'],
          fallback: _fallbackRowTimestamp(payload),
        );
        final record = _RemoteSyncRecord(
          entityType: entry.key,
          localId: id,
          payload: payload,
          updatedAt: updatedAt,
        );
        records[record.key] = record;
      }
    }
    return records;
  }

  Future<void> _pushRecords(
    PocketBase pb,
    String userId,
    List<_PushJob> jobs,
  ) async {
    for (var start = 0; start < jobs.length; start += _maxPushBatchSize) {
      final end = (start + _maxPushBatchSize).clamp(0, jobs.length);
      final batchJobs = jobs.sublist(start, end);
      await _pushBatch(pb, userId, batchJobs);
    }
  }

  Future<void> _pushBatch(
    PocketBase pb,
    String userId,
    List<_PushJob> jobs,
  ) async {
    if (jobs.isEmpty) {
      return;
    }
    if (jobs.length == 1) {
      await _pushRecordWithConflictRecovery(pb, userId, jobs.single);
      return;
    }

    final batch = pb.createBatch();
    final collection = batch.collection(_collection);
    for (final job in jobs) {
      final body = _remoteBody(userId, job.local);
      final recordId = job.remote?.recordId;
      if (recordId == null) {
        collection.create(body: body);
      } else {
        collection.update(recordId, body: body);
      }
    }

    try {
      final results = await batch.send();
      for (
        var index = 0;
        index < results.length && index < jobs.length;
        index++
      ) {
        final status = results[index].status.toInt();
        if (status >= 400) {
          await _pushRecordWithConflictRecovery(pb, userId, jobs[index]);
        }
      }
    } on ClientException {
      for (final job in jobs) {
        await _pushRecordWithConflictRecovery(pb, userId, job);
      }
    }
  }

  Future<void> _pushRecordWithConflictRecovery(
    PocketBase pb,
    String userId,
    _PushJob job,
  ) async {
    final local = job.local;
    try {
      await _pushRecord(pb, userId, local, remote: job.remote);
    } on ClientException catch (error) {
      if (job.remote?.recordId != null && error.statusCode == 404) {
        await _pushRecord(pb, userId, local);
        return;
      }
      if (!_isLikelyCreateConflict(error)) {
        rethrow;
      }
      final remote = await _findRemoteRecord(pb, userId, local);
      if (remote == null) {
        rethrow;
      }
      if (local.changedAt.isAfter(remote.changedAt)) {
        await _pushRecord(pb, userId, local, remote: remote);
      }
    }
  }

  Future<void> _pushRecord(
    PocketBase pb,
    String userId,
    _SyncRecord local, {
    _RemoteSyncRecord? remote,
  }) async {
    final body = _remoteBody(userId, local);
    if (remote?.recordId == null) {
      await pb.collection(_collection).create(body: body);
    } else {
      await pb.collection(_collection).update(remote!.recordId!, body: body);
    }
  }

  Map<String, dynamic> _remoteBody(String userId, _SyncRecord local) {
    final deletedAt = local.deletedAt == null
        ? null
        : _remoteDateString(local.deletedAt!);
    return <String, dynamic>{
      'owner': userId,
      'entity_type': local.entityType,
      'local_id': local.localId,
      'payload_json': jsonEncode(local.payload),
      'updated_at': _remoteDateString(local.updatedAt),
      'deleted_at': deletedAt,
    };
  }

  String _remoteDateString(DateTime value) => value.toUtc().toIso8601String();

  bool _recordsHaveSameContent(_SyncRecord local, _SyncRecord remote) {
    if ((local.deletedAt == null) != (remote.deletedAt == null)) {
      return false;
    }
    return jsonEncode(_canonicalJson(local.payload)) ==
        jsonEncode(_canonicalJson(remote.payload));
  }

  Object? _canonicalJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => '$key').toList()..sort();
      return {for (final key in keys) key: _canonicalJson(value[key])};
    }
    if (value is Iterable) {
      return value.map(_canonicalJson).toList();
    }
    return value;
  }

  Future<_RemoteSyncRecord?> _findRemoteRecord(
    PocketBase pb,
    String userId,
    _SyncRecord local,
  ) async {
    final filter =
        'owner = "${_escapePocketBaseFilterValue(userId)}" && '
        'entity_type = "${_escapePocketBaseFilterValue(local.entityType)}" && '
        'local_id = "${_escapePocketBaseFilterValue(local.localId)}"';
    try {
      final row = await pb.collection(_collection).getFirstListItem(filter);
      return _RemoteSyncRecord.fromRecord(row);
    } on ClientException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  bool _isLikelyCreateConflict(ClientException error) {
    if (error.statusCode != 400 && error.statusCode != 409) {
      return false;
    }
    final message = _extractMessage(error).toLowerCase();
    return message.contains('unique') ||
        message.contains('already') ||
        message.contains('exists') ||
        message.contains('conflict') ||
        message.contains('duplicate');
  }

  String _escapePocketBaseFilterValue(String value) {
    return value.replaceAll('\\', r'\\').replaceAll('"', r'\"');
  }

  Future<void> _applyRemoteRecord(_RemoteSyncRecord remote) async {
    final db = await LocalDatabase.instance.database;
    await db.transaction((txn) async {
      if (remote.isDeleted) {
        await _applyRemoteDelete(txn, remote);
      } else {
        await _applyRemoteUpsert(txn, remote);
      }
    });
  }

  Future<void> _applyRemoteDelete(
    Transaction txn,
    _RemoteSyncRecord remote,
  ) async {
    final spec = _entityTables[remote.entityType];
    if (spec == null) {
      return;
    }
    if (remote.entityType == _fileItem) {
      await txn.delete(
        'file_item_tags',
        where: 'file_item_id = ?',
        whereArgs: [remote.localId],
      );
    } else if (remote.entityType == _fileTag) {
      await txn.delete(
        'file_item_tags',
        where: 'tag_id = ?',
        whereArgs: [remote.localId],
      );
    }
    await txn.delete(spec.table, where: 'id = ?', whereArgs: [remote.localId]);
    await DeletedRecordService().recordDeletion(
      entityType: remote.entityType,
      entityId: remote.localId,
      deletedAt: remote.deletedAt,
      executor: txn,
    );
  }

  Future<void> _applyRemoteUpsert(
    Transaction txn,
    _RemoteSyncRecord remote,
  ) async {
    final spec = _entityTables[remote.entityType];
    if (spec == null) {
      return;
    }
    final payload = Map<String, dynamic>.from(remote.payload);
    final tagIds = payload.remove('tag_ids');
    await DeletedRecordService().clearDeletion(
      entityType: remote.entityType,
      entityId: remote.localId,
      executor: txn,
    );

    if (remote.entityType == _fileItem) {
      final existing = await txn.query(
        'file_items',
        columns: ['local_path', 'markdown_path'],
        where: 'id = ?',
        whereArgs: [remote.localId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        payload['local_path'] = existing.first['local_path'];
        payload['markdown_path'] = existing.first['markdown_path'];
      } else {
        payload['local_path'] = '';
        payload['markdown_path'] = '';
      }
    }

    await txn.insert(
      spec.table,
      payload,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (remote.entityType == _fileItem && tagIds is List) {
      await txn.delete(
        'file_item_tags',
        where: 'file_item_id = ?',
        whereArgs: [remote.localId],
      );
      final batch = txn.batch();
      for (final tagId in tagIds) {
        batch.insert('file_item_tags', {
          'file_item_id': remote.localId,
          'tag_id': '$tagId',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    }
  }

  Future<void> _normalizeTodoSortOrder() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'todo_items',
      columns: ['id'],
      orderBy: 'sort_order ASC, is_system DESC, created_at ASC',
    );
    final batch = db.batch();
    for (var index = 0; index < rows.length; index++) {
      batch.update(
        'todo_items',
        {'sort_order': index},
        where: 'id = ?',
        whereArgs: [rows[index]['id']],
      );
    }
    await batch.commit(noResult: true);
  }

  Map<String, dynamic> _normalizeRow(Map<String, Object?> row) {
    return {for (final entry in row.entries) entry.key: entry.value};
  }

  DateTime _fallbackRowTimestamp(Map<dynamic, dynamic> row) {
    return _parseDate(row['created_at'] ?? row['added_at']);
  }

  DateTime _parseDate(Object? value, {DateTime? fallback}) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    if (parsed != null) {
      return parsed;
    }
    return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  CloudSyncException _mapClientException(ClientException error) {
    final message = _extractMessage(error).toLowerCase();
    if (error.statusCode == 0) {
      return const CloudSyncException(
        'Could not reach the sync server. Check the network and URL.',
      );
    }
    if (error.statusCode == 404 && message.contains(_collection)) {
      return const CloudSyncException(
        'The sync_records collection is missing on the server.',
      );
    }
    if (error.statusCode == 400 && message.contains(_collection)) {
      return const CloudSyncException(
        'The sync_records schema is incomplete. Check owner, entity_type, local_id, payload_json, updated_at, and deleted_at.',
      );
    }
    if (message.isNotEmpty) {
      return CloudSyncException(message);
    }
    return CloudSyncException('Sync failed (${error.statusCode})');
  }

  String _extractMessage(ClientException error) {
    final response = error.response;
    if (response.isEmpty) {
      return '';
    }
    final topLevel = response['message'];
    if (topLevel is String && topLevel.trim().isNotEmpty) {
      return topLevel.trim();
    }
    final data = response['data'];
    if (data is Map) {
      for (final entry in data.values) {
        if (entry is Map && entry['message'] is String) {
          final message = (entry['message'] as String).trim();
          if (message.isNotEmpty) {
            return message;
          }
        }
      }
    }
    return '';
  }
}

class _TableSpec {
  const _TableSpec({
    required this.table,
    required this.timestampColumn,
    required this.orderBy,
  });

  final String table;
  final String timestampColumn;
  final String orderBy;
}

class _SyncRecord {
  const _SyncRecord({
    required this.entityType,
    required this.localId,
    required this.payload,
    required this.updatedAt,
    this.deletedAt,
  });

  final String entityType;
  final String localId;
  final Map<String, dynamic> payload;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  String get key => '$entityType:$localId';
  DateTime get changedAt => deletedAt ?? updatedAt;
}

class _PushJob {
  const _PushJob(this.local, {this.remote});

  final _SyncRecord local;
  final _RemoteSyncRecord? remote;
}

class _RemoteSyncRecord extends _SyncRecord {
  const _RemoteSyncRecord({
    required super.entityType,
    required super.localId,
    required super.payload,
    required super.updatedAt,
    super.deletedAt,
    this.recordId,
  });

  factory _RemoteSyncRecord.fromRecord(RecordModel record) {
    final payloadJson = '${record.data['payload_json'] ?? '{}'}';
    final decoded = jsonDecode(payloadJson);
    final payload = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    final deletedAt = _parseSyncDate(record.data['deleted_at']);
    final payloadUpdatedAt = _parseSyncDate(payload['updated_at']);
    final remoteUpdatedAt = _parseSyncDate(record.data['updated_at']);
    return _RemoteSyncRecord(
      recordId: record.id,
      entityType: '${record.data['entity_type'] ?? ''}',
      localId: '${record.data['local_id'] ?? ''}',
      payload: payload,
      updatedAt:
          payloadUpdatedAt ??
          remoteUpdatedAt ??
          DateTime.fromMillisecondsSinceEpoch(0),
      deletedAt: deletedAt,
    );
  }

  final String? recordId;

  bool get isDeleted => deletedAt != null;
}

DateTime? _parseSyncDate(Object? value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}
