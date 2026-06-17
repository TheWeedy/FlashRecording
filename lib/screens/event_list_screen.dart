import 'package:flutter/material.dart';

import '../models/time_event.dart';
import '../models/todo_item.dart';
import '../theme/app_theme.dart';
import '../utils/todo_persistence.dart';
import '../widgets/app_components.dart';
import 'settings_screen.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({
    super.key,
    required this.events,
    required this.onAdd,
    required this.onDeleteSelected,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onToggleSelectionMode,
  });

  final List<TimeEvent> events;
  final void Function(TimeEvent) onAdd;
  final void Function(Set<String>) onDeleteSelected;
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
  bool _isAddSheetVisible = false;
  String? _entryLinkedTodoId;
  int _entrySuggestedMinutes = 0;

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
      _isAddSheetVisible = true;
    });
  }

  void _closeAddEventSheet() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isAddSheetVisible = false;
    });
  }

  Future<void> _submitAddEvent() async {
    int hours = int.tryParse(_entryHoursController.text.trim()) ?? 0;
    int minutes = int.tryParse(_entryMinutesController.text.trim()) ?? 0;

    if (minutes < 0 || minutes > 59) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minutes must be between 0 and 59.')),
      );
      return;
    }
    if (hours < 0) {
      hours = 0;
    }
    if (minutes < 0) {
      minutes = 0;
    }
    if (_entryDescriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an entry description.')),
      );
      return;
    }
    if (_entryLinkedTodoId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose a task tag.')));
      return;
    }

    final linkedTodo = await _todoService.findTodoById(_entryLinkedTodoId!);
    if (!mounted) {
      return;
    }
    if (linkedTodo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The selected task tag no longer exists.'),
        ),
      );
      return;
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
    _closeAddEventSheet();
    await _loadAvailableTodos();
  }

  Widget _buildAddEventOverlay(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _closeAddEventSheet,
            child: ColoredBox(color: AppTheme.ink.withValues(alpha: 0.48)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedPadding(
            duration: AppTheme.fast,
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SafeArea(
              top: false,
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
                },
                onCancel: _closeAddEventSheet,
                onSubmit: _submitAddEvent,
              ),
            ),
          ),
        ),
      ],
    );
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

  void _toggleEventSelection(TimeEvent event) {
    final next = Set<String>.from(widget.selectedIds);
    if (next.contains(event.id)) {
      next.remove(event.id);
    } else {
      next.add(event.id);
    }
    widget.onDeleteSelected(next);
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

  @override
  Widget build(BuildContext context) {
    final selectedCount = widget.selectedIds.length;

    return PopScope(
      canPop: !_isAddSheetVisible,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isAddSheetVisible) {
          _closeAddEventSheet();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  18,
                  AppTheme.pagePadding,
                  104,
                ),
                children: [
                  PageIntro(
                    eyebrow: 'Activity ledger',
                    title: widget.isSelectionMode
                        ? '$selectedCount selected'
                        : 'Entries',
                    description: widget.isSelectionMode
                        ? 'Choose the records you want to remove from your local ledger.'
                        : 'Capture the work as it happens, then let insights assemble the pattern.',
                    trailing: widget.isSelectionMode
                        ? QuietIconButton(
                            tooltip: 'Exit selection',
                            icon: Icons.close,
                            onPressed: widget.onToggleSelectionMode,
                            color: AppTheme.danger,
                          )
                        : QuietIconButton(
                            tooltip: 'Settings',
                            icon: Icons.tune,
                            onPressed: _showSettingsDialog,
                          ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Today',
                          value: '${_todayEvents.length}',
                          icon: Icons.today_outlined,
                          accent: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MetricTile(
                          label: 'Time',
                          value: _formatDuration(_todayMinutes),
                          icon: Icons.timelapse,
                          accent: AppTheme.steel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (widget.events.isEmpty)
                    const FadeSlideIn(
                      delay: Duration(milliseconds: 80),
                      child: EmptyState(
                        icon: Icons.view_agenda_outlined,
                        title: 'No entries yet',
                        message:
                            'Add your first entry to start building a timeline.',
                      ),
                    )
                  else
                    ...List.generate(widget.events.length, (index) {
                      final event = widget.events[index];
                      return FadeSlideIn(
                        delay: Duration(
                          milliseconds: 30 * (index > 8 ? 8 : index),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _EntryCard(
                            event: event,
                            tag: _tagForEvent(event),
                            color: _colorForEvent(event),
                            timestamp: _formatDateTime(event.addedAt),
                            selected: widget.selectedIds.contains(event.id),
                            selectionMode: widget.isSelectionMode,
                            onTap: widget.isSelectionMode
                                ? () => _toggleEventSelection(event)
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
                ],
              ),
            ),
            if (_isAddSheetVisible) _buildAddEventOverlay(context),
          ],
        ),
        floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
        floatingActionButton: widget.isSelectionMode || _isAddSheetVisible
            ? null
            : FloatingActionButton(
                onPressed: _openAddEventSheet,
                tooltip: 'Add entry',
                child: const Icon(Icons.add),
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
    final sheetHeight = (availableHeight * 0.78).clamp(440.0, 720.0).toDouble();

    return SizedBox(
      height: sheetHeight,
      child: Material(
        color: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusSheet),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'New entry',
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
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task tag',
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
                              decoration: const InputDecoration(
                                labelText: 'Hours',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: minutesController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Minutes',
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
                        decoration: const InputDecoration(
                          labelText: 'Entry description',
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
                        decoration: const InputDecoration(
                          labelText: 'Note, optional',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Leave hours and minutes at 0 to record this as one count.',
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
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onSubmit,
                      child: const Text('Add entry'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
                            'Entry detail',
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
                      tooltip: 'Close',
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
                          label: 'Description',
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
                          label: 'Note',
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
                                  ? 'No note attached.'
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
                          label: 'Task tag',
                          value: tag,
                        ),
                        const SizedBox(height: 8),
                        _DetailMetaRow(
                          icon: Icons.av_timer_outlined,
                          label: event.recordMode == EventRecordMode.count
                              ? 'Count'
                              : 'Duration',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: AppTheme.fast,
      decoration: BoxDecoration(
        color: selected ? AppTheme.primarySoft : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: selected ? AppTheme.primary : AppTheme.border,
        ),
        boxShadow: selected ? [] : AppTheme.cardShadow,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode) ...[
                Checkbox(value: selected, onChanged: (_) => onTap?.call()),
                const SizedBox(width: 6),
              ] else ...[
                Container(
                  width: 4,
                  height: 72,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
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
                            event.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppChip(label: event.displayDuration, color: color),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppChip(
                          icon: Icons.sell_outlined,
                          label: tag,
                          color: color,
                        ),
                        AppChip(
                          icon: Icons.schedule,
                          label: timestamp,
                          color: AppTheme.steel,
                        ),
                      ],
                    ),
                    if (event.note.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        event.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                          height: 1.4,
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
