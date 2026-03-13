import 'package:flutter/material.dart';

import '../models/note_item.dart';
import '../utils/note_persistence.dart';
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
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(initialNote: note),
      ),
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
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定删除已选择的 ${_selectedIds.length} 条笔记吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
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

  String _formatDateTime(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
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

  Widget _buildNoteCard(NoteItem note, {bool archived = false}) {
    final isSelected = _selectedIds.contains(note.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isSelected ? Colors.blue.shade50 : Colors.white,
      child: ListTile(
        leading: _isSelectionMode && !archived
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(note),
              )
            : null,
        title: Text(
          note.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              note.plainTextPreview.isEmpty ? '空白笔记' : note.plainTextPreview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              '更新于 ${_formatDateTime(note.updatedAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
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
        trailing: archived
            ? IconButton(
                tooltip: '恢复',
                onPressed: () => _restoreNote(note),
                icon: const Icon(Icons.unarchive_outlined),
              )
            : _isSelectionMode
                ? null
                : IconButton(
                    tooltip: '归档',
                    onPressed: () => _archiveNote(note),
                    icon: const Icon(Icons.archive_outlined),
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
          setState(() {
            _isSelectionMode = false;
            _selectedIds.clear();
          });
        }
      },
      child: Scaffold(
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      appBar: AppBar(
        title: _isSelectionMode ? Text('已选择 ${_selectedIds.length} 项') : const Text('笔记'),
        leading: _isSelectionMode
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                },
                icon: const Icon(Icons.close),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_notes.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('还没有笔记，点击右下角开始创建。'),
              ),
            ),
          ..._notes.map((note) => _buildNoteCard(note)),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('已归档 (${_archivedNotes.length})'),
            children: _archivedNotes.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('暂无已归档笔记'),
                      ),
                    ),
                  ]
                : _archivedNotes
                    .map((note) => _buildNoteCard(note, archived: true))
                    .toList(),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? FloatingActionButton(
              onPressed: _deleteSelectedNotes,
              backgroundColor: Colors.red,
              child: const Icon(Icons.delete),
            )
          : FloatingActionButton(
              onPressed: _openEditor,
              child: const Icon(Icons.add),
            ),
    ),
    );
  }
}
