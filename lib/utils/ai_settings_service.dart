import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_settings.dart';

class AiSettingsService {
  static const _baseUrlKey = 'ai_base_url';
  static const _apiKeyKey = 'ai_api_key';
  static const _modelKey = 'ai_model';

  Future<AiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AiSettings(
      baseUrl: prefs.getString(_baseUrlKey) ?? AiSettings.defaultBaseUrl,
      apiKey: prefs.getString(_apiKeyKey) ?? '',
      model: prefs.getString(_modelKey) ?? AiSettings.defaultModel,
    );
  }

  Future<void> save(AiSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _baseUrlKey,
      settings.baseUrl.trim().isEmpty
          ? AiSettings.defaultBaseUrl
          : settings.baseUrl.trim(),
    );
    await prefs.setString(_apiKeyKey, settings.apiKey.trim());
    await prefs.setString(
      _modelKey,
      settings.model.trim().isEmpty
          ? AiSettings.defaultModel
          : settings.model.trim(),
    );
  }
}
