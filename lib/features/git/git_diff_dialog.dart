import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_theme.dart';
import '../../core/theme/codicons.dart';
import '../workspace/providers/workspace_provider.dart';
import 'git_provider.dart';

/// Shows a unified-diff viewer for a changed file.
Future<void> showGitDiff(
    BuildContext context, WidgetRef ref, GitChange change) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _GitDiffDialog(change: change),
  );
}

class _GitDiffDialog extends ConsumerWidget {
  final GitChange change;
  const _GitDiffDialog({required this.change});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: 760,
        height: 560,
        child: Column(
          children: [
            Container(
              height: 40,
              padding: const EdgeInsets.only(left: 14, right: 6),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Icon(Codicons.gitCommit,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.basename(change.path),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final root = ref.read(workspaceProvider);
                      if (root != null) {
                        ref
                            .read(editorProvider.notifier)
                            .openFile(p.join(root, change.path));
                      }
                      Navigator.of(context).pop();
                    },
                    child: const Text('Open File',
                        style: TextStyle(fontSize: 12)),
                  ),
                  IconButton(
                    icon: const Icon(Codicons.close, size: 14),
                    color: AppColors.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<String>(
                future: ref.read(gitProvider.notifier).diff(change),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  final lines = snap.data!.split('\n');
                  if (snap.data!.trim().isEmpty) {
                    return const Center(
                      child: Text('No changes to display',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    );
                  }
                  return Container(
                    color: AppColors.background,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: lines.length,
                      itemBuilder: (context, i) => _DiffLine(text: lines[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiffLine extends StatelessWidget {
  final String text;
  const _DiffLine({required this.text});

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color fg = AppColors.textSecondary;
    if (text.startsWith('+') && !text.startsWith('+++')) {
      bg = const Color(0x2289D185);
      fg = const Color(0xFFB5E0A0);
    } else if (text.startsWith('-') && !text.startsWith('---')) {
      bg = const Color(0x22F14C4C);
      fg = const Color(0xFFF1A0A0);
    } else if (text.startsWith('@@')) {
      fg = AppColors.info;
    } else if (text.startsWith('diff ') ||
        text.startsWith('index ') ||
        text.startsWith('+++') ||
        text.startsWith('---')) {
      fg = AppColors.textMuted;
    }
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: Text(
        text.isEmpty ? ' ' : text,
        style: TextStyle(
          color: fg,
          fontFamily: 'JetBrains Mono',
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }
}
