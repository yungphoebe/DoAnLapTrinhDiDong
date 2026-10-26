class AIConfig {
  static const String baseUrl = String.fromEnvironment(
    'LM_STUDIO_URL',
    defaultValue: 'http://127.0.0.1:1234/v1',
  );
}
