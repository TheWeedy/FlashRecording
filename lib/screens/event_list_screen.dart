import 'package:flutter/material.dart';
import '../models/time_event.dart';

class EventListScreen extends StatefulWidget {
  final List<TimeEvent> events;
  final Function(TimeEvent) onAdd;
  final Function(Set<String>) onDeleteSelected;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final Function() onToggleSelectionMode;

  const EventListScreen({
    super.key,
    required this.events,
    required this.onAdd,
    required this.onDeleteSelected,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onToggleSelectionMode,
  });

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  Future<void> _showAddEventDialog(BuildContext context) async {
    final TextEditingController descController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    String hoursInput = '0';
    String minutesInput = '0';
    EventType selectedType = EventType.study;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('添加新事件'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '小时',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => hoursInput = value,
                ),
                const SizedBox(height: 12),
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '分钟',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => minutesInput = value,
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '类型',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<EventType>(
                      value: selectedType,
                      isDense: true,
                      onChanged: (EventType? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedType = newValue;
                          });
                        }
                      },
                      items: EventType.values.map((EventType type) {
                        return DropdownMenuItem<EventType>(
                          value: type,
                          child: Text(
                            type == EventType.work
                                ? '工作'
                                : type == EventType.study
                                ? '学习'
                                : '玩',
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: '事件描述',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController, // 新建 TextEditingController
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                int hours = int.tryParse(hoursInput.trim()) ?? 0;
                int minutes = int.tryParse(minutesInput.trim()) ?? 0;

                if (minutes < 0 || minutes > 59) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('分钟应在 0-59 之间')),
                  );
                  return;
                }
                if (hours < 0) hours = 0;
                if (minutes < 0) minutes = 0;
                if (descController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入事件描述')),
                  );
                  return;
                }

                final newEvent = TimeEvent(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  hours: hours,
                  minutes: minutes,
                  description: descController.text.trim(),
                  note: noteController.text.trim(),
                  addedAt: DateTime.now(),
                  type: selectedType,
                );

                widget.onAdd(newEvent);
                Navigator.of(context).pop();
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            color: isSelected ? Colors.grey[200] : null,
            child: ListTile(
              leading: widget.isSelectionMode
                  ? Checkbox(
                value: isSelected,
                onChanged: (bool? value) {
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
                width: 8,
                decoration: BoxDecoration(
                  color: event.type == EventType.work
                      ? Colors.blue
                      : event.type == EventType.study
                      ? Colors.green
                      : Colors.orange,
                  borderRadius: BorderRadius.circular(4),
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
                  Text(
                    '类型: ${event.typeName}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  // 在类型下面加一行
                  if (event.note.isNotEmpty)
                    Text('备注: ${event.note}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              onLongPress: widget.isSelectionMode
                  ? null
                  : () {
                final newSet = <String>{};
                newSet.add(event.id);
                widget.onDeleteSelected(newSet);
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