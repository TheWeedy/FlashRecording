import 'package:shared_preferences/shared_preferences.dart';

import '../models/sync_settings.dart';

class SyncSettingsService {
  static const _serverUrlKey = 'sync_server_url';
  static const _usernameKey = 'sync_username';
  static const _passwordKey = 'sync_password';

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
}
