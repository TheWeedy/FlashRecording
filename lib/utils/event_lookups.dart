import 'package:flutter/material.dart';

import '../models/time_event.dart';
import '../theme/app_theme.dart';
import 'todo_persistence.dart';

class EventLookups {
  EventLookups(this._todoColorMap);

  final Map<String, Color> _todoColorMap;

  static Future<EventLookups> load() async {
    final colorMap = await TodoPersistenceService().loadTodoColorMap();
    return EventLookups(colorMap);
  }

  Color colorForEvent(TimeEvent event) {
    return _todoColorMap[event.linkedTodoId] ??
        switch (event.type) {
          EventType.work => AppTheme.steel,
          EventType.study => AppTheme.success,
          EventType.play => AppTheme.copper,
        };
  }

  String tagForEvent(TimeEvent event, String Function(String) l10nLookup) {
    switch (event.linkedTodoId) {
      case 'system-work':
        return l10nLookup('work');
      case 'system-study':
        return l10nLookup('study');
      case 'system-play':
        return l10nLookup('leisure');
      default:
        return event.linkedTodoTitle ?? l10nLookup('noTag');
    }
  }
}
