enum TodoMetricType { count, duration }

class TodoItem {
  final String id;
  final String title;
  final TodoMetricType metricType;
  final int progressValue;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime? archivedAt;

  const TodoItem({
    required this.id,
    required this.title,
    required this.metricType,
    required this.progressValue,
    required this.isSystem,
    required this.createdAt,
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  String get metricLabel =>
      metricType == TodoMetricType.count ? '次数' : '时长';

  String get progressLabel {
    if (metricType == TodoMetricType.count) {
      return '$progressValue 次';
    }

    final hours = progressValue ~/ 60;
    final minutes = progressValue % 60;
    if (hours == 0) {
      return '$minutes 分钟';
    }
    if (minutes == 0) {
      return '$hours 小时';
    }
    return '$hours 小时 $minutes 分钟';
  }
}
