import 'dart:async';

import 'package:flutter/material.dart';

import '../models/todo_item.dart';
import '../theme/app_theme.dart';
import '../utils/ai_service.dart';
import '../utils/cloud_sync_service.dart';
import '../utils/notification_service.dart';
import '../utils/todo_persistence.dart';
import '../widgets/app_components.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  static const _presetColors = [
    0xFF2F5D50,
    0xFF356B8C,
    0xFFB66A4B,
    0xFF3E8F6B,
    0xFFC78A2C,
    0xFFB94A48,
    0xFF64748B,
    0xFF8B5CF6,
    0xFFEC4899,
    0xFF06B6D4,
    0xFF84CC16,
    0xFFF43F5E,
  ];

  final TodoPersistenceService _service = TodoPersistenceService();
  final AiService _aiService = AiService();

  List<TodoItem> _activeTodos = [];
  List<TodoItem> _archivedTodos = [];
  bool _isLoading = true;
  bool _isAiLoading = false;
  String? _aiPlan;

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
    var selectedColor = _presetColors.first;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create task tag'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Accent color',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final colorValue in _presetColors)
                        _ColorSwatch(
                          colorValue: colorValue,
                          selected: selectedColor == colorValue,
                          onTap: () {
                            setDialogState(() {
                              selectedColor = colorValue;
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: navigator.pop,
                  child: const Text('Cancel'),
                ),
                FilledButton(
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
                  child: const Text('Save'),
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
          title: const Text('Rename task tag'),
          content: TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          actions: [
            TextButton(onPressed: navigator.pop, child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  return;
                }
                await _service.updateTodoTitle(id: item.id, title: title);
                if (!mounted) {
                  return;
                }
                navigator.pop();
                await _loadTodos();
              },
              child: const Text('Save'),
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
              title: Text('Change ${item.title} color'),
              content: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final colorValue in _presetColors)
                    _ColorSwatch(
                      colorValue: colorValue,
                      selected: selectedColor == colorValue,
                      onTap: () {
                        setDialogState(() {
                          selectedColor = colorValue;
                        });
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: navigator.pop,
                  child: const Text('Cancel'),
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
                  child: const Text('Save'),
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
      title: '${item.title} reminder',
      body: 'A small nudge to add one more signal today.',
    );
    if (!mounted) {
      return;
    }
    if (!shown) {
      await _showNotificationSettingsPrompt();
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Reminder sent for ${item.title}.')));
  }

  Future<void> _showNotificationSettingsPrompt() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        return AlertDialog(
          title: const Text('Notifications are off'),
          content: const Text(
            'Allow notifications for Record My Time in system settings, then send the reminder again.',
          ),
          actions: [
            TextButton(onPressed: navigator.pop, child: const Text('Not now')),
            FilledButton(
              onPressed: () {
                navigator.pop();
                unawaited(
                  NotificationService.instance.openNotificationSettings(),
                );
              },
              child: const Text('Open settings'),
            ),
          ],
        );
      },
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
      final item = _activeTodos.removeAt(oldIndex);
      _activeTodos.insert(newIndex, item);
    });
    await _service.updateTodoOrder(
      _activeTodos.map((item) => item.id).toList(),
    );
    await _loadTodos();
  }

  Future<void> _generateAiPlan() async {
    if (_activeTodos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create task tags before asking AI.')),
      );
      return;
    }

    setState(() {
      _isAiLoading = true;
      _aiPlan = null;
    });

    try {
      final result = await _aiService.complete(
        systemPrompt:
            'You are a practical planning assistant. Respond in concise Chinese with clear markdown bullets.',
        userPrompt: _buildTaskPlanPrompt(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _aiPlan = result;
      });
    } on AiServiceException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
        });
      }
    }
  }

  String _buildTaskPlanPrompt() {
    String itemLine(TodoItem item) {
      return '- ${item.title}: ${item.totalCount}次，${_formatMinutes(item.totalDurationMinutes)}';
    }

    return '''
请根据 RecordMyTime 当前任务标签制定计划建议，输出：
1. 任务优先级排序
2. 今天/下一工作段的推荐安排
3. 哪些标签需要拆分、合并或新增
4. 每个建议背后的理由

活跃标签：
${_activeTodos.map(itemLine).join('\n')}

归档标签：
${_archivedTodos.isEmpty ? '- 无' : _archivedTodos.map(itemLine).join('\n')}
''';
  }

  String _formatMinutes(int totalMinutes) {
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

  Widget _buildAiPlanPanel() {
    return FadeSlideIn(
      delay: const Duration(milliseconds: 80),
      child: AppPanel(
        color: AppTheme.raisedSurface,
        child: Column(
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
                    'AI planning',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isAiLoading ? null : _generateAiPlan,
                  icon: _isAiLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.route_outlined),
                  label: Text(_isAiLoading ? 'Planning' : 'Recommend'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_aiPlan == null)
              Text(
                'Generate a plan from your active tags, tracked counts, and accumulated time.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.muted,
                  height: 1.5,
                ),
              )
            else
              AiMarkdownBlock(data: _aiPlan!),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: ReorderableListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            18,
            AppTheme.pagePadding,
            104,
          ),
          onReorderItem: _reorderActiveTodos,
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageIntro(
                eyebrow: 'Operating tags',
                title: 'Tasks',
                description:
                    'Shape the categories you track, then reorder them as your work changes.',
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      label: 'Active',
                      value: '${_activeTodos.length}',
                      icon: Icons.layers_outlined,
                      accent: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricTile(
                      label: 'Archived',
                      value: '${_archivedTodos.length}',
                      icon: Icons.inventory_2_outlined,
                      accent: AppTheme.copper,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAiPlanPanel(),
              const SizedBox(height: 16),
            ],
          ),
          footer: Column(
            children: [
              const SizedBox(height: 10),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                collapsedIconColor: AppTheme.muted,
                iconColor: AppTheme.primary,
                title: Text(
                  'Archived (${_archivedTodos.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                children: _archivedTodos.isEmpty
                    ? const [
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('No archived task tags'),
                          ),
                        ),
                      ]
                    : List.generate(
                        _archivedTodos.length,
                        (index) => _buildTodoCard(
                          _archivedTodos[index],
                          archived: true,
                          key: ValueKey('archived-${_archivedTodos[index].id}'),
                        ),
                      ),
              ),
            ],
          ),
          children: _activeTodos.isEmpty
              ? const [
                  Padding(
                    key: ValueKey('empty-task-card'),
                    padding: EdgeInsets.only(bottom: 10),
                    child: EmptyState(
                      icon: Icons.checklist_outlined,
                      title: 'No task tags',
                      message: 'Create a tag to connect future entries.',
                    ),
                  ),
                ]
              : List.generate(
                  _activeTodos.length,
                  (index) => _buildTodoCard(
                    _activeTodos[index],
                    key: ValueKey(_activeTodos[index].id),
                    index: index,
                  ),
                ),
        ),
      ),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTodoDialog,
        tooltip: 'Create task tag',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTodoCard(
    TodoItem item, {
    bool archived = false,
    Key? key,
    int index = 0,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 10),
      child: FadeSlideIn(
        delay: Duration(milliseconds: 30 * (index > 8 ? 8 : index)),
        child: AppPanel(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  archived ? Icons.archive_outlined : Icons.label_outline,
                  color: item.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (item.isSystem)
                          AppChip(label: 'Default', color: item.color),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.summaryLabel,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (!archived)
                          QuietIconButton(
                            tooltip: 'Send reminder',
                            onPressed: () => _sendReminder(item),
                            icon: Icons.alarm_add_outlined,
                            color: AppTheme.steel,
                          ),
                        if (!archived && !item.isSystem)
                          QuietIconButton(
                            tooltip: 'Rename',
                            onPressed: () => _showEditTodoDialog(item),
                            icon: Icons.edit_outlined,
                            color: AppTheme.primary,
                          ),
                        QuietIconButton(
                          tooltip: 'Change color',
                          onPressed: archived
                              ? null
                              : () => _showColorDialog(item),
                          icon: Icons.palette_outlined,
                          color: item.color,
                        ),
                        if (archived)
                          QuietIconButton(
                            tooltip: 'Restore',
                            onPressed: () => _restoreTodo(item),
                            icon: Icons.unarchive_outlined,
                            color: AppTheme.primary,
                          )
                        else if (!item.isSystem)
                          QuietIconButton(
                            tooltip: 'Archive',
                            onPressed: () => _archiveTodo(item),
                            icon: Icons.archive_outlined,
                            color: AppTheme.muted,
                          ),
                      ],
                    ),
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

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.colorValue,
    required this.selected,
    required this.onTap,
  });

  final int colorValue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: AppTheme.fast,
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppTheme.ink : Colors.white,
            width: selected ? 2.4 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
