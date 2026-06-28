// Pure-Dart unit tests for the editor file model.
//
// These run on the Dart VM (no flutter_tester GUI harness), so they are fast
// and reliable on any machine.

import 'package:ai_desktop/features/workspace/data/editor_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EditorFile', () {
    test('is not dirty when content matches saved content', () {
      final file = EditorFile(
        path: r'D:\proj\main.dart',
        savedContent: 'void main() {}',
        content: 'void main() {}',
      );
      expect(file.isDirty, isFalse);
    });

    test('becomes dirty when content differs from saved content', () {
      final file = EditorFile(
        path: r'D:\proj\main.dart',
        savedContent: 'void main() {}',
        content: 'void main() { print("hi"); }',
      );
      expect(file.isDirty, isTrue);
    });

    test('exposes the base file name', () {
      final file = EditorFile(
        path: r'D:\proj\lib\app.dart',
        savedContent: '',
        content: '',
      );
      expect(file.name, 'app.dart');
    });

    test('extracts a lowercased extension without the dot', () {
      expect(
        EditorFile(path: 'README.MD', savedContent: '', content: '').extension,
        'md',
      );
      expect(
        EditorFile(path: 'config.YAML', savedContent: '', content: '')
            .extension,
        'yaml',
      );
    });

    test('returns empty extension for files without one', () {
      final file = EditorFile(path: 'Makefile', savedContent: '', content: '');
      expect(file.extension, '');
    });

    test('copyWith updates content and recomputes dirty flag', () {
      final clean = EditorFile(
        path: 'a.txt',
        savedContent: 'hello',
        content: 'hello',
      );
      final edited = clean.copyWith(content: 'hello world');
      expect(edited.isDirty, isTrue);

      final saved = edited.copyWith(savedContent: 'hello world');
      expect(saved.isDirty, isFalse);
    });
  });
}
