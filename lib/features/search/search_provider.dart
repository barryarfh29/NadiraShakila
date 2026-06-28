import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../workspace/providers/workspace_provider.dart';

/// A single match within a file.
class SearchHit {
  final String path;
  final int line; // 1-based
  final String text;

  SearchHit({required this.path, required this.line, required this.text});
}

class SearchState {
  final String query;
  final List<SearchHit> hits;
  final bool searching;
  final bool truncated;

  const SearchState({
    this.query = '',
    this.hits = const [],
    this.searching = false,
    this.truncated = false,
  });

  /// Number of distinct files in the results.
  int get fileCount => hits.map((h) => h.path).toSet().length;
}

final searchProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref);
});

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref _ref;
  SearchNotifier(this._ref) : super(const SearchState());

  static const _skipDirs = {
    '.git',
    '.dart_tool',
    'build',
    'node_modules',
    '.idea',
    '.vscode',
  };
  static const _maxHits = 500;
  static const _maxFileBytes = 1024 * 1024; // 1 MB

  void clear() => state = const SearchState();

  /// Replaces all matches of the current query across files (case-insensitive)
  /// and returns the list of changed file paths.
  Future<List<String>> replaceAll(String replacement) async {
    if (state.query.trim().isEmpty || state.hits.isEmpty) return [];
    final pattern =
        RegExp(RegExp.escape(state.query), caseSensitive: false);
    final files = state.hits.map((h) => h.path).toSet();
    final changed = <String>[];
    for (final path in files) {
      try {
        final f = File(path);
        final content = f.readAsStringSync();
        final updated = content.replaceAll(pattern, replacement);
        if (updated != content) {
          f.writeAsStringSync(updated);
          changed.add(path);
        }
      } catch (_) {}
    }
    await search(state.query);
    return changed;
  }

  Future<void> search(String query) async {
    final root = _ref.read(workspaceProvider);
    if (query.trim().isEmpty || root == null) {
      state = SearchState(query: query);
      return;
    }

    state = SearchState(query: query, searching: true);

    final lower = query.toLowerCase();
    final hits = <SearchHit>[];
    var truncated = false;

    try {
      await for (final entity in Directory(root).list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final rel = p.relative(entity.path, from: root);
        if (rel.split(p.separator).any(_skipDirs.contains)) continue;

        try {
          if (entity.lengthSync() > _maxFileBytes) continue;
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].toLowerCase().contains(lower)) {
              hits.add(SearchHit(
                path: entity.path,
                line: i + 1,
                text: lines[i].trim(),
              ));
              if (hits.length >= _maxHits) {
                truncated = true;
                break;
              }
            }
          }
        } catch (_) {
          // skip binary/unreadable files
        }
        if (truncated) break;
      }
    } catch (_) {
      // ignore traversal errors
    }

    state = SearchState(
      query: query,
      hits: hits,
      searching: false,
      truncated: truncated,
    );
  }
}
