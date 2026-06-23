import 'dart:async';

import 'package:flutter/material.dart';

import '../models/time_event.dart';
import '../models/todo_item.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';
import '../utils/todo_persistence.dart';
import '../widgets/app_components.dart';
import '../widgets/responsive_scaffold.dart';
import 'settings_screen.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({
    super.key,
    required this.events,
    required this.onAdd,
    required this.onRefresh,
    required this.onDeleteSelected,
    required this.onPerformDelete,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onToggleSelectionMode,
  });

  final List<TimeEvent> events;
  final void Function(TimeEvent) onAdd;
  final Future<void> Function() onRefresh;
  final void Function(Set<String>) onDeleteSelected;
  final Future<void> Function() onPerformDelete;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final VoidCallback onToggleSelectionMode;

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  final TodoPersistenceService _todoService = TodoPersistenceService();
  final TextEditingController _entryDescriptionController =
      TextEditingController();
  final TextEditingController _entryNoteController = TextEditingController();
  final TextEditingController _entryHoursController = TextEditingController();
  final TextEditingController _entryMinutesController = TextEditingController();

  List<TodoItem> _availableTodos = [];
  Map<String, Color> _todoColorMap = {};
  String? _entryLinkedTodoId;
  int _entrySuggestedMinutes = 0;
  String? _focusedEventId;

  @override
  void initState() {
    super.initState();
    _loadAvailableTodos();
  }

  @override
  void dispose() {
    _entryDescriptionController.dispose();
    _entryNoteController.dispose();
    _entryHoursController.dispose();
    _entryMinutesController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableTodos() async {
    final todos = await _todoService.loadAvailableTagTodos();
    final colorMap = await _todoService.loadTodoColorMap();
    if (!mounted) {
      return;
    }

    setState(() {
      _availableTodos = todos;
      _todoColorMap = colorMap;
    });
  }

  Future<void> _refresh() async {
    await widget.onRefresh();
    await _loadAvailableTodos();
  }

  EventType _typeForTodoId(String? todoId) {
    switch (todoId) {
      case 'system-work':
        return EventType.work;
      case 'system-study':
        return EventType.study;
      case 'system-play':
        return EventType.play;
      default:
        return EventType.study;
    }
  }

  ({int hours, int minutes}) _suggestedDuration() {
    final now = DateTime.now();
    final todayEvents =
        widget.events
            .where(
              (event) =>
                  event.addedAt.year == now.year &&
                  event.addedAt.month == now.month &&
                  event.addedAt.day == now.day &&
                  event.addedAt.isBefore(now),
            )
            .toList()
          ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

    Duration duration = Duration.zero;
    if (todayEvents.isNotEmpty) {
      duration = now.difference(todayEvents.first.addedAt);
    } else if (now.hour >= 9) {
      duration = now.difference(DateTime(now.year, now.month, now.day, 9));
    }

    final totalMinutes = duration.inMinutes.clamp(0, 24 * 60 - 1);
    return (hours: totalMinutes ~/ 60, minutes: totalMinutes % 60);
  }

  List<TimeEvent> get _todayEvents {
    final now = DateTime.now();
    return widget.events.where((event) {
      return event.addedAt.year == now.year &&
          event.addedAt.month == now.month &&
          event.addedAt.day == now.day;
    }).toList();
  }

  int get _todayMinutes =>
      _todayEvents.fold(0, (sum, event) => sum + event.totalMinutes);

  TimeEvent? get _focusedEvent {
    if (widget.events.isEmpty) {
      return null;
    }
    final focusedId = _focusedEventId;
    if (focusedId == null) {
      return widget.events.first;
    }
    for (final event in widget.events) {
      if (event.id == focusedId) {
        return event;
      }
    }
    return widget.events.first;
  }

  Future<void> _showSettingsDialog() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  Future<void> _openAddEventSheet() async {
    await _loadAvailableTodos();
    if (!mounted) {
      return;
    }

    final suggestion = _suggestedDuration();
    final defaultTodoId = _availableTodos.isEmpty
        ? null
        : (_availableTodos.any((todo) => todo.id == 'system-study')
              ? 'system-study'
              : _availableTodos.first.id);

    setState(() {
      _entryDescriptionController.clear();
      _entryNoteController.clear();
      _entryHoursController.text = '${suggestion.hours}';
      _entryMinutesController.text = '${suggestion.minutes}';
      _entryLinkedTodoId = defaultTodoId;
      _entrySuggestedMinutes = suggestion.hours * 60 + suggestion.minutes;
    });
    if (!mounted) {
      return;
    }
    await showAppActionSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: _AddEntrySheet(
                availableTodos: _availableTodos,
                linkedTodoId: _entryLinkedTodoId,
                suggestedLabel:
                    'Suggested ${_formatDuration(_entrySuggestedMinutes)}',
                descriptionController: _entryDescriptionController,
                noteController: _entryNoteController,
                hoursController: _entryHoursController,
                minutesController: _entryMinutesController,
                onLinkedTodoChanged: (value) {
                  setState(() {
                    _entryLinkedTodoId = value;
                  });
                  setSheetState(() {});
                },
                onCancel: () => Navigator.of(sheetContext).pop(),
                onSubmit: () async {
                  final saved = await _submitAddEvent();
                  if (saved && sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _submitAddEvent() async {
    int hours = int.tryParse(_entryHoursController.text.trim()) ?? 0;
    int minutes = int.tryParse(_entryMinutesController.text.trim()) ?? 0;

    if (minutes < 0 || minutes > 59) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.minutesRangeError)));
      return false;
    }
    if (hours < 0) {
      hours = 0;
    }
    if (minutes < 0) {
      minutes = 0;
    }
    if (_entryDescriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.entryDescriptionRequired)),
      );
      return false;
    }
    if (_entryLinkedTodoId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.chooseTaskTag)));
      return false;
    }

    final linkedTodo = await _todoService.findTodoById(_entryLinkedTodoId!);
    if (!mounted) {
      return false;
    }
    if (linkedTodo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.selectedTaskTagMissing)),
      );
      return false;
    }

    final recordMode = hours == 0 && minutes == 0
        ? EventRecordMode.count
        : EventRecordMode.duration;

    final newEvent = TimeEvent(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      hours: hours,
      minutes: minutes,
      description: _entryDescriptionController.text.trim(),
      note: _entryNoteController.text.trim(),
      addedAt: DateTime.now(),
      type: _typeForTodoId(linkedTodo.id),
      linkedTodoId: linkedTodo.id,
      linkedTodoTitle: linkedTodo.title,
      recordMode: recordMode,
    );

    widget.onAdd(newEvent);
    await _loadAvailableTodos();
    return true;
  }

  Color _colorForEvent(TimeEvent event) {
    return _todoColorMap[event.linkedTodoId] ??
        switch (event.type) {
          EventType.work => AppTheme.steel,
          EventType.study => AppTheme.success,
          EventType.play => AppTheme.copper,
        };
  }

  String _tagForEvent(TimeEvent event) {
    switch (event.linkedTodoId) {
      case 'system-work':
        return 'Work';
      case 'system-study':
        return 'Study';
      case 'system-play':
        return 'Leisure';
      default:
        return event.linkedTodoTitle ?? 'No tag';
    }
  }

  String _formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) {
      return '$minutes min';
    }
    if (minutes == 0) {
      return '$hours hr';
    }
    return '$hours hr $minutes min';
  }

  String _formatDateTime(DateTime value) {
    final date =
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date · $time';
  }

  String _entriesHeaderMeta() {
    return context.l10n.ui(
      '今天 ${_todayEvents.length} 条 · ${_formatDuration(_todayMinutes)}',
      'Today ${_todayEvents.length} · ${_formatDuration(_todayMinutes)}',
      '今日 ${_todayEvents.length} 件 · ${_formatDuration(_todayMinutes)}',
    );
  }

  void _toggleEventSelection(TimeEvent event) {
    final next = Set<String>.from(widget.selectedIds);
    if (next.contains(event.id)) {
      next.remove(event.id);
    } else {
      next.add(event.id);
    }
    widget.onDeleteSelected(next);
    if (next.isEmpty && widget.isSelectionMode) {
      widget.onToggleSelectionMode();
    }
  }

  Future<void> _showEntryDetails(TimeEvent event) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _EntryDetailDialog(
        event: event,
        tag: _tagForEvent(event),
        color: _colorForEvent(event),
        timestamp: _formatDateTime(event.addedAt),
      ),
    );
  }

  Widget _buildEntryList({required bool desktop}) {
    if (widget.events.isEmpty) {
      return FadeSlideIn(
        delay: const Duration(milliseconds: 80),
        child: EmptyState(
          icon: Icons.view_agenda_outlined,
          title: context.l10n.noEntriesTitle,
          message: context.l10n.noEntriesMessage,
        ),
      );
    }
    return Column(
      children: List.generate(widget.events.length, (index) {
        final event = widget.events[index];
        final isFocused = desktop && _focusedEvent?.id == event.id;
        return FadeSlideIn(
          delay: Duration(milliseconds: 30 * (index > 8 ? 8 : index)),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _EntryCard(
              event: event,
              tag: _tagForEvent(event),
              color: _colorForEvent(event),
              timestamp: _formatDateTime(event.addedAt),
              selected: isFocused || widget.selectedIds.contains(event.id),
              selectionMode: widget.isSelectionMode,
              onTap: widget.isSelectionMode
                  ? () => _toggleEventSelection(event)
                  : desktop
                  ? () => setState(() => _focusedEventId = event.id)
                  : () => _showEntryDetails(event),
              onLongPress: widget.isSelectionMode
                  ? null
                  : () {
                      widget.onDeleteSelected({event.id});
                      widget.onToggleSelectionMode();
                    },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSummaryTiles() {
    return Row(
      children: [
        Expanded(
          child: MetricTile(
            label: context.l10n.entriesTitle,
            value: '${_todayEvents.length}',
            icon: Icons.today_outlined,
            accent: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricTile(
            label: context.l10n.duration,
            value: _formatDuration(_todayMinutes),
            icon: Icons.timelapse,
            accent: AppTheme.steel,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopDetailPanel() {
    final event = _focusedEvent;
    if (event == null) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: context.l10n.entryDetail,
        message: context.l10n.noEntriesMessage,
      );
    }
    final color = _colorForEvent(event);
    final tag = _tagForEvent(event);
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          eyebrow: context.l10n.ui('当前记录', 'Selected entry', '選択中の記録'),
          title: context.l10n.entryDetail,
          description: _formatDateTime(event.addedAt),
        ),
        const SizedBox(height: AppTheme.space3),
        _buildSummaryTiles(),
        const SizedBox(height: AppTheme.space3),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppChip(
                    icon: Icons.sell_outlined,
                    label: tag,
                    color: color,
                    maxWidth: 220,
                  ),
                  AppChip(
                    icon: Icons.timelapse,
                    label: event.displayDuration,
                    color: AppTheme.steel,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailBlock(
                label: context.l10n.description,
                child: SelectableText(
                  event.description,
                  style: theme.titleMedium?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w700,
                    height: 1.42,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _DetailBlock(
                label: context.l10n.note,
                child: SelectableText(
                  event.note.isEmpty ? context.l10n.noNoteAttached : event.note,
                  style: theme.bodyMedium?.copyWith(
                    color: event.note.isEmpty ? AppTheme.faint : AppTheme.ink,
                    height: 1.5,
                    fontStyle: event.note.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(int selectedCount) {
    return AdaptiveWorkspace(
      primaryFlex: 5,
      secondaryFlex: 4,
      primary: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SectionHeader(
              eyebrow: context.l10n.entriesEyebrow,
              title: widget.isSelectionMode
                  ? context.l10n.selectedCount(selectedCount)
                  : context.l10n.navEntries,
              description: widget.isSelectionMode
                  ? context.l10n.ui(
                      '选择要从本地记录中删除的条目。',
                      'Choose the records you want to remove from your local ledger.',
                    )
                  : _entriesHeaderMeta(),
              showContext: false,
              showCompactMeta: true,
              trailing: widget.isSelectionMode
                  ? QuietIconButton(
                      tooltip: context.l10n.clearSelection,
                      icon: Icons.close,
                      onPressed: widget.onToggleSelectionMode,
                      color: AppTheme.danger,
                    )
                  : QuietIconButton(
                      tooltip: context.l10n.settings,
                      icon: Icons.tune,
                      onPressed: _showSettingsDialog,
                    ),
            ),
            const SizedBox(height: AppTheme.space3),
            _buildEntryList(desktop: true),
          ],
        ),
      ),
      secondary: SingleChildScrollView(child: _buildDesktopDetailPanel()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = widget.selectedIds.length;
    final desktop = isDesktopLayout(context);

    return PopScope(
      canPop: true,
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: desktop
                  ? _buildDesktopLayout(selectedCount)
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppTheme.pagePadding,
                          14,
                          AppTheme.pagePadding,
                          104,
                        ),
                        children: [
                          PageIntro(
                            eyebrow: context.l10n.entriesEyebrow,
                            title: widget.isSelectionMode
                                ? context.l10n.selectedCount(selectedCount)
                                : context.l10n.navEntries,
                            description: widget.isSelectionMode
                                ? context.l10n.ui(
                                    '选择要从本地记录中删除的条目。',
                                    'Choose the records you want to remove from your local ledger.',
                                  )
                                : _entriesHeaderMeta(),
                            showContext: false,
                            showCompactMeta: true,
                            trailing: widget.isSelectionMode
                                ? QuietIconButton(
                                    tooltip: context.l10n.clearSelection,
                                    icon: Icons.close,
                                    onPressed: widget.onToggleSelectionMode,
                                    color: AppTheme.danger,
                                  )
                                : QuietIconButton(
                                    tooltip: context.l10n.settings,
                                    icon: Icons.tune,
                                    onPressed: _showSettingsDialog,
                                  ),
                          ),
                          const SizedBox(height: 12),
                          _buildSummaryTiles(),
                          const SizedBox(height: 10),
                          _buildEntryList(desktop: false),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButtonLocation: const AppTuckedEndFabLocation(),
        floatingActionButton: ContextualActionFab(
          heroTag: 'entries-contextual-fab',
          tooltip: widget.isSelectionMode
              ? context.l10n.delete
              : context.l10n.addEntryTooltip,
          icon: widget.isSelectionMode ? Icons.delete : Icons.add,
          isDestructive: widget.isSelectionMode,
          onPressed: widget.isSelectionMode
              ? () => unawaited(widget.onPerformDelete())
              : _openAddEventSheet,
          actions: widget.isSelectionMode
              ? [
                  ContextualFabAction(
                    icon: Icons.close,
                    label: context.l10n.clearSelection,
                    tooltip: context.l10n.clearSelection,
                    onPressed: widget.onToggleSelectionMode,
                  ),
                ]
              : const [],
        ),
      ),
    );
  }
}

class _AddEntrySheet extends StatelessWidget {
  const _AddEntrySheet({
    required this.availableTodos,
    required this.linkedTodoId,
    required this.suggestedLabel,
    required this.descriptionController,
    required this.noteController,
    required this.hoursController,
    required this.minutesController,
    required this.onLinkedTodoChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  final List<TodoItem> availableTodos;
  final String? linkedTodoId;
  final String suggestedLabel;
  final TextEditingController descriptionController;
  final TextEditingController noteController;
  final TextEditingController hoursController;
  final TextEditingController minutesController;
  final ValueChanged<String?> onLinkedTodoChanged;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final availableHeight =
        media.size.height - media.padding.top - media.viewInsets.bottom - 16;
    final maxHeight = (availableHeight * 0.92).clamp(0.0, 680.0).toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.addEntry,
            style: theme.headlineSmall?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          AppChip(
            icon: Icons.auto_awesome,
            color: AppTheme.copper,
            label: suggestedLabel,
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.taskTag,
                    style: theme.labelLarge?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTodos.map((todo) {
                      final selected = linkedTodoId == todo.id;
                      return ChoiceChip(
                        selected: selected,
                        showCheckmark: false,
                        label: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: media.size.width * 0.58,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ColorDot(color: todo.color),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  todo.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        onSelected: (_) => onLinkedTodoChanged(todo.id),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: hoursController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: context.l10n.hours,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: minutesController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: context.l10n.minutes,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    minLines: 2,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: context.l10n.entryDescription,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    minLines: 2,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: context.l10n.noteOptional,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.ui(
                      '小时和分钟保持 0 时，将记录为一次计数。',
                      'Leave hours and minutes at 0 to record this as one count.',
                    ),
                    style: theme.bodySmall?.copyWith(
                      color: AppTheme.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: Text(context.l10n.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onSubmit,
                  child: Text(context.l10n.addEntry),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryDetailDialog extends StatelessWidget {
  const _EntryDetailDialog({
    required this.event,
    required this.tag,
    required this.color,
    required this.timestamp,
  });

  final TimeEvent event;
  final String tag;
  final Color color;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final media = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: media.height * 0.76,
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
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(Icons.receipt_long_outlined, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.entryDetail,
                            style: theme.titleLarge?.copyWith(
                              color: AppTheme.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            timestamp,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodySmall?.copyWith(
                              color: AppTheme.muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: context.l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.raisedSurface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusControl,
                          ),
                          side: const BorderSide(color: AppTheme.border),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppChip(
                      icon: Icons.sell_outlined,
                      label: tag,
                      color: color,
                      maxWidth: media.width * 0.72,
                    ),
                    AppChip(
                      icon: Icons.timelapse,
                      label: event.displayDuration,
                      color: AppTheme.steel,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: AppTheme.border, height: 1),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailBlock(
                          label: context.l10n.description,
                          child: SelectableText(
                            event.description,
                            style: theme.titleMedium?.copyWith(
                              color: AppTheme.ink,
                              fontWeight: FontWeight.w700,
                              height: 1.42,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DetailBlock(
                          label: context.l10n.note,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: AppTheme.raisedSurface,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusCard,
                              ),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: SelectableText(
                              event.note.isEmpty
                                  ? context.l10n.noNoteAttached
                                  : event.note,
                              style: theme.bodyMedium?.copyWith(
                                color: event.note.isEmpty
                                    ? AppTheme.faint
                                    : AppTheme.ink,
                                height: 1.48,
                                fontStyle: event.note.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _DetailMetaRow(
                          icon: Icons.category_outlined,
                          label: context.l10n.taskTag,
                          value: tag,
                        ),
                        const SizedBox(height: 8),
                        _DetailMetaRow(
                          icon: Icons.av_timer_outlined,
                          label: event.recordMode == EventRecordMode.count
                              ? context.l10n.count
                              : context.l10n.duration,
                          value: event.displayDuration,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.labelSmall?.copyWith(
            color: AppTheme.copper,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

class _DetailMetaRow extends StatelessWidget {
  const _DetailMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primarySoft.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppTheme.primary),
          const SizedBox(width: 9),
          Text(
            label,
            style: theme.labelMedium?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.bodyMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.event,
    required this.tag,
    required this.color,
    required this.timestamp,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  final TimeEvent event;
  final String tag;
  final Color color;
  final String timestamp;
  final bool selected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  String get _timeLabel {
    final hour = event.addedAt.hour.toString().padLeft(2, '0');
    final minute = event.addedAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get _dateLabel {
    final month = event.addedAt.month.toString().padLeft(2, '0');
    final day = event.addedAt.day.toString().padLeft(2, '0');
    return '$month/$day';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: AppTheme.fast,
      curve: AppTheme.motionCurve,
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.1) : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: selected ? color : AppTheme.border,
          width: selected ? 1.4 : 1,
        ),
        boxShadow: selected ? [] : AppTheme.cardShadow,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: Stack(
            children: [
              Positioned(
                right: -24,
                top: -28,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              Positioned(
                left: 22,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              Positioned(
                left: 17,
                top: 18,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(color: AppTheme.surface, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.24),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(44, 11, 13, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selectionMode) ...[
                          SizedBox(
                            width: 28,
                            height: 34,
                            child: Center(
                              child: Checkbox(
                                value: selected,
                                onChanged: (_) => onTap?.call(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            event.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.ink,
                              height: 1.18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusPill,
                            ),
                            border: Border.all(
                              color: color.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            child: Text(
                              event.displayDuration,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.operationText(
                                theme.labelMedium?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _EntryMetaPill(
                          icon: Icons.sell_outlined,
                          label: tag,
                          color: color,
                        ),
                        _EntryMetaPill(
                          icon: Icons.access_time_rounded,
                          label: _timeLabel,
                          color: AppTheme.steel,
                        ),
                        _EntryMetaPill(
                          icon: Icons.calendar_today_outlined,
                          label: _dateLabel,
                          color: AppTheme.muted,
                        ),
                      ],
                    ),
                    if (event.note.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        event.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryMetaPill extends StatelessWidget {
  const _EntryMetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData? icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
