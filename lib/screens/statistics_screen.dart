import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/time_event.dart';
import '../theme/app_theme.dart';
import '../utils/ai_service.dart';
import '../utils/todo_persistence.dart';
import '../widgets/app_components.dart';

enum StatisticsViewMode { day, week }

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key, required this.events});

  final List<TimeEvent> events;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  static const double _hourRowHeight = 52;

  final TodoPersistenceService _todoService = TodoPersistenceService();
  final AiService _aiService = AiService();
  late DateTime _selectedDate;
  StatisticsViewMode _viewMode = StatisticsViewMode.day;
  int _touchedPieIndex = -1;
  Map<String, Color> _todoColorMap = {};
  bool _isAiLoading = false;
  String? _aiInsight;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.events.isEmpty
        ? DateTime.now()
        : widget.events.first.addedAt;
    _loadTodoColors();
  }

  @override
  void didUpdateWidget(covariant StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadTodoColors();
  }

  Future<void> _loadTodoColors() async {
    final colorMap = await _todoService.loadTodoColorMap();
    if (!mounted) {
      return;
    }
    setState(() {
      _todoColorMap = colorMap;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
      _touchedPieIndex = -1;
      _aiInsight = null;
    });
  }

  DateTime get _startOfSelectedWeek => _dateOnly(
    _selectedDate,
  ).subtract(Duration(days: _selectedDate.weekday - 1));

  List<TimeEvent> get _filteredEvents {
    if (_viewMode == StatisticsViewMode.day) {
      final day = _dateOnly(_selectedDate);
      return widget.events
          .where((event) => _isSameDay(event.addedAt, day))
          .toList()
        ..sort((a, b) => a.addedAt.compareTo(b.addedAt));
    }

    final start = _startOfSelectedWeek;
    final end = start.add(const Duration(days: 7));
    return widget.events.where((event) {
      final timestamp = event.addedAt;
      return !timestamp.isBefore(start) && timestamp.isBefore(end);
    }).toList()..sort((a, b) => a.addedAt.compareTo(b.addedAt));
  }

  Map<String, _TagStats> get _tagStats {
    final stats = <String, _TagStats>{};
    for (final event in _filteredEvents) {
      final label = _tagForEvent(event);
      final current = stats[label];
      stats[label] = _TagStats(
        label: label,
        color: _colorForEvent(event),
        count: (current?.count ?? 0) + 1,
        minutes: (current?.minutes ?? 0) + event.totalMinutes,
      );
    }
    return stats;
  }

  int get _totalMinutes =>
      _filteredEvents.fold(0, (sum, event) => sum + event.totalMinutes);

  Color _colorForEvent(TimeEvent event) {
    return _todoColorMap[event.linkedTodoId] ??
        switch (event.linkedTodoId) {
          'system-work' => AppTheme.steel,
          'system-study' => AppTheme.success,
          'system-play' => AppTheme.copper,
          _ => AppTheme.primary,
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

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

  Future<void> _generateAiInsight() async {
    if (_filteredEvents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add entries first, then ask AI.')),
      );
      return;
    }

    setState(() {
      _isAiLoading = true;
      _aiInsight = null;
    });

    try {
      final result = await _aiService.complete(
        systemPrompt:
            'You are an insightful time management coach. Respond in concise, practical Chinese. Use markdown bullets.',
        userPrompt: _buildInsightPrompt(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _aiInsight = result;
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

  String _buildInsightPrompt() {
    final modeLabel = _viewMode == StatisticsViewMode.day ? '每日' : '每周';
    final rangeLabel = _viewMode == StatisticsViewMode.day
        ? _formatDate(_selectedDate)
        : '${_formatDate(_startOfSelectedWeek)} - ${_formatDate(_startOfSelectedWeek.add(const Duration(days: 6)))}';
    final tagLines = _tagStats.values
        .map(
          (entry) =>
              '- ${entry.label}: ${entry.count}次，${_formatDuration(entry.minutes)}',
        )
        .join('\n');
    final eventLines = _filteredEvents
        .map((event) {
          final time =
              '${event.addedAt.hour.toString().padLeft(2, '0')}:${event.addedAt.minute.toString().padLeft(2, '0')}';
          final label = _tagForEvent(event);
          final title = event.description.trim().isEmpty
              ? '(no title)'
              : event.description.trim();
          final note = event.note.trim().isEmpty
              ? ''
              : '；备注：${event.note.trim()}';
          return '- $time [$label] $title，${event.displayDuration}$note';
        })
        .join('\n');

    return '''
请分析 RecordMyTime 的$modeLabel时间记录，给出：
1. 主要时间流向
2. 精力和节奏观察
3. 可执行的改进建议
4. 明日/下阶段计划建议

范围：$rangeLabel
总记录：${_filteredEvents.length}次
总时长：${_formatDuration(_totalMinutes)}

分类统计：
$tagLines

时间线：
$eventLines
''';
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: MetricTile(
            label: 'Entries',
            value: '${_filteredEvents.length}',
            icon: Icons.numbers,
            accent: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricTile(
            label: 'Tracked time',
            value: _formatDuration(_totalMinutes),
            icon: Icons.timelapse,
            accent: AppTheme.steel,
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart() {
    final entries = _tagStats.values.toList()
      ..sort((a, b) {
        final scoreA = a.minutes == 0 ? a.count : a.minutes;
        final scoreB = b.minutes == 0 ? b.count : b.minutes;
        return scoreB.compareTo(scoreA);
      });
    final displayValues = <double>[
      for (final entry in entries)
        entry.minutes > 0
            ? entry.minutes.toDouble()
            : math.max(entry.count * 24.0, 12.0),
    ];
    final totalDisplayValue = displayValues.fold<double>(
      0,
      (sum, value) => sum + value,
    );

    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.pie_chart_outline,
        title: 'No chartable data',
        message: 'Add entries inside this range to see tag share.',
      );
    }

    final touchedEntry =
        _touchedPieIndex >= 0 && _touchedPieIndex < entries.length
        ? entries[_touchedPieIndex]
        : null;

    return FadeSlideIn(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_touchedPieIndex != -1) {
            setState(() {
              _touchedPieIndex = -1;
            });
          }
        },
        child: AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tag share',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 280,
                    maxHeight: 280,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (_, response) {
                            setState(() {
                              _touchedPieIndex =
                                  response
                                      ?.touchedSection
                                      ?.touchedSectionIndex ??
                                  -1;
                            });
                          },
                        ),
                        sectionsSpace: 4,
                        centerSpaceRadius: 56,
                        sections: [
                          for (var i = 0; i < entries.length; i++)
                            PieChartSectionData(
                              color: entries[i].color,
                              value: displayValues[i],
                              radius: _touchedPieIndex == i ? 102.0 : 92.0,
                              title:
                                  '${((displayValues[i] / math.max(totalDisplayValue, 1)) * 100).toStringAsFixed(0)}%',
                              titleStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  for (final entry in entries) _LegendChip(entry: entry),
                ],
              ),
              if (touchedEntry != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: touchedEntry.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  ),
                  child: Text(
                    '${touchedEntry.label}: ${touchedEntry.count} times, ${_formatDuration(touchedEntry.minutes)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    if (_filteredEvents.isEmpty) {
      return const EmptyState(
        icon: Icons.timeline_outlined,
        title: 'No timeline yet',
        message: 'The timeline appears after entries are added to this range.',
      );
    }

    return FadeSlideIn(
      delay: const Duration(milliseconds: 90),
      child: AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _viewMode == StatisticsViewMode.day
                  ? 'Daily timeline'
                  : 'Weekly timeline',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 14),
            _viewMode == StatisticsViewMode.day
                ? _DayTimeline(
                    date: _selectedDate,
                    events: _filteredEvents,
                    hourRowHeight: _hourRowHeight,
                    formatDuration: _formatDuration,
                    colorForEvent: _colorForEvent,
                    tagForEvent: _tagForEvent,
                  )
                : _WeekTimeline(
                    weekStart: _startOfSelectedWeek,
                    events: _filteredEvents,
                    hourRowHeight: _hourRowHeight,
                    formatDuration: _formatDuration,
                    colorForEvent: _colorForEvent,
                    tagForEvent: _tagForEvent,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiInsightPanel() {
    return FadeSlideIn(
      delay: const Duration(milliseconds: 120),
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
                    'AI schedule insight',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isAiLoading ? null : _generateAiInsight,
                  icon: _isAiLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.psychology_outlined),
                  label: Text(_isAiLoading ? 'Thinking' : 'Analyze'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_aiInsight == null)
              Text(
                'Use your selected range to generate a practical schedule review and next-step plan.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.muted,
                  height: 1.5,
                ),
              )
            else
              AiMarkdownBlock(data: _aiInsight!),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rangeLabel = _viewMode == StatisticsViewMode.day
        ? 'Date ${_formatDate(_selectedDate)}'
        : 'Week ${_formatDate(_startOfSelectedWeek)} - ${_formatDate(_startOfSelectedWeek.add(const Duration(days: 6)))}';

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;

            final header = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageIntro(
                  eyebrow: 'Analytics',
                  title: 'Insights',
                  description: rangeLabel,
                  trailing: QuietIconButton(
                    onPressed: _pickDate,
                    icon: Icons.calendar_month,
                    tooltip: 'Choose date',
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<StatisticsViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: StatisticsViewMode.day,
                      label: Text('Day'),
                      icon: Icon(Icons.today),
                    ),
                    ButtonSegment(
                      value: StatisticsViewMode.week,
                      label: Text('Week'),
                      icon: Icon(Icons.view_week),
                    ),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _viewMode = selection.first;
                      _touchedPieIndex = -1;
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
            );

            if (isLandscape) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.pagePadding,
                  18,
                  AppTheme.pagePadding,
                  18,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 32),
                        child: CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  header,
                                  _buildSummaryCards(),
                                  const SizedBox(height: 16),
                                  _buildAiInsightPanel(),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                            SliverFillRemaining(
                              hasScrollBody: true,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Center(child: _buildPieChart()),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.only(top: 0),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 104),
                          child: _buildTimeline(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.pagePadding,
                18,
                AppTheme.pagePadding,
                104,
              ),
              children: [
                header,
                _buildSummaryCards(),
                const SizedBox(height: 16),
                _buildAiInsightPanel(),
                const SizedBox(height: 16),
                _buildPieChart(),
                const SizedBox(height: 16),
                _buildTimeline(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TagStats {
  const _TagStats({
    required this.label,
    required this.color,
    required this.count,
    required this.minutes,
  });

  final String label;
  final Color color;
  final int count;
  final int minutes;
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.entry});

  final _TagStats entry;

  @override
  Widget build(BuildContext context) {
    return AppChip(label: entry.label, color: entry.color);
  }
}

class _DayTimeline extends StatelessWidget {
  const _DayTimeline({
    required this.date,
    required this.events,
    required this.hourRowHeight,
    required this.formatDuration,
    required this.colorForEvent,
    required this.tagForEvent,
  });

  final DateTime date;
  final List<TimeEvent> events;
  final double hourRowHeight;
  final String Function(int minutes) formatDuration;
  final Color Function(TimeEvent event) colorForEvent;
  final String Function(TimeEvent event) tagForEvent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleWidth = constraints.maxWidth * 0.28;
        final timelineHeight = hourRowHeight * 24;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _monthDay(date),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: timelineHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: scaleWidth,
                    child: _TimeScale(hourRowHeight: hourRowHeight),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimelineColumn(
                      events: events,
                      colorForEvent: colorForEvent,
                      tagForEvent: tagForEvent,
                      formatDuration: formatDuration,
                      hourRowHeight: hourRowHeight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _monthDay(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _WeekTimeline extends StatelessWidget {
  const _WeekTimeline({
    required this.weekStart,
    required this.events,
    required this.hourRowHeight,
    required this.formatDuration,
    required this.colorForEvent,
    required this.tagForEvent,
  });

  final DateTime weekStart;
  final List<TimeEvent> events;
  final double hourRowHeight;
  final String Function(int minutes) formatDuration;
  final Color Function(TimeEvent event) colorForEvent;
  final String Function(TimeEvent event) tagForEvent;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );
    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleWidth = constraints.maxWidth * 0.28;
        final timelineHeight = hourRowHeight * 24;

        return Column(
          children: [
            Row(
              children: [
                SizedBox(width: scaleWidth),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 0; i < days.length; i++)
                        Expanded(
                          child: Center(
                            child: Text(
                              weekdayLabels[i],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.muted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: timelineHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: scaleWidth,
                    child: _TimeScale(hourRowHeight: hourRowHeight),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        for (final day in days)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: _TimelineColumn(
                                events: events.where((event) {
                                  return event.addedAt.year == day.year &&
                                      event.addedAt.month == day.month &&
                                      event.addedAt.day == day.day;
                                }).toList(),
                                colorForEvent: colorForEvent,
                                tagForEvent: tagForEvent,
                                formatDuration: formatDuration,
                                hourRowHeight: hourRowHeight,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TimeScale extends StatelessWidget {
  const _TimeScale({required this.hourRowHeight});

  final double hourRowHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int hour = 0; hour < 24; hour++)
          SizedBox(
            height: hourRowHeight,
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: AppTheme.muted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TimelineColumn extends StatelessWidget {
  const _TimelineColumn({
    required this.events,
    required this.colorForEvent,
    required this.tagForEvent,
    required this.formatDuration,
    required this.hourRowHeight,
  });

  final List<TimeEvent> events;
  final Color Function(TimeEvent event) colorForEvent;
  final String Function(TimeEvent event) tagForEvent;
  final String Function(int minutes) formatDuration;
  final double hourRowHeight;

  @override
  Widget build(BuildContext context) {
    final totalHeight = hourRowHeight * 24;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.raisedSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.border),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: Column(
              children: [
                for (int i = 0; i < 24; i++)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: i == 0
                                ? Colors.transparent
                                : AppTheme.border.withValues(alpha: 0.55),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final event in events)
            _buildEventOverlay(context, event: event, totalHeight: totalHeight),
        ],
      ),
    );
  }

  Widget _buildEventOverlay(
    BuildContext context, {
    required TimeEvent event,
    required double totalHeight,
  }) {
    final timestamp = event.addedAt;
    final minuteOfDay = timestamp.hour * 60 + timestamp.minute;
    final top = (minuteOfDay / (24 * 60)) * totalHeight;
    final label = tagForEvent(event);
    final fillColor = colorForEvent(event).withValues(alpha: 0.18);
    final borderColor = colorForEvent(event);

    if (event.recordMode == EventRecordMode.count) {
      return Positioned(
        top: top.clamp(0.0, totalHeight - 18),
        left: 10,
        right: 10,
        child: Tooltip(
          message:
              '$label\n${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')} · 1 time',
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: borderColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
      );
    }

    final startMinutes = minuteOfDay - event.totalMinutes;
    final startTop = (startMinutes / (24 * 60)) * totalHeight;
    final height = math.max(
      (event.totalMinutes / (24 * 60)) * totalHeight,
      26.0,
    );

    return Positioned(
      top: startTop.clamp(0.0, totalHeight - height),
      left: 8,
      right: 8,
      child: Tooltip(
        message: '$label\n${formatDuration(event.totalMinutes)}',
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          alignment: Alignment.topLeft,
          child: Text(
            label,
            maxLines: height > 40 ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
