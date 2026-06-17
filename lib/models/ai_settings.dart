class AiSettings {
  const AiSettings({
    this.baseUrl = defaultBaseUrl,
    this.apiKey = '',
    this.model = defaultModel,
  });

  static const defaultBaseUrl = 'https://api.deepseek.com';
  static const defaultModel = 'deepseek-chat';

  final String baseUrl;
  final String apiKey;
  final String model;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  AiSettings copyWith({String? baseUrl, String? apiKey, String? model}) {
    return AiSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }
}
