import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../chat/presentation/providers/chat_provider.dart';

/// Provider that holds the current ghost text suggestion.
final ghostTextProvider = StateProvider<String?>((ref) => null);

/// Mixin that adds ghost text (autocomplete) functionality to the code editor.
/// Call [scheduleGhostText] whenever the user types, and [acceptGhostText]
/// when Tab is pressed.
mixin GhostTextMixin<T extends StatefulWidget> on State<T> {
  Timer? _ghostTimer;
  bool _ghostFetching = false;
  String? _ghostText;
  int _ghostOffset = -1; // cursor offset where ghost was generated

  /// Override in the editor state to provide current text and cursor position.
  String get editorText;
  int get cursorOffset;
  String get fileName;

  /// Override to get the API service and model.
  ApiService? get apiService;
  String get currentModel;

  /// Override to insert text at cursor.
  void insertTextAtCursor(String text);

  /// Call this from the editor's onChange listener.
  void scheduleGhostText() {
    // Cancel any pending request
    _ghostTimer?.cancel();
    _ghostText = null;
    _ghostOffset = -1;

    if (apiService == null) return;

    // Wait 1.5 seconds after user stops typing
    _ghostTimer = Timer(const Duration(milliseconds: 1500), () {
      _fetchGhostText();
    });
  }

  /// Dismiss ghost text (call on Esc or when user types past it).
  void dismissGhostText() {
    _ghostTimer?.cancel();
    setState(() {
      _ghostText = null;
      _ghostOffset = -1;
    });
  }

  /// Accept ghost text (call on Tab).
  bool acceptGhostText() {
    if (_ghostText == null || _ghostText!.isEmpty) return false;
    insertTextAtCursor(_ghostText!);
    setState(() {
      _ghostText = null;
      _ghostOffset = -1;
    });
    return true;
  }

  /// Returns the current ghost suggestion text (null if none).
  String? get currentGhostText => _ghostText;

  /// Returns the cursor offset where ghost text should be rendered.
  int get ghostTextOffset => _ghostOffset;

  Future<void> _fetchGhostText() async {
    if (_ghostFetching || apiService == null) return;
    _ghostFetching = true;

    try {
      final text = editorText;
      final offset = cursorOffset;
      if (offset < 0 || offset > text.length) return;

      // Get context: last ~30 lines before cursor
      final before = text.substring(0, offset);
      final lines = before.split('\n');
      final contextLines = lines.length > 30
          ? lines.sublist(lines.length - 30)
          : lines;
      final context = contextLines.join('\n');

      // Get a few lines after cursor for context
      final after = text.substring(offset);
      final afterLines = after.split('\n');
      final afterContext = afterLines.length > 5
          ? afterLines.sublist(0, 5).join('\n')
          : after;

      final ext = fileName.split('.').last;

      final prompt =
          'Continue this $ext code. Output ONLY the next 1-3 lines of code that '
          'logically follow. No explanation, no markdown fences, no comments about '
          'what you are doing. Just the raw code continuation.\n\n'
          '```$ext\n$context\n```\n\n'
          'Code after cursor (for context):\n```\n$afterContext\n```\n\n'
          'Continue from where the cursor is (after the first code block ends):';

      final result = await apiService!.chatCompletion(
        messages: [
          {'role': 'user', 'content': prompt}
        ],
        model: currentModel,
        temperature: 0.2,
        maxTokens: 150,
      );

      if (!mounted) return;

      // Clean up the result
      var suggestion = result.trim();
      // Remove markdown fences if present
      if (suggestion.startsWith('```')) {
        final nl = suggestion.indexOf('\n');
        if (nl != -1) suggestion = suggestion.substring(nl + 1);
        if (suggestion.endsWith('```')) {
          suggestion = suggestion.substring(0, suggestion.length - 3);
        }
      }
      suggestion = suggestion.trimRight();

      // Only show if cursor hasn't moved
      if (cursorOffset == offset && suggestion.isNotEmpty) {
        setState(() {
          _ghostText = suggestion;
          _ghostOffset = offset;
        });
      }
    } catch (_) {
      // Silently fail — ghost text is optional
    } finally {
      _ghostFetching = false;
    }
  }

  @override
  void dispose() {
    _ghostTimer?.cancel();
    super.dispose();
  }
}

/// Widget that renders ghost text (semi-transparent) after the cursor.
class GhostTextOverlay extends StatelessWidget {
  final String ghostText;
  final TextStyle baseStyle;

  const GhostTextOverlay({
    super.key,
    required this.ghostText,
    required this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      ghostText,
      style: baseStyle.copyWith(
        color: AppColors.textMuted.withValues(alpha: 0.4),
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
