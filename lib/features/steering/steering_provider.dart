import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../workspace/providers/workspace_provider.dart';

/// A steering document under `.kiro/steering/*.md`. Steering files hold
/// project rules / context that are (by default) always sent to the AI,
/// modeled after Kiro AI's steering feature.
class SteeringFile {
  final String name; // file name without extension
  final String path; // absolute path

  SteeringFile(this.name, this.path);

  String read() {
    try {
      return File(path).readAsStringSync();
    } catch (_) {
      return '';
    }
  }

  /// Inclusion mode parsed from optional front-matter `inclusion:` key.
  /// Defaults to `always`. Supported: always, manual, fileMatch.
  String get inclusion {
    final content = read();
    final m = RegExp(r'^---[\s\S]*?inclusion:\s*(\w+)[\s\S]*?---',
            multiLine: false)
        .firstMatch(content);
    return m?.group(1)?.toLowerCase() ?? 'always';
  }
}

String? _steeringRoot(String? workspace) {
  if (workspace == null) return null;
  return p.join(workspace, '.kiro', 'steering');
}

final steeringProvider =
    StateNotifierProvider<SteeringNotifier, List<SteeringFile>>((ref) {
  final notifier = SteeringNotifier(ref);
  ref.listen(workspaceProvider, (_, __) => notifier.refresh());
  return notifier;
});

class SteeringNotifier extends StateNotifier<List<SteeringFile>> {
  final Ref _ref;
  SteeringNotifier(this._ref) : super([]) {
    refresh();
  }

  void refresh() {
    final root = _steeringRoot(_ref.read(workspaceProvider));
    if (root == null) {
      state = [];
      return;
    }
    final dir = Directory(root);
    if (!dir.existsSync()) {
      state = [];
      return;
    }
    final files = <SteeringFile>[];
    for (final e in dir.listSync(followLinks: false)) {
      if (e is File && p.extension(e.path).toLowerCase() == '.md') {
        files.add(SteeringFile(
            p.basenameWithoutExtension(e.path), e.path));
      }
    }
    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = files;
  }

  /// Creates a new steering file with a starter template. Returns it or null.
  SteeringFile? create(String rawName) {
    final root = _steeringRoot(_ref.read(workspaceProvider));
    if (root == null) return null;
    final name = rawName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (name.isEmpty) return null;
    final path = p.join(root, '$name.md');
    try {
      Directory(root).createSync(recursive: true);
      if (!File(path).existsSync()) {
        File(path).writeAsStringSync(
            '# ${_title(name)}\n\n'
            'Tulis aturan, konvensi, atau konteks proyek di sini. '
            'Isi file ini akan selalu disertakan ke AI.\n\n'
            '- Contoh: Selalu gunakan Bahasa Indonesia pada komentar.\n'
            '- Contoh: Gunakan pola Riverpod untuk state management.\n');
      }
    } catch (_) {
      return null;
    }
    refresh();
    return SteeringFile(name, path);
  }

  void delete(SteeringFile file) {
    try {
      File(file.path).deleteSync();
    } catch (_) {}
    refresh();
  }

  String _title(String slug) =>
      slug.split('-').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

/// Builds the combined steering context (always-applied files) for injection
/// into the AI prompt. Returns null when there is nothing to add.
String? buildSteeringContext(String workspace) {
  final root = _steeringRoot(workspace);
  if (root == null) return null;
  final dir = Directory(root);
  if (!dir.existsSync()) return null;

  final sb = StringBuffer();
  var any = false;
  for (final e in dir.listSync(followLinks: false)) {
    if (e is File && p.extension(e.path).toLowerCase() == '.md') {
      final file = SteeringFile(p.basenameWithoutExtension(e.path), e.path);
      if (file.inclusion == 'manual') continue; // only auto-include non-manual
      final content = file.read().trim();
      if (content.isEmpty) continue;
      if (!any) {
        sb.writeln('\n# Project Steering (always-applied rules)');
        sb.writeln(
            'These are project conventions and rules the user has defined. '
            'Follow them in all your work.');
        any = true;
      }
      sb.writeln('\n## Steering: ${file.name}');
      sb.writeln(content);
    }
  }
  return any ? sb.toString() : null;
}
