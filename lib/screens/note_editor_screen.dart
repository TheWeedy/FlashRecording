import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../models/note_item.dart';
import '../utils/note_persistence.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.initialNote});

  final NoteItem? initialNote;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final NotePersistenceService _service = NotePersistenceService();
  late final TextEditingController _titleController;
  late final QuillController _quillController;
  late final FocusNode _editorFocusNode;
  late final ScrollController _editorScrollController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialNote?.title ?? '');
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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final plainText = _quillController.document.toPlainText().trim();
    final title = _titleController.text.trim().isEmpty
        ? (plainText.isEmpty ? '未命名笔记' : plainText.split('\n').first)
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
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  DefaultStyles _editorStyles(BuildContext context) {
    final base = DefaultStyles.getInstance(context);
    final paragraph = base.paragraph!;
    return base.merge(
      DefaultStyles(
        paragraph: paragraph.copyWith(
          style: paragraph.style.copyWith(
            fontSize: 18,
            height: 1.55,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        placeHolder: base.placeHolder?.copyWith(
          style: base.placeHolder?.style.copyWith(fontSize: 18, height: 1.55),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialNote == null ? '新建笔记' : '编辑笔记'),
        actions: [
          TextButton(
            onPressed: _saveNote,
            child: const Text('保存'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            QuillSimpleToolbar(
              controller: _quillController,
              config: QuillSimpleToolbarConfig(
                multiRowsDisplay: false,
                showClipboardPaste: true,
                showDividers: false,
                color: Colors.white,
                sectionDividerColor: Colors.grey.shade300,
              ),
            ),
            Expanded(
              child: QuillEditor.basic(
                controller: _quillController,
                focusNode: _editorFocusNode,
                scrollController: _editorScrollController,
                config: QuillEditorConfig(
                  placeholder: '开始记录你的想法...',
                  padding: const EdgeInsets.all(16),
                  customStyles: _editorStyles(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
