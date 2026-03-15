class SyncSettings {
  const SyncSettings({
    required this.serverUrl,
    required this.username,
    required this.password,
  });

  final String serverUrl;
  final String username;
  final String password;

  bool get isConfigured =>
      serverUrl.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.trim().isNotEmpty;

  SyncSettings copyWith({
    String? serverUrl,
    String? username,
    String? password,
  }) {
    return SyncSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  static const empty = SyncSettings(
    serverUrl: '',
    username: '',
    password: '',
  );
}
