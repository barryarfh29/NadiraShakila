import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'agent_changes.dart';

/// A restore point created after an agent run that modified files. Holds the
/// "before" snapshot of every file the agent touched, so the workspace can be
/// rolled back to the state just before that run (Kiro-style checkpoints).
class Checkpoint {
  final String id;
  final String label; // usually the user's request that triggered the run
  final DateTime time;
  final List<AgentChange> changes;

  Checkpoint({
    required this.id,
    required this.label,
    required this.time,
    required this.changes,
  });

  int get fileCount => changes.length;
}

final checkpointsProvider =
    StateNotifierProvider<CheckpointsNotifier, List<Checkpoint>>((ref) {
  return CheckpointsNotifier();
});

class CheckpointsNotifier extends StateNotifier<List<Checkpoint>> {
  CheckpointsNotifier() : super([]);

  static const _max = 30;

  /// Records a new checkpoint from the changes captured during an agent run.
  void push(String label, List<AgentChange> changes) {
    if (changes.isEmpty) return;
    final cp = Checkpoint(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: label.trim().isEmpty ? 'Agent run' : label.trim(),
      time: DateTime.now(),
      // Copy so later mutations of agentChangesProvider don't affect us.
      changes: List<AgentChange>.from(changes),
    );
    final next = [cp, ...state];
    state = next.length > _max ? next.sublist(0, _max) : next;
  }

  /// Restores every file in [cp] to its pre-run state. Returns affected paths
  /// so the UI can reload editors / refresh the explorer.
  List<String> restore(Checkpoint cp) {
    final paths = <String>[];
    for (final c in cp.changes) {
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
    return paths;
  }

  void delete(String id) {
    state = state.where((c) => c.id != id).toList();
  }

  void clear() => state = [];
}
