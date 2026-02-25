
enum EventType { work, study, play }

class TimeEvent {
  final String id;
  final int hours;
  final int minutes;
  final String description;
  final String note; // ← 新增备注字段
  final DateTime addedAt;
  final EventType type;

  TimeEvent({
    required this.id,
    required this.hours,
    required this.minutes,
    required this.description,
    this.note = '', // 默认空字符串
    required this.addedAt,
    required this.type,
  });

  int get totalMinutes => hours * 60 + minutes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'hours': hours,
    'minutes': minutes,
    'description': description,
    'note': note,
    'addedAt': addedAt.toIso8601String(),
    'type': type.name,
  };

  factory TimeEvent.fromJson(Map<String, dynamic> json) {
    return TimeEvent(
      id: json['id'] as String,
      hours: json['hours'] as int,
      minutes: json['minutes'] as int,
      description: json['description'] as String,
      note: json['note'] as String? ?? '',
      addedAt: DateTime.parse(json['addedAt'] as String),
      type: EventType.values.firstWhere((e) => e.name == json['type']),
    );
  }

  String get displayDuration {
    if (hours == 0 && minutes == 0) return '0分钟';
    final parts = <String>[];
    if (hours > 0) parts.add('$hours小时');
    if (minutes > 0) parts.add('$minutes分钟');
    return parts.join('');
  }

  String get typeName {
    switch (type) {
      case EventType.work:
        return '工作';
      case EventType.study:
        return '学习';
      case EventType.play:
        return '玩';
    }
  }
}