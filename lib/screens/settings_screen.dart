import 'package:flutter/material.dart';

import '../app_info.dart';
import '../models/ai_settings.dart';
import '../models/sync_settings.dart';
import '../theme/app_theme.dart';
import '../utils/ai_settings_service.dart';
import '../utils/app_localizations.dart';
import '../utils/app_preferences_service.dart';
import '../utils/cloud_sync_service.dart';
import '../utils/pocketbase_auth_service.dart';
import '../utils/sync_settings_service.dart';
import '../widgets/app_components.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SyncSettingsService _settingsService = SyncSettingsService();
  final AiSettingsService _aiSettingsService = AiSettingsService();
  final AppPreferencesService _preferencesService =
      AppPreferencesService.instance;
  final PocketBaseAuthService _authService = PocketBaseAuthService();

  late final TextEditingController _serverController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _aiBaseUrlController;
  late final TextEditingController _aiApiKeyController;
  late final TextEditingController _aiModelController;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureAiApiKey = true;
  PocketBaseSession? _session;
  AppPreferences _preferences = const AppPreferences(
    interfaceLanguageMode: InterfaceLanguageMode.chinese,
  );

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _aiBaseUrlController = TextEditingController();
    _aiApiKeyController = TextEditingController();
    _aiModelController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _aiBaseUrlController.dispose();
    _aiApiKeyController.dispose();
    _aiModelController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.load();
    final aiSettings = await _aiSettingsService.load();
    final preferences = await _preferencesService.load();
    final session = await _authService.loadSession(settings);
    if (!mounted) {
      return;
    }
    setState(() {
      _serverController.text = settings.serverUrl;
      _usernameController.text = settings.username;
      _passwordController.text = settings.password;
      _aiBaseUrlController.text = aiSettings.baseUrl;
      _aiApiKeyController.text = aiSettings.apiKey;
      _aiModelController.text = aiSettings.model;
      _preferences = preferences;
      _session = session;
      _isLoading = false;
    });
  }

  SyncSettings get _currentSettings => SyncSettings(
    serverUrl: _serverController.text,
    username: _usernameController.text,
    password: _passwordController.text,
  );

  AiSettings get _currentAiSettings => AiSettings(
    baseUrl: _aiBaseUrlController.text,
    apiKey: _aiApiKeyController.text,
    model: _aiModelController.text,
  );

  Future<void> _saveOnly() async {
    await _settingsService.save(_currentSettings);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.serverConfigSaved)));
  }

  Future<void> _saveAiSettings() async {
    await _aiSettingsService.save(_currentAiSettings);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.aiConfigSaved)));
  }

  Future<void> _savePreferences(AppPreferences preferences) async {
    await _preferencesService.save(preferences);
    if (!mounted) {
      return;
    }
    setState(() {
      _preferences = preferences;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.preferencesSaved)));
  }

  Future<void> _loginOrAskRegister() async {
    final l10n = context.l10n;
    final settings = _currentSettings;
    if (!settings.isConfigured) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.enterServerFirst)));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _authService.login(settings);
      await _applyLoginSuccess(settings, result, successMessage: l10n.signedIn);
    } on PocketBaseCredentialException {
      if (!mounted) {
        return;
      }
      final shouldRegister =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.signInFailed),
              content: Text(l10n.signInFailedBody(settings.username.trim())),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.createAccount),
                ),
              ],
            ),
          ) ??
          false;

      if (!shouldRegister) {
        return;
      }

      final result = await _authService.registerAndLogin(settings);
      await _applyLoginSuccess(
        settings,
        result,
        successMessage: l10n.accountCreated,
      );
    } on PocketBaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.localizeError(error.message))),
      );
    } on CloudSyncException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.localizeError(error.message))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _applyLoginSuccess(
    SyncSettings settings,
    PocketBaseAuthResult result, {
    required String successMessage,
  }) async {
    final normalizedSettings = settings.copyWith(serverUrl: result.serverUrl);
    await _settingsService.save(normalizedSettings);
    await CloudSyncService.instance.syncNow(throwOnError: true);
    final session = await _authService.loadSession(normalizedSettings);
    if (!mounted) {
      return;
    }
    setState(() {
      _serverController.text = result.serverUrl;
      _session = session;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  }

  Future<void> _logout() async {
    final settings = _currentSettings;
    if (settings.serverUrl.trim().isNotEmpty) {
      await _authService.logout(settings.serverUrl);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _session = PocketBaseSession(
        serverUrl: settings.serverUrl.trim(),
        username: settings.username.trim(),
        isLoggedIn: false,
      );
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.signedOut)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = _session;
    final isLoggedIn = session?.isLoggedIn ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            8,
            AppTheme.pagePadding,
            28,
          ),
          children: [
            PageIntro(
              eyebrow: context.l10n.ui('控制面板', 'Control panel', 'コントロールパネル'),
              title: context.l10n.syncSettingsTitle,
              description: context.l10n.syncSettingsDescription,
            ),
            const SizedBox(height: 18),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isLoggedIn
                              ? AppTheme.primarySoft
                              : AppTheme.copperSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Icon(
                          isLoggedIn
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                          color: isLoggedIn
                              ? AppTheme.primary
                              : AppTheme.copper,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isLoggedIn
                                  ? context.l10n.syncOnline
                                  : context.l10n.syncNotConnected,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isLoggedIn
                                  ? context.l10n.signedInAs(
                                      session?.username ?? '',
                                    )
                                  : context.l10n.syncNotConnectedBody,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.muted,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if ((session?.serverUrl ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    AppChip(
                      icon: Icons.dns_outlined,
                      label: session!.serverUrl,
                      color: AppTheme.steel,
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextField(
                    controller: _serverController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: context.l10n.serverUrl,
                      hintText: '47.100.10.10:8090 or https://example.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.username,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: context.l10n.password,
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? context.l10n.showPassword
                            : context.l10n.hidePassword,
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting ? null : _saveOnly,
                          child: Text(context.l10n.save),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _loginOrAskRegister,
                          child: Text(
                            _isSubmitting
                                ? context.l10n.connecting
                                : context.l10n.connect,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isLoggedIn) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _isSubmitting ? null : _logout,
                        icon: const Icon(Icons.logout),
                        label: Text(context.l10n.signOut),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.steelSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.tune_outlined,
                          color: AppTheme.steel,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.interfaceLanguage,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.l10n.interfaceLanguageBody,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.muted,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.interfaceLanguage,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<InterfaceLanguageMode>(
                    segments: [
                      ButtonSegment(
                        value: InterfaceLanguageMode.chinese,
                        label: Text(context.l10n.chineseUi),
                      ),
                      ButtonSegment(
                        value: InterfaceLanguageMode.english,
                        label: Text(context.l10n.englishUi),
                      ),
                      ButtonSegment(
                        value: InterfaceLanguageMode.japanese,
                        label: Text(context.l10n.japaneseUi),
                      ),
                    ],
                    selected: {_preferences.interfaceLanguageMode},
                    onSelectionChanged: (selection) {
                      _savePreferences(
                        _preferences.copyWith(
                          interfaceLanguageMode: selection.first,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primarySoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_outlined,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.aiService,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.l10n.aiServiceBody,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.muted,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _aiBaseUrlController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: context.l10n.aiBaseUrl,
                      hintText: AiSettings.defaultBaseUrl,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _aiModelController,
                    decoration: InputDecoration(
                      labelText: context.l10n.model,
                      hintText: AiSettings.defaultModel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _aiApiKeyController,
                    obscureText: _obscureAiApiKey,
                    decoration: InputDecoration(
                      labelText: context.l10n.apiKey,
                      suffixIcon: IconButton(
                        tooltip: _obscureAiApiKey
                            ? context.l10n.showApiKey
                            : context.l10n.hideApiKey,
                        onPressed: () {
                          setState(() {
                            _obscureAiApiKey = !_obscureAiApiKey;
                          });
                        },
                        icon: Icon(
                          _obscureAiApiKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saveAiSettings,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(context.l10n.saveAiSettings),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppPanel(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.info_outline,
                  color: AppTheme.primary,
                ),
                title: Text(context.l10n.version),
                subtitle: const Text(appVersion),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
