class AppConfig {
  static const String githubOwner = 'italofvm';
  static const String githubRepo = 'lumen-reader';

  static const String defaultAiProxyUrl = 'https://lumen-reader.onrender.com';

  static const String _aiProxyUrlEnv = String.fromEnvironment(
    'AI_PROXY_URL',
    defaultValue: '',
  );

  static String get aiProxyUrl {
    final v = _aiProxyUrlEnv.trim();
    return v.isNotEmpty ? v : defaultAiProxyUrl;
  }
}
