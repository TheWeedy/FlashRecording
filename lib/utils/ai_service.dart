import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/ai_settings.dart';
import 'ai_settings_service.dart';

class AiServiceException implements Exception {
  const AiServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiService {
  AiService({AiSettingsService? settingsService})
    : _settingsService = settingsService ?? AiSettingsService();

  final AiSettingsService _settingsService;

  Future<bool> isConfigured() async {
    final settings = await _settingsService.load();
    return settings.isConfigured;
  }

  Future<String> complete({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final settings = await _settingsService.load();
    if (!settings.isConfigured) {
      throw const AiServiceException('Add an AI API key in Settings first.');
    }

    final uri = _completionUri(settings.baseUrl);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);

    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 20));
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${settings.apiKey}',
      );
      request.write(
        jsonEncode({
          'model': settings.model.trim().isEmpty
              ? AiSettings.defaultModel
              : settings.model.trim(),
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.4,
          'stream': false,
        }),
      );

      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiServiceException(_extractError(body, response.statusCode));
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>? ?? [];
      if (choices.isEmpty) {
        throw const AiServiceException('AI returned no content.');
      }
      final message = choices.first as Map<String, dynamic>;
      final content =
          (message['message'] as Map<String, dynamic>?)?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw const AiServiceException('AI returned an empty response.');
      }
      return content.trim();
    } on TimeoutException {
      throw const AiServiceException('AI request timed out. Try again later.');
    } on SocketException {
      throw const AiServiceException('Could not reach the AI service.');
    } on FormatException {
      throw const AiServiceException('AI service returned invalid data.');
    } finally {
      client.close(force: true);
    }
  }

  Uri _completionUri(String baseUrl) {
    final normalized = baseUrl.trim().isEmpty
        ? AiSettings.defaultBaseUrl
        : baseUrl.trim();
    final uri = Uri.parse(normalized);
    if (uri.path.endsWith('/chat/completions')) {
      return uri;
    }
    final path = uri.path.endsWith('/')
        ? '${uri.path}chat/completions'
        : '${uri.path}/chat/completions';
    return uri.replace(path: path);
  }

  String _extractError(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    } on FormatException {
      // Fall through to the generic status message.
    }
    return 'AI request failed with status $statusCode.';
  }
}
