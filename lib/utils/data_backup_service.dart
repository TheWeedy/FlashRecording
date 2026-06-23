import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'local_database.dart';

class DataBackupException implements Exception {
  const DataBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DataBackupResult {
  const DataBackupResult({required this.path, required this.sizeBytes});

  final String path;
  final int sizeBytes;
}

class DataRestoreResult {
  const DataRestoreResult({required this.path});

  final String path;
}

class DataBackupService {
  static const _manifestPath = 'manifest.json';
  static const _databaseEntryPath = 'database/record_my_time.db';
  static const _knowledgeEntryPrefix = 'knowledge/';

  Future<DataBackupResult?> exportAllData() async {
    await _ensureDatabaseExists();
    await LocalDatabase.instance.close();

    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      p.join(
        tempDir.path,
        'recordmytime-backup-${DateTime.now().microsecondsSinceEpoch}.zip',
      ),
    );
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final encoder = ZipFileEncoder();
    var encoderOpen = false;
    try {
      encoder.create(tempFile.path);
      encoderOpen = true;
      encoder.addArchiveFile(
        ArchiveFile.string(_manifestPath, _manifestJson()),
      );
      await encoder.addFile(
        File(await LocalDatabase.instance.databasePath),
        _databaseEntryPath,
      );

      final knowledgeDirectory = await _knowledgeDirectory();
      if (await knowledgeDirectory.exists()) {
        await encoder.addDirectory(
          knowledgeDirectory,
          includeDirName: true,
          followLinks: false,
        );
      }
    } catch (_) {
      throw const DataBackupException('Could not prepare the backup file.');
    } finally {
      if (encoderOpen) {
        await encoder.close();
      }
    }

    final bytes = await tempFile.readAsBytes();
    final targetPath = await FilePicker.saveFile(
      dialogTitle: 'Export RecordMyTime data',
      fileName: _defaultBackupFileName(),
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      bytes: bytes,
    );
    await tempFile.delete().catchError((_) => tempFile);
    if (targetPath == null) {
      return null;
    }
    return DataBackupResult(path: targetPath, sizeBytes: bytes.length);
  }

  Future<DataRestoreResult?> importAllData() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Import RecordMyTime data',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
    );
    final pickedPath = result?.files.single.path;
    if (pickedPath == null || pickedPath.isEmpty) {
      return null;
    }

    final archive = await _readArchive(pickedPath);
    final databaseEntry = archive.findFile(_databaseEntryPath);
    if (databaseEntry == null || !databaseEntry.isFile) {
      throw const DataBackupException(
        'The backup does not contain a database.',
      );
    }

    final tempRoot = await Directory.systemTemp.createTemp(
      'recordmytime-restore-',
    );
    try {
      final tempDatabase = File(p.join(tempRoot.path, 'record_my_time.db'));
      await tempDatabase.writeAsBytes(databaseEntry.content, flush: true);
      await _validateDatabase(tempDatabase);

      final tempKnowledge = Directory(p.join(tempRoot.path, 'knowledge'));
      await _extractKnowledge(archive, tempKnowledge);

      await LocalDatabase.instance.close();
      await _replaceDatabase(tempDatabase);
      await _replaceKnowledgeDirectory(tempKnowledge);
    } catch (error) {
      if (error is DataBackupException) {
        rethrow;
      }
      throw const DataBackupException('Could not restore the backup.');
    } finally {
      await tempRoot.delete(recursive: true).catchError((_) => tempRoot);
      for (final file in archive.files) {
        file.closeSync();
      }
    }

    return DataRestoreResult(path: pickedPath);
  }

  Future<void> _ensureDatabaseExists() async {
    final db = await LocalDatabase.instance.database;
    await db.rawQuery('SELECT 1');
  }

  Future<Archive> _readArchive(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const DataBackupException('The backup file is invalid.');
    }
  }

  Future<void> _validateDatabase(File databaseFile) async {
    Database? db;
    try {
      db = await openDatabase(databaseFile.path, readOnly: true);
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'time_events'",
      );
      if (rows.isEmpty) {
        throw const DataBackupException(
          'The backup database is not compatible.',
        );
      }
    } finally {
      await db?.close();
    }
  }

  Future<void> _replaceDatabase(File sourceDatabase) async {
    final databasePath = await LocalDatabase.instance.databasePath;
    final target = File(databasePath);
    if (!await target.parent.exists()) {
      await target.parent.create(recursive: true);
    }
    for (final path in [
      databasePath,
      '$databasePath-wal',
      '$databasePath-shm',
      '$databasePath-journal',
    ]) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await sourceDatabase.copy(databasePath);
  }

  Future<void> _extractKnowledge(Archive archive, Directory target) async {
    for (final entry in archive.files) {
      if (!entry.isFile || !entry.name.startsWith(_knowledgeEntryPrefix)) {
        continue;
      }
      final relativePath = entry.name.substring(_knowledgeEntryPrefix.length);
      if (relativePath.isEmpty || !_isSafeRelativePath(relativePath)) {
        continue;
      }
      final output = File(
        p.joinAll([target.path, ...p.posix.split(relativePath)]),
      );
      if (!await output.parent.exists()) {
        await output.parent.create(recursive: true);
      }
      await output.writeAsBytes(entry.content, flush: true);
    }
  }

  Future<void> _replaceKnowledgeDirectory(Directory source) async {
    final target = await _knowledgeDirectory();
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    if (await source.exists()) {
      await _copyDirectory(source, target);
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    await for (final entity in source.list(
      recursive: false,
      followLinks: false,
    )) {
      final name = p.basename(entity.path);
      final targetPath = p.join(target.path, name);
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      } else if (entity is File) {
        await entity.copy(targetPath);
      }
    }
  }

  Future<Directory> _knowledgeDirectory() async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, 'knowledge'));
  }

  bool _isSafeRelativePath(String value) {
    final parts = p.posix.split(value);
    return parts.every((part) => part.isNotEmpty && part != '..') &&
        !p.posix.isAbsolute(value);
  }

  String _manifestJson() {
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'recordmytime-backup',
      'format_version': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'includes': ['database', 'knowledge'],
    });
  }

  String _defaultBackupFileName() {
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    return 'recordmytime-backup-$date-$time.zip';
  }
}
