class TodoItem {
  final String id;
  final String title;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime? archivedAt;
  final int totalCount;
  final int totalDurationMinutes;

  const TodoItem({
    required this.id,
    required this.title,
    required this.isSystem,
    required this.createdAt,
    required this.totalCount,
    required this.totalDurationMinutes,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

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
