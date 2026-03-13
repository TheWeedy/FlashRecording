import 'package:flutter/material.dart';

import '../models/time_event.dart';
import '../models/todo_item.dart';
import 'settings_screen.dart';
import '../utils/todo_persistence.dart';

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
  List<TodoItem> _availableTodos = [];
  Map<String, Color> _todoColorMap = {};

  @override
  void initState() {
    super.initState();
    _loadAvailableTodos();
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
    final todayEvents = widget.events
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
    return (
      hours: totalMinutes ~/ 60,
      minutes: totalMinutes % 60,
    );
  }

  Future<void> _showSettingsDialog() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  Future<void> _showAddEventDialog(BuildContext context) async {
    final descController = TextEditingController();
    final noteController = TextEditingController();
    final suggestion = _suggestedDuration();
    final hoursController = TextEditingController(text: '${suggestion.hours}');
    final minutesController = TextEditingController(text: '${suggestion.minutes}');
    String? linkedTodoId = 'system-study';

    await _loadAvailableTodos();

    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('添加新记录'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: linkedTodoId,
                      decoration: const InputDecoration(
                        labelText: '待办标签',
                        border: OutlineInputBorder(),
                      ),
                      items: _availableTodos
                          .map(
                            (todo) => DropdownMenuItem<String?>(
                              value: todo.id,
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: todo.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(todo.title),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          linkedTodoId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hoursController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '小时',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minutesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '分钟',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: '记录描述',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: '备注（可选）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: navigator.pop,
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    int hours = int.tryParse(hoursController.text.trim()) ?? 0;
                    int minutes = int.tryParse(minutesController.text.trim()) ?? 0;

                    if (minutes < 0 || minutes > 59) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('分钟应在 0-59 之间')),
                      );
                      return;
                    }
                    if (hours < 0) {
                      hours = 0;
                    }
                    if (minutes < 0) {
                      minutes = 0;
                    }
                    if (descController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入记录描述')),
                      );
                      return;
                    }
                    if (linkedTodoId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请选择待办标签')),
                      );
                      return;
                    }

                    final linkedTodo = await _todoService.findTodoById(linkedTodoId!);
                    if (!context.mounted) {
                      return;
                    }
                    if (linkedTodo == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('待办标签不存在')),
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
                      description: descController.text.trim(),
                      note: noteController.text.trim(),
                      addedAt: DateTime.now(),
                      type: _typeForTodoId(linkedTodo.id),
                      linkedTodoId: linkedTodo.id,
                      linkedTodoTitle: linkedTodo.title,
                      recordMode: recordMode,
                    );

                    widget.onAdd(newEvent);

                    if (!mounted) {
                      return;
                    }
                    navigator.pop();
                    await _loadAvailableTodos();
                  },
                  child: const Text('添加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _colorForEvent(TimeEvent event) {
    return _todoColorMap[event.linkedTodoId] ??
        switch (event.type) {
          EventType.work => Colors.blue,
          EventType.study => Colors.green,
          EventType.play => Colors.orange,
        };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      appBar: AppBar(
        title: widget.isSelectionMode
            ? Text('已选择 ${widget.selectedIds.length} 项')
            : const Text('事件列表'),
        leading: widget.isSelectionMode
            ? IconButton(
                onPressed: widget.onToggleSelectionMode,
                icon: const Icon(Icons.close),
              )
            : null,
        actions: widget.isSelectionMode
            ? null
            : [
                IconButton(
                  onPressed: _showSettingsDialog,
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: '设置',
                ),
              ],
      ),
      body: widget.events.isEmpty
          ? const Center(child: Text('暂无事件，请点击 + 添加'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.events.length,
              itemBuilder: (context, index) {
                final event = widget.events[index];
                final isSelected = widget.selectedIds.contains(event.id);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  color: isSelected ? Colors.blue.shade50 : Colors.white,
                  child: ListTile(
                    leading: widget.isSelectionMode
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              final newSet = Set<String>.from(widget.selectedIds);
                              if (value == true) {
                                newSet.add(event.id);
                              } else {
                                newSet.remove(event.id);
                              }
                              widget.onDeleteSelected(newSet);
                            },
                          )
                        : Container(
                            width: 10,
                            decoration: BoxDecoration(
                              color: _colorForEvent(event),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                    title: Text(event.description),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.displayDuration),
                        Text(
                          '${event.addedAt.year}-${event.addedAt.month.toString().padLeft(2, '0')}-${event.addedAt.day.toString().padLeft(2, '0')} '
                          '${event.addedAt.hour.toString().padLeft(2, '0')}:${event.addedAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        if (event.linkedTodoTitle != null)
                          Text(
                            '标签: ${event.linkedTodoTitle}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        if (event.note.isNotEmpty)
                          Text(
                            '备注: ${event.note}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    onTap: widget.isSelectionMode
                        ? () {
                            final newSet = Set<String>.from(widget.selectedIds);
                            if (isSelected) {
                              newSet.remove(event.id);
                            } else {
                              newSet.add(event.id);
                            }
                            widget.onDeleteSelected(newSet);
                          }
                        : null,
                    onLongPress: widget.isSelectionMode
                        ? null
                        : () {
                            widget.onDeleteSelected({event.id});
                            widget.onToggleSelectionMode();
                          },
                  ),
                );
              },
            ),
      floatingActionButton: widget.isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddEventDialog(context),
              tooltip: '添加事件',
              child: const Icon(Icons.add),
            ),
    );
  }
}
