import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/codicons.dart';
import 'terminal_provider.dart';
import 'terminal_sessions.dart';

/// VS Code-style integrated terminal supporting multiple sessions (tabs).
class TerminalPanel extends ConsumerStatefulWidget {
  const TerminalPanel({super.key});

  @override
  ConsumerState<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends ConsumerState<TerminalPanel> {
  @override
  void initState() {
    super.initState();
    // Ensure one terminal exists when the panel first opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(terminalSessionsProvider.notifier).ensureSession();
    });
  }

  void _copyAllLogs(Terminal terminal) {
    final buffer = terminal.buffer;
    final lines = <String>[];
    
    // Ambil semua lines dari buffer terminal
    for (int i = 0; i < buffer.lines.length; i++) {
      final line = buffer.lines[i];
      final text = line.toString();
      if (text.isNotEmpty) {
        lines.add(text);
      }
    }
    
    final allText = lines.join('\n');
    if (allText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: allText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terminal logs copied to clipboard'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.surfaceVariant,
        ),
      );
    }
  }

  void _copySelection(Terminal terminal) {
    // xterm package doesn't expose selection directly, so we copy all logs
    _copyAllLogs(terminal);
  }

  Future<void> _pasteFromClipboard(Terminal terminal) async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) {
      terminal.textInput(data.text!);
    }
  }

  void _clearTerminal(Terminal terminal) {
    terminal.write('\x1b[2J\x1b[H'); // Clear screen and move cursor to home
  }

  void _showContextMenu(BuildContext context, Offset position, Terminal terminal) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      color: AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      items: <PopupMenuEntry>[
        PopupMenuItem(
          height: 36,
          onTap: () => _copySelection(terminal),
          child: const Row(
            children: [
              Icon(Codicons.copy, size: 13, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Copy Selection',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5)),
              Spacer(),
              Text('Ctrl+Shift+C',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
        PopupMenuItem(
          height: 36,
          onTap: () => _copyAllLogs(terminal),
          child: const Row(
            children: [
              Icon(Codicons.copy, size: 13, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Copy All Logs',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5)),
            ],
          ),
        ),
        PopupMenuItem(
          height: 36,
          onTap: () => _pasteFromClipboard(terminal),
          child: const Row(
            children: [
              Icon(Codicons.edit, size: 13, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Paste',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5)),
              Spacer(),
              Text('Ctrl+Shift+V',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          height: 36,
          onTap: () => _clearTerminal(terminal),
          child: const Row(
            children: [
              Icon(Codicons.trash, size: 13, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Clear Terminal',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5)),
              Spacer(),
              Text('Ctrl+L',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(terminalSessionsProvider);
    final notifier = ref.read(terminalSessionsProvider.notifier);

    // Run a queued command (e.g. from Run & Debug).
    ref.listen(pendingTerminalCommandProvider, (prev, next) {
      if (next != null && next.isNotEmpty) {
        notifier.runCommand(next);
        ref.read(pendingTerminalCommandProvider.notifier).state = null;
      }
    });

    final active = state.active;

    return Container(
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(
            child: active == null
                ? const SizedBox.shrink()
                : GestureDetector(
                    onSecondaryTapDown: (details) {
                      _showContextMenu(context, details.globalPosition, active.terminal);
                    },
                    child: Shortcuts(
                      shortcuts: const {
                        SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true):
                            _CopyIntent(),
                        SingleActivator(LogicalKeyboardKey.keyV, control: true, shift: true):
                            _PasteIntent(),
                        SingleActivator(LogicalKeyboardKey.keyL, control: true):
                            _ClearIntent(),
                      },
                      child: Actions(
                        actions: {
                          _CopyIntent: CallbackAction<_CopyIntent>(
                            onInvoke: (_) { _copySelection(active.terminal); return null; },
                          ),
                          _PasteIntent: CallbackAction<_PasteIntent>(
                            onInvoke: (_) { _pasteFromClipboard(active.terminal); return null; },
                          ),
                          _ClearIntent: CallbackAction<_ClearIntent>(
                            onInvoke: (_) { _clearTerminal(active.terminal); return null; },
                          ),
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: TerminalView(
                            active.terminal,
                            autofocus: true,
                            theme: _terminalTheme,
                            textStyle: const TerminalStyle(
                              fontSize: 13,
                              fontFamily: 'JetBrains Mono',
                            ),
                            padding: const EdgeInsets.all(4),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          // Right-hand session list (like VS Code's terminal tabs).
          Container(
            width: 150,
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 28,
                  padding: const EdgeInsets.only(left: 10, right: 4),
                  child: Row(
                    children: [
                      const Text(
                        'TERMINALS',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      // Copy all logs button
                      if (active != null)
                        Tooltip(
                          message: 'Copy All Logs',
                          child: GestureDetector(
                            onTap: () => _copyAllLogs(active.terminal),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Codicons.copy,
                                  size: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      PopupMenuButton<String>(
                        tooltip: 'New Terminal',
                        offset: const Offset(0, 24),
                        color: AppColors.surfaceVariant,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        onSelected: (path) =>
                            notifier.newSession(shellPath: path),
                        itemBuilder: (context) => [
                          for (final s in notifier.availableShells())
                            PopupMenuItem(
                              value: s.path,
                              height: 36,
                              child: Row(
                                children: [
                                  const Icon(Codicons.terminal,
                                      size: 13, color: AppColors.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(s.label,
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 12.5)),
                                ],
                              ),
                            ),
                        ],
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Codicons.add,
                              size: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final s in state.sessions)
                        _SessionRow(
                          session: s,
                          active: s.id == state.activeId,
                          onTap: () => notifier.setActive(s.id),
                          onClose: () => notifier.close(s.id),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TerminalTheme get _terminalTheme => const TerminalTheme(
        cursor: AppColors.primary,
        selection: Color(0x40007ACC),
        foreground: AppColors.textPrimary,
        background: AppColors.background,
        black: Color(0xFF1E1E1E),
        red: Color(0xFFF14C4C),
        green: Color(0xFF89D185),
        yellow: Color(0xFFCCA700),
        blue: Color(0xFF569CD6),
        magenta: Color(0xFFC586C0),
        cyan: Color(0xFF4EC9B0),
        white: Color(0xFFD4D4D4),
        brightBlack: Color(0xFF858585),
        brightRed: Color(0xFFF14C4C),
        brightGreen: Color(0xFF89D185),
        brightYellow: Color(0xFFCCA700),
        brightBlue: Color(0xFF75BEFF),
        brightMagenta: Color(0xFFC586C0),
        brightCyan: Color(0xFF4EC9B0),
        brightWhite: Color(0xFFFFFFFF),
        searchHitBackground: Color(0xFFCCA700),
        searchHitBackgroundCurrent: Color(0xFF007ACC),
        searchHitForeground: Color(0xFF1E1E1E),
      );
}

class _SessionRow extends StatefulWidget {
  final TerminalSession session;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _SessionRow({
    required this.session,
    required this.active,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_SessionRow> createState() => _SessionRowState();
}

class _SessionRowState extends State<_SessionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 26,
          padding: const EdgeInsets.only(left: 10, right: 4),
          color: widget.active
              ? AppColors.surfaceVariant
              : (_hovered ? AppColors.surfaceHover : Colors.transparent),
          child: Row(
            children: [
              const Icon(Codicons.terminal,
                  size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${widget.session.title} ${widget.session.id}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ),
              if (_hovered || widget.active)
                GestureDetector(
                  onTap: widget.onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Codicons.close,
                        size: 11, color: AppColors.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Intent classes for keyboard shortcuts
class _CopyIntent extends Intent {
  const _CopyIntent();
}

class _PasteIntent extends Intent {
  const _PasteIntent();
}

class _ClearIntent extends Intent {
  const _ClearIntent();
}
