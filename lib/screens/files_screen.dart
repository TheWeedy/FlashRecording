import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../models/note_item.dart';
import '../models/file_item.dart';
import '../theme/app_theme.dart';
import '../utils/ai_service.dart';
import '../utils/app_localizations.dart';
import '../utils/cloud_sync_service.dart';
import '../utils/file_library_service.dart';
import '../utils/note_persistence.dart';
import '../widgets/app_components.dart';
import '../widgets/responsive_scaffold.dart';
import 'file_detail_screen.dart';

enum _FileLibraryView { active, archived }

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => FilesScreenState();
}

class FilesScreenState extends State<FilesScreen> {
  final FileLibraryService _service = FileLibraryService();
  final TextEditingController _searchController = TextEditingController();

  List<FileItem> _items = [];
  List<FileTag> _tags = [];
  final Set<String> _selectedIds = {};
  String? _focusedItemId;
  String? _selectedTagId;
  _FileLibraryView _view = _FileLibraryView.active;
  bool _isLoading = true;
  bool _isImporting = false;
  bool _isAiTitling = false;

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(refreshFromCloud(force: false));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _service.loadItems(
      query: _searchController.text,
      tagId: _selectedTagId,
      archived: _view == _FileLibraryView.archived,
    );
    final tags = await _service.loadTags();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _tags = tags;
      _isLoading = false;
    });
  }

  Future<void> refresh() => _load();

  Future<void> refreshFromCloud({bool force = true}) async {
    await CloudSyncService.instance.syncNow(force: force);
    await _load();
  }

  FileItem? get _focusedItem {
    if (_items.isEmpty) {
      return null;
    }
    final focusedId = _focusedItemId;
    if (focusedId == null) {
      return _items.first;
    }
    for (final item in _items) {
      if (item.id == focusedId) {
        return item;
      }
    }
    return _items.first;
  }

  Future<void> importSharedText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _runImport(() => _service.addSharedText(trimmed));
  }

  Future<void> importSharedFile(String path, {String? mimeType}) async {
    await _runImport(() => _service.addFile(path, mimeType: mimeType));
  }

  Future<void> _runImport(Future<FileItem> Function() action) async {
    if (_isImporting) {
      return;
    }
    setState(() {
      _isImporting = true;
    });
    try {
      await action();
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.addedToFiles)));
    } on FileLibraryException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.localizeError(error.message))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _showAddSheet() async {
    await showAppActionSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSheetHeader(
              icon: Icons.library_add_outlined,
              title: context.l10n.addToFiles,
              description: context.l10n.filesDescription,
              accent: AppTheme.primary,
            ),
            const SizedBox(height: AppTheme.space3),
            AppActionTile(
              icon: Icons.public,
              title: context.l10n.addWebpage,
              subtitle: context.l10n.addWebpageSubtitle,
              onTap: () {
                Navigator.of(context).pop();
                unawaited(_showAddWebpageDialog());
              },
            ),
            const SizedBox(height: AppTheme.space2),
            AppActionTile(
              icon: Icons.notes_outlined,
              title: context.l10n.addText,
              subtitle: context.l10n.addTextSubtitle,
              accent: AppTheme.copper,
              onTap: () {
                Navigator.of(context).pop();
                unawaited(_showAddTextDialog());
              },
            ),
            const SizedBox(height: AppTheme.space2),
            AppActionTile(
              icon: Icons.attach_file,
              title: context.l10n.addFiles,
              subtitle: context.l10n.addFilesSubtitle,
              accent: AppTheme.steel,
              onTap: () {
                Navigator.of(context).pop();
                unawaited(_pickFiles());
              },
            ),
            const SizedBox(height: AppTheme.space2),
            AppActionTile(
              icon: Icons.new_label_outlined,
              title: context.l10n.addTags,
              subtitle: context.l10n.addTagsSubtitle,
              accent: AppTheme.success,
              onTap: () {
                Navigator.of(context).pop();
                unawaited(_showTagManager());
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddWebpageDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.addWebpage),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'https://example.com/article',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final url = controller.text;
                Navigator.of(dialogContext).pop();
                unawaited(_runImport(() => _service.addWebpage(url)));
              },
              child: Text(context.l10n.save),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  Future<void> _showAddTextDialog() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.addText),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: context.l10n.title),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  minLines: 5,
                  maxLines: 10,
                  decoration: InputDecoration(labelText: context.l10n.content),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text;
                final content = contentController.text;
                Navigator.of(dialogContext).pop();
                unawaited(
                  _runImport(
                    () => _service.addText(title: title, content: content),
                  ),
                );
              },
              child: Text(context.l10n.save),
            ),
          ],
        );
      },
    );
    titleController.dispose();
    contentController.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null) {
      return;
    }
    setState(() {
      _isImporting = true;
    });
    try {
      for (final file in result.files) {
        final path = file.path;
        if (path != null) {
          await _service.addFile(path);
        }
      }
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.filesImported)));
    } on FileLibraryException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.localizeError(error.message))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _showTagEditor(FileItem item) async {
    var tags = await _service.loadTags();
    if (!mounted) {
      return;
    }
    final selectedTagIds = item.tags.map((tag) => tag.id).toSet();
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 28,
              ),
              backgroundColor: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.78,
                ),
                child: Material(
                  color: AppTheme.surface,
                  surfaceTintColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppTheme.primarySoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Icon(
                                Icons.sell_outlined,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.editTags,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: AppTheme.ink,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppTheme.muted,
                                          height: 1.35,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.raisedSurface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusControl,
                                  ),
                                  side: const BorderSide(
                                    color: AppTheme.border,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                  labelText: context.l10n.newTag,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              tooltip: context.l10n.addTag,
                              onPressed: () async {
                                try {
                                  final tag = await _service.ensureTag(
                                    controller.text,
                                  );
                                  controller.clear();
                                  tags = await _service.loadTags();
                                  selectedTagIds.add(tag.id);
                                  setDialogState(() {});
                                } on FileLibraryException catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(error.message)),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(color: AppTheme.border, height: 1),
                        const SizedBox(height: 12),
                        Flexible(
                          child: tags.isEmpty
                              ? EmptyState(
                                  icon: Icons.sell_outlined,
                                  title: context.l10n.noTagsYet,
                                  message: context.l10n.createTagAbove,
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: tags.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 4),
                                  itemBuilder: (context, index) {
                                    final tag = tags[index];
                                    final selected = selectedTagIds.contains(
                                      tag.id,
                                    );
                                    return ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Checkbox(
                                        value: selected,
                                        onChanged: (_) {
                                          if (selected) {
                                            selectedTagIds.remove(tag.id);
                                          } else {
                                            selectedTagIds.add(tag.id);
                                          }
                                          setDialogState(() {});
                                        },
                                      ),
                                      title: Text(tag.name),
                                      trailing: IconButton(
                                        tooltip: context.l10n.deleteTag,
                                        onPressed: () async {
                                          await _service.deleteTag(tag.id);
                                          selectedTagIds.remove(tag.id);
                                          tags = await _service.loadTags();
                                          setDialogState(() {});
                                        },
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                      onTap: () {
                                        if (selected) {
                                          selectedTagIds.remove(tag.id);
                                        } else {
                                          selectedTagIds.add(tag.id);
                                        }
                                        setDialogState(() {});
                                      },
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () async {
                              await _service.setTagsForItem(
                                itemId: item.id,
                                tagIds: selectedTagIds,
                              );
                              if (!mounted) {
                                return;
                              }
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                              await _load();
                            },
                            child: Text(context.l10n.saveTags),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<void> _showTagManager() async {
    var tags = await _service.loadTags();
    if (!mounted) {
      return;
    }
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> createTag() async {
              try {
                await _service.ensureTag(controller.text);
                controller.clear();
                tags = await _service.loadTags();
                setDialogState(() {});
                await _load();
              } on FileLibraryException catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.localizeError(error.message)),
                    ),
                  );
                }
              }
            }

            Future<void> reorderTags(int oldIndex, int newIndex) async {
              final reordered = [...tags];
              final moved = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, moved);
              tags = reordered;
              setDialogState(() {});
              await _service.reorderTags(
                reordered.map((tag) => tag.id).toList(),
              );
              tags = await _service.loadTags();
              setDialogState(() {});
              await _load();
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: MediaQuery.sizeOf(context).height * 0.78,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppTheme.primarySoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Icon(
                              Icons.sell_outlined,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.l10n.manageTags,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppTheme.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: context.l10n.cancel,
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => createTag(),
                              decoration: InputDecoration(
                                labelText: context.l10n.newTag,
                                prefixIcon: const Icon(Icons.add),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            tooltip: context.l10n.addTag,
                            onPressed: createTag,
                            icon: const Icon(Icons.check),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(color: AppTheme.border, height: 1),
                      const SizedBox(height: 8),
                      Flexible(
                        child: tags.isEmpty
                            ? EmptyState(
                                icon: Icons.sell_outlined,
                                title: context.l10n.noTagsYet,
                                message: context.l10n.createTagAbove,
                              )
                            : ReorderableListView.builder(
                                shrinkWrap: true,
                                buildDefaultDragHandles: true,
                                itemCount: tags.length,
                                onReorderItem: (oldIndex, newIndex) =>
                                    unawaited(reorderTags(oldIndex, newIndex)),
                                itemBuilder: (context, index) {
                                  final tag = tags[index];
                                  return Padding(
                                    key: ValueKey(tag.id),
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.drag_handle),
                                      title: Text(
                                        tag.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Wrap(
                                        spacing: 2,
                                        children: [
                                          IconButton(
                                            tooltip: context.l10n.rename,
                                            onPressed: () async {
                                              await _showRenameTagDialog(tag);
                                              tags = await _service.loadTags();
                                              setDialogState(() {});
                                            },
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: context.l10n.deleteTag,
                                            color: AppTheme.danger,
                                            onPressed: () async {
                                              await _deleteTag(tag);
                                              tags = await _service.loadTags();
                                              setDialogState(() {});
                                            },
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<void> _showRenameTagDialog(FileTag tag) async {
    final controller = TextEditingController(text: tag.name);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.rename),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: context.l10n.newTag),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                try {
                  await _service.renameTag(id: tag.id, name: controller.text);
                  if (!mounted) {
                    return;
                  }
                  navigator.pop();
                  await _load();
                } on FileLibraryException catch (error) {
                  if (!mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.localizeError(error.message)),
                    ),
                  );
                }
              },
              child: Text(context.l10n.save),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  Future<void> _deleteTag(FileTag tag) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.deleteTagTitle(tag.name)),
            content: Text(context.l10n.deleteTagBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.delete),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) {
      return;
    }
    await _service.deleteTag(tag.id);
    if (_selectedTagId == tag.id) {
      _selectedTagId = null;
    }
    await _load();
  }

  Future<void> _archiveSelected() async {
    await _service.archiveItems(_selectedIds);
    _exitSelectionMode();
    await _load();
  }

  Future<void> _archiveItem(FileItem item) async {
    await _service.archiveItems([item.id]);
    await _load();
  }

  Future<void> _restoreSelected() async {
    await _service.restoreItems(_selectedIds);
    _exitSelectionMode();
    await _load();
  }

  Future<void> _restoreItem(FileItem item) async {
    await _service.restoreItems([item.id]);
    await _load();
  }

  Future<void> _showSelectedFilesAiChat() async {
    final selectedItems = _items
        .where((item) => _selectedIds.contains(item.id))
        .toList(growable: false);
    if (selectedItems.isEmpty) {
      return;
    }
    await showAppActionSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => FileAiChatSheet(items: selectedItems),
    );
  }

  Future<void> _showRenameItemDialog(FileItem item) async {
    final controller = TextEditingController(text: item.title);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.renameFile),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: context.l10n.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                try {
                  await _service.renameItem(
                    id: item.id,
                    title: controller.text,
                  );
                  if (!mounted) {
                    return;
                  }
                  navigator.pop();
                  await _load();
                } on FileLibraryException catch (error) {
                  if (!mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.localizeError(error.message)),
                    ),
                  );
                }
              },
              child: Text(context.l10n.save),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }

  Future<void> _showAiTitleSheet() async {
    final pending = await _service.loadAiTitlePendingItems();
    if (!mounted) {
      return;
    }
    await showAppActionSheet<void>(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> generate() async {
              if (_isAiTitling || pending.isEmpty) {
                return;
              }
              final l10n = this.context.l10n;
              final messenger = ScaffoldMessenger.of(this.context);
              setSheetState(() {
                _isAiTitling = true;
              });
              setState(() {
                _isAiTitling = true;
              });
              try {
                final result = await _service.generateAiTitlesForPendingFiles();
                if (!mounted) {
                  return;
                }
                await _load();
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      result.updatedCount == 0
                          ? l10n.aiTitleNoPending
                          : l10n.aiTitleUpdatedCount(result.updatedCount),
                    ),
                  ),
                );
              } on Object catch (error) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l10n.localizeError('$error'))),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isAiTitling = false;
                  });
                }
                if (sheetContext.mounted) {
                  setSheetState(() {
                    _isAiTitling = false;
                  });
                }
              }
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSheetHeader(
                    icon: Icons.auto_awesome_outlined,
                    title: context.l10n.aiTitleFiles,
                    description: context.l10n.aiTitleFilesBody,
                    accent: AppTheme.warning,
                  ),
                  const SizedBox(height: 14),
                  AppPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pending.isEmpty
                                ? context.l10n.aiTitleNoPending
                                : context.l10n.aiTitlePendingCount(
                                    pending.length,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: pending.isEmpty || _isAiTitling
                          ? null
                          : generate,
                      icon: _isAiTitling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_outlined),
                      label: Text(context.l10n.generateAiTitles),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSelected() async {
    final deleted = await _deleteItems(_selectedIds);
    if (deleted) {
      _exitSelectionMode();
    }
  }

  Future<void> _deleteItem(FileItem item) async {
    await _deleteItems([item.id]);
  }

  Future<bool> _deleteItems(Iterable<String> ids) async {
    final idList = ids.toList(growable: false);
    if (idList.isEmpty) {
      return false;
    }
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.deleteSelectedFiles),
            content: Text(context.l10n.deleteFilesMessage(idList.length)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.delete),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldDelete) {
      return false;
    }
    await _service.deleteItems(idList);
    await _load();
    return true;
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedIds.clear();
    });
  }

  void _openItem(FileItem item) {
    if (_selectedIds.isNotEmpty) {
      _toggleSelection(item.id);
      return;
    }
    if (isDesktopLayout(context)) {
      setState(() {
        _focusedItemId = item.id;
      });
      return;
    }
    unawaited(_openItemPage(item));
  }

  Future<void> _openItemPage(FileItem item) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => FileDetailScreen(item: item)));
    await _load();
  }

  String _filesHeaderMeta() {
    final showingArchive = _view == _FileLibraryView.archived;
    return context.l10n.ui(
      '${showingArchive ? '归档' : '当前'} ${_items.length} 个文件 · ${_tags.length} 个标签',
      '${showingArchive ? 'Archived' : 'Current'} ${_items.length} files · ${_tags.length} tags',
      '${showingArchive ? 'アーカイブ' : '現在'} ${_items.length} 件 · タグ ${_tags.length}',
    );
  }

  Widget _buildDesktopFilters() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            eyebrow: context.l10n.filesEyebrow,
            title: context.l10n.filesTitle,
            description: _filesHeaderMeta(),
            showContext: false,
            showCompactMeta: true,
            trailing: QuietIconButton(
              icon: Icons.auto_awesome_outlined,
              tooltip: context.l10n.aiTitleFiles,
              onPressed: _showAiTitleSheet,
            ),
          ),
          const SizedBox(height: AppTheme.space3),
          _buildSearch(),
          const SizedBox(height: AppTheme.space3),
          ChoiceChip(
            avatar: const Icon(Icons.layers_outlined, size: 18),
            showCheckmark: false,
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(context.l10n.allFiles),
            ),
            selected:
                _view == _FileLibraryView.active && _selectedTagId == null,
            onSelected: (_) {
              setState(() {
                _view = _FileLibraryView.active;
                _selectedTagId = null;
              });
              _load();
            },
          ),
          const SizedBox(height: AppTheme.space1),
          ChoiceChip(
            avatar: const Icon(Icons.archive_outlined, size: 18),
            showCheckmark: false,
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(context.l10n.archivedFiles),
            ),
            selected:
                _view == _FileLibraryView.archived && _selectedTagId == null,
            onSelected: (_) {
              setState(() {
                _view = _FileLibraryView.archived;
                _selectedTagId = null;
              });
              _load();
            },
          ),
          const SizedBox(height: AppTheme.space2),
          for (final tag in _tags) ...[
            ChoiceChip(
              avatar: const Icon(Icons.sell_outlined, size: 18),
              showCheckmark: false,
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(tag.name),
              ),
              selected: _selectedTagId == tag.id,
              onSelected: (_) {
                setState(() {
                  _view = _FileLibraryView.active;
                  _selectedTagId = tag.id;
                });
                _load();
              },
            ),
            const SizedBox(height: AppTheme.space1),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopDetailPanel() {
    final item = _focusedItem;
    if (item == null) {
      return EmptyState(
        icon: Icons.folder_copy_outlined,
        title: context.l10n.noFilesTitle,
        message: context.l10n.noFilesMessage,
      );
    }
    final archived = _view == _FileLibraryView.archived;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            eyebrow: archived
                ? context.l10n.archivedFiles
                : context.l10n.ui('当前文件', 'Selected file', '選択中のファイル'),
            title: item.title,
            description: _sourceLabel(item),
            trailing: PopupMenuButton<String>(
              tooltip: context.l10n.fileActions,
              onSelected: (value) {
                if (value == 'open') {
                  unawaited(_openItemPage(item));
                } else if (value == 'tag') {
                  unawaited(_showTagEditor(item));
                } else if (value == 'rename') {
                  unawaited(_showRenameItemDialog(item));
                } else if (value == 'archive') {
                  unawaited(_archiveItem(item));
                } else if (value == 'restore') {
                  unawaited(_restoreItem(item));
                } else if (value == 'delete') {
                  unawaited(_deleteItem(item));
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'open',
                  child: _FileMenuAction(
                    icon: Icons.open_in_new,
                    label: context.l10n.openExternally,
                  ),
                ),
                if (!archived)
                  PopupMenuItem(
                    value: 'tag',
                    child: _FileMenuAction(
                      icon: Icons.sell_outlined,
                      label: context.l10n.editTags,
                    ),
                  ),
                PopupMenuItem(
                  value: 'rename',
                  child: _FileMenuAction(
                    icon: Icons.edit_outlined,
                    label: context.l10n.rename,
                  ),
                ),
                PopupMenuItem(
                  value: archived ? 'restore' : 'archive',
                  child: _FileMenuAction(
                    icon: archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    label: archived
                        ? context.l10n.restore
                        : context.l10n.archive,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: _FileMenuAction(
                    icon: Icons.delete_outline,
                    label: context.l10n.delete,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space3),
          AppPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppChip(
                      icon: _iconForKind(item.kind),
                      label: item.kind.label,
                      color: AppTheme.primary,
                    ),
                    AppChip(
                      icon: Icons.update,
                      label: context.l10n.updatedAt(
                        _formatDateTime(item.updatedAt),
                      ),
                      color: AppTheme.steel,
                    ),
                    for (final tag in item.tags)
                      AppChip(
                        label: tag.name,
                        color: AppTheme.steel,
                        icon: Icons.sell_outlined,
                        maxWidth: 160,
                      ),
                  ],
                ),
                const SizedBox(height: AppTheme.space3),
                SelectableText(
                  item.plainTextPreview.isEmpty
                      ? '${item.kind.label} item'
                      : item.plainTextPreview,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.ink,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space3),
          FilledButton.icon(
            onPressed: () => unawaited(_openItemPage(item)),
            icon: const Icon(Icons.open_in_new),
            label: Text(context.l10n.openExternally),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(int selectedCount) {
    return AdaptiveWorkspace(
      primaryFlex: 3,
      secondaryFlex: 5,
      tertiaryFlex: 4,
      primary: _buildDesktopFilters(),
      secondary: RefreshIndicator(
        onRefresh: refreshFromCloud,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionHeader(
              eyebrow: context.l10n.ui('资料列表', 'Library', 'ライブラリ'),
              title: selectedCount == 0
                  ? context.l10n.filesTitle
                  : context.l10n.selectedCount(selectedCount),
              description: context.l10n.filesDescription,
              showContext: false,
              trailing: selectedCount == 0
                  ? QuietIconButton(
                      icon: Icons.auto_awesome_outlined,
                      tooltip: context.l10n.aiTitleFiles,
                      onPressed: _showAiTitleSheet,
                    )
                  : null,
            ),
            const SizedBox(height: AppTheme.space3),
            if (_isImporting)
              const LinearProgressIndicator(minHeight: 3)
            else if (_items.isEmpty)
              EmptyState(
                icon: Icons.folder_copy_outlined,
                title: context.l10n.noFilesTitle,
                message: context.l10n.noFilesMessage,
              )
            else
              ...List.generate(
                _items.length,
                (index) => _buildItemCard(_items[index], index),
              ),
          ],
        ),
      ),
      tertiary: _buildDesktopDetailPanel(),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final selectedCount = _selectedIds.length;
    final l10n = context.l10n;
    final showingArchive = _view == _FileLibraryView.archived;
    if (isDesktopLayout(context)) {
      return PopScope(
        canPop: selectedCount == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _selectedIds.isNotEmpty) {
            _exitSelectionMode();
          }
        },
        child: Scaffold(
          body: SafeArea(child: _buildDesktopLayout(selectedCount)),
          floatingActionButtonLocation: const AppTuckedEndFabLocation(),
          floatingActionButton: _buildFileContextualFab(selectedCount),
        ),
      );
    }
    return PopScope(
      canPop: selectedCount == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedIds.isNotEmpty) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: refreshFromCloud,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                18,
                AppTheme.pagePadding,
                selectedCount > 0 ? 150 : 104,
              ),
              children: [
                PageIntro(
                  eyebrow: l10n.filesEyebrow,
                  title: selectedCount == 0
                      ? l10n.filesTitle
                      : l10n.selectedCount(selectedCount),
                  description: selectedCount == 0
                      ? _filesHeaderMeta()
                      : l10n.filesDescription,
                  showContext: false,
                  showCompactMeta: selectedCount == 0,
                  trailing: selectedCount == 0
                      ? QuietIconButton(
                          icon: Icons.auto_awesome_outlined,
                          tooltip: l10n.aiTitleFiles,
                          onPressed: _showAiTitleSheet,
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                if (selectedCount == 0) ...[
                  _buildSearch(),
                  const SizedBox(height: 12),
                ],
                _buildTagFilters(),
                const SizedBox(height: 16),
                if (_isImporting)
                  const LinearProgressIndicator(minHeight: 3)
                else if (_items.isEmpty)
                  EmptyState(
                    icon: showingArchive
                        ? Icons.archive_outlined
                        : Icons.folder_copy_outlined,
                    title: showingArchive
                        ? l10n.ui('归档为空', 'Archive is empty', 'アーカイブは空です')
                        : l10n.noFilesTitle,
                    message: showingArchive
                        ? l10n.ui(
                            '归档后的文件会显示在这里，可随时恢复。',
                            'Archived files appear here and can be restored anytime.',
                            'アーカイブ済みファイルはここに表示され、いつでも復元できます。',
                          )
                        : l10n.noFilesMessage,
                  )
                else
                  ...List.generate(
                    _items.length,
                    (index) => _buildItemCard(_items[index], index),
                  ),
              ],
            ),
          ),
        ),
        floatingActionButtonLocation: const AppTuckedEndFabLocation(),
        floatingActionButton: _buildFileContextualFab(selectedCount),
      ),
    );
  }

  Widget _buildFileContextualFab(int selectedCount) {
    final showingArchive = _view == _FileLibraryView.archived;
    final isSelectionMode = selectedCount > 0;
    return ContextualActionFab(
      heroTag: 'files-contextual-fab',
      tooltip: isSelectionMode ? context.l10n.delete : context.l10n.addToFiles,
      icon: isSelectionMode ? Icons.delete : Icons.add,
      isDestructive: isSelectionMode,
      onPressed: isSelectionMode
          ? _deleteSelected
          : _isImporting
          ? null
          : _showAddSheet,
      actions: isSelectionMode
          ? [
              ContextualFabAction(
                icon: Icons.psychology_outlined,
                label: context.l10n.askSelectedFiles,
                tooltip: context.l10n.askSelectedFiles,
                onPressed: _showSelectedFilesAiChat,
                backgroundColor: AppTheme.sunshineSoft,
                foregroundColor: AppTheme.warning,
              ),
              ContextualFabAction(
                icon: showingArchive
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                label: showingArchive
                    ? context.l10n.restoreSelected
                    : context.l10n.archiveSelected,
                tooltip: showingArchive
                    ? context.l10n.restoreSelected
                    : context.l10n.archiveSelected,
                onPressed: showingArchive ? _restoreSelected : _archiveSelected,
              ),
              ContextualFabAction(
                icon: Icons.close,
                label: context.l10n.clearSelection,
                tooltip: context.l10n.clearSelection,
                onPressed: _exitSelectionMode,
              ),
            ]
          : const [],
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onChanged: (_) => _load(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: context.l10n.searchFiles,
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  _load();
                },
                icon: const Icon(Icons.close),
              ),
      ),
    );
  }

  Widget _buildTagFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            avatar: const Icon(Icons.layers_outlined, size: 18),
            showCheckmark: false,
            label: Text(context.l10n.allFiles),
            selected:
                _view == _FileLibraryView.active && _selectedTagId == null,
            onSelected: (_) {
              setState(() {
                _view = _FileLibraryView.active;
                _selectedTagId = null;
              });
              _load();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: const Icon(Icons.archive_outlined, size: 18),
            showCheckmark: false,
            label: Text(context.l10n.archivedFiles),
            selected:
                _view == _FileLibraryView.archived && _selectedTagId == null,
            onSelected: (_) {
              setState(() {
                _view = _FileLibraryView.archived;
                _selectedTagId = null;
              });
              _load();
            },
          ),
          const SizedBox(width: 8),
          for (final tag in _tags) ...[
            ChoiceChip(
              avatar: const Icon(Icons.sell_outlined, size: 18),
              showCheckmark: false,
              label: Text(tag.name),
              selected: _selectedTagId == tag.id,
              onSelected: (_) {
                setState(() {
                  _view = _FileLibraryView.active;
                  _selectedTagId = tag.id;
                });
                _load();
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildItemCard(FileItem item, int index) {
    final selected = _selectedIds.contains(item.id);
    final isSelectionMode = _selectedIds.isNotEmpty;
    final archived = _view == _FileLibraryView.archived;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FadeSlideIn(
        delay: Duration(milliseconds: 25 * (index > 8 ? 8 : index)),
        child: AppPanel(
          padding: EdgeInsets.zero,
          color: selected ? AppTheme.primarySoft : AppTheme.surface,
          borderColor: selected ? AppTheme.primary : AppTheme.border,
          child: InkWell(
            onTap: () => _openItem(item),
            onLongPress: () => _toggleSelection(item.id),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSelectionMode) ...[
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Checkbox(
                        value: selected,
                        onChanged: (_) => _toggleSelection(item.id),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: archived
                            ? AppTheme.copperSoft
                            : AppTheme.primarySoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        archived
                            ? Icons.archive_outlined
                            : _iconForKind(item.kind),
                        color: archived ? AppTheme.copper : AppTheme.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.18,
                                    ),
                              ),
                            ),
                            if (!isSelectionMode) _buildFileMenu(item),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              _iconForKind(item.kind),
                              size: 14,
                              color: AppTheme.faint,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _sourceLabel(item),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.muted,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          item.plainTextPreview.isEmpty
                              ? '${item.kind.label} item'
                              : item.plainTextPreview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.muted, height: 1.35),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            AppChip(
                              icon: archived
                                  ? Icons.archive_outlined
                                  : Icons.update,
                              label: archived
                                  ? context.l10n.archivedFiles
                                  : context.l10n.updatedAt(
                                      _formatDateTime(item.updatedAt),
                                    ),
                              color: archived
                                  ? AppTheme.copper
                                  : AppTheme.steel,
                            ),
                            for (final tag in item.tags)
                              AppChip(
                                label: tag.name,
                                color: AppTheme.steel,
                                icon: Icons.sell_outlined,
                                maxWidth: 160,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileMenu(FileItem item) {
    final archived = _view == _FileLibraryView.archived;
    return PopupMenuButton<String>(
      tooltip: context.l10n.fileActions,
      color: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        side: const BorderSide(color: AppTheme.border),
      ),
      onSelected: (value) {
        if (value == 'tag') {
          unawaited(_showTagEditor(item));
        } else if (value == 'rename') {
          unawaited(_showRenameItemDialog(item));
        } else if (value == 'archive') {
          unawaited(_archiveItem(item));
        } else if (value == 'restore') {
          unawaited(_restoreItem(item));
        } else if (value == 'delete') {
          unawaited(_deleteItem(item));
        }
      },
      itemBuilder: (context) => [
        if (!archived)
          PopupMenuItem(
            value: 'tag',
            child: _FileMenuAction(
              icon: Icons.sell_outlined,
              label: context.l10n.editTags,
            ),
          ),
        PopupMenuItem(
          value: 'rename',
          child: _FileMenuAction(
            icon: Icons.edit_outlined,
            label: context.l10n.rename,
          ),
        ),
        PopupMenuItem(
          value: archived ? 'restore' : 'archive',
          child: _FileMenuAction(
            icon: archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            label: archived ? context.l10n.restore : context.l10n.archive,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: _FileMenuAction(
            icon: Icons.delete_outline,
            label: context.l10n.delete,
            color: AppTheme.danger,
          ),
        ),
      ],
    );
  }

  IconData _iconForKind(FileItemKind kind) {
    switch (kind) {
      case FileItemKind.web:
        return Icons.public;
      case FileItemKind.text:
        return Icons.description_outlined;
      case FileItemKind.image:
        return Icons.image_outlined;
      case FileItemKind.video:
        return Icons.movie_outlined;
      case FileItemKind.pdf:
        return Icons.picture_as_pdf_outlined;
      case FileItemKind.file:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _hostForUrl(String url) {
    return Uri.tryParse(url)?.host ?? url;
  }

  String _sourceLabel(FileItem item) {
    if (item.originalUrl.isNotEmpty) {
      return _hostForUrl(item.originalUrl);
    }
    if (item.mimeType.isNotEmpty) {
      return item.mimeType;
    }
    return item.kind.label;
  }

  String _formatDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
}

class _FileMenuAction extends StatelessWidget {
  const _FileMenuAction({
    required this.icon,
    required this.label,
    this.color = AppTheme.ink,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FileAiChatSheet extends StatefulWidget {
  const FileAiChatSheet({super.key, required this.items});

  final List<FileItem> items;

  @override
  State<FileAiChatSheet> createState() => _FileAiChatSheetState();
}

class _FileAiChatSheetState extends State<FileAiChatSheet> {
  final AiService _aiService = AiService();
  final NotePersistenceService _noteService = NotePersistenceService();
  final TextEditingController _questionController = TextEditingController();
  bool _isLoading = false;
  bool _isSavingNote = false;
  String? _answer;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _saveAnswerToNotes() async {
    final answer = _answer;
    final question = _questionController.text.trim();
    if (answer == null || answer.trim().isEmpty) {
      return;
    }
    setState(() {
      _isSavingNote = true;
    });
    try {
      final sourceLines = widget.items
          .map((item) => '- ${item.title}')
          .join('\n');
      final content =
          '''
# Question

$question

# Answer

$answer

# Sources

$sourceLines
''';
      final document = Document()..insert(0, content);
      final now = DateTime.now();
      final titleSeed = question.isEmpty ? answer : question;
      final title = _noteTitle(titleSeed);
      await _noteService.upsertNote(
        NoteItem(
          id: now.microsecondsSinceEpoch.toString(),
          title: title,
          deltaJson: jsonEncode(document.toDelta().toJson()),
          plainTextPreview: content,
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.aiAnswerSaved)));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingNote = false;
        });
      }
    }
  }

  String _noteTitle(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) {
      return 'AI answer';
    }
    return compact.length <= 60 ? compact : compact.substring(0, 60);
  }

  void _applyQuickPrompt(String prompt) {
    _questionController.text = prompt;
    _questionController.selection = TextSelection.collapsed(
      offset: _questionController.text.length,
    );
  }

  Future<void> _ask() async {
    final question = _questionController.text.trim();
    if (question.isEmpty) {
      return;
    }
    setState(() {
      _isLoading = true;
      _answer = null;
    });
    try {
      final prompt = await _buildPrompt(question);
      final answer = await _aiService.complete(
        systemPrompt:
            'You answer questions from a personal knowledge base. Use only the provided materials when possible. Respond in concise Chinese markdown.',
        userPrompt: prompt,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _answer = answer;
      });
    } on AiServiceException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.localizeError(error.message))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String> _buildPrompt(String question) async {
    const perFileLimit = 8000;
    const totalLimit = 24000;
    var total = 0;
    var truncated = false;
    final buffer = StringBuffer();
    final usable = widget.items.where((item) => item.canAnswerWithAi).toList();
    final skipped = widget.items.length - usable.length;
    for (final item in usable) {
      var content = await item.loadTextContent().catchError((_) => '');
      if (content.length > perFileLimit) {
        content = content.substring(0, perFileLimit);
        truncated = true;
      }
      if (total + content.length > totalLimit) {
        final remaining = totalLimit - total;
        if (remaining <= 0) {
          truncated = true;
          break;
        }
        content = content.substring(0, remaining);
        truncated = true;
      }
      total += content.length;
      buffer.writeln('## ${item.title}');
      if (item.originalUrl.isNotEmpty) {
        buffer.writeln('Source: ${item.originalUrl}');
      }
      buffer.writeln(content);
      buffer.writeln('\n---\n');
    }

    return '''
用户问题：
$question

材料说明：
- 可用于问答的材料：${usable.length}
- 跳过的不可问答材料：$skipped
- 内容是否截断：${truncated ? '是' : '否'}

知识材料：
$buffer
''';
  }

  @override
  Widget build(BuildContext context) {
    final usableCount = widget.items
        .where((item) => item.canAnswerWithAi)
        .length;
    final skippedCount = widget.items.length - usableCount;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_outlined,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.askSelectedFiles,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.usingKnowledgeItems(usableCount, skippedCount),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: Text(l10n.summarizeButton),
                  onPressed: () => _applyQuickPrompt(l10n.summarizePrompt),
                ),
                ActionChip(
                  label: Text(l10n.keyPointsButton),
                  onPressed: () => _applyQuickPrompt(l10n.keyPointsPrompt),
                ),
                ActionChip(
                  label: Text(l10n.actionsButton),
                  onPressed: () => _applyQuickPrompt(l10n.actionsPrompt),
                ),
                ActionChip(
                  label: Text(l10n.noteSummaryButton),
                  onPressed: () => _applyQuickPrompt(l10n.noteSummaryPrompt),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _questionController,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.question,
                hintText: l10n.questionHint,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading || usableCount == 0 ? null : _ask,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology_outlined),
                label: Text(_isLoading ? l10n.thinking : l10n.askAi),
              ),
            ),
            if (_answer != null) ...[
              const SizedBox(height: 16),
              AppPanel(child: AiMarkdownBlock(data: _answer!)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isSavingNote ? null : _saveAnswerToNotes,
                  icon: _isSavingNote
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.note_add_outlined),
                  label: Text(
                    _isSavingNote
                        ? l10n.ui('保存中...', 'Saving...', '保存中...')
                        : l10n.saveToNotes,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
