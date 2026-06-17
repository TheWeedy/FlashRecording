import 'package:flutter/material.dart';

import '../app_info.dart';
import '../models/ai_settings.dart';
import '../models/sync_settings.dart';
import '../theme/app_theme.dart';
import '../utils/ai_settings_service.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Server configuration saved.')),
    );
  }

  Future<void> _saveAiSettings() async {
    await _aiSettingsService.save(_currentAiSettings);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('AI configuration saved.')));
  }

  Future<void> _loginOrAskRegister() async {
    final settings = _currentSettings;
    if (!settings.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the server URL, username, and password first.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _authService.login(settings);
      await _applyLoginSuccess(
        settings,
        result,
        successMessage: 'Signed in. Automatic sync is active.',
      );
    } on PocketBaseCredentialException {
      if (!mounted) {
        return;
      }
      final shouldRegister =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Sign-in failed'),
              content: Text(
                'The username "${settings.username.trim()}" may not exist yet, or the password is incorrect. Create the account and sign in?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Create account'),
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
        successMessage: 'Account created. Automatic sync is active.',
      );
    } on PocketBaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on CloudSyncException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
    ).showSnackBar(const SnackBar(content: Text('Signed out.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = _session;
    final isLoggedIn = session?.isLoggedIn ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            8,
            AppTheme.pagePadding,
            28,
          ),
          children: [
            const PageIntro(
              eyebrow: 'Control panel',
              title: 'Sync settings',
              description:
                  'Connect PocketBase when you want this local workspace to follow you across devices.',
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
                              isLoggedIn ? 'Sync online' : 'Sync not connected',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isLoggedIn
                                  ? 'Signed in as ${session?.username ?? ''}'
                                  : 'Sign in to upload local changes and pull the latest snapshot.',
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
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: '47.100.10.10:8090 or https://example.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
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
                          child: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _loginOrAskRegister,
                          child: Text(
                            _isSubmitting ? 'Connecting...' : 'Connect',
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
                        label: const Text('Sign out'),
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
                              'AI service',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Default provider is DeepSeek. Used by Insights, Notes, and Tasks.',
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
                    decoration: const InputDecoration(
                      labelText: 'AI Base URL',
                      hintText: AiSettings.defaultBaseUrl,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _aiModelController,
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      hintText: AiSettings.defaultModel,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _aiApiKeyController,
                    obscureText: _obscureAiApiKey,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      suffixIcon: IconButton(
                        tooltip: _obscureAiApiKey
                            ? 'Show API key'
                            : 'Hide API key',
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
                      label: const Text('Save AI settings'),
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
                title: const Text('Version'),
                subtitle: const Text(appVersion),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
