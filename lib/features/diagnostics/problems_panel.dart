import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_theme.dart';
import '../../core/theme/codicons.dart';
import '../workspace/providers/workspace_provider.dart';
import 'diagnostics_provider.dart';

/// VS Code-style Problems list showing all current diagnostics.
class ProblemsPanel extends ConsumerWidget {
  const ProblemsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diags = ref.watch(allDiagnosticsProvider);
    final root = ref.watch(workspaceProvider);

    if (diags.isEmpty) {
      return const Center(
        child: Text(
          'No problems have been detected in the workspace.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: diags.length,
      itemBuilder: (context, i) {
        final d = diags[i];
        return _ProblemRow(diagnostic: d, root: root);
      },
    );
  }
}

class _ProblemRow extends ConsumerStatefulWidget {
  final Diagnostic diagnostic;
  final String? root;
  const _ProblemRow({required this.diagnostic, this.root});

  @override
  ConsumerState<_ProblemRow> createState() => _ProblemRowState();
}

class _ProblemRowState extends ConsumerState<_ProblemRow> {
  bool _hovered = false;

  IconData get _icon {
    switch (widget.diagnostic.severity) {
      case DiagSeverity.error:
        return Codicons.circleSlash;
      case DiagSeverity.warning:
        return Codicons.lightbulb;
      case DiagSeverity.info:
        return Codicons.comment;
    }
  }

  Color get _color {
    switch (widget.diagnostic.severity) {
      case DiagSeverity.error:
        return AppColors.error;
      case DiagSeverity.warning:
        return AppColors.warning;
      case DiagSeverity.info:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.diagnostic;
    final name = p.basename(d.filePath);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          ref.read(editorProvider.notifier).openFile(d.filePath);
          ref.read(gotoLineProvider.notifier).state =
              GotoLine(d.filePath, d.line);
        },
        child: Container(
          color: _hovered ? AppColors.surfaceHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(_icon, size: 14, color: _color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: d.message,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                      ),
                    ),
                    if (d.code != null)
                      TextSpan(
                        text: '  ${d.code}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$name:${d.line}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
