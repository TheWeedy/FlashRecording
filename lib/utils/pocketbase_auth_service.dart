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
    : super('The username does not exist or the password is incorrect.');
}

class PocketBaseUserNotFoundException extends PocketBaseAuthException {
  const PocketBaseUserNotFoundException()
    : super('This user is not registered yet.');
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
    return PocketBase(normalizedUrl, authStore: authStore);
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
    final username = settings.username.trim();
    if (pb.authStore.isValid && !_recordMatchesUsername(record, username)) {
      pb.authStore.clear();
      return PocketBaseSession(
        serverUrl: normalizeServerUrl(settings.serverUrl),
        username: username,
        isLoggedIn: false,
      );
    }
    return PocketBaseSession(
      serverUrl: normalizeServerUrl(settings.serverUrl),
      username: username,
      userId: record?.id,
      isLoggedIn: pb.authStore.isValid,
    );
  }

  Future<PocketBaseAuthResult> login(SyncSettings settings) async {
    final normalizedUrl = normalizeServerUrl(settings.serverUrl);
    final username = settings.username.trim();
    final password = settings.password;

    if (normalizedUrl.isEmpty || username.isEmpty || password.isEmpty) {
      throw const PocketBaseAuthException(
        'Enter the server URL, username, and password first.',
      );
    }

    final pb = await createClient(normalizedUrl);
    final identity = identityFromUsername(username);

    try {
      final authData = await pb
          .collection('users')
          .authWithPassword(identity, password);
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
      final created = await pb
          .collection('users')
          .create(
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
    final normalized = username.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '_',
    );
    return '$normalized@recordmytime.local';
  }

  bool _recordMatchesUsername(RecordModel? record, String username) {
    if (record == null) {
      return false;
    }
    final expectedEmail = identityFromUsername(username).toLowerCase();
    final email = '${record.data['email'] ?? ''}'.trim().toLowerCase();
    final recordUsername = '${record.data['username'] ?? ''}'
        .trim()
        .toLowerCase();
    final normalizedUsername = username.trim().toLowerCase();
    return email == expectedEmail || recordUsername == normalizedUsername;
  }

  PocketBaseAuthException _mapLoginException(ClientException error) {
    final message = _extractMessage(error).toLowerCase();
    if (error.statusCode == 0) {
      return const PocketBaseAuthException(
        'Could not reach the server. Check the URL and network.',
      );
    }
    if (error.statusCode == 404 && message.contains('users')) {
      return const PocketBaseAuthException(
        'The users auth collection is not configured on the server.',
      );
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
    return PocketBaseAuthException('Login failed (${error.statusCode})');
  }

  PocketBaseAuthException _mapRegisterException(ClientException error) {
    final extracted = _extractMessage(error);
    final message = extracted.toLowerCase();
    if (error.statusCode == 0) {
      return const PocketBaseAuthException(
        'Could not reach the server. Check the URL and network.',
      );
    }
    if (error.statusCode == 404 && message.contains('users')) {
      return const PocketBaseAuthException(
        'The users auth collection is not configured on the server.',
      );
    }
    if (message.contains('already') ||
        message.contains('unique') ||
        message.contains('must be unique')) {
      return const PocketBaseAuthException(
        'This username already exists. Sign in or check the password.',
      );
    }
    if (message.contains('password')) {
      return const PocketBaseAuthException(
        'The password does not meet server requirements.',
      );
    }
    if (message.contains('email')) {
      return const PocketBaseAuthException(
        'The generated email failed validation. Check the users collection settings.',
      );
    }
    if (extracted.isNotEmpty) {
      return PocketBaseAuthException(extracted);
    }
    return PocketBaseAuthException('Registration failed (${error.statusCode})');
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
          final fieldMessage =
              '${entry.key}: ${(value['message'] as String).trim()}';
          messages.add(fieldMessage);
        }
      }
      if (messages.isNotEmpty) {
        return messages.join('; ');
      }
    }
    return '';
  }
}
