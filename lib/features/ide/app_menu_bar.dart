import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/codicons.dart';
import '../github/github_dialog.dart';
import '../workspace/providers/workspace_provider.dart';
import '../workspace/widgets/file_explorer.dart';
import '../terminal/terminal_provider.dart';
import 'ide_providers.dart';
import 'quick_open.dart';

/// A single menu action shown inside a menu dropdown.
class _MenuAction {
  final String label;
  final VoidCallback? onTap;
  final String? shortcut;
  final bool divider;

  const _MenuAction(this.label, this.onTap, {this.shortcut}) : divider = false;
  const _MenuAction.divider()
      : label = '',
        onTap = null,
        shortcut = null,
        divider = true;
}

/// Tracks which top menu is currently open, so hovering another title can
/// switch to it instantly (VS Code / Kiro behavior).
MenuController? _openMenuController;

/// A clickable top-bar menu title with hover highlight.
class _MenuTitle extends StatefulWidget {
  final String title;
  final VoidCallback onTap;
  final VoidCallback onHover;
  const _MenuTitle({
    required this.title,
    required this.onTap,
    required this.onHover,
  });

  @override
  State<_MenuTitle> createState() => _MenuTitleState();
}

class _MenuTitleState extends State<_MenuTitle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        widget.onHover();
      },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          color: _hovered ? AppColors.surfaceHover : Colors.transparent,
          child: Text(
            widget.title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// VS Code-style top menu bar: File, Edit, Selection, View, Go, Run,
/// Terminal, Help.
class AppMenuBar extends ConsumerWidget {
  const AppMenuBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 34,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(right: 8),
                    child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                  ),
                  _menu(context, ref, 'File', _fileMenu(context, ref)),
                  _menu(context, ref, 'Edit', _editMenu()),
                  _menu(context, ref, 'Selection', _selectionMenu()),
                  _menu(context, ref, 'View', _viewMenu(ref)),
                  _menu(context, ref, 'Go', _goMenu(context, ref)),
                  _menu(context, ref, 'Run', _runMenu(ref)),
                  _menu(context, ref, 'Terminal', _terminalMenu(ref)),
                  _menu(context, ref, 'Help', _helpMenu(context)),
                  const SizedBox(width: 8),
                  Expanded(child: Center(child: _CommandPalette())),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          const _WindowButtons(),
        ],
      ),
    );
  }

  Widget _menu(
      BuildContext context, WidgetRef ref, String title, List<_MenuAction> items) {
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor:
            const WidgetStatePropertyAll(AppColors.surfaceVariant),
        padding:
            const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 4)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        )),
      ),
      menuChildren: [
        for (final item in items)
          if (item.divider)
            const Divider(height: 1, color: AppColors.border)
          else
            MenuItemButton(
              onPressed: item.onTap,
              trailingIcon: item.shortcut != null
                  ? Text(item.shortcut!,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11))
                  : null,
              child: SizedBox(
                width: 170,
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: item.onTap != null
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
      ],
      builder: (context, controller, child) {
        return _MenuTitle(
          title: title,
          onTap: () {
            if (controller.isOpen) {
              controller.close();
              _openMenuController = null;
            } else {
              controller.open();
              _openMenuController = controller;
            }
          },
          onHover: () {
            // VS Code-like: if another menu is already open, switch instantly.
            final open = _openMenuController;
            if (open != null && open != controller && open.isOpen) {
              open.close();
              controller.open();
              _openMenuController = controller;
            }
          },
        );
      },
    );
  }

  // === Menus ===

  List<_MenuAction> _fileMenu(BuildContext context, WidgetRef ref) {
    final hasWorkspace = ref.read(workspaceProvider) != null;
    final activePath = ref.read(editorProvider).activePath;
    return [
      _MenuAction('New File...', hasWorkspace
          ? () => _newFile(context, ref)
          : null),
      _MenuAction('New Folder...', hasWorkspace
          ? () => _newFolder(context, ref)
          : null),
      const _MenuAction.divider(),
      _MenuAction('Open Folder...', () => openWorkspaceFolder(context, ref)),
      _MenuAction('Clone GitHub Repo...', () => showGitHubClone(context, ref)),
      if (hasWorkspace)
        _MenuAction('Close Folder',
            () => ref.read(workspaceProvider.notifier).closeFolder()),
      const _MenuAction.divider(),
      _MenuAction('Save', activePath != null
          ? () => _save(context, ref, activePath)
          : null, shortcut: 'Ctrl+S'),
      _MenuAction('Save All', () => _saveAll(context, ref)),
      _MenuAction('Close Editor', activePath != null
          ? () => ref.read(editorProvider.notifier).closeFile(activePath)
          : null),
      const _MenuAction.divider(),
      _MenuAction('Exit', () => exit(0)),
    ];
  }

  List<_MenuAction> _editMenu() {
    return [
      _MenuAction('Undo', () => _invoke(const UndoTextIntent(SelectionChangedCause.keyboard)),
          shortcut: 'Ctrl+Z'),
      _MenuAction('Redo', () => _invoke(const RedoTextIntent(SelectionChangedCause.keyboard)),
          shortcut: 'Ctrl+Y'),
      const _MenuAction.divider(),
      _MenuAction('Cut', () => _invoke(const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard)),
          shortcut: 'Ctrl+X'),
      _MenuAction('Copy', () => _invoke(CopySelectionTextIntent.copy),
          shortcut: 'Ctrl+C'),
      _MenuAction('Paste', () => _invoke(const PasteTextIntent(SelectionChangedCause.keyboard)),
          shortcut: 'Ctrl+V'),
    ];
  }

  List<_MenuAction> _selectionMenu() {
    return [
      _MenuAction('Select All', () => _invoke(const SelectAllTextIntent(SelectionChangedCause.keyboard)),
          shortcut: 'Ctrl+A'),
    ];
  }

  List<_MenuAction> _viewMenu(WidgetRef ref) {
    return [
      _MenuAction('Explorer', () => _togglePanel(ref, SidePanel.explorer)),
      _MenuAction('Chat History', () => _togglePanel(ref, SidePanel.history)),
      const _MenuAction.divider(),
      _MenuAction('Toggle Terminal', () {
        final cur = ref.read(bottomPanelProvider);
        ref.read(bottomPanelProvider.notifier).state =
            cur == BottomTab.terminal ? null : BottomTab.terminal;
      }, shortcut: 'Ctrl+`'),
      _MenuAction('Toggle AI Panel', () {
        final v = ref.read(chatVisibleProvider);
        ref.read(chatVisibleProvider.notifier).state = !v;
      }),
      _MenuAction('Problems', () {
        ref.read(bottomPanelProvider.notifier).state = BottomTab.problems;
      }),
    ];
  }

  List<_MenuAction> _goMenu(BuildContext context, WidgetRef ref) {
    return [
      _MenuAction('Open Folder...', () => openWorkspaceFolder(context, ref)),
    ];
  }

  List<_MenuAction> _runMenu(WidgetRef ref) {
    return [
      _MenuAction('Open Terminal', () =>
          ref.read(bottomPanelProvider.notifier).state = BottomTab.terminal),
    ];
  }

  List<_MenuAction> _terminalMenu(WidgetRef ref) {
    return [
      _MenuAction('New Terminal', () =>
          ref.read(bottomPanelProvider.notifier).state = BottomTab.terminal,
          shortcut: 'Ctrl+`'),
      _MenuAction('Hide Terminal', () =>
          ref.read(bottomPanelProvider.notifier).state = null),
    ];
  }

  List<_MenuAction> _helpMenu(BuildContext context) {
    return [
      _MenuAction('About Nadira Shakila', () => _about(context)),
    ];
  }

  // === Actions ===

  void _invoke(Intent intent) {
    final ctx = primaryFocus?.context;
    if (ctx != null) {
      Actions.maybeInvoke(ctx, intent);
    }
  }

  void _togglePanel(WidgetRef ref, SidePanel panel) {
    final current = ref.read(sidePanelProvider);
    ref.read(sidePanelProvider.notifier).state =
        current == panel ? SidePanel.none : panel;
  }

  void _save(BuildContext context, WidgetRef ref, String path) {
    final err = ref.read(editorProvider.notifier).saveFile(path);
    _toast(context, err ?? 'Saved');
  }

  void _saveAll(BuildContext context, WidgetRef ref) {
    final files = ref.read(editorProvider).openFiles;
    for (final f in files) {
      ref.read(editorProvider.notifier).saveFile(f.path);
    }
    _toast(context, 'Saved all files');
  }

  Future<void> _newFile(BuildContext context, WidgetRef ref) async {
    final name = await _promptName(context, 'New File', 'e.g. main.dart');
    if (name == null || name.isEmpty) return;
    final root = ref.read(workspaceProvider);
    if (root == null) return;
    final path = p.join(root, name);
    try {
      final file = File(path);
      if (file.existsSync()) {
        if (context.mounted) _toast(context, 'File already exists');
        return;
      }
      file.createSync(recursive: true);
      ref.read(explorerRefreshProvider.notifier).state++;
      ref.read(editorProvider.notifier).openFile(path);
    } catch (e) {
      if (context.mounted) _toast(context, 'Cannot create file: $e');
    }
  }

  Future<void> _newFolder(BuildContext context, WidgetRef ref) async {
    final name = await _promptName(context, 'New Folder', 'e.g. widgets');
    if (name == null || name.isEmpty) return;
    final root = ref.read(workspaceProvider);
    if (root == null) return;
    try {
      Directory(p.join(root, name)).createSync(recursive: true);
      ref.read(explorerRefreshProvider.notifier).state++;
    } catch (e) {
      if (context.mounted) _toast(context, 'Cannot create folder: $e');
    }
  }

  Future<String?> _promptName(
      BuildContext context, String title, String hint) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(hintText: hint),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
  }

  void _about(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Nadira Shakila', style: TextStyle(fontSize: 16)),
        content: const Text(
          'An AI coding assistant IDE built with Flutter.\nPowered by HidePulsa AI.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }
}

/// VS Code-style centered command box showing the project name.
class _CommandPalette extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final root = ref.watch(workspaceProvider);
    final name = root != null ? p.basename(root) : 'Nadira Shakila';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => showQuickOpen(context, ref),
          child: Container(
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Codicons.search, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom window control buttons (minimize / maximize-restore / close).
class _WindowButtons extends StatefulWidget {
  const _WindowButtons();

  @override
  State<_WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<_WindowButtons> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _sync();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _sync() async {
    final m = await windowManager.isMaximized();
    if (mounted) setState(() => _maximized = m);
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _WinBtn(
          icon: Icons.minimize,
          onTap: () => windowManager.minimize(),
        ),
        _WinBtn(
          icon: _maximized ? Icons.filter_none : Icons.crop_square,
          iconSize: _maximized ? 11 : 13,
          onTap: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
        ),
        _WinBtn(
          icon: Icons.close,
          hoverColor: const Color(0xFFE81123),
          onTap: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _WinBtn extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final Color? hoverColor;
  final VoidCallback onTap;

  const _WinBtn({
    required this.icon,
    this.iconSize = 14,
    this.hoverColor,
    required this.onTap,
  });

  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 34,
          color: _hovered
              ? (widget.hoverColor ?? AppColors.surfaceHover)
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: (_hovered && widget.hoverColor != null)
                ? Colors.white
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
