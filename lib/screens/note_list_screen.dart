import 'dart:async';

import 'package:flutter/material.dart';

import '../models/note_item.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';
import '../utils/cloud_sync_service.dart';
import '../utils/note_persistence.dart';
import '../widgets/app_components.dart';
import 'note_editor_screen.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  final NotePersistenceService _service = NotePersistenceService();

  List<NoteItem> _notes = [];
  List<NoteItem> _archivedNotes = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    unawaited(_backgroundSync());
  }

  Future<void> _backgroundSync() async {
    await CloudSyncService.instance.syncNow();
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

  Future<void> _archiveNote(NoteItem note) async {
    await _service.archiveNote(note.id);
    await _loadNotes();
  }

  Future<void> _restoreNote(NoteItem note) async {
    await _service.restoreNote(note.id);
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

  Widget _buildNoteCard(NoteItem note, {bool archived = false, int index = 0}) {
    final isSelected = _selectedIds.contains(note.id);
    return FadeSlideIn(
      delay: Duration(milliseconds: 30 * (index > 8 ? 8 : index)),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AnimatedContainer(
          duration: AppTheme.fast,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primarySoft : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border,
            ),
            boxShadow: isSelected ? [] : AppTheme.cardShadow,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            onTap: archived
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
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isSelectionMode && !archived) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(note),
                    ),
                    const SizedBox(width: 6),
                  ] else ...[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.copperSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.notes_rounded,
                        size: 20,
                        color: AppTheme.copper,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          note.plainTextPreview.isEmpty
                              ? context.l10n.ui('空白笔记', 'Blank note', '空白ノート')
                              : note.plainTextPreview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppTheme.muted, height: 1.35),
                        ),
                        const SizedBox(height: 10),
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
                    )
                  else if (!_isSelectionMode)
                    QuietIconButton(
                      tooltip: context.l10n.archive,
                      onPressed: () => _archiveNote(note),
                      icon: Icons.archive_outlined,
                      color: AppTheme.muted,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
          child: ListView(
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
                    : context.l10n.ui(
                        '把思考保存在对应的时间记录旁边。',
                        'Keep the thinking beside the time records it explains.',
                      ),
                trailing: _isSelectionMode
                    ? QuietIconButton(
                        onPressed: _exitSelectionMode,
                        icon: Icons.close,
                        tooltip: context.l10n.clearSelection,
                        color: AppTheme.danger,
                      )
                    : null,
              ),
              const SizedBox(height: 18),
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
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                collapsedIconColor: AppTheme.muted,
                iconColor: AppTheme.primary,
                title: Text(
                  '${context.l10n.archivedNotes} (${_archivedNotes.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                children: _archivedNotes.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(context.l10n.noArchivedNotes),
                          ),
                        ),
                      ]
                    : List.generate(
                        _archivedNotes.length,
                        (index) => _buildNoteCard(
                          _archivedNotes[index],
                          archived: true,
                          index: index,
                        ),
                      ),
              ),
            ],
          ),
        ),
        floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
        floatingActionButton: _isSelectionMode
            ? FloatingActionButton(
                onPressed: _deleteSelectedNotes,
                backgroundColor: AppTheme.danger,
                child: const Icon(Icons.delete),
              )
            : FloatingActionButton(
                onPressed: _openEditor,
                tooltip: context.l10n.createNote,
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}
