import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/file_item.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';
import '../utils/file_library_service.dart';
import '../widgets/app_components.dart';

enum _WebViewMode { live, snapshot }

enum _ImageViewMode { image, ocr }

enum _PdfViewMode { file, markdown }

const String _liveMarkdownCaptureScript = r'''
(() => {
  const cleanup = (root) => {
    root.querySelectorAll('script, style, noscript, nav, footer, header, iframe, form').forEach((node) => node.remove());
    root.querySelectorAll('[hidden], [aria-hidden="true"], .advert, .ad, .ads, .recommend, .related, .comment, .share, .toolbar').forEach((node) => node.remove());
    root.querySelectorAll('img').forEach((img) => {
      const lazySrc = img.getAttribute('data-src') || img.getAttribute('data-original') || img.getAttribute('data-url');
      if (lazySrc && !img.getAttribute('src')) {
        img.setAttribute('src', lazySrc);
      }
    });
  };

  const selectors = [
    '#js_content',
    '.rich_media_content',
    'article',
    'main',
    '[role="main"]',
    '.article',
    '.content',
    '.post-content',
    '.entry-content',
    '.markdown-body'
  ];
  let source = null;
  for (const selector of selectors) {
    const candidate = document.querySelector(selector);
    if (candidate && candidate.innerText && candidate.innerText.trim().length > 40) {
      source = candidate;
      break;
    }
  }
  if (!source) {
    source = document.body || document.documentElement;
  }

  const clone = source.cloneNode(true);
  cleanup(clone);
  const wechatTitle = document.querySelector('.rich_media_title')?.innerText?.trim();
  const title = wechatTitle || document.title || location.hostname;
  return JSON.stringify({
    title,
    url: location.href,
    html: clone.outerHTML,
    textLength: (clone.innerText || '').trim().length
  });
})()
''';

class FileDetailScreen extends StatefulWidget {
  const FileDetailScreen({super.key, required this.item});

  final FileItem item;

  @override
  State<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends State<FileDetailScreen> {
  final FileLibraryService _service = FileLibraryService();
  late FileItem _item;
  _WebViewMode _webMode = _WebViewMode.snapshot;
  _ImageViewMode _imageMode = _ImageViewMode.image;
  _PdfViewMode _pdfMode = _PdfViewMode.markdown;
  String? _textContent;
  bool _isLoadingText = true;
  bool _isRefreshingMarkdown = false;
  bool _isRefreshingOcr = false;
  bool _livePageLoaded = false;
  ImageOcrLanguageMode _ocrLanguageMode = ImageOcrLanguageMode.chineseEnglish;
  InAppWebViewController? _webController;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _loadText();
  }

  Future<void> _loadText() async {
    if (!_item.canAnswerWithAi) {
      setState(() {
        _isLoadingText = false;
      });
      return;
    }
    final fallback = context.l10n.markdownUpdateFailed;
    final content = await _item
        .loadTextContent(includeMetadata: true)
        .catchError((_) => fallback);
    if (!mounted) {
      return;
    }
    setState(() {
      _textContent = content;
      _isLoadingText = false;
    });
  }

  Future<void> _reloadTextForItem(FileItem item) async {
    setState(() {
      _item = item;
      _isLoadingText = true;
      _textContent = null;
    });
    await _loadText();
  }

  Future<void> _openExternally() async {
    final path = _item.localPath.isNotEmpty
        ? _item.localPath
        : _item.markdownPath;
    if (path.isEmpty) {
      return;
    }
    await OpenFilex.open(path);
  }

  Future<void> _openSource() async {
    if (_item.originalUrl.isNotEmpty) {
      final uri = Uri.tryParse(_item.originalUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    await _openExternally();
  }

  Future<void> _copyUrl() async {
    final url = _item.originalUrl.trim();
    if (url.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) {
      return;
    }
    _showMessage(context.l10n.urlCopied);
  }

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: _item.title);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.renameFile),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                await _service.renameItem(id: _item.id, title: controller.text);
                final updated = await _service.findById(_item.id);
                if (!mounted) {
                  return;
                }
                if (updated != null) {
                  setState(() {
                    _item = updated;
                  });
                }
                navigator.pop();
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    if (item.kind == FileItemKind.web && _webMode == _WebViewMode.live) {
      return Scaffold(
        appBar: _buildAppBar(item),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  12,
                  AppTheme.pagePadding,
                  10,
                ),
                child: _buildWebModeSwitch(),
              ),
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(item.originalUrl)),
                  onWebViewCreated: (controller) {
                    _webController = controller;
                  },
                  onLoadStart: (_, _) {
                    if (mounted) {
                      setState(() {
                        _livePageLoaded = false;
                      });
                    }
                  },
                  onLoadStop: (_, _) {
                    if (mounted) {
                      setState(() {
                        _livePageLoaded = true;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: _buildAppBar(item),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            12,
            AppTheme.pagePadding,
            28,
          ),
          children: [_buildBody()],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(FileItem item) {
    return AppBar(
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: context.l10n.rename,
          onPressed: _showRenameDialog,
          icon: const Icon(Icons.edit_outlined),
        ),
        PopupMenuButton<String>(
          tooltip: context.l10n.fileActions,
          color: AppTheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            side: const BorderSide(color: AppTheme.border),
          ),
          onSelected: (value) {
            if (value == 'copy-url') {
              _copyUrl();
            } else if (value == 'update-markdown') {
              _captureMarkdownFromLiveWeb();
            } else if (value == 'open') {
              _openExternally();
            } else if (value == 'source') {
              _openSource();
            }
          },
          itemBuilder: (context) => [
            if (item.originalUrl.isNotEmpty)
              PopupMenuItem(
                value: 'copy-url',
                child: _MenuAction(
                  icon: Icons.copy_outlined,
                  label: context.l10n.copyUrl,
                ),
              ),
            if (item.originalUrl.isNotEmpty || item.localPath.isNotEmpty)
              PopupMenuItem(
                value: 'source',
                child: _MenuAction(
                  icon: Icons.open_in_browser_outlined,
                  label: context.l10n.source,
                ),
              ),
            if (item.localPath.isNotEmpty || item.markdownPath.isNotEmpty)
              PopupMenuItem(
                value: 'open',
                child: _MenuAction(
                  icon: Icons.open_in_new,
                  label: context.l10n.openExternally,
                ),
              ),
            if (item.kind == FileItemKind.web &&
                _webMode == _WebViewMode.live &&
                _livePageLoaded &&
                !_isRefreshingMarkdown)
              PopupMenuItem(
                value: 'update-markdown',
                child: _MenuAction(
                  icon: Icons.travel_explore,
                  label: context.l10n.updateMarkdown,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody() {
    final item = _item;
    switch (item.kind) {
      case FileItemKind.web:
        return _buildWebBody(item);
      case FileItemKind.text:
        return _buildTextBody();
      case FileItemKind.image:
        return _buildImageBody();
      case FileItemKind.video:
        return _VideoPreview(path: item.localPath, onOpen: _openExternally);
      case FileItemKind.pdf:
        return _buildPdfBody(item);
      case FileItemKind.file:
        return _buildGenericFileBody(item);
    }
  }

  Widget _buildWebBody(FileItem item) {
    return Column(
      children: [
        _buildWebModeSwitch(),
        const SizedBox(height: 14),
        _buildTextBody(),
      ],
    );
  }

  Widget _buildWebModeSwitch() {
    return _buildModeSwitch<_WebViewMode>(
      segments: [
        ButtonSegment(
          value: _WebViewMode.snapshot,
          label: Text(
            context.l10n.markdownSnapshot,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          icon: const Icon(Icons.article_outlined),
        ),
        ButtonSegment(
          value: _WebViewMode.live,
          label: Text(
            context.l10n.liveWeb,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          icon: const Icon(Icons.public),
        ),
      ],
      selected: {_webMode},
      onSelectionChanged: (selection) {
        setState(() {
          _webMode = selection.first;
        });
      },
    );
  }

  Widget _buildModeSwitch<T extends Object>({
    required Set<T> selected,
    required List<ButtonSegment<T>> segments,
    required ValueChanged<Set<T>> onSelectionChanged,
  }) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        segments: segments,
        selected: selected,
        showSelectedIcon: false,
        onSelectionChanged: onSelectionChanged,
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTextPanel(String text) {
    final parsed = _ParsedMarkdown.from(text);
    return AppPanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parsed.metadata.isNotEmpty) ...[
            _MarkdownMetadataPanel(metadata: parsed.metadata),
            const SizedBox(height: 14),
          ],
          AiMarkdownBlock(data: parsed.body),
        ],
      ),
    );
  }

  Future<void> _captureMarkdownFromLiveWeb() async {
    final controller = _webController;
    if (controller == null) {
      _showMessage(context.l10n.liveWebNotReady);
      return;
    }
    await _runMarkdownRefresh(() async {
      final raw = await controller.evaluateJavascript(
        source: _liveMarkdownCaptureScript,
      );
      final payload = _decodeLiveCapturePayload(raw);
      final html = (payload['html'] as String? ?? '').trim();
      final sourceUrl = (payload['url'] as String? ?? _item.originalUrl).trim();
      final title = (payload['title'] as String? ?? '').trim();
      if (html.isEmpty) {
        throw const FileLibraryException(
          'The live page did not expose readable article content yet.',
        );
      }
      return _service.refreshWebpageMarkdownFromHtml(
        item: _item,
        html: html,
        sourceUrl: sourceUrl.isEmpty ? _item.originalUrl : sourceUrl,
        title: title.isEmpty ? null : title,
      );
    });
  }

  Future<void> _runMarkdownRefresh(Future<FileItem> Function() refresh) async {
    if (_isRefreshingMarkdown) {
      return;
    }
    setState(() {
      _isRefreshingMarkdown = true;
    });
    try {
      final updated = await refresh();
      if (!mounted) {
        return;
      }
      await _reloadTextForItem(updated);
      if (!mounted) {
        return;
      }
      _showMessage(context.l10n.markdownUpdated);
    } on FileLibraryException catch (error) {
      if (mounted) {
        _showMessage(context.l10n.localizeError(error.message));
      }
    } catch (_) {
      if (mounted) {
        _showMessage(context.l10n.markdownUpdateFailed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingMarkdown = false;
        });
      }
    }
  }

  Map<String, Object?> _decodeLiveCapturePayload(Object? raw) {
    Object? decoded = raw;
    if (decoded is String) {
      decoded = jsonDecode(decoded);
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }
    }
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      );
    }
    throw const FormatException('Unexpected Live Web capture response.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildTextBody() {
    if (_isLoadingText) {
      return const Center(child: CircularProgressIndicator());
    }
    return _buildCompactTextPanel(_textContent ?? context.l10n.noTextContent);
  }

  Widget _buildImageBody() {
    return Column(
      children: [
        _buildModeSwitch<_ImageViewMode>(
          segments: [
            ButtonSegment(
              value: _ImageViewMode.image,
              label: Text(context.l10n.image),
              icon: const Icon(Icons.image_outlined),
            ),
            ButtonSegment(
              value: _ImageViewMode.ocr,
              label: Text(context.l10n.ocrText),
              icon: const Icon(Icons.document_scanner_outlined),
            ),
          ],
          selected: {_imageMode},
          onSelectionChanged: (selection) {
            setState(() {
              _imageMode = selection.first;
            });
          },
        ),
        const SizedBox(height: 14),
        if (_imageMode == _ImageViewMode.ocr) ...[
          _buildOcrRefreshActions(),
          const SizedBox(height: 14),
          _buildTextBody(),
        ] else
          _buildImagePreview(),
      ],
    );
  }

  Widget _buildPdfBody(FileItem item) {
    return Column(
      children: [
        _buildModeSwitch<_PdfViewMode>(
          segments: [
            ButtonSegment(
              value: _PdfViewMode.file,
              label: Text(context.l10n.pdfFile),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
            ButtonSegment(
              value: _PdfViewMode.markdown,
              label: Text(context.l10n.markdownText),
              icon: const Icon(Icons.article_outlined),
            ),
          ],
          selected: {_pdfMode},
          onSelectionChanged: (selection) {
            setState(() {
              _pdfMode = selection.first;
            });
          },
        ),
        const SizedBox(height: 14),
        if (_pdfMode == _PdfViewMode.markdown)
          _buildTextBody()
        else
          _buildGenericFileBody(item),
      ],
    );
  }

  Widget _buildImagePreview() {
    final file = File(_item.localPath);
    return AppPanel(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => EmptyState(
            icon: Icons.broken_image_outlined,
            title: context.l10n.imageUnavailable,
            message: context.l10n.imageUnavailableBody,
          ),
        ),
      ),
    );
  }

  Widget _buildOcrRefreshActions() {
    return AppPanel(
      padding: const EdgeInsets.all(12),
      color: AppTheme.raisedSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.updateOcrHelp,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.muted,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final picker = _buildModeSwitch<ImageOcrLanguageMode>(
                segments: [
                  ButtonSegment(
                    value: ImageOcrLanguageMode.chineseEnglish,
                    label: Text(context.l10n.ocrChineseEnglish),
                  ),
                  ButtonSegment(
                    value: ImageOcrLanguageMode.japaneseEnglish,
                    label: Text(context.l10n.ocrJapaneseEnglish),
                  ),
                  ButtonSegment(
                    value: ImageOcrLanguageMode.englishOnly,
                    label: Text(context.l10n.ocrEnglishOnly),
                  ),
                ],
                selected: {_ocrLanguageMode},
                onSelectionChanged: (selection) {
                  if (_isRefreshingOcr) {
                    return;
                  }
                  setState(() {
                    _ocrLanguageMode = selection.first;
                  });
                },
              );
              final updateButton = FilledButton.icon(
                onPressed: _isRefreshingOcr ? null : _refreshImageOcr,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                icon: _isRefreshingOcr
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.document_scanner_outlined, size: 18),
                label: Text(
                  _isRefreshingOcr
                      ? context.l10n.updating
                      : context.l10n.updateOcr,
                ),
              );
              if (constraints.maxWidth < 430) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [picker, const SizedBox(height: 10), updateButton],
                );
              }
              return Row(
                children: [
                  Expanded(child: picker),
                  const SizedBox(width: 10),
                  updateButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _refreshImageOcr() async {
    if (_isRefreshingOcr) {
      return;
    }
    setState(() {
      _isRefreshingOcr = true;
    });
    try {
      final updated = await _service.refreshImageOcrMarkdown(
        _item,
        languageMode: _ocrLanguageMode,
      );
      if (!mounted) {
        return;
      }
      await _reloadTextForItem(updated);
      if (!mounted) {
        return;
      }
      _showMessage(context.l10n.ocrUpdated);
    } on FileLibraryException catch (error) {
      if (mounted) {
        _showMessage(context.l10n.localizeError(error.message));
      }
    } catch (_) {
      if (mounted) {
        _showMessage(context.l10n.ocrUpdateFailed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingOcr = false;
        });
      }
    }
  }

  Widget _buildGenericFileBody(FileItem item) {
    return AppPanel(
      child: Column(
        children: [
          _UnavailableContent(
            icon: Icons.insert_drive_file_outlined,
            title: context.l10n.previewUnavailable,
            message: context.l10n.previewUnavailableBody,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openExternally,
              icon: const Icon(Icons.open_in_new),
              label: Text(context.l10n.openExternally),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuAction extends StatelessWidget {
  const _MenuAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppTheme.ink),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParsedMarkdown {
  const _ParsedMarkdown({required this.metadata, required this.body});

  final Map<String, String> metadata;
  final String body;

  factory _ParsedMarkdown.from(String value) {
    if (!value.startsWith('---')) {
      return _ParsedMarkdown(metadata: const {}, body: value);
    }
    final match = RegExp(r'^---\s*\n([\s\S]*?)\n---\s*\n?').firstMatch(value);
    if (match == null) {
      return _ParsedMarkdown(metadata: const {}, body: value);
    }
    final metadata = <String, String>{};
    for (final line in match.group(1)!.split('\n')) {
      final separator = line.indexOf(':');
      if (separator <= 0) {
        continue;
      }
      final key = line.substring(0, separator).trim();
      final rawValue = line.substring(separator + 1).trim();
      metadata[key] = _cleanMetadataValue(rawValue);
    }
    final body = value.substring(match.end).trimLeft();
    return _ParsedMarkdown(metadata: metadata, body: body);
  }

  static String _cleanMetadataValue(String value) {
    final trimmed = value.trim();
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is String) {
          return decoded;
        }
      } catch (_) {
        return trimmed.substring(1, trimmed.length - 1);
      }
    }
    return trimmed;
  }
}

class _MarkdownMetadataPanel extends StatelessWidget {
  const _MarkdownMetadataPanel({required this.metadata});

  final Map<String, String> metadata;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = metadata['title'];
    final sourceFile = metadata['source_file'];
    final source = sourceFile ?? metadata['source'];
    final capturedAt = _formatMetadataDate(metadata['captured_at']);
    final entries = <_MetadataEntry>[
      if (title != null && title.isNotEmpty)
        _MetadataEntry(Icons.title, l10n.title, title),
      if (source != null && source.isNotEmpty)
        _MetadataEntry(
          Icons.insert_drive_file_outlined,
          l10n.sourceFile,
          sourceFile == null ? source : p.basename(source),
        ),
      if (capturedAt != null && capturedAt.isNotEmpty)
        _MetadataEntry(Icons.schedule_outlined, l10n.capturedAt, capturedAt),
      if ((metadata['ocr_status'] ?? '').isNotEmpty)
        _MetadataEntry(
          Icons.document_scanner_outlined,
          l10n.ocrStatus,
          metadata['ocr_status']!,
        ),
      if ((metadata['scripts'] ?? '').isNotEmpty)
        _MetadataEntry(
          Icons.translate_outlined,
          l10n.ocrScripts,
          metadata['scripts']!,
        ),
      if ((metadata['image_size'] ?? '').isNotEmpty)
        _MetadataEntry(
          Icons.photo_size_select_large_outlined,
          l10n.imageSize,
          metadata['image_size']!,
        ),
      if ((metadata['ocr_tiles'] ?? '').isNotEmpty)
        _MetadataEntry(
          Icons.grid_view_outlined,
          l10n.ocrTiles,
          metadata['ocr_tiles']!,
        ),
    ];
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.raisedSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppTheme.primary),
              const SizedBox(width: 7),
              Text(
                l10n.ocrMetadata,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in entries) _MetadataChip(entry: entry),
            ],
          ),
        ],
      ),
    );
  }

  static String? _formatMetadataDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      return value;
    }
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} '
        '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }
}

class _MetadataEntry {
  const _MetadataEntry(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.entry});

  final _MetadataEntry entry;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.primarySoft,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(entry.icon, size: 15, color: AppTheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${entry.label}: ${entry.value}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnavailableContent extends StatelessWidget {
  const _UnavailableContent({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.path, required this.onOpen});

  final String path;
  final VoidCallback onOpen;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final controller = VideoPlayerController.file(File(widget.path));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed) {
      return AppPanel(
        child: Column(
          children: [
            _UnavailableContent(
              icon: Icons.movie_filter_outlined,
              title: context.l10n.videoPreviewUnavailable,
              message: context.l10n.videoPreviewUnavailableBody,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.onOpen,
                icon: const Icon(Icons.open_in_new),
                label: Text(context.l10n.openExternally),
              ),
            ),
          ],
        ),
      );
    }
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return AppPanel(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filled(
                style: IconButton.styleFrom(
                  fixedSize: const Size(42, 42),
                  minimumSize: const Size(42, 42),
                ),
                onPressed: () {
                  setState(() {
                    controller.value.isPlaying
                        ? controller.pause()
                        : controller.play();
                  });
                },
                icon: Icon(
                  controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: VideoProgressIndicator(controller, allowScrubbing: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
