import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sync_settings.dart';

class PocketBaseAuthResult {
  const PocketBaseAuthResult({
    required this.serverUrl,
    required this.username,
    required this.userId,
  });

  final String serverUrl;
  final String username;
  final String userId;
}

class PocketBaseSession {
  const PocketBaseSession({
    required this.serverUrl,
    required this.username,
    required this.isLoggedIn,
    this.userId,
  });

  final String serverUrl;
  final String username;
  final String? userId;
  final bool isLoggedIn;
}

class PocketBaseAuthException implements Exception {
  const PocketBaseAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PocketBaseCredentialException extends PocketBaseAuthException {
  const PocketBaseCredentialException()
      : super('用户名不存在或密码不正确');
}

class PocketBaseUserNotFoundException extends PocketBaseAuthException {
  const PocketBaseUserNotFoundException() : super('该用户尚未注册');
}

class PocketBaseAuthService {
  static const _authStoreKey = 'pb_auth';

  Future<PocketBase> createClient(String serverUrl) async {
    final normalizedUrl = normalizeServerUrl(serverUrl);
    final prefs = await SharedPreferences.getInstance();
    final authStore = AsyncAuthStore(
      save: (String data) async => prefs.setString(_authStoreKey, data),
      initial: prefs.getString(_authStoreKey),
    );
    return PocketBase(
      normalizedUrl,
      authStore: authStore,
    );
  }

  Future<PocketBaseSession> loadSession(SyncSettings settings) async {
    if (!settings.isConfigured) {
      return const PocketBaseSession(
        serverUrl: '',
        username: '',
        isLoggedIn: false,
      );
    }

    final pb = await createClient(settings.serverUrl);
    final record = pb.authStore.record;
    return PocketBaseSession(
      serverUrl: normalizeServerUrl(settings.serverUrl),
      username: settings.username.trim(),
      userId: record?.id,
      isLoggedIn: pb.authStore.isValid,
    );
  }

  Future<PocketBaseAuthResult> login(SyncSettings settings) async {
    final normalizedUrl = normalizeServerUrl(settings.serverUrl);
    final username = settings.username.trim();
    final password = settings.password;

    if (normalizedUrl.isEmpty || username.isEmpty || password.isEmpty) {
      throw const PocketBaseAuthException('请先完整填写服务器地址、用户名和密码');
    }

    final pb = await createClient(normalizedUrl);
    final identity = identityFromUsername(username);

    try {
      final authData = await pb.collection('users').authWithPassword(
            identity,
            password,
          );
      return PocketBaseAuthResult(
        serverUrl: normalizedUrl,
        username: username,
        userId: authData.record.id,
      );
    } on ClientException catch (error) {
      throw _mapLoginException(error);
    }
  }

  Future<PocketBaseAuthResult> registerAndLogin(SyncSettings settings) async {
    final normalizedUrl = normalizeServerUrl(settings.serverUrl);
    final username = settings.username.trim();
    final password = settings.password;
    final pb = await createClient(normalizedUrl);
    final identity = identityFromUsername(username);

    try {
      final created = await pb.collection('users').create(
        body: {
          'username': username,
          'email': identity,
          'emailVisibility': false,
          'password': password,
          'passwordConfirm': password,
        },
      );
      await pb.collection('users').authWithPassword(identity, password);
      return PocketBaseAuthResult(
        serverUrl: normalizedUrl,
        username: username,
        userId: created.id,
      );
    } on ClientException catch (error) {
      throw _mapRegisterException(error);
    }
  }

  Future<void> logout(String serverUrl) async {
    final pb = await createClient(serverUrl);
    pb.authStore.clear();
  }

  String normalizeServerUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final withScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed
            : 'http://$trimmed';
    return withScheme.endsWith('/')
        ? withScheme.substring(0, withScheme.length - 1)
        : withScheme;
  }

  String identityFromUsername(String username) {
    final normalized =
        username.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    return '$normalized@recordmytime.local';
  }

  PocketBaseAuthException _mapLoginException(ClientException error) {
    final message = _extractMessage(error).toLowerCase();
    if (error.statusCode == 0) {
      return const PocketBaseAuthException('无法连接到服务器，请检查地址和网络');
    }
    if (error.statusCode == 404 && message.contains('users')) {
      return const PocketBaseAuthException('服务器未正确配置 users 认证集合');
    }
    if (error.statusCode == 400 || error.statusCode == 401) {
      return const PocketBaseCredentialException();
    }
    if (message.contains('failed to authenticate') ||
        message.contains('invalid login credentials')) {
      return const PocketBaseCredentialException();
    }
    final extracted = _extractMessage(error);
    if (extracted.isNotEmpty) {
      return PocketBaseAuthException(extracted);
    }
    return PocketBaseAuthException('登录失败（${error.statusCode}）');
  }

  PocketBaseAuthException _mapRegisterException(ClientException error) {
    final extracted = _extractMessage(error);
    final message = extracted.toLowerCase();
    if (error.statusCode == 0) {
      return const PocketBaseAuthException('无法连接到服务器，请检查地址和网络');
    }
    if (error.statusCode == 404 && message.contains('users')) {
      return const PocketBaseAuthException('服务器未正确配置 users 认证集合');
    }
    if (message.contains('already') ||
        message.contains('unique') ||
        message.contains('must be unique')) {
      return const PocketBaseAuthException('该用户名已存在，请直接登录或检查密码');
    }
    if (message.contains('password')) {
      return const PocketBaseAuthException('密码不符合服务器要求，请换一个更复杂的密码');
    }
    if (message.contains('email')) {
      return const PocketBaseAuthException('注册邮箱字段校验失败，请检查服务器 users 配置');
    }
    if (extracted.isNotEmpty) {
      return PocketBaseAuthException(extracted);
    }
    return PocketBaseAuthException('注册失败（${error.statusCode}）');
  }

  String _extractMessage(ClientException error) {
    final response = error.response;
    if (response.isEmpty) {
      return '';
    }
    final topLevel = response['message'];
    if (topLevel is String && topLevel.trim().isNotEmpty) {
      return topLevel.trim();
    }
    final data = response['data'];
    if (data is Map) {
      final messages = <String>[];
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is Map && value['message'] is String) {
          final fieldMessage = '${entry.key}: ${(value['message'] as String).trim()}';
          messages.add(fieldMessage);
        }
      }
      if (messages.isNotEmpty) {
        return messages.join('；');
      }
    }
    return '';
  }
}
