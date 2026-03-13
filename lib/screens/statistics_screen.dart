import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/time_event.dart';

class StatisticsScreen extends StatelessWidget {
  final List<TimeEvent> events;

  const StatisticsScreen({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final totalMinutes = events.fold(0, (sum, e) => sum + e.totalMinutes);
    final totalHours = totalMinutes ~/ 60;
    final remainingMinutes = totalMinutes % 60;

    final Map<String, Map<EventType, int>> dailyData = {};
    for (var event in events) {
      final dateKey =
          '${event.addedAt.year}-${event.addedAt.month.toString().padLeft(2, '0')}-${event.addedAt.day.toString().padLeft(2, '0')}';
      dailyData.putIfAbsent(
        dateKey,
        () => {
          EventType.work: 0,
          EventType.study: 0,
          EventType.play: 0,
        },
      );
      dailyData[dateKey]![event.type] =
          dailyData[dateKey]![event.type]! + event.totalMinutes;
    }

    final sortedDates = dailyData.keys.toList()..sort((a, b) => b.compareTo(a));

    if (sortedDates.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    final overallMax = dailyData.values
        .expand((v) => [v[EventType.work]!, v[EventType.study]!, v[EventType.play]!])
        .fold<int>(0, math.max);
    final chartMax = math.max(480, ((overallMax + 59) ~/ 60) * 60).toDouble();

    return DefaultTabController(
      length: sortedDates.length,
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('统计'),
          bottom: TabBar(
            isScrollable: true,
            tabs: sortedDates.map((date) => Tab(text: date)).toList(),
          ),
        ),
        body: TabBarView(
          children: sortedDates.map((date) {
            final data = dailyData[date]!;
            final workMin = data[EventType.work]!;
            final studyMin = data[EventType.study]!;
            final playMin = data[EventType.play]!;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '总时长: $totalHours 小时 $remainingMinutes 分钟',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        minY: 0,
                        maxY: chartMax,
                        barGroups: [
                          BarChartGroupData(
                            x: 0,
                            barRods: [
                              BarChartRodData(
                                toY: workMin.toDouble(),
                                color: Colors.blue,
                                width: 20,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 1,
                            barRods: [
                              BarChartRodData(
                                toY: studyMin.toDouble(),
                                color: Colors.green,
                                width: 20,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                          BarChartGroupData(
                            x: 2,
                            barRods: [
                              BarChartRodData(
                                toY: playMin.toDouble(),
                                color: Colors.orange,
                                width: 20,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        ],
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final labels = ['工作', '学习', '玩'];
                                final index = value.toInt();
                                if (index >= 0 && index < labels.length) {
                                  return Text(
                                    labels[index],
                                    style: const TextStyle(fontSize: 12),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 60,
                              reservedSize: 40,
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
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 60,
                        ),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(enabled: false),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
