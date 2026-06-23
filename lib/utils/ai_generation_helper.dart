import 'package:flutter/material.dart';

import '../utils/ai_service.dart';
import '../utils/app_localizations.dart';

class AiGenerationHelper {
  static Future<String?> generate({
    required BuildContext context,
    required AiService aiService,
    required String systemPrompt,
    required String userPrompt,
    required void Function(bool isLoading) setLoading,
    required bool mounted,
  }) async {
    setLoading(true);
    try {
      final result = await aiService.complete(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );
      if (!mounted) {
        return null;
      }
      return result;
    } on AiServiceException catch (error) {
      if (!mounted) {
        return null;
      }
      final messenger = ScaffoldMessenger.of(context);
      final message = context.l10n.localizeError(error.message);
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return null;
    } finally {
      if (mounted) {
        setLoading(false);
      }
    }
  }
}
