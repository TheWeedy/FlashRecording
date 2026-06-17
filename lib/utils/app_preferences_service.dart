import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum InterfaceLanguageMode { chinese, english, japanese }

class AppPreferences {
  const AppPreferences({required this.interfaceLanguageMode});

  final InterfaceLanguageMode interfaceLanguageMode;

  AppPreferences copyWith({InterfaceLanguageMode? interfaceLanguageMode}) {
    return AppPreferences(
      interfaceLanguageMode:
          interfaceLanguageMode ?? this.interfaceLanguageMode,
    );
  }
}

class AppPreferencesService {
  AppPreferencesService._();

  static final AppPreferencesService instance = AppPreferencesService._();

  static const _languageKey = 'interface_language_mode';

  final ValueNotifier<AppPreferences> notifier = ValueNotifier<AppPreferences>(
    const AppPreferences(interfaceLanguageMode: InterfaceLanguageMode.chinese),
  );

  Future<AppPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawLanguage = prefs.getString(_languageKey);
    final loaded = AppPreferences(
      interfaceLanguageMode: InterfaceLanguageMode.values.firstWhere(
        (mode) => mode.name == rawLanguage,
        orElse: () => rawLanguage == 'mixed'
            ? InterfaceLanguageMode.english
            : InterfaceLanguageMode.chinese,
      ),
    );
    notifier.value = loaded;
    return loaded;
  }

  Future<void> save(AppPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, preferences.interfaceLanguageMode.name);
    notifier.value = preferences;
  }
}

class AppStrings {
  const AppStrings(this.mode);

  final InterfaceLanguageMode mode;

  String label({required String zh, required String en, String? mixed}) {
    switch (mode) {
      case InterfaceLanguageMode.chinese:
        return zh;
      case InterfaceLanguageMode.english:
        return en;
      case InterfaceLanguageMode.japanese:
        return mixed ?? en;
    }
  }
}
