import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/codicons.dart';
import '../../diagnostics/diagnostics_provider.dart';
import '../../terminal/terminal_provider.dart';
import '../providers/workspace_provider.dart';
import 'editor_area.dart';

/// VS Code-style bottom status bar.
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider);
    final editor = ref.watch(editorProvider);
    final cursor = ref.watch(cursorPositionProvider);
    final active = editor.activeFile;
    final diags = ref.watch(allDiagnosticsProvider);
    final errors = diags.where((d) => d.severity == DiagSeverity.error).length;
    final warnings =
        diags.where((d) => d.severity == DiagSeverity.warning).length;

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: AppColors.statusBar,
        border: Border(top: BorderSide(color: AppColors.statusBar)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          _Item(
            text: workspace == null ? 'No Folder' : p.basename(workspace),
            icon: Icons.folder_outlined,
          ),
          const SizedBox(width: 14),
          // Errors / warnings count (click to open Problems).
          InkWell(
            onTap: () =>
                ref.read(bottomPanelProvider.notifier).state =
                    BottomTab.problems,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Codicons.circleSlash, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text('$errors',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
                const SizedBox(width: 8),
                const Icon(Codicons.lightbulb, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text('$warnings',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
          const Spacer(),
          if (active != null) ...[
            _Item(text: 'Ln ${cursor.line}, Col ${cursor.col}'),
            const SizedBox(width: 14),
            _Item(text: _languageLabel(active.extension)),
            const SizedBox(width: 14),
            _Item(text: active.isDirty ? 'Unsaved' : 'Saved'),
          ],
        ],
      ),
    );
  }

  String _languageLabel(String ext) {
    switch (ext) {
      case 'dart':
        return 'Dart';
      case 'js':
        return 'JavaScript';
      case 'ts':
        return 'TypeScript';
      case 'py':
        return 'Python';
      case 'json':
        return 'JSON';
      case 'yaml':
      case 'yml':
        return 'YAML';
      case 'md':
        return 'Markdown';
      case 'html':
        return 'HTML';
      case 'css':
        return 'CSS';
      case '':
        return 'Plain Text';
      default:
        return ext.toUpperCase();
    }
  }
}

class _Item extends StatelessWidget {
  final String text;
  final IconData? icon;

  const _Item({required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
