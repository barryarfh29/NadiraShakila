import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/codicons.dart';
import '../diagnostics/diagnostics_provider.dart';
import '../diagnostics/problems_panel.dart';
import '../terminal/terminal_panel.dart';
import '../terminal/terminal_provider.dart';

/// VS Code-style bottom panel with PROBLEMS / TERMINAL tabs.
class BottomPanel extends ConsumerWidget {
  const BottomPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(bottomPanelProvider);
    final problemCount = ref.watch(allDiagnosticsProvider).length;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Container(
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                _Tab(
                  label: 'PROBLEMS',
                  badge: problemCount > 0 ? '$problemCount' : null,
                  active: tab == BottomTab.problems,
                  onTap: () => ref.read(bottomPanelProvider.notifier).state =
                      BottomTab.problems,
                ),
                _Tab(
                  label: 'TERMINAL',
                  active: tab == BottomTab.terminal,
                  onTap: () => ref.read(bottomPanelProvider.notifier).state =
                      BottomTab.terminal,
                ),
                const Spacer(),
                Tooltip(
                  message: 'Close Panel',
                  child: InkWell(
                    onTap: () =>
                        ref.read(bottomPanelProvider.notifier).state = null,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Codicons.close,
                          size: 14, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: tab == BottomTab.terminal ? 1 : 0,
              children: const [
                ProblemsPanel(),
                TerminalPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final String? badge;
  final bool active;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    this.badge,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primaryDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
