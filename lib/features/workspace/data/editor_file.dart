import 'package:path/path.dart' as p;

/// Represents a file open in an editor tab.
class EditorFile {
  final String path;
  final String savedContent;
  final String content;
  final bool isDirty;

  EditorFile({
    required this.path,
    required this.savedContent,
    required this.content,
  }) : isDirty = savedContent != content;

  String get name => p.basename(path);

  /// File extension without the dot, lowercased (e.g. "dart", "json").
  String get extension {
    final ext = p.extension(path);
    return ext.isEmpty ? '' : ext.substring(1).toLowerCase();
  }

  EditorFile copyWith({String? savedContent, String? content}) {
    return EditorFile(
      path: path,
      savedContent: savedContent ?? this.savedContent,
      content: content ?? this.content,
    );
  }
}
