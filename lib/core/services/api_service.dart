import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

/// Service for communicating with HidePulsa AI API
/// Supports streaming (SSE) responses
class ApiService {
  final String apiKey;
  final http.Client _client;

  ApiService({required this.apiKey}) : _client = http.Client();

  /// Send a chat completion request with streaming enabled
  /// Returns a Stream of content chunks (token by token)
  /// Filters out <think>...</think> reasoning blocks from Qwen models
  Stream<String> streamChatCompletion({
    required List<Map<String, dynamic>> messages,
    String model = ApiConstants.defaultModel,
    double temperature = 0.7,
    int? maxTokens,
  }) async* {
    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'stream': true,
      if (maxTokens != null) 'max_tokens': maxTokens,
    });

    final request = http.Request(
      'POST',
      Uri.parse(ApiConstants.chatCompletionsEndpoint),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
      'Accept': 'text/event-stream',
    });
    request.body = body;

    final response = await _client.send(request).timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw ApiException(
        statusCode: 408,
        message:
            'Koneksi ke AI timeout. Coba lagi (gambar besar bisa memperlambat).',
      ),
    );

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw ApiException(
        statusCode: response.statusCode,
        message: 'API request failed: $errorBody',
      );
    }

    // Track whether we're inside a <think> block
    bool inThinkBlock = false;
    final buffer = StringBuffer();

    // Parse SSE stream. Errors out if the server stalls (no data) too long.
    await for (final chunk in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(
      const Duration(seconds: 120),
      onTimeout: (sink) {
        sink.close();
      },
    )) {
      if (chunk.isEmpty) continue;
      if (chunk == 'data: [DONE]') break;
      if (!chunk.startsWith('data: ')) continue;

      final jsonStr = chunk.substring(6); // Remove 'data: ' prefix
      try {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final delta = choices[0]['delta'] as Map<String, dynamic>?;
          if (delta != null) {
            final content = delta['content'] as String?;
            if (content != null && content.isNotEmpty) {
              // Filter out <think>...</think> blocks
              buffer.write(content);
              final text = buffer.toString();

              if (inThinkBlock) {
                final endIdx = text.indexOf('</think>');
                if (endIdx != -1) {
                  inThinkBlock = false;
                  final afterThink = text.substring(endIdx + 8);
                  buffer.clear();
                  if (afterThink.isNotEmpty) {
                    yield afterThink;
                  }
                } else {
                  // Still in think block, consume and don't yield
                  buffer.clear();
                }
              } else {
                final startIdx = text.indexOf('<think>');
                if (startIdx != -1) {
                  // Output text before <think>
                  final beforeThink = text.substring(0, startIdx);
                  if (beforeThink.isNotEmpty) {
                    yield beforeThink;
                  }
                  inThinkBlock = true;
                  final remaining = text.substring(startIdx + 7);
                  buffer.clear();
                  // Check if </think> is also in this chunk
                  final endIdx = remaining.indexOf('</think>');
                  if (endIdx != -1) {
                    inThinkBlock = false;
                    final afterThink = remaining.substring(endIdx + 8);
                    if (afterThink.isNotEmpty) {
                      yield afterThink;
                    }
                  }
                } else {
                  buffer.clear();
                  yield content;
                }
              }
            }
          }
        }
      } catch (_) {
        // Skip malformed chunks
        continue;
      }
    }
  }

  /// Non-streaming chat completion (for simple requests)
  Future<String> chatCompletion({
    required List<Map<String, dynamic>> messages,
    String model = ApiConstants.defaultModel,
    double temperature = 0.7,
    int? maxTokens,
  }) async {
    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'stream': false,
      if (maxTokens != null) 'max_tokens': maxTokens,
    });

    final response = await http.post(
      Uri.parse(ApiConstants.chatCompletionsEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'API request failed: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List;
    return choices[0]['message']['content'] as String;
  }

  /// Fetch available models from the API
  Future<List<Map<String, dynamic>>> fetchModels() async {
    final response = await http.get(
      Uri.parse(ApiConstants.modelsEndpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Failed to fetch models: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['data'] ?? []);
  }

  void dispose() {
    _client.close();
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
