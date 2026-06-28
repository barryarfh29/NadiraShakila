import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../workspace/providers/workspace_provider.dart';

/// A changed file reported by `git status`.
class GitChange {
  final String path;
  final String code; // two-char XY porcelain code, e.g. ' M', '??', 'A '
  GitChange(this.path, this.code);

  bool get staged => code[0] != ' ' && code[0] != '?';

  /// Whether there are unstaged working-tree changes for this entry.
  bool get unstaged =>
      code.trim() == '??' ||
      (code.length > 1 && (code[1] == 'M' || code[1] == 'D'));

  String get label {
    final c = code.trim();
    if (c == '??') return 'U'; // untracked
    if (c.contains('M')) return 'M';
    if (c.contains('A')) return 'A';
    if (c.contains('D')) return 'D';
    if (c.contains('R')) return 'R';
    return c.isEmpty ? '•' : c[0];
  }
}

class GitState {
  final bool isRepo;
  final String? branch;
  final List<GitChange> changes;
  final bool loading;
  final String? message;

  const GitState({
    this.isRepo = false,
    this.branch,
    this.changes = const [],
    this.loading = false,
    this.message,
  });
}

final gitProvider = StateNotifierProvider<GitNotifier, GitState>((ref) {
  final notifier = GitNotifier(ref);
  // Re-scan whenever the workspace changes.
  ref.listen(workspaceProvider, (_, __) => notifier.refresh());
  return notifier;
});

class GitNotifier extends StateNotifier<GitState> {
  final Ref _ref;
  GitNotifier(this._ref) : super(const GitState()) {
    refresh();
  }

  String? get _root => _ref.read(workspaceProvider);

  Future<ProcessResult?> _git(List<String> args) async {
    final root = _root;
    if (root == null) return null;
    try {
      return await Process.run('git', args,
          workingDirectory: root, runInShell: true);
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    final root = _root;
    if (root == null) {
      state = const GitState();
      return;
    }
    state = const GitState(loading: true);

    final check = await _git(['rev-parse', '--is-inside-work-tree']);
    if (check == null || check.exitCode != 0) {
      state = const GitState(isRepo: false);
      return;
    }

    final branchRes = await _git(['rev-parse', '--abbrev-ref', 'HEAD']);
    final branch = (branchRes?.stdout as String?)?.trim();

    final statusRes = await _git(['status', '--porcelain']);
    final changes = <GitChange>[];
    if (statusRes != null) {
      final lines = (statusRes.stdout as String).split('\n');
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final code = line.length >= 2 ? line.substring(0, 2) : line;
        final path = line.length > 3 ? line.substring(3) : line;
        changes.add(GitChange(path.trim(), code));
      }
    }

    state = GitState(
      isRepo: true,
      branch: branch?.isEmpty ?? true ? null : branch,
      changes: changes,
      loading: false,
    );
  }

  Future<void> stageFile(String path) async {
    await _git(['add', '--', path]);
    await refresh();
  }

  Future<void> stageAll() async {
    await _git(['add', '-A']);
    await refresh();
  }

  Future<void> unstageFile(String path) async {
    await _git(['restore', '--staged', '--', path]);
    await refresh();
  }

  /// Discards working-tree changes for a file. Untracked files are deleted.
  /// Destructive — the UI confirms first.
  Future<String?> discardFile(GitChange change) async {
    final root = _root;
    if (root == null) return 'No folder open';
    try {
      if (change.code.trim() == '??') {
        File(p.join(root, change.path)).deleteSync();
      } else {
        await _git(['restore', '--', change.path]);
      }
      await refresh();
      return null;
    } catch (e) {
      return '$e';
    }
  }

  Future<String?> commit(String message) async {
    if (message.trim().isEmpty) return 'Commit message is empty';
    await _git(['add', '-A']);
    final res = await _git(['commit', '-m', message]);
    await refresh();
    if (res != null && res.exitCode != 0) {
      final err = (res.stderr as String).trim();
      final out = (res.stdout as String).trim();
      return err.isNotEmpty ? err : (out.isNotEmpty ? out : 'Commit failed');
    }
    return null;
  }

  /// Pushes commits to the remote. Returns an error message or null.
  Future<String?> push() async {
    var res = await _git(['push']);
    if (res != null && res.exitCode != 0) {
      final err = (res.stderr as String).trim();
      // First push of a new branch: set upstream.
      if (err.contains('no upstream') || err.contains('--set-upstream')) {
        final branch = state.branch ?? 'HEAD';
        res = await _git(['push', '--set-upstream', 'origin', branch]);
        if (res != null && res.exitCode == 0) return null;
      }
      return (res?.stderr as String?)?.trim() ?? 'Push failed';
    }
    return null;
  }

  /// Pulls from the remote. Returns an error message or null.
  Future<String?> pull() async {
    final res = await _git(['pull']);
    await refresh();
    if (res != null && res.exitCode != 0) {
      return (res.stderr as String).trim();
    }
    return null;
  }

  Future<String?> initRepo() async {
    final res = await _git(['init']);
    await refresh();
    if (res != null && res.exitCode != 0) {
      return (res.stderr as String).trim();
    }
    return null;
  }

  /// Returns a unified diff for [change] (working tree vs HEAD). Untracked
  /// files are shown entirely as additions.
  Future<String> diff(GitChange change) async {
    final root = _root;
    if (root == null) return '';
    if (change.code.trim() == '??') {
      try {
        final content = File(p.join(root, change.path)).readAsStringSync();
        return content.split('\n').map((l) => '+$l').join('\n');
      } catch (_) {
        return '';
      }
    }
    final res = await _git(['diff', 'HEAD', '--', change.path]);
    var out = (res?.stdout as String?) ?? '';
    if (out.trim().isEmpty) {
      final r2 = await _git(['diff', '--cached', '--', change.path]);
      out = (r2?.stdout as String?) ?? '';
    }
    return out;
  }

  /// Publishes the folder to a new GitHub repo using the `gh` CLI.
  Future<String?> publishToGitHub() async {
    final root = _root;
    if (root == null) return 'No folder open';
    try {
      // Ensure it's a repo first.
      final check = await _git(['rev-parse', '--is-inside-work-tree']);
      if (check == null || check.exitCode != 0) {
        await _git(['init']);
        await _git(['add', '-A']);
        await _git(['commit', '-m', 'Initial commit']);
      }
      final name = p.basename(root);
      final res = await Process.run(
        'gh',
        ['repo', 'create', name, '--source=.', '--private', '--push'],
        workingDirectory: root,
        runInShell: true,
      );
      await refresh();
      if (res.exitCode != 0) {
        final err = (res.stderr as String).trim();
        return err.isNotEmpty
            ? err
            : 'Failed. Make sure the GitHub CLI (gh) is installed and you are logged in.';
      }
      return null;
    } catch (e) {
      return 'GitHub CLI (gh) not found. Install it from cli.github.com';
    }
  }
}
