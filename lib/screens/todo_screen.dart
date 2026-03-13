import 'package:flutter/material.dart';

import '../models/todo_item.dart';
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
    int selectedColor = _presetColors[5];

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

  Future<void> _showColorDialog(TodoItem item) async {
    int selectedColor = item.colorValue;
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

  Future<void> _restoreTodo(TodoItem item) async {
    await _service.restoreTodo(item.id);
    await _loadTodos();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '进行中',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_activeTodos.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('暂无待办'),
              ),
            ),
          ..._activeTodos.map(_buildTodoCard),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTodoDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTodoCard(TodoItem item, {bool archived = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(item.title)),
            if (item.isSystem)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ActionChip(
                  onPressed: archived ? null : () => _showColorDialog(item),
                  avatar: CircleAvatar(
                    radius: 7,
                    backgroundColor: item.color,
                  ),
                  label: const Text('默认'),
                  visualDensity: VisualDensity.compact,
                ),
              )
            else if (!archived)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ActionChip(
                  onPressed: () => _showColorDialog(item),
                  avatar: CircleAvatar(
                    radius: 7,
                    backgroundColor: item.color,
                  ),
                  label: const Text('颜色'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        subtitle: Text(item.summaryLabel),
        trailing: archived
            ? IconButton(
                tooltip: '恢复',
                onPressed: () => _restoreTodo(item),
                icon: const Icon(Icons.unarchive_outlined),
              )
            : item.isSystem
                ? null
                : IconButton(
                    tooltip: '归档',
                    onPressed: () => _archiveTodo(item),
                    icon: const Icon(Icons.archive_outlined),
                  ),
      ),
    );
  }
}
