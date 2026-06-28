import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// The kind of context a [ContextItem] represents.
enum ContextKind { file, folder, problems, terminal, codebase }

/// A piece of context the user explicitly attached to the chat (Kiro-style
/// `#` mentions). May be a file/folder, or a special source like the current
/// Problems list, Terminal output, or a Codebase file map.
class ContextItem {
  final ContextKind kind;

  /// Absolute path for [ContextKind.file] / [ContextKind.folder]; empty for
  /// the special kinds.
  final String path;

  ContextItem(this.path, bool isFolder)
      : kind = isFolder ? ContextKind.folder : ContextKind.file;

  const ContextItem.kind(this.kind, [this.path = '']);

  bool get isFolder => kind == ContextKind.folder;

  /// A stable key used for de-duplication.
  String get key => kind == ContextKind.file || kind == ContextKind.folder
      ? '${kind.name}:$path'
      : kind.name;

  String get name {
    switch (kind) {
      case ContextKind.file:
      case ContextKind.folder:
        return p.basename(path);
      case ContextKind.problems:
        return 'Problems';
      case ContextKind.terminal:
        return 'Terminal';
      case ContextKind.codebase:
        return 'Codebase';
    }
  }
}

final attachedContextProvider =
    StateNotifierProvider<AttachedContextNotifier, List<ContextItem>>((ref) {
  return AttachedContextNotifier();
});

class AttachedContextNotifier extends StateNotifier<List<ContextItem>> {
  AttachedContextNotifier() : super([]);

  void add(String path, bool isFolder) {
    _addItem(ContextItem(path, isFolder));
  }

  /// Attach a special context source (Problems / Terminal / Codebase).
  void addKind(ContextKind kind) {
    _addItem(ContextItem.kind(kind));
  }

  void _addItem(ContextItem item) {
    if (state.any((c) => c.key == item.key)) return;
    state = [...state, item];
  }

  void remove(String path) {
    state = state.where((c) => c.path != path || c.path.isEmpty).toList();
  }

  void removeItem(ContextItem item) {
    state = state.where((c) => c.key != item.key).toList();
  }

  void clear() => state = [];
}

/// Recursively lists workspace files (relative paths) for the picker.
/// Skips heavy/hidden folders and caps the result for performance.
List<String> listWorkspaceFiles(String root, {int max = 2000}) {
  const skip = {
    '.git',
    '.dart_tool',
    'build',
    'node_modules',
    '.idea',
    '.vscode',
    'Pods',
    'DerivedData',
  };
  final results = <String>[];
  void walk(Directory dir) {
    if (results.length >= max) return;
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } catch (_) {
      return;
    }
    for (final e in entries) {
      if (results.length >= max) return;
      final name = p.basename(e.path);
      if (skip.contains(name)) continue;
      if (e is Directory) {
        walk(e);
      } else if (e is File) {
        results.add(p.relative(e.path, from: root).replaceAll('\\', '/'));
      }
    }
  }

  walk(Directory(root));
  results.sort();
  return results;
}
