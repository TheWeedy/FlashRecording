import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../models/note_item.dart';
import '../theme/app_theme.dart';
import '../utils/ai_service.dart';
import '../utils/note_persistence.dart';
import '../widgets/app_components.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.initialNote});

  final NoteItem? initialNote;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  static const _noteFontFamily = AppTheme.fontSerif;

  final NotePersistenceService _service = NotePersistenceService();
  final AiService _aiService = AiService();
  late final TextEditingController _titleController;
  late final QuillController _quillController;
  late final FocusNode _editorFocusNode;
  late final ScrollController _editorScrollController;
  late final String _initialTitle;
  late final String _initialDeltaJson;
  bool _isSaving = false;
  bool _isAiLoading = false;

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

  Future<void> _showAiWritingSheet() async {
    final instructionController = TextEditingController(
      text: '请续写这篇笔记，保持原有语气。',
    );
    String? aiResult;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> runAi(String instruction) async {
              final content = _quillController.document.toPlainText().trim();
              if (content.isEmpty && _titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Write something first.')),
                );
                return;
              }

              setSheetState(() {
                _isAiLoading = true;
                aiResult = null;
              });

              try {
                final result = await _aiService.complete(
                  systemPrompt:
                      'You are a thoughtful writing assistant inside a personal notes app. Respond in polished Chinese unless the user content uses another language.',
                  userPrompt:
                      '''
标题：${_titleController.text.trim().isEmpty ? 'Untitled' : _titleController.text.trim()}

用户指令：
$instruction

当前笔记：
$content
''',
                );
                if (!mounted) {
                  return;
                }
                setSheetState(() {
                  aiResult = result;
                });
              } on AiServiceException catch (error) {
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(SnackBar(content: Text(error.message)));
              } finally {
                if (mounted) {
                  setSheetState(() {
                    _isAiLoading = false;
                  });
                }
              }
            }

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
                            'AI writing',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Polish'),
                          onPressed: _isAiLoading
                              ? null
                              : () => runAi('请润色这篇笔记，使表达更清晰、有层次，但保留原意。'),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.notes_outlined, size: 18),
                          label: const Text('Continue'),
                          onPressed: _isAiLoading
                              ? null
                              : () => runAi('请基于已有内容自然续写 2-4 段。'),
                        ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.account_tree_outlined,
                            size: 18,
                          ),
                          label: const Text('Outline'),
                          onPressed: _isAiLoading
                              ? null
                              : () => runAi('请把这篇笔记整理成结构化提纲，并补充可继续展开的问题。'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: instructionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Custom instruction',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isAiLoading
                            ? null
                            : () => runAi(instructionController.text.trim()),
                        icon: _isAiLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.psychology_outlined),
                        label: Text(_isAiLoading ? 'Writing...' : 'Generate'),
                      ),
                    ),
                    if (aiResult != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.raisedSurface,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusCard,
                          ),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: AiMarkdownBlock(data: aiResult!),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _insertAiText(aiResult!);
                            Navigator.of(sheetContext).pop();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Insert into note'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    instructionController.dispose();
  }

  void _insertAiText(String text) {
    final selection = _quillController.selection;
    final insertAt = selection.isValid
        ? selection.baseOffset
        : _quillController.document.length - 1;
    final prefix = insertAt > 0 ? '\n\n' : '';
    _quillController.replaceText(
      insertAt,
      0,
      '$prefix$text',
      TextSelection.collapsed(offset: insertAt + prefix.length + text.length),
    );
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
            IconButton(
              tooltip: 'AI writing',
              onPressed: _showAiWritingSheet,
              icon: const Icon(Icons.auto_awesome_outlined),
            ),
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
