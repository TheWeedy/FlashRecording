import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/time_event.dart';
import '../utils/todo_persistence.dart';

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
  late DateTime _selectedDate;
  StatisticsViewMode _viewMode = StatisticsViewMode.day;
  int _touchedPieIndex = -1;
  Map<String, Color> _todoColorMap = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.events.isEmpty ? DateTime.now() : widget.events.first.addedAt;
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
    });
  }

  DateTime get _startOfSelectedWeek =>
      _dateOnly(_selectedDate).subtract(Duration(days: _selectedDate.weekday - 1));

  List<TimeEvent> get _filteredEvents {
    if (_viewMode == StatisticsViewMode.day) {
      final day = _dateOnly(_selectedDate);
      return widget.events.where((event) => _isSameDay(event.addedAt, day)).toList()
        ..sort((a, b) => a.addedAt.compareTo(b.addedAt));
    }

    final start = _startOfSelectedWeek;
    final end = start.add(const Duration(days: 7));
    return widget.events.where((event) {
      final timestamp = event.addedAt;
      return !timestamp.isBefore(start) && timestamp.isBefore(end);
    }).toList()
      ..sort((a, b) => a.addedAt.compareTo(b.addedAt));
  }

  Map<String, _TagStats> get _tagStats {
    final stats = <String, _TagStats>{};
    for (final event in _filteredEvents) {
      final label = event.linkedTodoTitle ?? '未命名标签';
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

  int get _totalMinutes => _filteredEvents.fold(0, (sum, event) => sum + event.totalMinutes);

  Color _colorForEvent(TimeEvent event) {
    return _todoColorMap[event.linkedTodoId] ??
        switch (event.linkedTodoId) {
          'system-work' => Colors.blue.shade600,
          'system-study' => Colors.green.shade600,
          'system-play' => Colors.orange.shade700,
          _ => Colors.teal.shade600,
        };
  }

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

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
      return '$minutes 分钟';
    }
    if (minutes == 0) {
      return '$hours 小时';
    }
    return '$hours 小时 $minutes 分钟';
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: '记录次数',
            value: '${_filteredEvents.length} 次',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: '记录时长',
            value: _formatDuration(_totalMinutes),
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
        entry.minutes > 0 ? entry.minutes.toDouble() : math.max(entry.count * 24.0, 12.0),
    ];
    final totalDisplayValue = displayValues.fold<double>(0, (sum, value) => sum + value);

    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            '当前时间范围内没有可统计的数据。',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    final touchedEntry =
        _touchedPieIndex >= 0 && _touchedPieIndex < entries.length ? entries[_touchedPieIndex] : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_touchedPieIndex != -1) {
          setState(() {
            _touchedPieIndex = -1;
          });
        }
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '标签占比',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (_, response) {
                          setState(() {
                            _touchedPieIndex = response?.touchedSection?.touchedSectionIndex ?? -1;
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
                            title: '${((displayValues[i] / math.max(totalDisplayValue, 1)) * 100).toStringAsFixed(0)}%',
                            titleStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                      ],
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${touchedEntry.label}：${touchedEntry.count} 次，${_formatDuration(touchedEntry.minutes)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
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
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            '当前时间范围内没有记录，时间轴会在新增记录后显示。',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _viewMode == StatisticsViewMode.day ? '单日时间轴' : '本周时间轴',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            _viewMode == StatisticsViewMode.day
                ? _DayTimeline(
                    date: _selectedDate,
                    events: _filteredEvents,
                    hourRowHeight: _hourRowHeight,
                    formatDuration: _formatDuration,
                    colorForEvent: _colorForEvent,
                  )
                : _WeekTimeline(
                    weekStart: _startOfSelectedWeek,
                    events: _filteredEvents,
                    hourRowHeight: _hourRowHeight,
                    formatDuration: _formatDuration,
                    colorForEvent: _colorForEvent,
                  ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _viewMode == StatisticsViewMode.day
        ? '日期：${_formatDate(_selectedDate)}'
        : '周范围：${_formatDate(_startOfSelectedWeek)} - ${_formatDate(_startOfSelectedWeek.add(const Duration(days: 6)))}';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '统计',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
            tooltip: '选择日期',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          SegmentedButton<StatisticsViewMode>(
            segments: const [
              ButtonSegment(
                value: StatisticsViewMode.day,
                label: Text('单日'),
                icon: Icon(Icons.today),
              ),
              ButtonSegment(
                value: StatisticsViewMode.week,
                label: Text('周视图'),
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
            style: const ButtonStyle(
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildPieChart(),
          const SizedBox(height: 16),
          _buildTimeline(),
        ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: entry.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: entry.color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            entry.label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTimeline extends StatelessWidget {
  const _DayTimeline({
    required this.date,
    required this.events,
    required this.hourRowHeight,
    required this.formatDuration,
    required this.colorForEvent,
  });

  final DateTime date;
  final List<TimeEvent> events;
  final double hourRowHeight;
  final String Function(int minutes) formatDuration;
  final Color Function(TimeEvent event) colorForEvent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleWidth = constraints.maxWidth * 0.32;
        final timelineHeight = hourRowHeight * 24;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.month}月${date.day}日',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
}

class _WeekTimeline extends StatelessWidget {
  const _WeekTimeline({
    required this.weekStart,
    required this.events,
    required this.hourRowHeight,
    required this.formatDuration,
    required this.colorForEvent,
  });

  final DateTime weekStart;
  final List<TimeEvent> events;
  final double hourRowHeight;
  final String Function(int minutes) formatDuration;
  final Color Function(TimeEvent event) colorForEvent;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (index) => weekStart.add(Duration(days: index)));
    const weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleWidth = constraints.maxWidth * 0.32;
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
                              '周${weekdayLabels[i]}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
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
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: _TimelineColumn(
                                events: events.where((event) {
                                  return event.addedAt.year == day.year &&
                                      event.addedAt.month == day.month &&
                                      event.addedAt.day == day.day;
                                }).toList(),
                                colorForEvent: colorForEvent,
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
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1,
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
    required this.formatDuration,
    required this.hourRowHeight,
  });

  final List<TimeEvent> events;
  final Color Function(TimeEvent event) colorForEvent;
  final String Function(int minutes) formatDuration;
  final double hourRowHeight;

  @override
  Widget build(BuildContext context) {
    final totalHeight = hourRowHeight * 24;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
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
                            color: i == 0 ? Colors.transparent : Colors.grey.shade200,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final event in events)
            _buildEventOverlay(
              context,
              event: event,
              totalHeight: totalHeight,
            ),
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
    final fillColor = colorForEvent(event).withValues(alpha: 0.22);
    final borderColor = colorForEvent(event);

    if (event.recordMode == EventRecordMode.count) {
      return Positioned(
        top: top.clamp(0.0, totalHeight - 18),
        left: 10,
        right: 10,
        child: Tooltip(
          message:
              '${event.linkedTodoTitle ?? event.description}\n${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')} · 1 次',
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
    final height = math.max((event.totalMinutes / (24 * 60)) * totalHeight, 26.0);

    return Positioned(
      top: startTop.clamp(0.0, totalHeight - height),
      left: 8,
      right: 8,
      child: Tooltip(
        message: '${event.linkedTodoTitle ?? event.description}\n${formatDuration(event.totalMinutes)}',
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          alignment: Alignment.topLeft,
          child: Text(
            event.linkedTodoTitle ?? event.description,
            maxLines: height > 40 ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
