import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_theme.dart';
import '../../core/theme/codicons.dart';
import '../ide/panel_widgets.dart';
import '../terminal/terminal_provider.dart';
import '../workspace/providers/workspace_provider.dart';

/// VS Code-style Run and Debug panel. Detects the project type and runs it
/// in the integrated terminal.
class RunDebugPanel extends ConsumerWidget {
  const RunDebugPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final root = ref.watch(workspaceProvider);
    final command = _detectRunCommand(root);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelHeader(title: 'Run and Debug'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PanelPrimaryButton(
                  label: 'Run and Debug',
                  icon: Codicons.debugAlt,
                  onPressed: root == null
                      ? null
                      : () => _run(ref, command),
                ),
                const SizedBox(height: 12),
                if (root == null)
                  const PanelText('Open a folder to run a project.')
                else if (command == null)
                  const PanelText(
                    'No runnable project detected. Open the terminal to run '
                    'commands manually.',
                  )
                else
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const PanelText('Detected command: '),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.inlineCode,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          command,
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                const PanelText(
                  'The project runs in the integrated terminal. Configure '
                  'commands per project type (Flutter, Node, Python).',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _run(WidgetRef ref, String? command) {
    if (command == null) {
      ref.read(bottomPanelProvider.notifier).state = BottomTab.terminal;
      return;
    }
    ref.read(bottomPanelProvider.notifier).state = BottomTab.terminal;
    ref.read(pendingTerminalCommandProvider.notifier).state = command;
  }

  /// Detects a sensible run command based on files present in the workspace.
  String? _detectRunCommand(String? root) {
    if (root == null) return null;
    bool has(String name) => File(p.join(root, name)).existsSync();

    if (has('pubspec.yaml')) return 'flutter run -d windows';
    if (has('package.json')) return 'npm run dev';
    if (has('Cargo.toml')) return 'cargo run';
    if (has('go.mod')) return 'go run .';
    if (has('main.py')) return 'python main.py';
    if (has('requirements.txt')) return 'python main.py';
    if (has('Makefile')) return 'make';
    return null;
  }
}
