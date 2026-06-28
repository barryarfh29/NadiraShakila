import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_theme.dart';
import '../../core/theme/codicons.dart';
import '../ide/panel_widgets.dart';
import '../workspace/providers/workspace_provider.dart';
import 'git_diff_dialog.dart';
import 'git_provider.dart';

/// VS Code-style Source Control panel backed by the git CLI.
class GitPanel extends ConsumerStatefulWidget {
  const GitPanel({super.key});

  @override
  ConsumerState<GitPanel> createState() => _GitPanelState();
}

class _GitPanelState extends ConsumerState<GitPanel> {
  final TextEditingController _message = TextEditingController();
  bool _committing = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    setState(() => _committing = true);
    final err = await ref.read(gitProvider.notifier).commit(_message.text);
    if (!mounted) return;
    setState(() => _committing = false);
    if (err == null) {
      _message.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Committed'), duration: Duration(seconds: 1)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    }
  }

  Future<void> _publish() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Publishing to GitHub...'),
          duration: Duration(seconds: 1)),
    );
    final err = await ref.read(gitProvider.notifier).publishToGitHub();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Published to GitHub')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final git = ref.watch(gitProvider);
    final hasWorkspace = ref.watch(workspaceProvider) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(git),
        Expanded(child: _body(git, hasWorkspace)),
      ],
    );
  }

  Widget _header(GitState git) {
    return PanelHeader(
      title: 'Source Control',
      actions: [
        if (git.isRepo) ...[
          PanelIconButton(
            icon: Icons.arrow_upward,
            tooltip: 'Push to GitHub',
            onTap: () => _runRemote('Pushing...', 'Pushed to remote',
                () => ref.read(gitProvider.notifier).push()),
          ),
          PanelIconButton(
            icon: Icons.arrow_downward,
            tooltip: 'Pull from GitHub',
            onTap: () => _runRemote('Pulling...', 'Pulled from remote',
                () => ref.read(gitProvider.notifier).pull()),
          ),
        ],
        PanelIconButton(
          icon: Codicons.refresh,
          tooltip: 'Refresh',
          onTap: () => ref.read(gitProvider.notifier).refresh(),
        ),
      ],
    );
  }

  Future<void> _runRemote(
      String busy, String okMsg, Future<String?> Function() action) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(busy), duration: const Duration(milliseconds: 800)),
    );
    final err = await action();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? okMsg)),
    );
  }

  Widget _body(GitState git, bool hasWorkspace) {
    if (!hasWorkspace) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: PanelText('Open a folder to use Source Control.'),
      );
    }
    if (git.loading) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (!git.isRepo) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PanelText(
              "The folder currently open doesn't have a Git repository. You "
              'can initialize a repository which will enable source control '
              'features powered by Git.',
            ),
            const SizedBox(height: 12),
            PanelPrimaryButton(
              label: 'Initialize Repository',
              onPressed: () => ref.read(gitProvider.notifier).initRepo(),
            ),
            const SizedBox(height: 16),
            const PanelText(
              'You can directly publish this folder to a GitHub repository. '
              "Once published, you'll have access to source control features "
              'powered by Git and GitHub.',
            ),
            const SizedBox(height: 12),
            PanelPrimaryButton(
              label: 'Publish to GitHub',
              icon: Codicons.github,
              onPressed: () => _publish(),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          child: Column(
            children: [
              TextField(
                controller: _message,
                minLines: 1,
                maxLines: 3,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'Message (commit on ${git.branch ?? "HEAD"})',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (git.changes.isEmpty || _committing)
                      ? null
                      : _commit,
                  icon: _committing
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Codicons.check, size: 14),
                  label: Text('Commit${git.branch != null ? ' to ${git.branch}' : ''}'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final staged = git.changes.where((c) => c.staged).toList();
              final unstaged = git.changes.where((c) => c.unstaged).toList();
              if (staged.isEmpty && unstaged.isEmpty) {
                return const _Hint('No changes.');
              }
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (staged.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'STAGED CHANGES',
                      count: staged.length,
                      action: _SectionAction(
                        icon: Icons.remove,
                        tooltip: 'Unstage All',
                        onTap: () {
                          for (final c in staged) {
                            ref
                                .read(gitProvider.notifier)
                                .unstageFile(c.path);
                          }
                        },
                      ),
                    ),
                    for (final c in staged)
                      _ChangeRow(change: c, isStaged: true),
                  ],
                  if (unstaged.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'CHANGES',
                      count: unstaged.length,
                      action: _SectionAction(
                        icon: Icons.add,
                        tooltip: 'Stage All',
                        onTap: () =>
                            ref.read(gitProvider.notifier).stageAll(),
                      ),
                    ),
                    for (final c in unstaged)
                      _ChangeRow(change: c, isStaged: false),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _SectionAction(
      {required this.icon, required this.tooltip, required this.onTap});
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final _SectionAction? action;
  const _SectionHeader(
      {required this.title, required this.count, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 4),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 10)),
          ),
          const Spacer(),
          if (action != null)
            Tooltip(
              message: action!.tooltip,
              child: InkWell(
                onTap: action!.onTap,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(action!.icon,
                      size: 14, color: AppColors.textMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChangeRow extends ConsumerStatefulWidget {
  final GitChange change;
  final bool isStaged;
  const _ChangeRow({required this.change, required this.isStaged});

  @override
  ConsumerState<_ChangeRow> createState() => _ChangeRowState();
}

class _ChangeRowState extends ConsumerState<_ChangeRow> {
  bool _hovered = false;

  Color _statusColor(String label) {
    switch (label) {
      case 'M':
        return AppColors.warning;
      case 'A':
      case 'U':
        return AppColors.success;
      case 'D':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final change = widget.change;
    final name = p.basename(change.path);
    final dir = p.dirname(change.path);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => showGitDiff(context, ref, change),
        child: Container(
          color: _hovered ? AppColors.surfaceHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (dir != '.') ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    dir,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (_hovered) ...[
                if (widget.isStaged)
                  _rowAction(Icons.remove, 'Unstage',
                      () => ref
                          .read(gitProvider.notifier)
                          .unstageFile(change.path))
                else ...[
                  _rowAction(Icons.undo, 'Discard',
                      () => _confirmDiscard(context, ref, change)),
                  _rowAction(Icons.add, 'Stage',
                      () => ref
                          .read(gitProvider.notifier)
                          .stageFile(change.path)),
                ],
              ],
              const SizedBox(width: 4),
              Text(
                change.label,
                style: TextStyle(
                  color: _statusColor(change.label),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowAction(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 14, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Future<void> _confirmDiscard(
      BuildContext context, WidgetRef ref, GitChange change) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Discard changes?', style: TextStyle(fontSize: 16)),
        content: Text(
          'This will permanently discard changes to ${p.basename(change.path)}. '
          'This cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final err = await ref.read(gitProvider.notifier).discardFile(change);
      if (err != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      } else {
        // Reflect on disk in the editor if open.
        final root = ref.read(workspaceProvider);
        if (root != null) {
          ref
              .read(editorProvider.notifier)
              .reloadFromDisk(p.join(root, change.path));
        }
      }
    }
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }
}
