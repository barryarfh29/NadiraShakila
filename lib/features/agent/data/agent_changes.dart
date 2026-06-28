import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single file change made by the agent during a run, with enough info to
/// undo it.
class AgentChange {
  final String path;
  final String? before; // null if the file did not exist before
  final bool existedBefore;

  AgentChange({
    required this.path,
    required this.before,
    required this.existedBefore,
  });
}

final agentChangesProvider =
    StateNotifierProvider<AgentChangesNotifier, List<AgentChange>>((ref) {
  return AgentChangesNotifier();
});

class AgentChangesNotifier extends StateNotifier<List<AgentChange>> {
  AgentChangesNotifier() : super([]);

  void clear() => state = [];

  /// Snapshot a file's current state before the agent modifies it.
  /// Only the first change per path (the original) is kept.
  void record(String path) {
    if (state.any((c) => c.path == path)) return;
    final f = File(path);
    final existed = f.existsSync();
    String? before;
    if (existed) {
      try {
        before = f.readAsStringSync();
      } catch (_) {
        before = null;
      }
    }
    state = [
      ...state,
      AgentChange(path: path, before: before, existedBefore: existed),
    ];
  }

  /// Returns a label describing the kind of change for the UI.
  String labelFor(AgentChange c) {
    if (!c.existedBefore) return 'Created';
    if (!File(c.path).existsSync()) return 'Deleted';
    return 'Accepted edits to';
  }

  /// Reverts a single recorded file to its original state.
  bool revertOne(String path) {
    final match = state.where((c) => c.path == path).toList();
    if (match.isEmpty) return false;
    final c = match.first;
    try {
      final f = File(c.path);
      if (c.existedBefore) {
        f.writeAsStringSync(c.before ?? '');
      } else if (f.existsSync()) {
        f.deleteSync();
      }
    } catch (_) {
      return false;
    }
    state = state.where((e) => e.path != path).toList();
    return true;
  }

  /// Restores every recorded file to its original state. Returns the list of
  /// affected paths so the UI can refresh editors/explorer.
  List<String> revertAll() {
    final paths = <String>[];
    for (final c in state) {
      try {
        final f = File(c.path);
        if (c.existedBefore) {
          f.writeAsStringSync(c.before ?? '');
        } else if (f.existsSync()) {
          f.deleteSync();
        }
        paths.add(c.path);
      } catch (_) {}
    }
    clear();
    return paths;
  }
}
