import 'dart:async';

import 'package:flutter/material.dart';

import '../models/note_item.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';
import '../utils/cloud_sync_service.dart';
import '../utils/note_persistence.dart';
import '../widgets/app_components.dart';
import '../widgets/responsive_scaffold.dart';
import 'note_editor_screen.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => NoteListScreenState();
}

class NoteListScreenState extends State<NoteListScreen> {
  final NotePersistenceService _service = NotePersistenceService();

  List<NoteItem> _notes = [];
  List<NoteItem> _archivedNotes = [];
  final Set<String> _selectedIds = {};
  String? _focusedNoteId;
  bool _isLoading = true;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    unawaited(refreshFromCloud(force: false));
  }

  Future<void> refreshFromCloud({bool force = true}) async {
    await CloudSyncService.instance.syncNow(force: force);
    await _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await _service.loadActiveNotes();
    final archived = await _service.loadArchivedNotes();
    if (!mounted) {
      return;
    }
    setState(() {
      _notes = notes;
      _archivedNotes = archived;
      _isLoading = false;
    });
  }

  Future<void> _openEditor({NoteItem? note}) async {
    if (_isSelectionMode) {
      return;
    }
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NoteEditorScreen(initialNote: note)),
    );
    if (result == true) {
      await _loadNotes();
    }
  }

  NoteItem? get _focusedNote {
    final allNotes = [..._notes, ..._archivedNotes];
    if (allNotes.isEmpty) {
      return null;
    }
    final focusedId = _focusedNoteId;
    if (focusedId == null) {
      return allNotes.first;
    }
    for (final note in allNotes) {
      if (note.id == focusedId) {
        return note;
      }
    }
    return allNotes.first;
  }

  Future<void> _archiveNote(NoteItem note) async {
    await _service.archiveNote(note.id);
    await _loadNotes();
  }

  Future<void> _restoreNote(NoteItem note) async {
    await _service.restoreNote(note.id);
    await _loadNotes();
  }

  Future<void> _archiveSelectedNotes() async {
    if (_selectedIds.isEmpty) {
      return;
    }
    for (final id in _selectedIds) {
      await _service.archiveNote(id);
    }
    if (!mounted) {
      return;
    }
    _exitSelectionMode();
    await _loadNotes();
  }

  Future<void> _deleteSelectedNotes() async {
    if (_selectedIds.isEmpty) {
      return;
    }
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.deleteSelectedNotes),
            content: Text(context.l10n.deleteNotesMessage(_selectedIds.length)),
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
    await _service.deleteNotes(_selectedIds);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    await _loadNotes();
  }

  void _toggleSelection(NoteItem note) {
    setState(() {
      if (_selectedIds.contains(note.id)) {
        _selectedIds.remove(note.id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(note.id);
        _isSelectionMode = true;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  String _formatDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _notesHeaderMeta() {
    return context.l10n.ui(
      '${_notes.length} 篇笔记 · 归档 ${_archivedNotes.length}',
      '${_notes.length} notes · ${_archivedNotes.length} archived',
      '${_notes.length} 件のノート · アーカイブ ${_archivedNotes.length}',
    );
  }

  Future<void> _showArchivedNotes() async {
    await showAppActionSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  eyebrow: context.l10n.notesEyebrow,
                  title:
                      '${context.l10n.archivedNotes} (${_archivedNotes.length})',
                  description: context.l10n.noArchivedNotes,
                  showContext: false,
                  showCompactMeta: _archivedNotes.isEmpty,
                ),
                const SizedBox(height: AppTheme.space3),
                Flexible(
                  child: _archivedNotes.isEmpty
                      ? EmptyState(
                          icon: Icons.archive_outlined,
                          title: context.l10n.archivedNotes,
                          message: context.l10n.noArchivedNotes,
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _archivedNotes.length,
                          itemBuilder: (context, index) => _buildNoteCard(
                            _archivedNotes[index],
                            archived: true,
                            index: index,
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoteCard(
    NoteItem note, {
    bool archived = false,
    int index = 0,
    bool desktop = false,
  }) {
    final isSelected =
        _selectedIds.contains(note.id) ||
        desktop && _focusedNote?.id == note.id;
    return FadeSlideIn(
      delay: Duration(milliseconds: 30 * (index > 8 ? 8 : index)),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AnimatedContainer(
          duration: AppTheme.fast,
          curve: AppTheme.motionCurve,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.copperSoft : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: isSelected ? AppTheme.copper : AppTheme.border,
            ),
            boxShadow: isSelected ? [] : AppTheme.cardShadow,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            onTap: desktop
                ? () => setState(() => _focusedNoteId = note.id)
                : archived
                ? () => _openEditor(note: note)
                : _isSelectionMode
                ? () => _toggleSelection(note)
                : () => _openEditor(note: note),
            onLongPress: archived
                ? null
                : () {
                    if (!_isSelectionMode) {
                      setState(() {
                        _isSelectionMode = true;
                        _selectedIds.add(note.id);
                      });
                    }
                  },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isSelectionMode && !archived) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(note),
                    ),
                    const SizedBox(width: 4),
                  ] else ...[
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppTheme.copper.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.notes_rounded,
                        size: 17,
                        color: AppTheme.copper,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.16,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          note.plainTextPreview.isEmpty
                              ? context.l10n.ui('空白笔记', 'Blank note', '空白ノート')
                              : note.plainTextPreview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.muted,
                                height: 1.3,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 7),
                        AppChip(
                          icon: Icons.update,
                          label: context.l10n.updatedAt(
                            _formatDateTime(note.updatedAt),
                          ),
                          color: AppTheme.steel,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (archived)
                    QuietIconButton(
                      tooltip: context.l10n.restore,
                      onPressed: () => _restoreNote(note),
                      icon: Icons.unarchive_outlined,
                      color: AppTheme.primary,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopDetailPanel() {
    final note = _focusedNote;
    if (note == null) {
      return EmptyState(
        icon: Icons.sticky_note_2_outlined,
        title: context.l10n.noNotesTitle,
        message: context.l10n.noNotesMessage,
      );
    }
    final archived = note.archivedAt != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          eyebrow: archived
              ? context.l10n.archivedNotes
              : context.l10n.ui('当前笔记', 'Selected note', '選択中のノート'),
          title: note.title,
          description: context.l10n.updatedAt(_formatDateTime(note.updatedAt)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              QuietIconButton(
                icon: Icons.edit_outlined,
                tooltip: context.l10n.rename,
                onPressed: () => _openEditor(note: note),
              ),
              const SizedBox(width: 4),
              QuietIconButton(
                icon: archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                tooltip: archived ? context.l10n.restore : context.l10n.archive,
                color: archived ? AppTheme.primary : AppTheme.muted,
                onPressed: () =>
                    archived ? _restoreNote(note) : _archiveNote(note),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        AppPanel(
          child: SelectableText(
            note.plainTextPreview.isEmpty
                ? context.l10n.ui('空白笔记', 'Blank note', '空白ノート')
                : note.plainTextPreview,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.ink, height: 1.55),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return AdaptiveWorkspace(
      primaryFlex: 4,
      secondaryFlex: 5,
      primary: RefreshIndicator(
        onRefresh: refreshFromCloud,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionHeader(
              eyebrow: context.l10n.notesEyebrow,
              title: _isSelectionMode
                  ? context.l10n.selectedCount(_selectedIds.length)
                  : context.l10n.notesTitle,
              description: _isSelectionMode
                  ? context.l10n.ui(
                      '删除前请确认选中的笔记。',
                      'Review selected notes before deleting them.',
                    )
                  : _notesHeaderMeta(),
              showContext: false,
              showCompactMeta: true,
              trailing: QuietIconButton(
                icon: Icons.archive_outlined,
                tooltip: context.l10n.archivedNotes,
                onPressed: _showArchivedNotes,
              ),
            ),
            const SizedBox(height: AppTheme.space3),
            if (_notes.isEmpty)
              EmptyState(
                icon: Icons.sticky_note_2_outlined,
                title: context.l10n.noNotesTitle,
                message: context.l10n.noNotesMessage,
              )
            else
              ...List.generate(
                _notes.length,
                (index) =>
                    _buildNoteCard(_notes[index], index: index, desktop: true),
              ),
          ],
        ),
      ),
      secondary: SingleChildScrollView(child: _buildDesktopDetailPanel()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (isDesktopLayout(context)) {
      return Scaffold(
        body: SafeArea(child: _buildDesktopLayout()),
        floatingActionButtonLocation: const AppTuckedEndFabLocation(),
        floatingActionButton: ContextualActionFab(
          heroTag: 'notes-contextual-fab',
          tooltip: _isSelectionMode
              ? context.l10n.delete
              : context.l10n.createNote,
          icon: _isSelectionMode ? Icons.delete : Icons.add,
          isDestructive: _isSelectionMode,
          onPressed: _isSelectionMode ? _deleteSelectedNotes : _openEditor,
          actions: _isSelectionMode
              ? [
                  ContextualFabAction(
                    icon: Icons.archive_outlined,
                    label: context.l10n.archiveSelected,
                    tooltip: context.l10n.archiveSelected,
                    onPressed: _archiveSelectedNotes,
                  ),
                  ContextualFabAction(
                    icon: Icons.close,
                    label: context.l10n.clearSelection,
                    tooltip: context.l10n.clearSelection,
                    onPressed: _exitSelectionMode,
                  ),
                ]
              : const [],
        ),
      );
    }

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: refreshFromCloud,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                18,
                AppTheme.pagePadding,
                104,
              ),
              children: [
                PageIntro(
                  eyebrow: context.l10n.notesEyebrow,
                  title: _isSelectionMode
                      ? context.l10n.selectedCount(_selectedIds.length)
                      : context.l10n.notesTitle,
                  description: _isSelectionMode
                      ? context.l10n.ui(
                          '删除前请确认选中的笔记。',
                          'Review selected notes before deleting them.',
                        )
                      : _notesHeaderMeta(),
                  showContext: false,
                  showCompactMeta: true,
                  trailing: _isSelectionMode
                      ? QuietIconButton(
                          onPressed: _exitSelectionMode,
                          icon: Icons.close,
                          tooltip: context.l10n.clearSelection,
                          color: AppTheme.danger,
                        )
                      : QuietIconButton(
                          onPressed: _showArchivedNotes,
                          icon: Icons.archive_outlined,
                          tooltip: context.l10n.archivedNotes,
                        ),
                ),
                const SizedBox(height: 12),
                if (_notes.isEmpty)
                  EmptyState(
                    icon: Icons.sticky_note_2_outlined,
                    title: context.l10n.noNotesTitle,
                    message: context.l10n.noNotesMessage,
                  )
                else
                  ...List.generate(
                    _notes.length,
                    (index) => _buildNoteCard(_notes[index], index: index),
                  ),
              ],
            ),
          ),
        ),
        floatingActionButtonLocation: const AppTuckedEndFabLocation(),
        floatingActionButton: ContextualActionFab(
          heroTag: 'notes-contextual-fab',
          tooltip: _isSelectionMode
              ? context.l10n.delete
              : context.l10n.createNote,
          icon: _isSelectionMode ? Icons.delete : Icons.add,
          isDestructive: _isSelectionMode,
          onPressed: _isSelectionMode ? _deleteSelectedNotes : _openEditor,
          actions: _isSelectionMode
              ? [
                  ContextualFabAction(
                    icon: Icons.archive_outlined,
                    label: context.l10n.archiveSelected,
                    tooltip: context.l10n.archiveSelected,
                    onPressed: _archiveSelectedNotes,
                  ),
                  ContextualFabAction(
                    icon: Icons.close,
                    label: context.l10n.clearSelection,
                    tooltip: context.l10n.clearSelection,
                    onPressed: _exitSelectionMode,
                  ),
                ]
              : const [],
        ),
      ),
    );
  }
}
