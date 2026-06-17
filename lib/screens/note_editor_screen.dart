import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../models/note_item.dart';
import '../theme/app_theme.dart';
import '../utils/note_persistence.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.initialNote});

  final NoteItem? initialNote;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  static const _noteFontFamily = AppTheme.fontSerif;

  final NotePersistenceService _service = NotePersistenceService();
  late final TextEditingController _titleController;
  late final QuillController _quillController;
  late final FocusNode _editorFocusNode;
  late final ScrollController _editorScrollController;
  late final String _initialTitle;
  late final String _initialDeltaJson;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialNote?.title ?? '',
    );
    _editorFocusNode = FocusNode();
    _editorScrollController = ScrollController();

    final document = widget.initialNote == null
        ? Document()
        : Document.fromJson(jsonDecode(widget.initialNote!.deltaJson) as List);

    _quillController = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: false,
    );
    _initialTitle = _titleController.text.trim();
    _initialDeltaJson = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final currentTitle = _titleController.text.trim();
    final currentDeltaJson = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );
    return currentTitle != _initialTitle ||
        currentDeltaJson != _initialDeltaJson;
  }

  Future<void> _saveNote() async {
    if (_isSaving) {
      return;
    }
    _isSaving = true;

    final plainText = _quillController.document.toPlainText().trim();
    final title = _titleController.text.trim().isEmpty
        ? (plainText.isEmpty ? 'Untitled note' : plainText.split('\n').first)
        : _titleController.text.trim();

    final now = DateTime.now();
    final note = NoteItem(
      id: widget.initialNote?.id ?? now.microsecondsSinceEpoch.toString(),
      title: title,
      deltaJson: jsonEncode(_quillController.document.toDelta().toJson()),
      plainTextPreview: plainText,
      createdAt: widget.initialNote?.createdAt ?? now,
      updatedAt: now,
      archivedAt: widget.initialNote?.archivedAt,
    );

    await _service.upsertNote(note);
    _isSaving = false;
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _handleBackNavigation() async {
    if (_isSaving) {
      return;
    }
    final plainText = _quillController.document.toPlainText().trim();
    final title = _titleController.text.trim();
    if (!_hasChanges || (title.isEmpty && plainText.isEmpty)) {
      if (mounted) {
        Navigator.of(context).pop(false);
      }
      return;
    }
    await _saveNote();
  }

  DefaultStyles _editorStyles(BuildContext context) {
    final base = DefaultStyles.getInstance(context);
    final paragraph = base.paragraph!;
    return base.merge(
      DefaultStyles(
        paragraph: paragraph.copyWith(
          style: paragraph.style.copyWith(
            fontFamily: _noteFontFamily,
            fontFamilyFallback: AppTheme.fontFallback,
            fontSize: 18,
            height: 1.55,
            fontWeight: FontWeight.w500,
            color: AppTheme.ink,
          ),
        ),
        placeHolder: base.placeHolder?.copyWith(
          style: base.placeHolder?.style.copyWith(
            fontFamily: _noteFontFamily,
            fontFamilyFallback: AppTheme.fontFallback,
            fontSize: 18,
            height: 1.55,
            color: AppTheme.faint,
          ),
        ),
        h1: base.h1?.copyWith(
          style: base.h1?.style.copyWith(
            fontFamily: _noteFontFamily,
            fontFamilyFallback: AppTheme.fontFallback,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        h2: base.h2?.copyWith(
          style: base.h2?.style.copyWith(
            fontFamily: _noteFontFamily,
            fontFamilyFallback: AppTheme.fontFallback,
            fontWeight: FontWeight.w700,
            color: AppTheme.ink,
          ),
        ),
      ),
    );
  }

  Widget _buildEditorToolbar() {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.raisedSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: QuillSimpleToolbar(
          controller: _quillController,
          config: const QuillSimpleToolbarConfig(
            multiRowsDisplay: false,
            toolbarSize: 32,
            showDividers: false,
            showFontFamily: false,
            showFontSize: false,
            showSmallButton: false,
            showInlineCode: false,
            showColorButton: false,
            showBackgroundColorButton: false,
            showAlignmentButtons: false,
            showHeaderStyle: false,
            showCodeBlock: false,
            showIndent: false,
            showDirection: false,
            showSearchButton: false,
            showSubscript: false,
            showSuperscript: false,
            color: AppTheme.raisedSurface,
            sectionDividerColor: AppTheme.border,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _handleBackNavigation,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(widget.initialNote == null ? 'New note' : 'Edit note'),
          actions: [
            TextButton(onPressed: _saveNote, child: const Text('Save')),
          ],
        ),
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontFamily: _noteFontFamily,
                    fontFamilyFallback: AppTheme.fontFallback,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
              ),
              _buildEditorToolbar(),
              const SizedBox(height: 8),
              Expanded(
                child: QuillEditor.basic(
                  controller: _quillController,
                  focusNode: _editorFocusNode,
                  scrollController: _editorScrollController,
                  config: QuillEditorConfig(
                    placeholder: 'Start shaping the thought...',
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    customStyles: _editorStyles(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
