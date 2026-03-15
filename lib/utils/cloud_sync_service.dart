import 'dart:async';
import 'dart:convert';

import 'package:pocketbase/pocketbase.dart';

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

  static const _snapshotEntityType = 'app_state';
  static const _snapshotLocalId = 'full_snapshot';

  final SyncSettingsService _settingsService = SyncSettingsService();
  final PocketBaseAuthService _authService = PocketBaseAuthService();

  Timer? _debounceTimer;
  Future<void>? _activeSync;
  bool _pendingSync = false;
  bool _forceNextSync = false;
  DateTime? _lastCompletedAt;

  void scheduleSync({bool force = false}) {
    unawaited(_settingsService.markLocalDirty());
    _pendingSync = true;
    _forceNextSync = _forceNextSync || force;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(
      const Duration(seconds: 2),
      () {
        unawaited(_drainQueue());
      },
    );
  }

  Future<void> syncNow({
    bool force = false,
    bool throwOnError = false,
  }) async {
    _pendingSync = true;
    _forceNextSync = _forceNextSync || force;
    _debounceTimer?.cancel();
    await _drainQueue(throwOnError: throwOnError);
  }

  Future<void> _drainQueue({bool throwOnError = false}) async {
    if (_activeSync != null) {
      await _activeSync;
      if (!_pendingSync) {
        return;
      }
    }

    final completer = Completer<void>();
    _activeSync = completer.future;

    try {
      do {
        final force = _forceNextSync;
        _pendingSync = false;
        _forceNextSync = false;
        await _runSingleSync(force: force, throwOnError: throwOnError);
      } while (_pendingSync);
      completer.complete();
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      if (throwOnError) {
        rethrow;
      }
    } finally {
      _activeSync = null;
    }
  }

  Future<void> _runSingleSync({
    required bool force,
    required bool throwOnError,
  }) async {
    if (!force &&
        _lastCompletedAt != null &&
        DateTime.now().difference(_lastCompletedAt!) <
            const Duration(seconds: 8)) {
      return;
    }

    try {
      final settings = await _settingsService.load();
      if (!settings.isConfigured) {
        return;
      }

      final session = await _authService.loadSession(settings);
      if (!session.isLoggedIn || session.userId == null) {
        return;
      }

      final pb = await _authService.createClient(settings.serverUrl);
      final localSnapshot = await _buildLocalSnapshot();
      final localUpdatedAt = _snapshotUpdatedAt(localSnapshot);
      final localDirty = await _settingsService.isLocalDirty();
      final remoteRecord = await _loadRemoteSnapshot(pb, session.userId!);
      final remoteUpdatedAt = remoteRecord == null
          ? null
          : DateTime.tryParse('${remoteRecord.data['updated_at'] ?? ''}');

      if (remoteRecord == null ||
          force ||
          localDirty ||
          remoteUpdatedAt == null ||
          localUpdatedAt.isAfter(remoteUpdatedAt)) {
        await _uploadSnapshot(
          pb: pb,
          userId: session.userId!,
          remoteRecord: remoteRecord,
          snapshot: localSnapshot,
          updatedAt: localUpdatedAt,
        );
        await _settingsService.clearLocalDirty();
      } else if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
        final payloadJson = '${remoteRecord.data['payload_json'] ?? '{}'}';
        final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
        await _applyRemoteSnapshot(payload);
        await _settingsService.clearLocalDirty();
      }

      _lastCompletedAt = DateTime.now();
    } on ClientException catch (error) {
      final mapped = _mapClientException(error);
      if (throwOnError) {
        throw mapped;
      }
    } on CloudSyncException {
      if (throwOnError) {
        rethrow;
      }
    } catch (error) {
      if (throwOnError) {
        throw CloudSyncException('同步失败：$error');
      }
    }
  }

  Future<RecordModel?> _loadRemoteSnapshot(PocketBase pb, String userId) async {
    try {
      return await pb.collection('sync_records').getFirstListItem(
            'owner = "$userId" && entity_type = "$_snapshotEntityType" && local_id = "$_snapshotLocalId"',
          );
    } on ClientException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> _uploadSnapshot({
    required PocketBase pb,
    required String userId,
    required RecordModel? remoteRecord,
    required Map<String, dynamic> snapshot,
    required DateTime updatedAt,
  }) async {
    final body = <String, dynamic>{
      'owner': userId,
      'entity_type': _snapshotEntityType,
      'local_id': _snapshotLocalId,
      'payload_json': jsonEncode(snapshot),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': null,
    };
    if (remoteRecord == null) {
      await pb.collection('sync_records').create(body: body);
    } else {
      await pb.collection('sync_records').update(remoteRecord.id, body: body);
    }
  }

  Future<Map<String, dynamic>> _buildLocalSnapshot() async {
    final db = await LocalDatabase.instance.database;
    final timeEvents = await db.query('time_events', orderBy: 'added_at DESC');
    final todoItems = await db.query('todo_items', orderBy: 'sort_order ASC');
    final notes = await db.query('notes', orderBy: 'updated_at DESC');

    return {
      'schema_version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'time_events': timeEvents.map(_normalizeRow).toList(),
      'todo_items': todoItems.map(_normalizeRow).toList(),
      'notes': notes.map(_normalizeRow).toList(),
    };
  }

  Future<void> _applyRemoteSnapshot(Map<String, dynamic> snapshot) async {
    final db = await LocalDatabase.instance.database;
    final timeEvents = _normalizeSnapshotRows(snapshot['time_events']);
    final todoItems = _normalizeSnapshotRows(snapshot['todo_items']);
    final notes = _normalizeSnapshotRows(snapshot['notes']);

    await db.transaction((txn) async {
      await txn.delete('time_events');
      await txn.delete('todo_items');
      await txn.delete('notes');
      await txn.delete('deleted_records');

      final batch = txn.batch();
      for (final event in timeEvents) {
        batch.insert('time_events', event);
      }
      for (final todo in todoItems) {
        batch.insert('todo_items', todo);
      }
      for (final note in notes) {
        batch.insert('notes', note);
      }
      await batch.commit(noResult: true);
    });
  }

  List<Map<String, dynamic>> _normalizeSnapshotRows(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  DateTime _snapshotUpdatedAt(Map<String, dynamic> snapshot) {
    DateTime latest = DateTime.fromMillisecondsSinceEpoch(0);
    for (final section in ['time_events', 'todo_items', 'notes']) {
      final rows =
          (snapshot[section] as List<dynamic>? ?? const <dynamic>[]).cast<Map<String, dynamic>>();
      for (final row in rows) {
        final candidate = DateTime.tryParse(
          '${row['updated_at'] ?? row['created_at'] ?? row['added_at'] ?? ''}',
        );
        if (candidate != null && candidate.isAfter(latest)) {
          latest = candidate;
        }
      }
    }
    return latest;
  }

  Map<String, dynamic> _normalizeRow(Map<String, Object?> row) {
    return {
      for (final entry in row.entries) entry.key: entry.value,
    };
  }

  CloudSyncException _mapClientException(ClientException error) {
    final message = _extractMessage(error).toLowerCase();
    if (error.statusCode == 0) {
      return const CloudSyncException('无法连接到同步服务器，请检查网络和地址');
    }
    if (error.statusCode == 404 && message.contains('sync_records')) {
      return const CloudSyncException('服务器缺少 sync_records 集合，请先在 PocketBase 中创建');
    }
    if (error.statusCode == 400 && message.contains('sync_records')) {
      return const CloudSyncException('服务器中的 sync_records 字段不完整，请检查 owner、entity_type、local_id、payload_json、updated_at');
    }
    if (message.isNotEmpty) {
      return CloudSyncException(message);
    }
    return CloudSyncException('同步失败（${error.statusCode}）');
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
