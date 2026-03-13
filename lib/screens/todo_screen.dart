import 'package:flutter/material.dart';

import '../models/todo_item.dart';
import '../utils/todo_persistence.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        return AlertDialog(
          title: const Text('新增待办标签'),
          content: TextField(
            controller: titleController,
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
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  return;
                }

                await _service.createTodo(title: title);
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
            Expanded(child: Text(item.title)),
            if (item.isSystem)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Chip(
                  label: Text('系统'),
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
