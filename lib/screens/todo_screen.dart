import 'dart:async';

import 'package:flutter/material.dart';

import '../models/todo_item.dart';
import '../utils/cloud_sync_service.dart';
import '../utils/notification_service.dart';
import '../utils/todo_persistence.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  static const _presetColors = [
    0xFF3B82F6,
    0xFF22C55E,
    0xFFF97316,
    0xFFEF4444,
    0xFF8B5CF6,
    0xFF14B8A6,
    0xFFEAB308,
    0xFF64748B,
  ];

  final TodoPersistenceService _service = TodoPersistenceService();

  List<TodoItem> _activeTodos = [];
  List<TodoItem> _archivedTodos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodos();
    unawaited(_backgroundSync());
  }

  Future<void> _backgroundSync() async {
    await CloudSyncService.instance.syncNow();
    await _loadTodos();
  }

  Future<void> _loadTodos() async {
    final active = await _service.loadActiveTodos();
    final archived = await _service.loadArchivedTodos();
    if (!mounted) {
      return;
    }

    setState(() {
      _activeTodos = active;
      _archivedTodos = archived;
      _isLoading = false;
    });
  }

  Future<void> _showCreateTodoDialog() async {
    final titleController = TextEditingController();
    var selectedColor = _presetColors[5];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('新增待办标签'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final colorValue in _presetColors)
                          InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedColor = colorValue;
                              });
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Color(colorValue),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selectedColor == colorValue
                                      ? Colors.black
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: navigator.pop,
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      return;
                    }

                    await _service.createTodo(
                      title: title,
                      colorValue: selectedColor,
                    );
                    if (!mounted) {
                      return;
                    }
                    navigator.pop();
                    await _loadTodos();
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditTodoDialog(TodoItem item) async {
    final titleController = TextEditingController(text: item.title);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        return AlertDialog(
          title: const Text('修改待办标签'),
          content: TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '标题',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: navigator.pop,
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  return;
                }
                await _service.updateTodoTitle(
                  id: item.id,
                  title: title,
                );
                if (!mounted) {
                  return;
                }
                navigator.pop();
                await _loadTodos();
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showColorDialog(TodoItem item) async {
    var selectedColor = item.colorValue;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('更换 ${item.title} 颜色'),
              content: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final colorValue in _presetColors)
                    InkWell(
                      onTap: () {
                        setDialogState(() {
                          selectedColor = colorValue;
                        });
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Color(colorValue),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selectedColor == colorValue
                                ? Colors.black
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: navigator.pop,
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    await _service.updateTodoColor(
                      id: item.id,
                      colorValue: selectedColor,
                    );
                    if (!mounted) {
                      return;
                    }
                    navigator.pop();
                    await _loadTodos();
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _archiveTodo(TodoItem item) async {
    await _service.archiveTodo(item.id);
    await _loadTodos();
  }

  Future<void> _sendReminder(TodoItem item) async {
    final shown = await NotificationService.instance.showTodoReminder(
      id: item.id.hashCode,
      title: '${item.title} 提醒',
      body: '今天也可以继续积累次数和时长。',
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          shown ? '已发送 ${item.title} 的通知提醒' : '通知权限未开启，请在系统设置中允许通知',
        ),
      ),
    );
  }

  Future<void> _restoreTodo(TodoItem item) async {
    await _service.restoreTodo(item.id);
    await _loadTodos();
  }

  Future<void> _reorderActiveTodos(int oldIndex, int newIndex) async {
    if (_activeTodos.isEmpty) {
      return;
    }
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _activeTodos.removeAt(oldIndex);
      _activeTodos.insert(newIndex, item);
    });
    await _service.updateTodoOrder(_activeTodos.map((item) => item.id).toList());
    await _loadTodos();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      appBar: AppBar(
        title: const Text('待办'),
      ),
      body: ReorderableListView(
        padding: const EdgeInsets.all(16),
        onReorder: _reorderActiveTodos,
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '进行中',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
          ],
        ),
        footer: Column(
          children: [
            const SizedBox(height: 20),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('已归档 (${_archivedTodos.length})'),
              children: _archivedTodos.isEmpty
                  ? const [
                      Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('暂无已归档内容'),
                        ),
                      ),
                    ]
                  : _archivedTodos
                      .map((item) => _buildTodoCard(item, archived: true))
                      .toList(),
            ),
          ],
        ),
        children: _activeTodos.isEmpty
            ? const [
                Card(
                  key: ValueKey('empty-todo-card'),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('暂无待办'),
                  ),
                ),
              ]
            : _activeTodos
                .map((item) => _buildTodoCard(item, key: ValueKey(item.id)))
                .toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTodoDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTodoCard(TodoItem item, {bool archived = false, Key? key}) {
    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: item.color,
            shape: BoxShape.circle,
          ),
        ),
        title: GestureDetector(
          onTap: item.isSystem || archived ? null : () => _showEditTodoDialog(item),
          child: Text(item.title),
        ),
        subtitle: Text(item.summaryLabel),
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!archived)
              IconButton(
                tooltip: '发送提醒',
                onPressed: () => _sendReminder(item),
                icon: const Icon(Icons.alarm),
              ),
            if (item.isSystem)
              ActionChip(
                onPressed: archived ? null : () => _showColorDialog(item),
                avatar: CircleAvatar(
                  radius: 7,
                  backgroundColor: item.color,
                ),
                label: const Text('默认'),
                visualDensity: VisualDensity.compact,
              )
            else if (!archived)
              InkWell(
                onTap: () => _showColorDialog(item),
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                ),
              ),
            if (archived)
              IconButton(
                tooltip: '恢复',
                onPressed: () => _restoreTodo(item),
                icon: const Icon(Icons.unarchive_outlined),
              )
            else if (!item.isSystem)
              IconButton(
                tooltip: '归档',
                onPressed: () => _archiveTodo(item),
                icon: const Icon(Icons.archive_outlined),
              ),
          ],
        ),
      ),
    );
  }
}
