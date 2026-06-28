import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/hive_storage.dart';

/// Provider for API key stored in Hive
final apiKeyProvider = StateNotifierProvider<ApiKeyNotifier, String>((ref) {
  return ApiKeyNotifier();
});

class ApiKeyNotifier extends StateNotifier<String> {
  /// Default API key (loaded on first run)
  static const String _defaultApiKey =
      'sk-kr-hdsquNFhQkSiGt5koUnXsB37e3r7HL3L';

  ApiKeyNotifier() : super('') {
    _loadApiKey();
  }

  void _loadApiKey() {
    final stored = HiveStorage.settings.get('api_key', defaultValue: '') as String;
    if (stored.isEmpty) {
      // First run: use default key and persist it
      setApiKey(_defaultApiKey);
    } else {
      state = stored;
    }
  }

  void setApiKey(String key) {
    HiveStorage.settings.put('api_key', key);
    state = key;
  }

  void clearApiKey() {
    HiveStorage.settings.delete('api_key');
    state = '';
  }
}

/// Provider for the GitHub personal access token (stored in Hive).
final githubTokenProvider =
    StateNotifierProvider<GithubTokenNotifier, String>((ref) {
  return GithubTokenNotifier();
});

class GithubTokenNotifier extends StateNotifier<String> {
  GithubTokenNotifier() : super('') {
    state = HiveStorage.settings.get('github_token', defaultValue: '') as String;
  }

  void setToken(String token) {
    HiveStorage.settings.put('github_token', token);
    state = token;
  }
}
