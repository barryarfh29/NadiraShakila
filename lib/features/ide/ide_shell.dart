import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/codicons.dart';
import '../chat/presentation/widgets/ai_chat_dock.dart';
import '../chat/presentation/widgets/settings_dialog.dart';
import '../chat/presentation/widgets/sidebar.dart';
import '../extensions/extensions_panel.dart';
import '../git/git_panel.dart';
import '../rundebug/run_debug_panel.dart';
import '../search/search_panel.dart';
import '../specs/specs_panel.dart';
import '../terminal/terminal_provider.dart';
import '../workspace/widgets/editor_area.dart';
import '../workspace/widgets/file_explorer.dart';
import '../workspace/widgets/status_bar.dart';
import 'app_menu_bar.dart';
import 'bottom_panel.dart';
import 'ide_providers.dart';
import 'quick_open.dart';

/// Main IDE shell: menu bar + activity bar + side panel + editor + terminal
/// + AI chat dock, modeled after VS Code / Kiro AI.
class IdeShell extends ConsumerWidget {
  const IdeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = ref.watch(sidePanelProvider);
    final chatVisible = ref.watch(chatVisibleProvider);
    final bottomTab = ref.watch(bottomPanelProvider);
    final terminalHeight = ref.watch(terminalHeightProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.backquote, control: true):
            () {
          final cur = ref.read(bottomPanelProvider);
          ref.read(bottomPanelProvider.notifier).state =
              cur == BottomTab.terminal ? null : BottomTab.terminal;
        },
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          showQuickOpen(context, ref);
        },
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
          openWorkspaceFolder(context, ref);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              const AppMenuBar(),
              Expanded(
                child: Row(
                  children: [
                    const _ActivityBar(),
                    if (panel != SidePanel.none)
                      _buildSidePanel(context, panel),
                    Expanded(
                      child: Column(
                        children: [
                          const Expanded(child: EditorArea()),
                          if (bottomTab != null) ...[
                            _TerminalResizeHandle(
                              onDrag: (dy) {
                                final h = (ref.read(terminalHeightProvider) - dy)
                                    .clamp(120.0, 600.0);
                                ref.read(terminalHeightProvider.notifier).state =
                                    h;
                              },
                            ),
                            SizedBox(
                              height: terminalHeight,
                              child: const BottomPanel(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (chatVisible)
                      AiChatDock(
                        onClose: () => ref
                            .read(chatVisibleProvider.notifier)
                            .state = false,
                      ),
                  ],
                ),
              ),
              const StatusBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidePanel(BuildContext context, SidePanel panel) {
    switch (panel) {
      case SidePanel.explorer:
        return Container(
          width: 250,
          decoration: const BoxDecoration(
            color: AppColors.sidebarBg,
            border: Border(right: BorderSide(color: AppColors.border)),
          ),
          child: const FileExplorer(),
        );
      case SidePanel.search:
        return Container(
          width: 280,
          decoration: const BoxDecoration(
            color: AppColors.sidebarBg,
            border: Border(right: BorderSide(color: AppColors.border)),
          ),
          child: const SearchPanel(),
        );
      case SidePanel.sourceControl:
        return Container(
          width: 280,
          decoration: const BoxDecoration(
            color: AppColors.sidebarBg,
            border: Border(right: BorderSide(color: AppColors.border)),
          ),
          child: const GitPanel(),
        );
      case SidePanel.runDebug:
        return Container(
          width: 280,
          decoration: const BoxDecoration(
            color: AppColors.sidebarBg,
            border: Border(right: BorderSide(color: AppColors.border)),
          ),
          child: const RunDebugPanel(),
        );
      case SidePanel.specs:
        return Container(
          width: 300,
          decoration: const BoxDecoration(
            color: AppColors.sidebarBg,
            border: Border(right: BorderSide(color: AppColors.border)),
          ),
          child: const SpecsPanel(),
        );
      case SidePanel.extensions:
        return Container(
          width: 290,
          decoration: const BoxDecoration(
            color: AppColors.sidebarBg,
            border: Border(right: BorderSide(color: AppColors.border)),
          ),
          child: const ExtensionsPanel(),
        );
      case SidePanel.history:
        return Sidebar(
          activeTab: 1,
          onNewChat: () {},
          onSettingsPressed: () => showDialog(
            context: context,
            builder: (_) => const SettingsDialog(),
          ),
        );
      case SidePanel.settings:
        return Sidebar(
          activeTab: 4,
          onNewChat: () {},
          onSettingsPressed: () => showDialog(
            context: context,
            builder: (_) => const SettingsDialog(),
          ),
        );
      case SidePanel.none:
        return const SizedBox.shrink();
    }
  }
}

class _ActivityBar extends ConsumerWidget {
  const _ActivityBar();

  void _selectPanel(WidgetRef ref, SidePanel panel) {
    final current = ref.read(sidePanelProvider);
    ref.read(sidePanelProvider.notifier).state =
        current == panel ? SidePanel.none : panel;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(sidePanelProvider);
    final chatVisible = ref.watch(chatVisibleProvider);
    final terminalVisible = ref.watch(terminalVisibleProvider);

    return Container(
      width: 48,
      color: AppColors.activityBar,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _BarItem(
            icon: Codicons.files,
            activeIcon: Codicons.files,
            tooltip: 'Explorer',
            isActive: active == SidePanel.explorer,
            onTap: () => _selectPanel(ref, SidePanel.explorer),
          ),
          _BarItem(
            icon: Codicons.search,
            activeIcon: Codicons.search,
            tooltip: 'Search',
            isActive: active == SidePanel.search,
            onTap: () => _selectPanel(ref, SidePanel.search),
          ),
          _BarItem(
            icon: Codicons.sourceControl,
            activeIcon: Codicons.sourceControl,
            tooltip: 'Source Control',
            isActive: active == SidePanel.sourceControl,
            onTap: () => _selectPanel(ref, SidePanel.sourceControl),
          ),
          _BarItem(
            icon: Codicons.debugAlt,
            activeIcon: Codicons.debugAlt,
            tooltip: 'Run and Debug',
            isActive: active == SidePanel.runDebug,
            onTap: () => _selectPanel(ref, SidePanel.runDebug),
          ),
          _BarItem(
            icon: Icons.checklist_rounded,
            activeIcon: Icons.checklist_rounded,
            tooltip: 'Specs',
            isActive: active == SidePanel.specs,
            onTap: () => _selectPanel(ref, SidePanel.specs),
          ),
          _BarItem(
            icon: Codicons.extensions,
            activeIcon: Codicons.extensions,
            tooltip: 'Extensions',
            isActive: active == SidePanel.extensions,
            onTap: () => _selectPanel(ref, SidePanel.extensions),
          ),
          _BarItem(
            icon: Codicons.commentDiscussion,
            activeIcon: Codicons.commentDiscussion,
            tooltip: chatVisible ? 'Hide AI Panel' : 'Show AI Panel',
            isActive: chatVisible,
            onTap: () => ref.read(chatVisibleProvider.notifier).state =
                !chatVisible,
          ),
          _BarItem(
            icon: Codicons.terminal,
            activeIcon: Codicons.terminal,
            tooltip: terminalVisible ? 'Hide Terminal' : 'Show Terminal',
            isActive: terminalVisible,
            onTap: () {
              final cur = ref.read(bottomPanelProvider);
              ref.read(bottomPanelProvider.notifier).state =
                  cur == BottomTab.terminal ? null : BottomTab.terminal;
            },
          ),
          const Spacer(),
          _BarItem(
            icon: Codicons.account,
            activeIcon: Codicons.account,
            tooltip: 'Account',
            isActive: false,
            onTap: () {},
          ),
          _BarItem(
            icon: Codicons.gear,
            activeIcon: Codicons.gear,
            tooltip: 'Settings',
            isActive: active == SidePanel.settings,
            onTap: () => showDialog(
              context: context,
              builder: (_) => const SettingsDialog(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _BarItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _BarItem({
    required this.icon,
    required this.activeIcon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_BarItem> createState() => _BarItemState();
}

class _BarItemState extends State<_BarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 48,
            height: 42,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: widget.isActive
                      ? AppColors.activityBarActive
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Center(
              child: Icon(
                widget.isActive ? widget.activeIcon : widget.icon,
                size: 20,
                color: widget.isActive
                    ? AppColors.textPrimary
                    : (_hovered ? AppColors.textPrimary : AppColors.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin draggable divider for resizing the terminal panel height.
class _TerminalResizeHandle extends StatefulWidget {
  final ValueChanged<double> onDrag;
  const _TerminalResizeHandle({required this.onDrag});

  @override
  State<_TerminalResizeHandle> createState() => _TerminalResizeHandleState();
}

class _TerminalResizeHandleState extends State<_TerminalResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onVerticalDragUpdate: (d) => widget.onDrag(d.delta.dy),
        child: Container(
          height: 5,
          color: _hovered ? AppColors.primary : AppColors.border,
        ),
      ),
    );
  }
}
