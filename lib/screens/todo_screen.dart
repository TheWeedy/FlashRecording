import 'dart:async';

import 'package:flutter/material.dart';

import '../models/todo_item.dart';
import '../theme/app_theme.dart';
import '../utils/ai_generation_helper.dart';
import '../utils/ai_service.dart';
import '../utils/app_localizations.dart';
import '../utils/cloud_sync_service.dart';
import '../utils/notification_service.dart';
import '../utils/todo_persistence.dart';
import '../widgets/app_components.dart';
import '../widgets/archived_items_sheet.dart';
import '../widgets/page_fab.dart';
import '../widgets/responsive_scaffold.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({
    super.key,
    required this.fabController,
    required this.pageIndex,
  });

  final PageFabController fabController;
  final int pageIndex;

  @override
  State<TodoScreen> createState() => TodoScreenState();
}

class TodoScreenState extends State<TodoScreen>
    with PageFabBinding<TodoScreen> {
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
  PageFabController get pageFabController => widget.fabController;

  @override
  int get pageFabIndex => widget.pageIndex;

  @override
  bool get pageFabReady => !_isLoading;

  @override
  void initState() {
    super.initState();
    _loadTodos();
    unawaited(refreshFromCloud(force: false));
  }

  @override
  PageFabConfig buildPageFabConfig() {
    return PageFabConfig(
      tooltip: context.l10n.createTaskTag,
      icon: Icons.add,
      onPressed: _showCreateTodoDialog,
    );
  }

  Future<void> refreshFromCloud({bool force = true}) async {
    await CloudSyncService.instance.syncNow(force: force);
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
    schedulePageFabSync();
  }

  Future<void> _showCreateTodoDialog() async {
    final titleController = TextEditingController();
    var selectedColor = _presetColors.first;

    await showAppActionSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final media = MediaQuery.of(context);
            final availableHeight =
                media.size.height -
                media.padding.top -
                media.viewInsets.bottom -
                16;
            final maxHeight = (availableHeight * 0.9)
                .clamp(0.0, 560.0)
                .toDouble();

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.createTaskTag,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: titleController,
                              decoration: InputDecoration(
                                labelText: l10n.title,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.accentColor,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
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
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: Text(l10n.cancel),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
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
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                              await _loadTodos();
                            },
                            child: Text(l10n.save),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    titleController.dispose();
  }

  Future<void> _showEditTodoDialog(TodoItem item) async {
    final titleController = TextEditingController(text: item.title);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        final navigator = Navigator.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.renameTaskTag),
          content: TextField(
            controller: titleController,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.title),
          ),
          actions: [
            TextButton(onPressed: navigator.pop, child: Text(l10n.cancel)),
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
              child: Text(l10n.save),
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
        final l10n = dialogContext.l10n;
        final navigator = Navigator.of(dialogContext);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.changeColor(item.title)),
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
                TextButton(onPressed: navigator.pop, child: Text(l10n.cancel)),
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
                  child: Text(l10n.save),
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
      title: context.l10n.reminderTitle(item.title),
      body: 'A small nudge to add one more signal today.',
    );
    if (!mounted) {
      return;
    }
    if (!shown) {
      await _showNotificationSettingsPrompt();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.reminderSent(item.title))),
    );
  }

  Future<void> _showNotificationSettingsPrompt() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        final navigator = Navigator.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.notificationsOff),
          content: Text(l10n.notificationsOffMessage),
          actions: [
            TextButton(onPressed: navigator.pop, child: Text(l10n.notNow)),
            FilledButton(
              onPressed: () {
                navigator.pop();
                unawaited(
                  NotificationService.instance.openNotificationSettings(),
                );
              },
              child: Text(l10n.openSettings),
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
        SnackBar(content: Text(context.l10n.createTaskTagsBeforeAi)),
      );
      return;
    }

    setState(() {
      _isAiLoading = true;
      _aiPlan = null;
    });

    final result = await AiGenerationHelper.generate(
      context: context,
      aiService: _aiService,
      systemPrompt:
          'You are a practical planning assistant. Respond in concise Chinese with clear markdown bullets.',
      userPrompt: _buildTaskPlanPrompt(),
      setLoading: (loading) {
        if (mounted) {
          setState(() {
            _isAiLoading = loading;
          });
        }
      },
      mounted: mounted,
    );
    if (result != null && mounted) {
      setState(() {
        _aiPlan = result;
      });
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
      return context.l10n.minutesShort(minutes);
    }
    if (minutes == 0) {
      return context.l10n.hoursShort(hours);
    }
    return context.l10n.hoursMinutesShort(hours, minutes);
  }

  String _tasksHeaderMeta() {
    final l10n = context.l10n;
    return '${l10n.active} ${_activeTodos.length} · ${l10n.archived} ${_archivedTodos.length}';
  }

  Future<void> _showArchivedTodos() async {
    final l10n = context.l10n;
    await showArchivedItemsSheet(
      context: context,
      eyebrow: l10n.tasksEyebrow,
      title: l10n.archived,
      emptyMessage: l10n.noArchivedTaskTags,
      itemCount: _archivedTodos.length,
      itemBuilder: (context, index) => _buildTodoCard(
        _archivedTodos[index],
        archived: true,
        key: ValueKey('archived-${_archivedTodos[index].id}'),
      ),
    );
  }

  Widget _buildAiPlanPanel() {
    return FadeSlideIn(
      delay: const Duration(milliseconds: 80),
      child: AppPanel(
        color: AppTheme.raisedSurface,
        borderColor: AppTheme.sunshine.withValues(alpha: 0.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FlatIllustrationBadge(
                  icon: Icons.route_outlined,
                  color: AppTheme.warning,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.aiPlanning,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.ink,
                              fontWeight: FontWeight.w900,
                              height: 1.16,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.l10n.aiPlanningBody,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isAiLoading ? null : _generateAiPlan,
                icon: _isAiLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  _isAiLoading ? context.l10n.planning : context.l10n.recommend,
                ),
              ),
            ),
            if (_aiPlan != null) ...[
              const SizedBox(height: 14),
              AiMarkdownBlock(data: _aiPlan!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow() {
    final l10n = context.l10n;
    final totalMinutes = _activeTodos.fold<int>(
      0,
      (sum, item) => sum + item.totalDurationMinutes,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final tiles = [
          MetricTile(
            label: l10n.active,
            value: '${_activeTodos.length}',
            icon: Icons.layers_outlined,
            accent: AppTheme.primary,
          ),
          MetricTile(
            label: l10n.archived,
            value: '${_archivedTodos.length}',
            icon: Icons.inventory_2_outlined,
            accent: AppTheme.copper,
          ),
          MetricTile(
            label: l10n.trackedTime,
            value: _formatMinutes(totalMinutes),
            icon: Icons.timelapse,
            accent: AppTheme.steel,
          ),
        ];
        if (compact) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: tiles[0]),
                  const SizedBox(width: 10),
                  Expanded(child: tiles[1]),
                ],
              ),
              const SizedBox(height: 10),
              tiles[2],
            ],
          );
        }
        return Row(
          children: [
            for (var index = 0; index < tiles.length; index++) ...[
              Expanded(child: tiles[index]),
              if (index != tiles.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    final l10n = context.l10n;
    return AdaptiveWorkspace(
      primaryFlex: 5,
      secondaryFlex: 4,
      primary: RefreshIndicator(
        onRefresh: refreshFromCloud,
        child: _buildTodoList(
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                eyebrow: l10n.tasksEyebrow,
                title: l10n.tasksTitle,
                description: _tasksHeaderMeta(),
                showContext: false,
                showCompactMeta: true,
                trailing: QuietIconButton(
                  icon: Icons.archive_outlined,
                  tooltip: l10n.archived,
                  onPressed: _showArchivedTodos,
                ),
              ),
              const SizedBox(height: AppTheme.space3),
              _buildMetricsRow(),
              const SizedBox(height: AppTheme.space3),
            ],
          ),
        ),
      ),
      secondary: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_buildAiPlanPanel()],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final l10n = context.l10n;

    if (isDesktopLayout(context)) {
      return SafeArea(child: _buildDesktopLayout());
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refreshFromCloud,
        child: _buildTodoList(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            12,
            AppTheme.pagePadding,
            142,
          ),
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageIntro(
                eyebrow: l10n.tasksEyebrow,
                title: l10n.tasksTitle,
                description: _tasksHeaderMeta(),
                showContext: false,
                showCompactMeta: true,
                trailing: QuietIconButton(
                  icon: Icons.archive_outlined,
                  tooltip: l10n.archived,
                  onPressed: _showArchivedTodos,
                ),
              ),
              const SizedBox(height: 10),
              _buildAiPlanPanel(),
              const SizedBox(height: 10),
              _buildMetricsRow(),
              const SizedBox(height: 10),
            ],
          ),
          footer: const SizedBox(height: 16),
        ),
      ),
    );
  }

  Widget _buildTodoList({
    required Widget header,
    EdgeInsets? padding,
    Widget? footer,
  }) {
    final l10n = context.l10n;
    final isEmpty = _activeTodos.isEmpty;
    return ReorderableListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      onReorderItem: _reorderActiveTodos,
      header: header,
      footer: footer,
      itemCount: isEmpty ? 1 : _activeTodos.length,
      itemBuilder: (context, index) {
        if (isEmpty) {
          return Padding(
            key: const ValueKey('empty-task-card'),
            padding: const EdgeInsets.only(bottom: 10),
            child: EmptyState(
              icon: Icons.checklist_outlined,
              title: l10n.noTaskTagsTitle,
              message: l10n.noTaskTagsMessage,
            ),
          );
        }
        final todo = _activeTodos[index];
        return _buildTodoCard(todo, key: ValueKey(todo.id), index: index);
      },
    );
  }

  Widget _buildTodoCard(
    TodoItem item, {
    bool archived = false,
    Key? key,
    int index = 0,
  }) {
    final compact = !isDesktopLayout(context);
    final panelPadding = compact
        ? const EdgeInsets.fromLTRB(44, 11, 10, 11)
        : const EdgeInsets.fromLTRB(44, 13, 12, 13);

    return Padding(
      key: key,
      padding: EdgeInsets.only(bottom: compact ? 8 : 10),
      child: FadeSlideIn(
        delay: Duration(milliseconds: 30 * (index > 8 ? 8 : index)),
        child: AppPanel(
          padding: panelPadding,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -22,
                top: -13,
                bottom: -13,
                child: Container(
                  width: 2,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              Positioned(
                left: -27,
                top: 6,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    border: Border.all(color: AppTheme.surface, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.24),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Column(
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
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.18,
                              ),
                        ),
                      ),
                      if (item.isSystem)
                        AppChip(
                          label: context.l10n.defaultLabel,
                          color: item.color,
                          maxWidth: compact ? 72 : null,
                        ),
                    ],
                  ),
                  SizedBox(height: compact ? 4 : 7),
                  Row(
                    children: [
                      Icon(
                        archived
                            ? Icons.archive_outlined
                            : Icons.timer_outlined,
                        size: 14,
                        color: item.color,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.summaryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.muted,
                                fontSize: compact ? 12 : null,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  Wrap(
                    spacing: compact ? 5 : 6,
                    runSpacing: compact ? 5 : 6,
                    children: [
                      if (!archived)
                        _buildTaskActionButton(
                          tooltip: context.l10n.sendReminder,
                          onPressed: () => _sendReminder(item),
                          icon: Icons.alarm_add_outlined,
                          color: AppTheme.steel,
                          compact: compact,
                        ),
                      if (!archived && !item.isSystem)
                        _buildTaskActionButton(
                          tooltip: context.l10n.rename,
                          onPressed: () => _showEditTodoDialog(item),
                          icon: Icons.edit_outlined,
                          color: AppTheme.primary,
                          compact: compact,
                        ),
                      _buildTaskActionButton(
                        tooltip: context.l10n.changeColorTooltip,
                        onPressed: archived
                            ? null
                            : () => _showColorDialog(item),
                        icon: Icons.palette_outlined,
                        color: item.color,
                        compact: compact,
                      ),
                      if (archived)
                        _buildTaskActionButton(
                          tooltip: context.l10n.restore,
                          onPressed: () => _restoreTodo(item),
                          icon: Icons.unarchive_outlined,
                          color: AppTheme.primary,
                          compact: compact,
                        )
                      else if (!item.isSystem)
                        _buildTaskActionButton(
                          tooltip: context.l10n.archive,
                          onPressed: () => _archiveTodo(item),
                          icon: Icons.archive_outlined,
                          color: AppTheme.muted,
                          compact: compact,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    required Color color,
    required bool compact,
  }) {
    if (!compact) {
      return QuietIconButton(
        icon: icon,
        onPressed: onPressed,
        tooltip: tooltip,
        color: color,
      );
    }

    return SizedBox.square(
      dimension: 36,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 18,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        visualDensity: VisualDensity.compact,
        color: color,
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.raisedSurface,
          disabledForegroundColor: AppTheme.faint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
            side: const BorderSide(color: AppTheme.border),
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
        curve: AppTheme.motionCurve,
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
