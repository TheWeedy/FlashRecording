import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_customizable_calendar/flutter_customizable_calendar.dart';

import '../models/time_event.dart';

enum StatisticsViewMode { day, week }

class StatisticsScreen extends StatefulWidget {
  final List<TimeEvent> events;

  const StatisticsScreen({super.key, required this.events});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late DateTime _selectedDate;
  late StatisticsViewMode _viewMode;
  late DaysViewController _daysController;
  late WeekViewController _weekController;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.events.isEmpty
        ? DateTime.now()
        : widget.events.first.addedAt;
    _viewMode = StatisticsViewMode.day;
    _daysController = DaysViewController(
      initialDate: DateTime(_selectedDate.year, _selectedDate.month, 1),
      focusedDate: _selectedDate,
    );
    _weekController = WeekViewController(
      initialDate: _selectedDate,
      visibleDays: 7,
    );
    _daysController.selectDay(_selectedDate);
    _weekController.setDisplayedDate(_selectedDate);
  }

  @override
  void dispose() {
    _daysController.dispose();
    _weekController.dispose();
    super.dispose();
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
      _daysController.selectDay(picked);
      _weekController.setDisplayedDate(picked);
    });
  }

  List<TimeEvent> get _filteredEvents {
    if (_viewMode == StatisticsViewMode.day) {
      return widget.events.where((event) {
        return event.addedAt.year == _selectedDate.year &&
            event.addedAt.month == _selectedDate.month &&
            event.addedAt.day == _selectedDate.day;
      }).toList();
    }

    final startOfWeek =
        _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return widget.events.where((event) {
      final addedAt = event.addedAt;
      return !addedAt.isBefore(startOfWeek) && addedAt.isBefore(endOfWeek);
    }).toList();
  }

  List<FloatingCalendarEvent> get _calendarEvents {
    return _filteredEvents.map((event) {
      final color = _colorForEvent(event);
      if (event.recordMode == EventRecordMode.count) {
        return TaskDue(
          id: event.id,
          start: event.addedAt,
          color: color,
        );
      }

      final duration = Duration(
        minutes: math.max(1, event.totalMinutes),
      );
      return SimpleEvent(
        id: event.id,
        start: event.addedAt.subtract(duration),
        duration: duration,
        title: event.linkedTodoTitle ?? event.description,
        color: color,
      );
    }).toList();
  }

  Color _colorForEvent(TimeEvent event) {
    switch (event.linkedTodoId) {
      case 'system-work':
        return Colors.blue;
      case 'system-study':
        return Colors.green;
      case 'system-play':
        return Colors.orange;
      default:
        return Colors.teal;
    }
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
    final totalCount = _filteredEvents.length;
    final totalMinutes = _filteredEvents.fold<int>(
      0,
      (sum, event) => sum + event.totalMinutes,
    );

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: '记录次数',
            value: '$totalCount 次',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            label: '记录时长',
            value: _formatDuration(totalMinutes),
          ),
        ),
      ],
    );
  }

  Widget _buildTagChart() {
    final tagMinutes = <String, int>{};
    for (final event in _filteredEvents) {
      final label = event.linkedTodoTitle ?? '未命名';
      tagMinutes[label] = (tagMinutes[label] ?? 0) + event.totalMinutes;
    }

    final entries = tagMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('当前时间范围内还没有可统计的数据'),
        ),
      );
    }

    final chartMax = math.max(
      60,
      entries.map((e) => e.value).fold<int>(0, math.max),
    ).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '标签时长',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: chartMax,
                  barGroups: [
                    for (var i = 0; i < entries.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: entries[i].value.toDouble(),
                            color: Colors.teal,
                            width: 20,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
                      ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= entries.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              entries[index].key,
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: 60,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value / 60).toStringAsFixed(0)}h',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 60,
                  ),
                  barTouchData: BarTouchData(enabled: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    if (_calendarEvents.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('当前时间范围内没有记录，时间轴会在新增记录后显示。'),
        ),
      );
    }

    const timelineTheme = TimelineTheme(
      timeScaleTheme: TimeScaleTheme(
        width: 40,
        hourExtent: 64,
      ),
    );

    return SizedBox(
      height: 420,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: _viewMode == StatisticsViewMode.day
            ? DaysView<FloatingCalendarEvent>(
                controller: _daysController,
                events: _calendarEvents,
                timelineTheme: timelineTheme,
                enableFloatingEvents: false,
              )
            : WeekView<FloatingCalendarEvent>(
                controller: _weekController,
                events: _calendarEvents,
                timelineTheme: timelineTheme,
                enableFloatingEvents: false,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _viewMode == StatisticsViewMode.day
        ? '日期：${_formatDate(_selectedDate)}'
        : '周视图：${_formatDate(_selectedDate)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
              });
            },
          ),
          const SizedBox(height: 16),
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildCalendarView(),
          const SizedBox(height: 16),
          _buildTagChart(),
        ],
      ),
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
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
