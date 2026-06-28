/// API constants for HidePulsa AI service
class ApiConstants {
  static const String baseUrl = 'https://ai.hidepulsa.com/v1';
  static const String chatCompletionsEndpoint = '$baseUrl/chat/completions';
  static const String modelsEndpoint = '$baseUrl/models';

  /// Default model - Claude Sonnet 4.5 (best quality like Kiro)
  static const String defaultModel = 'kr/claude-sonnet-4.5';

  /// Auto mode: rotates between best models
  static const String autoModelId = 'auto';

  /// Models to use in auto mode (picks best available)
  static const List<String> autoModelPriority = [
    'kr/claude-sonnet-4.5',
    'kr/claude-sonnet-4',
    'ag/claude-sonnet-4-6',
    'abb/deepseek-v4-pro',
    'kr/claude-haiku-4.5',
  ];
}
