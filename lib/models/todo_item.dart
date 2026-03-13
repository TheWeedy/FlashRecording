import 'package:flutter/material.dart';

class TodoItem {
  final String id;
  final String title;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime? archivedAt;
  final int totalCount;
  final int totalDurationMinutes;
  final int colorValue;

  const TodoItem({
    required this.id,
    required this.title,
    required this.isSystem,
    required this.createdAt,
    required this.totalCount,
    required this.totalDurationMinutes,
    required this.colorValue,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  Color get color => Color(colorValue);

  String get summaryLabel {
    final hours = totalDurationMinutes ~/ 60;
    final minutes = totalDurationMinutes % 60;
    final durationLabel = hours == 0
        ? '$minutes 分钟'
        : minutes == 0
            ? '$hours 小时'
            : '$hours 小时 $minutes 分钟';
    return '$totalCount 次 · $durationLabel';
  }
}
