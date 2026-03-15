import 'package:shared_preferences/shared_preferences.dart';

import '../models/sync_settings.dart';

class SyncSettingsService {
  static const _serverUrlKey = 'sync_server_url';
  static const _usernameKey = 'sync_username';
  static const _passwordKey = 'sync_password';
  static const _syncDirtyKey = 'sync_local_dirty';
  static const _lastLocalChangeAtKey = 'sync_last_local_change_at';

  Future<SyncSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SyncSettings(
      serverUrl: prefs.getString(_serverUrlKey) ?? '',
      username: prefs.getString(_usernameKey) ?? '',
      password: prefs.getString(_passwordKey) ?? '',
    );
  }

  Future<void> save(SyncSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, settings.serverUrl.trim());
    await prefs.setString(_usernameKey, settings.username.trim());
    await prefs.setString(_passwordKey, settings.password);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverUrlKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
  }

  Future<void> markLocalDirty() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncDirtyKey, true);
    await prefs.setString(
      _lastLocalChangeAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> clearLocalDirty() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncDirtyKey, false);
  }

  Future<bool> isLocalDirty() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncDirtyKey) ?? false;
  }

  Future<DateTime?> loadLastLocalChangeAt() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_lastLocalChangeAtKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
