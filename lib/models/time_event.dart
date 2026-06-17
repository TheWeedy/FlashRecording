enum EventType { work, study, play }

enum EventRecordMode { duration, count }

class TimeEvent {
  final String id;
  final int hours;
  final int minutes;
  final String description;
  final String note;
  final DateTime addedAt;
  final EventType type;
  final String? linkedTodoId;
  final String? linkedTodoTitle;
  final EventRecordMode recordMode;

  TimeEvent({
    required this.id,
    required this.hours,
    required this.minutes,
    required this.description,
    this.note = '',
    required this.addedAt,
    required this.type,
    this.linkedTodoId,
    this.linkedTodoTitle,
    this.recordMode = EventRecordMode.duration,
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
    'linkedTodoId': linkedTodoId,
    'linkedTodoTitle': linkedTodoTitle,
    'recordMode': recordMode.name,
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
      linkedTodoId: json['linkedTodoId'] as String?,
      linkedTodoTitle: json['linkedTodoTitle'] as String?,
      recordMode: EventRecordMode.values.firstWhere(
        (mode) => mode.name == (json['recordMode'] as String? ?? 'duration'),
        orElse: () => EventRecordMode.duration,
      ),
    );
  }

  String get displayDuration {
    if (recordMode == EventRecordMode.count) {
      return '1 time';
    }

    if (hours == 0 && minutes == 0) {
      return '0 min';
    }
    final parts = <String>[];
    if (hours > 0) {
      parts.add('$hours hr');
    }
    if (minutes > 0) {
      parts.add('$minutes min');
    }
    return parts.join(' ');
  }

  String get typeName {
    switch (type) {
      case EventType.work:
        return 'Work';
      case EventType.study:
        return 'Study';
      case EventType.play:
        return 'Leisure';
    }
  }

  String get recordModeName =>
      recordMode == EventRecordMode.count ? 'Count' : 'Duration';
}
