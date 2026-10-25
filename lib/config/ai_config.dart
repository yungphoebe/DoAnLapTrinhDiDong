class AIConfig {
  static const String baseUrl = String.fromEnvironment(
    'LM_STUDIO_URL',
    defaultValue: 'http://127.0.0.1:1234/v1',
  );

  static const String visionModelId = String.fromEnvironment(
    'LM_STUDIO_VISION_MODEL',
    defaultValue: 'qwen/qwen3.5-9b',
  );
}
