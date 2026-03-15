import 'package:flutter/material.dart';

import '../app_info.dart';
import '../models/sync_settings.dart';
import '../utils/cloud_sync_service.dart';
import '../utils/pocketbase_auth_service.dart';
import '../utils/sync_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SyncSettingsService _settingsService = SyncSettingsService();
  final PocketBaseAuthService _authService = PocketBaseAuthService();

  late final TextEditingController _serverController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  PocketBaseSession? _session;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.load();
    final session = await _authService.loadSession(settings);
    if (!mounted) {
      return;
    }
    setState(() {
      _serverController.text = settings.serverUrl;
      _usernameController.text = settings.username;
      _passwordController.text = settings.password;
      _session = session;
      _isLoading = false;
    });
  }

  SyncSettings get _currentSettings => SyncSettings(
        serverUrl: _serverController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );

  Future<void> _saveOnly() async {
    await _settingsService.save(_currentSettings);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('服务器配置已保存')),
    );
  }

  Future<void> _loginOrAskRegister() async {
    final settings = _currentSettings;
    if (!settings.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先完整填写服务器地址、用户名和密码')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _authService.login(settings);
      await _applyLoginSuccess(settings, result, successMessage: '登录成功，自动同步已开启');
    } on PocketBaseCredentialException {
      if (!mounted) {
        return;
      }
      final shouldRegister = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('登录失败'),
              content: Text('用户名“${settings.username.trim()}”可能尚未注册，或密码不正确。是否尝试注册并登录？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('注册'),
                ),
              ],
            ),
          ) ??
          false;

      if (!shouldRegister) {
        return;
      }

      final result = await _authService.registerAndLogin(settings);
      await _applyLoginSuccess(settings, result, successMessage: '注册成功，自动同步已开启');
    } on PocketBaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on CloudSyncException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage)),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已退出登录')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final session = _session;
    final isLoggedIn = session?.isLoggedIn ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '云同步',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isLoggedIn
                        ? '已登录：${session?.username ?? ''}'
                        : '未登录。登录后会自动同步，若用户不存在会先询问是否注册。',
                    style: TextStyle(
                      color: isLoggedIn ? Colors.green.shade700 : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '当前版本默认开启自动同步。',
                    style: TextStyle(color: Colors.black54),
                  ),
                  if ((session?.serverUrl ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '服务器：${session!.serverUrl}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _serverController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      hintText: '例如 47.100.10.10:8090 或 https://example.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: '密码',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
                          child: const Text('保存配置'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSubmitting ? null : _loginOrAskRegister,
                          child: Text(_isSubmitting ? '连接中...' : '连接并登录'),
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
                        label: const Text('退出登录'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('版本号'),
              subtitle: const Text(appVersion),
            ),
          ),
        ],
      ),
    );
  }
}
