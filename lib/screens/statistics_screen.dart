import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/time_event.dart';

enum StatisticsViewMode { day, week }

class StatisticsScreen extends StatefulWidget {
  final List<TimeEvent> events;

  const StatisticsScreen({super.key, required this.events});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  static const double _hourRowHeight = 52;

  late DateTime _selectedDate;
  StatisticsViewMode _viewMode = StatisticsViewMode.day;
  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    _selectedDate =
        widget.events.isEmpty ? DateTime.now() : widget.events.first.addedAt;
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
    }).toList()..sort((a, b) => a.addedAt.compareTo(b.addedAt));
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

  int get _totalMinutes =>
      _filteredEvents.fold(0, (sum, event) => sum + event.totalMinutes);

  Color _colorForEvent(TimeEvent event) {
    switch (event.linkedTodoId) {
      case 'system-work':
        return Colors.blue.shade600;
      case 'system-study':
        return Colors.green.shade600;
      case 'system-play':
        return Colors.orange.shade700;
      default:
        return Colors.teal.shade600;
    }
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
      ..sort((a, b) => b.minutes.compareTo(a.minutes));

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

    return Card(
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
            SizedBox(
              height: 260,
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              _touchedPieIndex = response?.touchedSection?.touchedSectionIndex ?? -1;
                            });
                          },
                        ),
                        sectionsSpace: 3,
                        centerSpaceRadius: 54,
                        sections: [
                          for (var i = 0; i < entries.length; i++)
                            PieChartSectionData(
                              color: entries[i].color,
                              value: math.max(entries[i].minutes.toDouble(), 1),
                              radius: _touchedPieIndex == i ? 92 : 82,
                              title: '${((entries[i].minutes / math.max(_totalMinutes, 1)) * 100).toStringAsFixed(0)}%',
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final entry in entries) ...[
                          _LegendRow(entry: entry),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (touchedEntry != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
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
  final String label;
  final Color color;
  final int count;
  final int minutes;

  const _TagStats({
    required this.label,
    required this.color,
    required this.count,
    required this.minutes,
  });
}

class _LegendRow extends StatelessWidget {
  final _TagStats entry;

  const _LegendRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Row(
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
        Expanded(
          child: Text(
            entry.label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryCard({
    required this.label,
    required this.value,
  });

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
  final DateTime date;
  final List<TimeEvent> events;
  final double hourRowHeight;
  final String Function(int minutes) formatDuration;
  final Color Function(TimeEvent event) colorForEvent;

  const _DayTimeline({
    required this.date,
    required this.events,
    required this.hourRowHeight,
    required this.formatDuration,
    required this.colorForEvent,
  });

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
  final DateTime weekStart;
  final List<TimeEvent> events;
  final double hourRowHeight;
  final String Function(int minutes) formatDuration;
  final Color Function(TimeEvent event) colorForEvent;

  const _WeekTimeline({
    required this.weekStart,
    required this.events,
    required this.hourRowHeight,
    required this.formatDuration,
    required this.colorForEvent,
  });

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (index) => weekStart.add(Duration(days: index)));

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
                      for (final day in days)
                        Expanded(
                          child: Center(
                            child: Text(
                              '${day.month}/${day.day}',
                              style: const TextStyle(
                                fontSize: 13,
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
  final double hourRowHeight;

  const _TimeScale({required this.hourRowHeight});

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
  final List<TimeEvent> events;
  final Color Function(TimeEvent event) colorForEvent;
  final String Function(int minutes) formatDuration;
  final double hourRowHeight;

  const _TimelineColumn({
    required this.events,
    required this.colorForEvent,
    required this.formatDuration,
    required this.hourRowHeight,
  });

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
        children: [
          Column(
            children: [
              for (int i = 0; i < 24; i++)
                Container(
                  height: hourRowHeight,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: i == 0 ? Colors.transparent : Colors.grey.shade200,
                      ),
                    ),
                  ),
                ),
            ],
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

    if (event.recordMode == EventRecordMode.count) {
      return Positioned(
        top: top.clamp(0.0, totalHeight - 16),
        left: 10,
        right: 10,
        child: Tooltip(
          message:
              '${event.linkedTodoTitle ?? event.description}\n${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')} · 1 次',
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: colorForEvent(event),
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
    final height = math.max((event.totalMinutes / (24 * 60)) * totalHeight, 18.0);

    return Positioned(
      top: startTop.clamp(0.0, totalHeight - height),
      left: 8,
      right: 8,
      child: Tooltip(
        message:
            '${event.linkedTodoTitle ?? event.description}\n${formatDuration(event.totalMinutes)}',
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: colorForEvent(event).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: colorForEvent(event).withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          alignment: Alignment.topLeft,
          child: Text(
            event.linkedTodoTitle ?? event.description,
            maxLines: height > 34 ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
