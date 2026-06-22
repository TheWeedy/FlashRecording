import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:html/parser.dart' as html_parser;
import 'package:html2md/html2md.dart' as html2md;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:reader_mode/reader_mode.dart' as reader_mode;
import 'package:sqflite/sqflite.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/file_item.dart';
import 'local_database.dart';

enum ImageOcrLanguageMode { chineseEnglish, japaneseEnglish, englishOnly }

class FileLibraryException implements Exception {
  const FileLibraryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FileLibraryService {
  bool get _supportsImageOcr => Platform.isAndroid || Platform.isIOS;

  Future<List<FileItem>> loadItems({
    String query = '',
    String? tagId,
    bool archived = false,
  }) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'file_items',
      where: archived ? 'archived_at IS NOT NULL' : 'archived_at IS NULL',
      orderBy: 'updated_at DESC',
    );
    final all = <FileItem>[];
    for (final row in rows) {
      final item = await _mapItem(row);
      if (tagId != null && !item.tags.any((tag) => tag.id == tagId)) {
        continue;
      }
      if (query.trim().isNotEmpty && !await _matchesQuery(item, query.trim())) {
        continue;
      }
      all.add(item);
    }
    return all;
  }

  Future<List<FileTag>> loadTags() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'file_tags',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(_mapTag).toList();
  }

  Future<FileItem?> findById(String id) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'file_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapItem(rows.first);
  }

  Future<FileItem> addText({
    required String title,
    required String content,
  }) async {
    final now = DateTime.now();
    final id = _newId();
    final directory = await _ensureDirectory('text');
    final file = File(p.join(directory.path, '$id.md'));
    final normalizedTitle = title.trim().isEmpty
        ? _firstLine(content, fallback: 'Untitled text')
        : title.trim();
    final markdown = '# $normalizedTitle\n\n$content';
    await file.writeAsString(markdown);
    final item = FileItem(
      id: id,
      title: normalizedTitle,
      kind: FileItemKind.text,
      mimeType: 'text/markdown',
      originalUrl: '',
      localPath: file.path,
      markdownPath: file.path,
      plainTextPreview: _preview(content),
      sizeBytes: await file.length(),
      createdAt: now,
      updatedAt: now,
      tags: const [],
    );
    await _upsertItem(item);
    return item;
  }

  Future<FileItem> addSharedText(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const FileLibraryException('Enter a webpage URL first.');
    }
    final sharedWebpage = _parseSharedWebpageText(trimmed);
    if (sharedWebpage != null) {
      return addWebpage(
        sharedWebpage.url,
        titleHint: sharedWebpage.title.isEmpty ? null : sharedWebpage.title,
      );
    }
    return addText(title: '', content: trimmed);
  }

  Future<FileItem> addWebpage(String inputUrl, {String? titleHint}) async {
    final sharedWebpage = _parseSharedWebpageText(inputUrl.trim());
    final url = _normalizeUrl(sharedWebpage?.url ?? inputUrl);
    final effectiveTitleHint = (titleHint?.trim().isNotEmpty ?? false)
        ? titleHint!.trim()
        : sharedWebpage?.title;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final html = await _downloadWebpage(client, url);
      return _saveCapturedWebpage(
        url: url,
        captured: await _captureMarkdown(
          html: html,
          url: url,
          titleOverride: effectiveTitleHint,
        ),
      );
    } on SocketException {
      return _saveCapturedWebpage(
        url: url,
        captured: _fallbackWebpageCapture(
          url: url,
          titleOverride: effectiveTitleHint,
          reason: 'Could not reach this webpage.',
        ),
      );
    } on FormatException {
      throw const FileLibraryException('The URL is not valid.');
    } on FileLibraryException catch (error) {
      return _saveCapturedWebpage(
        url: url,
        captured: _fallbackWebpageCapture(
          url: url,
          titleOverride: effectiveTitleHint,
          reason: error.message,
        ),
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<FileItem> refreshWebpageMarkdownFromNetwork(FileItem item) async {
    if (item.kind != FileItemKind.web || item.originalUrl.isEmpty) {
      throw const FileLibraryException('This item is not a webpage.');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final html = await _downloadWebpage(client, item.originalUrl);
      final captured = await _captureMarkdown(
        html: html,
        url: item.originalUrl,
        statusOverride: 'network_refresh',
      );
      if (!_hasEnoughCapturedText(captured)) {
        throw const FileLibraryException(
          'The refreshed page did not contain enough readable text. Try Live Web capture after the page finishes loading.',
        );
      }
      return _replaceWebpageMarkdown(item: item, captured: captured);
    } on SocketException {
      throw const FileLibraryException('Could not reach this webpage.');
    } finally {
      client.close(force: true);
    }
  }

  Future<FileItem> refreshWebpageMarkdown(FileItem item) {
    return refreshWebpageMarkdownFromNetwork(item);
  }

  Future<FileItem> refreshWebpageMarkdownFromHtml({
    required FileItem item,
    required String html,
    required String sourceUrl,
    String? title,
  }) async {
    if (item.kind != FileItemKind.web) {
      throw const FileLibraryException('This item is not a webpage.');
    }
    final captured = await _captureMarkdown(
      html: html,
      url: sourceUrl,
      titleOverride: title,
      statusOverride: 'live_web_dom',
    );
    if (!_hasEnoughCapturedText(captured)) {
      throw const FileLibraryException(
        'The live page did not expose enough readable text yet. Wait for the article to finish loading, scroll once if needed, then try again.',
      );
    }
    return _replaceWebpageMarkdown(item: item, captured: captured);
  }

  Future<String> _downloadWebpage(HttpClient client, String url) async {
    final attempts = [
      _WebRequestProfile(
        userAgent: 'RecordMyTime/6.0',
        referer: Uri.parse(url).origin,
      ),
      _WebRequestProfile(
        userAgent:
            'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Version/4.0 Chrome/120.0.0.0 Mobile Safari/537.36 '
            'MicroMessenger/8.0.47',
        referer: 'https://mp.weixin.qq.com/',
      ),
    ];
    FileLibraryException? lastError;
    for (final profile in attempts) {
      try {
        final request = await client.getUrl(Uri.parse(url));
        request.headers.set(HttpHeaders.userAgentHeader, profile.userAgent);
        request.headers.set(
          HttpHeaders.acceptHeader,
          'text/html,application/xhtml+xml',
        );
        request.headers.set(
          HttpHeaders.acceptLanguageHeader,
          'zh-CN,zh;q=0.9,en;q=0.7',
        );
        request.headers.set(HttpHeaders.refererHeader, profile.referer);
        final response = await request.close();
        final html = await response.transform(utf8.decoder).join();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (_looksBlockedPage(html)) {
            lastError = const FileLibraryException(
              'The webpage appears to be blocked by anti-bot protection.',
            );
            continue;
          }
          return html;
        }
        lastError = FileLibraryException(
          'Webpage download failed with status ${response.statusCode}.',
        );
      } on SocketException {
        lastError = const FileLibraryException('Could not reach this webpage.');
      }
    }
    throw lastError ?? const FileLibraryException('Webpage download failed.');
  }

  Future<FileItem> addFile(String sourcePath, {String? mimeType}) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileLibraryException('The selected file no longer exists.');
    }
    final now = DateTime.now();
    final id = _newId();
    final detectedMime = mimeType ?? lookupMimeType(sourcePath) ?? '';
    final kind = _kindForMime(detectedMime, sourcePath);
    final ext = p.extension(sourcePath);
    final directory = await _ensureDirectory('files');
    final safeName = _safeFilename(
      '${id}_${p.basenameWithoutExtension(sourcePath)}$ext',
    );
    final copied = await source.copy(p.join(directory.path, safeName));
    if (kind == FileItemKind.pdf) {
      return _addCopiedPdf(
        id: id,
        copied: copied,
        originalName: p.basename(sourcePath),
        mimeType: detectedMime.isEmpty ? 'application/pdf' : detectedMime,
        createdAt: now,
      );
    }
    if (kind == FileItemKind.image) {
      final originalName = p.basename(sourcePath);
      if (_supportsImageOcr) {
        return _addCopiedImage(
          id: id,
          copied: copied,
          originalName: originalName,
          mimeType: detectedMime,
          createdAt: now,
        );
      }
      return _addCopiedImageWithoutOcr(
        id: id,
        copied: copied,
        originalName: originalName,
        mimeType: detectedMime,
        createdAt: now,
      );
    }
    final textContent = kind == FileItemKind.text
        ? await copied.readAsString().catchError((_) => '')
        : '';
    final item = FileItem(
      id: id,
      title: p.basename(sourcePath),
      kind: kind,
      mimeType: detectedMime,
      originalUrl: '',
      localPath: copied.path,
      markdownPath: kind == FileItemKind.text ? copied.path : '',
      plainTextPreview: kind == FileItemKind.text
          ? _preview(textContent)
          : '${kind.label} file',
      sizeBytes: await copied.length(),
      createdAt: now,
      updatedAt: now,
      tags: const [],
    );
    await _upsertItem(item);
    return item;
  }

  Future<FileItem> _addCopiedImage({
    required String id,
    required File copied,
    required String originalName,
    required String mimeType,
    required DateTime createdAt,
  }) async {
    final extracted = await _extractImageOcrMarkdown(
      copied,
      originalName,
      languageMode: ImageOcrLanguageMode.chineseEnglish,
    );
    final directory = await _ensureDirectory('text');
    final markdownFile = File(p.join(directory.path, '$id.md'));
    await markdownFile.writeAsString(extracted.markdown);
    final item = FileItem(
      id: id,
      title: originalName,
      kind: FileItemKind.image,
      mimeType: mimeType,
      originalUrl: '',
      localPath: copied.path,
      markdownPath: markdownFile.path,
      plainTextPreview: _preview(extracted.plainText),
      sizeBytes: await copied.length(),
      createdAt: createdAt,
      updatedAt: createdAt,
      tags: const [],
    );
    await _upsertItem(item);
    return item;
  }

  Future<FileItem> _addCopiedImageWithoutOcr({
    required String id,
    required File copied,
    required String originalName,
    required String mimeType,
    required DateTime createdAt,
  }) async {
    final item = FileItem(
      id: id,
      title: originalName,
      kind: FileItemKind.image,
      mimeType: mimeType,
      originalUrl: '',
      localPath: copied.path,
      markdownPath: '',
      plainTextPreview: '${FileItemKind.image.label} file',
      sizeBytes: await copied.length(),
      createdAt: createdAt,
      updatedAt: createdAt,
      tags: const [],
    );
    await _upsertItem(item);
    return item;
  }

  Future<FileItem> _addCopiedPdf({
    required String id,
    required File copied,
    required String originalName,
    required String mimeType,
    required DateTime createdAt,
  }) async {
    final extracted = await _extractPdfMarkdown(copied, originalName);
    final directory = await _ensureDirectory('text');
    final markdownFile = File(p.join(directory.path, '$id.md'));
    await markdownFile.writeAsString(extracted.markdown);
    final item = FileItem(
      id: id,
      title: originalName,
      kind: FileItemKind.pdf,
      mimeType: mimeType,
      originalUrl: '',
      localPath: copied.path,
      markdownPath: markdownFile.path,
      plainTextPreview: _preview(extracted.plainText),
      sizeBytes: await copied.length(),
      createdAt: createdAt,
      updatedAt: createdAt,
      tags: const [],
    );
    await _upsertItem(item);
    return item;
  }

  Future<_ExtractedPdf> _extractPdfMarkdown(File file, String title) async {
    final capturedAt = DateTime.now().toIso8601String();
    try {
      final bytes = await file.readAsBytes();
      final document = PdfDocument(inputBytes: bytes);
      final pageCount = document.pages.count;
      final text = PdfTextExtractor(document).extractText(layoutText: true);
      document.dispose();
      final normalized = text.trim();
      final body = normalized.isEmpty
          ? 'No selectable text was found in this PDF. Scanned PDFs require OCR, which is not enabled in this version.'
          : normalized;
      return _ExtractedPdf(
        plainText: body,
        markdown:
            '''
---
title: ${_yamlValue(title)}
source_file: ${_yamlValue(file.path)}
captured_at: $capturedAt
page_count: $pageCount
tags: []
---

# $title

$body
''',
      );
    } catch (error) {
      final body = 'Could not extract text from this PDF: $error';
      return _ExtractedPdf(
        plainText: body,
        markdown:
            '''
---
title: ${_yamlValue(title)}
source_file: ${_yamlValue(file.path)}
captured_at: $capturedAt
page_count: unknown
tags: []
---

# $title

$body
''',
      );
    }
  }

  Future<FileItem> refreshImageOcrMarkdown(
    FileItem item, {
    ImageOcrLanguageMode languageMode = ImageOcrLanguageMode.chineseEnglish,
  }) async {
    if (!_supportsImageOcr) {
      throw const FileLibraryException(
        'Image OCR is not available on this platform.',
      );
    }
    if (item.kind != FileItemKind.image || item.localPath.isEmpty) {
      throw const FileLibraryException('This item is not an image.');
    }
    final file = File(item.localPath);
    if (!await file.exists()) {
      throw const FileLibraryException('The stored image file is missing.');
    }
    final extracted = await _extractImageOcrMarkdown(
      file,
      item.title,
      languageMode: languageMode,
    );
    final directory = await _ensureDirectory('text');
    final markdownPath = item.markdownPath.isNotEmpty
        ? item.markdownPath
        : p.join(directory.path, '${item.id}.md');
    final markdownFile = File(markdownPath);
    if (!await markdownFile.parent.exists()) {
      await markdownFile.parent.create(recursive: true);
    }
    await markdownFile.writeAsString(extracted.markdown);
    final db = await LocalDatabase.instance.database;
    await db.update(
      'file_items',
      {
        'markdown_path': markdownFile.path,
        'plain_text_preview': _preview(extracted.plainText),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
    return await findById(item.id) ?? item;
  }

  Future<_ExtractedOcr> _extractImageOcrMarkdown(
    File file,
    String title, {
    required ImageOcrLanguageMode languageMode,
  }) async {
    final capturedAt = DateTime.now().toIso8601String();
    final decoded = await _decodeImageInfo(file);
    final imageWidth = decoded?.width;
    final imageHeight = decoded?.height;
    final tiles = decoded == null
        ? <_OcrTile>[_OcrTile(file: file, top: 0, height: 0, scale: 1.0)]
        : await _buildOcrTileFiles(file, decoded);
    final usingTiles = tiles.length > 1 || tiles.first.file.path != file.path;
    final scripts = switch (languageMode) {
      ImageOcrLanguageMode.chineseEnglish => <TextRecognitionScript>[
        TextRecognitionScript.chinese,
        TextRecognitionScript.latin,
      ],
      ImageOcrLanguageMode.japaneseEnglish => <TextRecognitionScript>[
        TextRecognitionScript.japanese,
        TextRecognitionScript.latin,
      ],
      ImageOcrLanguageMode.englishOnly => <TextRecognitionScript>[
        TextRecognitionScript.latin,
      ],
    };
    final scriptNames = scripts.map((script) => script.name).toList();
    final lines = <_OcrLine>[];
    final seenLines = <String>{};
    final failures = <String>[];
    var blockSerial = 0;
    try {
      for (var scriptIndex = 0; scriptIndex < scripts.length; scriptIndex++) {
        final script = scripts[scriptIndex];
        final isPrimaryScript = scriptIndex == 0;
        final recognizer = TextRecognizer(script: script);
        try {
          for (final tile in tiles) {
            final recognized = await recognizer.processImage(
              InputImage.fromFilePath(tile.file.path),
            );
            for (final block in recognized.blocks) {
              final currentBlock = blockSerial++;
              for (final line in block.lines) {
                final cleaned = _cleanOcrLine(line.text);
                if (cleaned.isEmpty || _isLikelyOcrNoiseLine(cleaned)) {
                  continue;
                }
                final left = line.boundingBox.left / tile.scale;
                final top = tile.top + line.boundingBox.top / tile.scale;
                final right = line.boundingBox.right / tile.scale;
                final bottom = tile.top + line.boundingBox.bottom / tile.scale;
                if (!isPrimaryScript &&
                    (!_isUsefulSupplementalOcrLine(cleaned) ||
                        _hasOverlappingOcrLine(
                          lines,
                          left: left,
                          top: top,
                          right: right,
                          bottom: bottom,
                        ))) {
                  continue;
                }
                final dedupeKey = _ocrLineDedupeKey(cleaned, top);
                if (seenLines.add(dedupeKey)) {
                  lines.add(
                    _OcrLine(
                      text: cleaned,
                      left: left,
                      top: top,
                      right: right,
                      bottom: bottom,
                      blockIndex: currentBlock,
                    ),
                  );
                }
              }
            }
          }
        } catch (error) {
          failures.add('${script.name}: $error');
        } finally {
          await recognizer.close().catchError((_) {});
        }
      }
    } finally {
      if (usingTiles) {
        for (final tile in tiles) {
          await _deleteIfExists(tile.file.path);
        }
      }
    }
    final parts = _reconstructOcrParagraphs(lines, imageWidth: imageWidth);
    final body = parts.isEmpty
        ? 'No text was recognized in this image.'
        : parts.join('\n\n');
    final status = parts.isEmpty ? 'empty' : 'recognized';
    final failureBlock = failures.isEmpty
        ? ''
        : '\n\n> OCR warnings: ${failures.join(' | ')}';
    return _ExtractedOcr(
      plainText: body,
      markdown:
          '''
---
title: ${_yamlValue(title)}
source_file: ${_yamlValue(file.path)}
captured_at: $capturedAt
image_size: ${imageWidth == null || imageHeight == null ? 'unknown' : '${imageWidth}x$imageHeight'}
ocr_tiles: ${tiles.length}
ocr_status: $status
scripts: [${scriptNames.join(', ')}]
tags: []
---

# $title

$body$failureBlock
''',
    );
  }

  Future<void> renameItem({required String id, required String title}) async {
    final normalized = title.trim();
    if (normalized.isEmpty) {
      throw const FileLibraryException('File name cannot be empty.');
    }
    final db = await LocalDatabase.instance.database;
    await db.update(
      'file_items',
      {'title': normalized, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> renameTag({required String id, required String name}) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const FileLibraryException('Tag name cannot be empty.');
    }
    final db = await LocalDatabase.instance.database;
    final existing = await db.query(
      'file_tags',
      where: 'LOWER(name) = LOWER(?) AND id <> ?',
      whereArgs: [normalized, id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw const FileLibraryException('A tag with this name already exists.');
    }
    await db.update(
      'file_tags',
      {'name': normalized},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTag(String id) async {
    final db = await LocalDatabase.instance.database;
    await db.delete('file_item_tags', where: 'tag_id = ?', whereArgs: [id]);
    await db.delete('file_tags', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> archiveItems(Iterable<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final db = await LocalDatabase.instance.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.update(
      'file_items',
      {
        'archived_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id IN ($placeholders)',
      whereArgs: ids.toList(),
    );
  }

  Future<void> restoreItems(Iterable<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final db = await LocalDatabase.instance.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.update(
      'file_items',
      {'archived_at': null, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id IN ($placeholders)',
      whereArgs: ids.toList(),
    );
  }

  Future<void> deleteItems(Iterable<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final db = await LocalDatabase.instance.database;
    final items = <FileItem>[];
    for (final id in ids) {
      final item = await findById(id);
      if (item != null) {
        items.add(item);
      }
    }
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(
      'file_item_tags',
      where: 'file_item_id IN ($placeholders)',
      whereArgs: ids.toList(),
    );
    await db.delete(
      'file_items',
      where: 'id IN ($placeholders)',
      whereArgs: ids.toList(),
    );
    for (final item in items) {
      await _deleteIfExists(item.localPath);
      if (item.markdownPath != item.localPath) {
        await _deleteIfExists(item.markdownPath);
      }
    }
  }

  Future<FileTag> ensureTag(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw const FileLibraryException('Tag name cannot be empty.');
    }
    final db = await LocalDatabase.instance.database;
    final existing = await db.query(
      'file_tags',
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [normalized],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return _mapTag(existing.first);
    }
    final tag = FileTag(
      id: _newId(),
      name: normalized,
      createdAt: DateTime.now(),
    );
    await db.insert('file_tags', {
      'id': tag.id,
      'name': tag.name,
      'created_at': tag.createdAt.toIso8601String(),
    });
    return tag;
  }

  Future<void> addTagToItems({
    required Iterable<String> itemIds,
    required String tagName,
  }) async {
    final tag = await ensureTag(tagName);
    final db = await LocalDatabase.instance.database;
    final batch = db.batch();
    for (final itemId in itemIds) {
      batch.insert('file_item_tags', {
        'file_item_id': itemId,
        'tag_id': tag.id,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> setTagsForItem({
    required String itemId,
    required Iterable<String> tagIds,
  }) async {
    final db = await LocalDatabase.instance.database;
    final batch = db.batch();
    batch.delete(
      'file_item_tags',
      where: 'file_item_id = ?',
      whereArgs: [itemId],
    );
    for (final tagId in tagIds) {
      batch.insert('file_item_tags', {
        'file_item_id': itemId,
        'tag_id': tagId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> removeTagFromItems({
    required Iterable<String> itemIds,
    required String tagId,
  }) async {
    if (itemIds.isEmpty) {
      return;
    }
    final db = await LocalDatabase.instance.database;
    final placeholders = List.filled(itemIds.length, '?').join(',');
    await db.delete(
      'file_item_tags',
      where: 'tag_id = ? AND file_item_id IN ($placeholders)',
      whereArgs: [tagId, ...itemIds],
    );
  }

  Future<_CapturedWebpage> _captureMarkdown({
    required String html,
    required String url,
    String? titleOverride,
    String? statusOverride,
  }) async {
    reader_mode.Article? article;
    try {
      article = reader_mode.parse(html, baseUri: url);
    } catch (_) {
      article = null;
    }

    final document = html_parser.parse(html);
    final fallbackTitle = document.querySelector('title')?.text.trim();
    final title = (titleOverride?.trim().isNotEmpty ?? false)
        ? titleOverride!.trim()
        : (article?.title.trim().isNotEmpty ?? false)
        ? article!.title.trim()
        : (fallbackTitle?.isNotEmpty ?? false)
        ? fallbackTitle!
        : Uri.parse(url).host;
    final contentHtml = (article?.content.trim().isNotEmpty ?? false)
        ? article!.content
        : html;
    final markdownBody = html2md.convert(
      contentHtml,
      styleOptions: {
        'headingStyle': 'atx',
        'bulletListMarker': '-',
        'codeBlockStyle': 'fenced',
        'linkStyle': 'inlined',
      },
      ignore: const ['script', 'style', 'nav', 'footer'],
    );
    final plainText = (article?.textContent.trim().isNotEmpty ?? false)
        ? article!.textContent
        : html_parser.parse(contentHtml).body?.text.trim() ??
              document.body?.text.trim() ??
              '';
    final excerpt = article?.excerpt?.trim() ?? '';
    final capturedAt = DateTime.now().toIso8601String();
    final status =
        statusOverride ?? (article == null ? 'fallback' : 'readability');
    final markdown =
        '''
---
title: ${_yamlValue(title)}
source: $url
captured_at: $capturedAt
capture_status: $status
tags: []
---

# $title

${excerpt.isEmpty ? '' : '> $excerpt\n\n'}
$markdownBody
''';
    return _CapturedWebpage(
      title: title,
      markdown: markdown,
      plainText: plainText,
    );
  }

  Future<FileItem> _saveCapturedWebpage({
    required String url,
    required _CapturedWebpage captured,
  }) async {
    final id = _newId();
    final directory = await _ensureDirectory('web_markdown');
    final file = File(p.join(directory.path, '$id.md'));
    await file.writeAsString(captured.markdown);
    final now = DateTime.now();
    final item = FileItem(
      id: id,
      title: captured.title,
      kind: FileItemKind.web,
      mimeType: 'text/markdown',
      originalUrl: url,
      localPath: '',
      markdownPath: file.path,
      plainTextPreview: _preview(captured.plainText),
      sizeBytes: await file.length(),
      createdAt: now,
      updatedAt: now,
      tags: const [],
    );
    await _upsertItem(item);
    return item;
  }

  Future<FileItem> _replaceWebpageMarkdown({
    required FileItem item,
    required _CapturedWebpage captured,
  }) async {
    final directory = await _ensureDirectory('web_markdown');
    final markdownPath = item.markdownPath.isNotEmpty
        ? item.markdownPath
        : p.join(directory.path, '${item.id}.md');
    final file = File(markdownPath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(captured.markdown);
    final db = await LocalDatabase.instance.database;
    await db.update(
      'file_items',
      {
        'markdown_path': file.path,
        'plain_text_preview': _preview(captured.plainText),
        'size_bytes': await file.length(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
    return await findById(item.id) ?? item;
  }

  _CapturedWebpage _fallbackWebpageCapture({
    required String url,
    required String reason,
    String? titleOverride,
  }) {
    final host = Uri.tryParse(url)?.host ?? url;
    final title = (titleOverride?.trim().isNotEmpty ?? false)
        ? titleOverride!.trim()
        : host;
    final capturedAt = DateTime.now().toIso8601String();
    final body =
        'This webpage could not be downloaded as Markdown.\n\n'
        'Reason: $reason\n\n'
        'You can still keep the source URL here, or copy the article text from the original app and add it as text.';
    return _CapturedWebpage(
      title: title,
      plainText: body,
      markdown:
          '''
---
title: ${_yamlValue(title)}
source: $url
captured_at: $capturedAt
capture_status: failed
tags: []
---

# $title

$body
''',
    );
  }

  Future<FileItem> _mapItem(Map<String, Object?> row) async {
    final db = await LocalDatabase.instance.database;
    final tagRows = await db.rawQuery(
      '''
      SELECT t.id, t.name, t.created_at
      FROM file_tags t
      INNER JOIN file_item_tags it ON it.tag_id = t.id
      WHERE it.file_item_id = ?
      ORDER BY t.name COLLATE NOCASE ASC
      ''',
      [row['id']],
    );
    return FileItem(
      id: row['id'] as String,
      title: row['title'] as String,
      kind: FileItemKind.values.firstWhere(
        (kind) => kind.name == row['kind'],
        orElse: () => FileItemKind.file,
      ),
      mimeType: row['mime_type'] as String? ?? '',
      originalUrl: row['original_url'] as String? ?? '',
      localPath: row['local_path'] as String? ?? '',
      markdownPath: row['markdown_path'] as String? ?? '',
      plainTextPreview: row['plain_text_preview'] as String? ?? '',
      sizeBytes: _asInt(row['size_bytes']),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      archivedAt: row['archived_at'] == null
          ? null
          : DateTime.parse(row['archived_at'] as String),
      tags: tagRows.map(_mapTag).toList(),
    );
  }

  FileTag _mapTag(Map<String, Object?> row) {
    return FileTag(
      id: row['id'] as String,
      name: row['name'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<void> _upsertItem(FileItem item) async {
    final db = await LocalDatabase.instance.database;
    await db.insert('file_items', {
      'id': item.id,
      'title': item.title,
      'kind': item.kind.name,
      'mime_type': item.mimeType,
      'original_url': item.originalUrl,
      'local_path': item.localPath,
      'markdown_path': item.markdownPath,
      'plain_text_preview': item.plainTextPreview,
      'size_bytes': item.sizeBytes,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': item.updatedAt.toIso8601String(),
      'archived_at': item.archivedAt?.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> _matchesQuery(FileItem item, String query) async {
    final needle = query.toLowerCase();
    final fields = [
      item.title,
      item.originalUrl,
      item.mimeType,
      item.plainTextPreview,
      ...item.tags.map((tag) => tag.name),
    ];
    if (fields.any((field) => field.toLowerCase().contains(needle))) {
      return true;
    }
    if (item.canAnswerWithAi) {
      final content = await item.loadTextContent().catchError((_) => '');
      return content.toLowerCase().contains(needle);
    }
    return false;
  }

  Future<Directory> _ensureDirectory(String child) async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory(p.join(base.path, 'knowledge', child));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  FileItemKind _kindForMime(String mimeType, String path) {
    final lower = mimeType.toLowerCase();
    final ext = p.extension(path).toLowerCase();
    if (lower == 'application/pdf' || ext == '.pdf') {
      return FileItemKind.pdf;
    }
    if (lower.startsWith('image/')) {
      return FileItemKind.image;
    }
    if (lower.startsWith('video/')) {
      return FileItemKind.video;
    }
    if (lower.startsWith('text/') ||
        const [
          '.md',
          '.markdown',
          '.txt',
          '.csv',
          '.json',
          '.xml',
        ].contains(ext)) {
      return FileItemKind.text;
    }
    return FileItemKind.file;
  }

  String _normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FileLibraryException('Enter a webpage URL first.');
    }
    final candidate = trimmed.startsWith(RegExp('https?://'))
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.parse(candidate);
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw const FileLibraryException('Enter a valid webpage URL.');
    }
    return uri.toString();
  }

  _SharedWebpageText? _parseSharedWebpageText(String value) {
    final match = RegExp(r'https?://[^\s]+').firstMatch(value);
    if (match == null) {
      return null;
    }
    var url = match.group(0)!.trim();
    while (url.isNotEmpty &&
        RegExp(r'[，。！？；、,.!?;)\]}>》」』]').hasMatch(url[url.length - 1])) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isEmpty) {
      return null;
    }
    final title = [
      value.substring(0, match.start),
      value.substring(match.end),
    ].join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return _SharedWebpageText(url: url, title: title);
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  String _preview(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 180) {
      return compact;
    }
    return '${compact.substring(0, 180)}...';
  }

  Future<img.Image?> _decodeImageInfo(File file) async {
    try {
      return img.decodeImage(await file.readAsBytes());
    } catch (_) {
      return null;
    }
  }

  Future<List<_OcrTile>> _buildOcrTileFiles(File file, img.Image image) async {
    const longImageHeightThreshold = 8000;
    const longImageRatioThreshold = 4.0;
    const tileHeight = 8000;
    const tileOverlap = 240;
    const scale = 1.0;
    const sourceTileHeight = tileHeight;
    const sourceTileOverlap = tileOverlap;
    final isLongImage =
        image.height > longImageHeightThreshold ||
        image.height / image.width > longImageRatioThreshold;
    if (!isLongImage && scale == 1.0) {
      return [_OcrTile(file: file, top: 0, height: image.height, scale: 1.0)];
    }

    final directory = await _ensureDirectory('ocr_tiles');
    final tiles = <_OcrTile>[];
    var top = 0;
    var index = 0;
    while (top < image.height) {
      final height = (image.height - top).clamp(1, sourceTileHeight).toInt();
      var tile = img.copyCrop(
        image,
        x: 0,
        y: top,
        width: image.width,
        height: height,
      );
      final tileFile = File(
        p.join(
          directory.path,
          '${p.basenameWithoutExtension(file.path)}_${index++}.png',
        ),
      );
      await tileFile.writeAsBytes(img.encodePng(tile));
      tiles.add(
        _OcrTile(file: tileFile, top: top, height: height, scale: scale),
      );
      if (top + sourceTileHeight >= image.height) {
        break;
      }
      top += sourceTileHeight - sourceTileOverlap;
    }
    return tiles;
  }

  String _cleanOcrLine(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

  List<String> _reconstructOcrParagraphs(
    List<_OcrLine> rawLines, {
    required int? imageWidth,
  }) {
    final lines = rawLines.toList()
      ..sort((a, b) {
        final topCompare = a.top.compareTo(b.top);
        if (topCompare != 0) {
          return topCompare;
        }
        return a.left.compareTo(b.left);
      });
    final deduped = <_OcrLine>[];
    for (final line in lines) {
      if (deduped.any(
        (existing) =>
            (existing.top - line.top).abs() < 360 &&
            (_ocrDedupeKey(existing.text) == _ocrDedupeKey(line.text) ||
                _isSimilarOcrText(existing.text, line.text)),
      )) {
        continue;
      }
      deduped.add(line);
    }
    if (deduped.isEmpty) {
      return const [];
    }

    final heights =
        deduped.map((line) => math.max(1.0, line.bottom - line.top)).toList()
          ..sort();
    final medianHeight = heights[heights.length ~/ 2];
    final paragraphs = <String>[];
    var current = deduped.first.text;
    var previous = deduped.first;
    for (final line in deduped.skip(1)) {
      if (_shouldStartOcrParagraph(
        previous,
        line,
        medianHeight: medianHeight,
        imageWidth: imageWidth,
      )) {
        paragraphs.add(current.trim());
        current = line.text;
      } else {
        current = _joinOcrLines(current, line.text);
      }
      previous = line;
    }
    paragraphs.add(current.trim());
    return paragraphs.where((part) => part.isNotEmpty).toList();
  }

  bool _shouldStartOcrParagraph(
    _OcrLine previous,
    _OcrLine current, {
    required double medianHeight,
    required int? imageWidth,
  }) {
    final verticalGap = current.top - previous.bottom;
    final previousEnds = _endsSentence(previous.text);
    if (verticalGap > medianHeight * 4.0 + 24) {
      return true;
    }
    if (_startsStructuredLine(current.text)) {
      return true;
    }
    final width = imageWidth?.toDouble() ?? 0;
    final indentDelta = current.left - previous.left;
    if (width > 0 &&
        indentDelta > math.max(36, width * 0.045) &&
        (previousEnds || verticalGap > medianHeight * 1.5)) {
      return true;
    }
    if (previous.blockIndex != current.blockIndex &&
        previousEnds &&
        verticalGap > medianHeight * 0.85) {
      return true;
    }
    if (_looksLikeStandaloneHeading(previous.text) &&
        verticalGap > medianHeight * 1.2 &&
        current.left <=
            previous.left + math.max(28, (imageWidth ?? 0) * 0.035)) {
      return true;
    }
    return false;
  }

  bool _startsStructuredLine(String value) {
    final trimmed = value.trim();
    return RegExp(
      r'^([\-•●▪▫*]|\d+[\.、)]|[一二三四五六七八九十]+[、.])',
    ).hasMatch(trimmed);
  }

  bool _endsSentence(String value) =>
      RegExp(r'''[。！？!?；;：:]["'”’」』）)]?$''').hasMatch(value.trim());

  bool _looksLikeStandaloneHeading(String value) {
    final compact = value.trim();
    return compact.length <= 18 &&
        !RegExp(r'[，,。.!！？?；;：:]$').hasMatch(compact) &&
        RegExp(r'[\u4e00-\u9fffA-Za-z]').hasMatch(compact);
  }

  String _joinOcrLines(String previous, String current) {
    final left = previous.trimRight();
    final right = current.trimLeft();
    if (left.isEmpty) {
      return right;
    }
    if (right.isEmpty) {
      return left;
    }
    if (left.endsWith('-') && _isLatinTextBoundary(left, right)) {
      return '${left.substring(0, left.length - 1)}$right';
    }
    if (_isCjkTextBoundary(left, right)) {
      return '$left$right';
    }
    if (RegExp(r'[\s\(（「『《]$').hasMatch(left) ||
        RegExp(r'^[，。！？；：,.!?;:)\]）】》」』]').hasMatch(right)) {
      return '$left$right';
    }
    return '$left $right';
  }

  bool _isCjkTextBoundary(String left, String right) {
    final leftChar = _lastRune(left);
    final rightChar = _firstRune(right);
    return RegExp(r'[\u4e00-\u9fff\u3040-\u30ff]').hasMatch(leftChar) ||
        RegExp(r'[\u4e00-\u9fff\u3040-\u30ff]').hasMatch(rightChar);
  }

  bool _isLatinTextBoundary(String left, String right) {
    final leftChar = _lastRune(left);
    final rightChar = _firstRune(right);
    return RegExp(r'[A-Za-z]').hasMatch(leftChar) &&
        RegExp(r'[A-Za-z]').hasMatch(rightChar);
  }

  String _firstRune(String value) => String.fromCharCode(value.runes.first);

  String _lastRune(String value) => String.fromCharCode(value.runes.last);

  bool _isUsefulSupplementalOcrLine(String line) {
    final compact = line.replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'https?://|www\.|@[A-Za-z0-9._-]+').hasMatch(line)) {
      return true;
    }
    final cjkCount = RegExp(
      r'[\u4e00-\u9fff\u3040-\u30ff]',
    ).allMatches(compact).length;
    if (cjkCount > 0) {
      return false;
    }
    final latinCount = RegExp(r'[A-Za-z]').allMatches(compact).length;
    final digitCount = RegExp(r'\d').allMatches(compact).length;
    final validCount = latinCount + digitCount;
    if (validCount < 4) {
      return false;
    }
    final punctuationCount = RegExp(
      r'''[^A-Za-z0-9\s]''',
    ).allMatches(compact).length;
    final length = math.max(1, compact.runes.length);
    return latinCount / validCount >= 0.55 && punctuationCount / length < 0.28;
  }

  bool _hasOverlappingOcrLine(
    List<_OcrLine> lines, {
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final width = math.max(1.0, right - left);
    final height = math.max(1.0, bottom - top);
    for (final line in lines) {
      final overlapLeft = math.max(left, line.left);
      final overlapRight = math.min(right, line.right);
      final overlapTop = math.max(top, line.top);
      final overlapBottom = math.min(bottom, line.bottom);
      final overlapWidth = overlapRight - overlapLeft;
      final overlapHeight = overlapBottom - overlapTop;
      if (overlapWidth <= 0 || overlapHeight <= 0) {
        continue;
      }
      final lineWidth = math.max(1.0, line.right - line.left);
      final lineHeight = math.max(1.0, line.bottom - line.top);
      final horizontalRatio = overlapWidth / math.min(width, lineWidth);
      final verticalRatio = overlapHeight / math.min(height, lineHeight);
      if (horizontalRatio > 0.45 && verticalRatio > 0.55) {
        return true;
      }
    }
    return false;
  }

  bool _isLikelyOcrNoiseLine(String line) {
    final compact = line.replaceAll(' ', '');
    if (compact.isEmpty) {
      return true;
    }
    if (compact.length <= 2 &&
        !RegExp(r'[\u4e00-\u9fffA-Za-z0-9]').hasMatch(compact)) {
      return true;
    }
    if (compact.runes.length == 1) {
      return true;
    }
    if (RegExp(r'^\d{1,2}[:：]\d{2}$').hasMatch(compact)) {
      return true;
    }
    if (RegExp(r'^\d{1,2}[:：]\d{2}[oO0Il1|]{1,8}$').hasMatch(compact)) {
      return true;
    }
    final lower = compact.toLowerCase();
    final fileUiHits = [
      'kb',
      'mb',
      'pdf',
      'jpg',
      'jpeg',
      'png',
      'app',
      'com.tencent',
      'screenshot',
    ].where(lower.contains).length;
    final hasTime = RegExp(r'^\<?\d{1,2}[:：]\d{2}').hasMatch(compact);
    if (hasTime && fileUiHits >= 1) {
      return true;
    }
    if (fileUiHits >= 3 && compact.length < 120) {
      return true;
    }

    final validMatches = RegExp(
      r'[\u4e00-\u9fff\u3040-\u30ffA-Za-z0-9]',
    ).allMatches(compact).length;
    final punctuationMatches = RegExp(
      r'''[^\u4e00-\u9fff\u3040-\u30ffA-Za-z0-9\s]''',
    ).allMatches(compact).length;
    final length = compact.runes.length;
    final validRatio = validMatches / length;
    final punctuationRatio = punctuationMatches / length;
    if (hasTime && (fileUiHits >= 1 || punctuationRatio > 0.22)) {
      return true;
    }
    if (RegExp(r'\d+(\.\d+)?(kb|mb|gb)').hasMatch(lower) && fileUiHits >= 1) {
      return true;
    }
    if (length >= 24 && validRatio < 0.42 && punctuationRatio > 0.32) {
      return true;
    }

    final mojibakeHits = RegExp(
      r'[ÅÄÃÕÊËÆØÐÞðþŁłŽžİı]',
    ).allMatches(compact).length;
    if (length >= 18 && mojibakeHits >= 2 && punctuationRatio > 0.18) {
      return true;
    }
    return false;
  }

  String _ocrLineDedupeKey(String value, double top) {
    final key = _ocrDedupeKey(value);
    final bucket = (top / 80).round();
    return '$bucket:$key';
  }

  String _ocrDedupeKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(
          RegExp(r'''[，。、“”‘’：:；;,.!?！？()\[\]{}<>《》\-_/\\|"'`~·]'''),
          '',
        )
        .trim();
  }

  bool _isSimilarOcrText(String a, String b) {
    final left = _ocrDedupeKey(a);
    final right = _ocrDedupeKey(b);
    if (left.length < 12 || right.length < 12) {
      return false;
    }
    final longer = math.max(left.runes.length, right.runes.length);
    if ((left.runes.length - right.runes.length).abs() >
        math.max(2, longer * 0.18)) {
      return false;
    }
    return _boundedEditDistance(left, right, 2) <= 2;
  }

  int _boundedEditDistance(String a, String b, int maxDistance) {
    final left = a.runes.toList();
    final right = b.runes.toList();
    if ((left.length - right.length).abs() > maxDistance) {
      return maxDistance + 1;
    }
    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 1; i <= left.length; i++) {
      final current = List<int>.filled(right.length + 1, 0);
      current[0] = i;
      var rowMin = current[0];
      for (var j = 1; j <= right.length; j++) {
        final substitution =
            previous[j - 1] + (left[i - 1] == right[j - 1] ? 0 : 1);
        final insertion = current[j - 1] + 1;
        final deletion = previous[j] + 1;
        current[j] = math.min(substitution, math.min(insertion, deletion));
        rowMin = math.min(rowMin, current[j]);
      }
      if (rowMin > maxDistance) {
        return maxDistance + 1;
      }
      previous = current;
    }
    return previous.last;
  }

  bool _hasEnoughCapturedText(_CapturedWebpage captured) {
    final compact = captured.plainText.replaceAll(RegExp(r'\s+'), '').trim();
    if (compact.length >= 60) {
      return true;
    }
    final markdownText = captured.markdown
        .replaceAll(RegExp(r'---[\s\S]*?---'), '')
        .replaceAll(RegExp(r'[#>*`\-\[\]()]'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
    return markdownText.length >= 60;
  }

  String _firstLine(String value, {required String fallback}) {
    for (final line in value.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        return trimmed.length > 80 ? trimmed.substring(0, 80) : trimmed;
      }
    }
    return fallback;
  }

  String _safeFilename(String value) {
    return value.replaceAll(RegExp(r'[\\/:*?"<>|#\[\]^]'), '_');
  }

  bool _looksBlockedPage(String html) {
    final lower = html.toLowerCase();
    return lower.contains('环境异常') ||
        lower.contains('访问过于频繁') ||
        lower.contains('verify') && lower.contains('wechat') ||
        lower.contains('当前环境异常') ||
        lower.contains('请在微信客户端打开');
  }

  String _yamlValue(String value) {
    return jsonEncode(value);
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  Future<void> _deleteIfExists(String path) async {
    if (path.isEmpty) {
      return;
    }
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

class _CapturedWebpage {
  const _CapturedWebpage({
    required this.title,
    required this.markdown,
    required this.plainText,
  });

  final String title;
  final String markdown;
  final String plainText;
}

class _ExtractedPdf {
  const _ExtractedPdf({required this.markdown, required this.plainText});

  final String markdown;
  final String plainText;
}

class _ExtractedOcr {
  const _ExtractedOcr({required this.markdown, required this.plainText});

  final String markdown;
  final String plainText;
}

class _OcrTile {
  const _OcrTile({
    required this.file,
    required this.top,
    required this.height,
    required this.scale,
  });

  final File file;
  final int top;
  final int height;
  final double scale;
}

class _OcrLine {
  const _OcrLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.blockIndex,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final int blockIndex;
}

class _SharedWebpageText {
  const _SharedWebpageText({required this.url, required this.title});

  final String url;
  final String title;
}

class _WebRequestProfile {
  const _WebRequestProfile({required this.userAgent, required this.referer});

  final String userAgent;
  final String referer;
}
