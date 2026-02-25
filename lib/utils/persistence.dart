import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/time_event.dart';

class PersistenceService {
  static const String _key = 'events';

  Future<List<TimeEvent>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key) ?? '[]';
    final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
    return jsonList
        .map((e) => TimeEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveEvents(List<TimeEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(events.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }
}