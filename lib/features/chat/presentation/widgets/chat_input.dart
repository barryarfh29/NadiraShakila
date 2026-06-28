import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/codicons.dart';
import '../../../workspace/providers/workspace_provider.dart';
import '../providers/attached_context.dart';
import '../providers/attached_images.dart';
import '../providers/chat_provider.dart';
import 'model_selector.dart';

/// Chat input area styled like Kiro AI
class ChatInput extends ConsumerStatefulWidget {
  const ChatInput({super.key});

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isComposing = false;
  String _lastText = '';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final isStreaming = ref.read(isStreamingProvider);
    if (isStreaming) return;

    _controller.clear();
    setState(() => _isComposing = false);

    ref.read(chatControllerProvider).sendMessage(text);
  }

  /// Detects the Kiro-style `#` mention: when the user types `#`, strip it and
  /// open the context picker so they can attach a file/folder/source.
  void _onTextChanged(String text) {
    final added = text.length == _lastText.length + 1;
    final sel = _controller.selection.baseOffset;
    final justTypedHash =
        added && sel > 0 && sel <= text.length && text[sel - 1] == '#';

    setState(() => _isComposing = text.trim().isNotEmpty);

    if (justTypedHash) {
      // Remove the '#' character that triggered the picker.
      final stripped = text.substring(0, sel - 1) + text.substring(sel);
      _controller.text = stripped;
      _controller.selection = TextSelection.collapsed(offset: sel - 1);
      _lastText = stripped;
      _openMentionPicker();
    } else {
      _lastText = text;
    }
  }

  void _openMentionPicker() {
    final root = ref.read(workspaceProvider);
    showDialog<void>(
      context: context,
      builder: (_) => _ContextPickerDialog(root: root),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyV) {
      _handlePaste();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        return KeyEventResult.ignored;
      } else {
        _handleSubmit();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Ctrl+V: if the clipboard holds an image (e.g. a screenshot), attach it as
  /// a vision input; otherwise paste text at the caret.
  Future<void> _handlePaste() async {
    try {
      final img = await Pasteboard.image;
      if (img != null && img.isNotEmpty) {
        ref
            .read(attachedImagesProvider.notifier)
            .add('pasted.png', img, '.png');
        return;
      }
    } catch (_) {}

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    final base = _controller.text;
    final sel = _controller.selection;
    final start = sel.start < 0 ? base.length : sel.start;
    final end = sel.end < 0 ? base.length : sel.end;
    final newText = base.replaceRange(start, end, text);
    _controller.text = newText;
    _controller.selection =
        TextSelection.collapsed(offset: start + text.length);
    setState(() => _isComposing = newText.trim().isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final isStreaming = ref.watch(isStreamingProvider);

    // Fill the input when a suggestion card / draft is requested.
    ref.listen<String?>(chatInputDraftProvider, (prev, next) {
      if (next != null) {
        _controller.text = next;
        _controller.selection =
            TextSelection.collapsed(offset: _controller.text.length);
        setState(() => _isComposing = next.trim().isNotEmpty);
        _focusNode.requestFocus();
        ref.read(chatInputDraftProvider.notifier).state = null;
      }
    });

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active-file context pill (shows what the AI can "see")
          const _ContextBar(),
          // Input container
          Container(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 180),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focusNode.hasFocus
                    ? AppColors.borderFocus
                    : AppColors.border,
              ),
              boxShadow: [
                if (_focusNode.hasFocus)
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Text field
                Flexible(
                  child: Focus(
                    onKeyEvent: _handleKeyEvent,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: null,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      cursorColor: AppColors.primary,
                      cursorWidth: 1.5,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Ask anything... (Shift+Enter for new line)',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        filled: true,
                        contentPadding: EdgeInsets.fromLTRB(14, 12, 14, 4),
                        isDense: true,
                      ),
                      onChanged: _onTextChanged,
                    ),
                  ),
                ),

                // Bottom toolbar
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                  child: Row(
                    children: [
                      // Add-context button (Kiro-style '#')
                      const _ContextAddButton(),
                      const SizedBox(width: 4),
                      const _ImageAddButton(),
                      const SizedBox(width: 4),
                      // Chat / Agent mode toggle
                      const _AgentModeToggle(),

                      const Spacer(),

                      // Model selector
                      const Flexible(child: ModelSelectorChip()),
                      const SizedBox(width: 8),

                      // Send/Stop button
                      isStreaming
                          ? _buildStopButton()
                          : _buildSendButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footer hint
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Nadira Shakila • Powered by HidePulsa AI',
              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    final enabled = _isComposing;
    return GestureDetector(
      onTap: enabled ? _handleSubmit : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryHover],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : AppColors.surfaceLight,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Codicons.arrowUp,
          size: 16,
          color: enabled ? Colors.white : AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return GestureDetector(
      onTap: () => ref.read(chatControllerProvider).stopStreaming(),
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: AppColors.error,
          shape: BoxShape.circle,
        ),
        child: const Icon(Codicons.stop, size: 16, color: Colors.white),
      ),
    );
  }
}

/// Shows context pills: the active editor file plus any explicitly attached
/// files/folders (Kiro-style).
class _ContextBar extends ConsumerWidget {
  const _ContextBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFile = ref.watch(editorProvider).activeFile;
    final attached = ref.watch(attachedContextProvider);
    final images = ref.watch(attachedImagesProvider);

    if (activeFile == null && attached.isEmpty && images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (activeFile != null)
            _Pill(
              icon: Codicons.file,
              label: activeFile.name,
              suffix: 'Current file',
            ),
          for (final item in attached)
            _Pill(
              icon: _iconForKind(item),
              label: item.name,
              onRemove: () => ref
                  .read(attachedContextProvider.notifier)
                  .removeItem(item),
            ),
          for (var i = 0; i < images.length; i++)
            _Pill(
              icon: Icons.image_outlined,
              label: images[i].name,
              onRemove: () =>
                  ref.read(attachedImagesProvider.notifier).removeAt(i),
            ),
        ],
      ),
    );
  }

  IconData _iconForKind(ContextItem item) {
    switch (item.kind) {
      case ContextKind.folder:
        return Codicons.folder;
      case ContextKind.problems:
        return Icons.error_outline;
      case ContextKind.terminal:
        return Codicons.terminal;
      case ContextKind.codebase:
        return Icons.account_tree_outlined;
      case ContextKind.file:
        return Codicons.file;
    }
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? suffix;
  final VoidCallback? onRemove;

  const _Pill({
    required this.icon,
    required this.label,
    this.suffix,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 4),
            Text(
              suffix!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
            const SizedBox(width: 4),
          ],
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.only(left: 2, right: 2),
                child: Icon(Codicons.close, size: 11, color: AppColors.textMuted),
              ),
            )
          else
            const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Toggles between plain Chat mode and autonomous Agent mode.
class _AgentModeToggle extends ConsumerWidget {
  const _AgentModeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentMode = ref.watch(agentModeProvider);
    final hasWorkspace = ref.watch(workspaceProvider) != null;

    return Tooltip(
      message: agentMode
          ? (hasWorkspace
              ? 'Agent can read, edit & run in your workspace'
              : 'Open a folder to let the agent edit files')
          : 'Plain chat. Click to enable Agent mode.',
      child: InkWell(
        onTap: () => ref.read(agentModeProvider.notifier).state = !agentMode,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: agentMode
                ? AppColors.primary.withValues(alpha: 0.15)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: agentMode ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                agentMode ? Codicons.sparkle : Codicons.comment,
                size: 13,
                color: agentMode ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                agentMode ? 'Agent' : 'Chat',
                style: TextStyle(
                  color:
                      agentMode ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (agentMode && !hasWorkspace) ...[
                const SizedBox(width: 4),
                const Icon(Icons.warning_amber_rounded,
                    size: 12, color: AppColors.warning),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Button to attach image(s) to the next message (sent to the AI as vision).
class _ImageAddButton extends ConsumerWidget {
  const _ImageAddButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: 'Attach image (foto / screenshot)',
      child: GestureDetector(
        onTap: () => _pick(ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Icons.image_outlined,
              size: 15, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Future<void> _pick(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null) return;
    final notifier = ref.read(attachedImagesProvider.notifier);
    for (final f in result.files) {
      if (f.bytes != null) {
        notifier.add(f.name, f.bytes!, p.extension(f.name));
      }
    }
  }
}

/// Kiro-style '#' button that opens a searchable picker to attach a workspace
/// file or folder as chat context.
class _ContextAddButton extends ConsumerWidget {
  const _ContextAddButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasWorkspace = ref.watch(workspaceProvider) != null;
    return Tooltip(
      message: hasWorkspace
          ? 'Add file, folder or source as context'
          : 'Add a source as context (open a folder for files)',
      child: GestureDetector(
        onTap: () => _openPicker(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Codicons.add,
              size: 15, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final root = ref.read(workspaceProvider);
    await showDialog<void>(
      context: context,
      builder: (_) => _ContextPickerDialog(root: root),
    );
  }
}

class _ContextPickerDialog extends ConsumerStatefulWidget {
  final String? root;
  const _ContextPickerDialog({required this.root});

  @override
  ConsumerState<_ContextPickerDialog> createState() =>
      _ContextPickerDialogState();
}

class _ContextPickerDialogState extends ConsumerState<_ContextPickerDialog> {
  late final List<String> _all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _all = widget.root == null ? <String>[] : listWorkspaceFiles(widget.root!);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? _all.take(60).toList()
        : _all.where((f) => f.toLowerCase().contains(q)).take(60).toList();

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: 520,
        height: 460,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Search files, or pick a source (#)...',
                  isDense: true,
                  prefixIcon: Icon(Codicons.search, size: 15),
                  prefixIconConstraints:
                      BoxConstraints(minWidth: 34, minHeight: 34),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Builder(
                builder: (context) {
                  // Special context sources (filtered by the same query).
                  final specials = <(ContextKind, String, IconData)>[
                    (
                      ContextKind.codebase,
                      'Codebase',
                      Icons.account_tree_outlined
                    ),
                    (ContextKind.problems, 'Problems', Icons.error_outline),
                    (ContextKind.terminal, 'Terminal', Codicons.terminal),
                  ]
                      .where((s) =>
                          q.isEmpty || s.$2.toLowerCase().contains(q))
                      .toList();

                  if (specials.isEmpty && filtered.isEmpty) {
                    return const Center(
                      child: Text('No results',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    );
                  }

                  return ListView(
                    children: [
                      if (specials.isNotEmpty) ...[
                        const _PickerHeader('Sources'),
                        for (final s in specials)
                          _SourceRow(
                            icon: s.$3,
                            label: s.$2,
                            onTap: () {
                              ref
                                  .read(attachedContextProvider.notifier)
                                  .addKind(s.$1);
                              Navigator.of(context).pop();
                            },
                          ),
                      ],
                      if (filtered.isNotEmpty) ...[
                        const _PickerHeader('Files'),
                        for (final rel in filtered)
                          _PickerRow(
                            rel: rel,
                            onTap: () {
                              ref
                                  .read(attachedContextProvider.notifier)
                                  .add(p.join(widget.root!, rel), false);
                              Navigator.of(context).pop();
                            },
                          ),
                      ],
                    ],
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

class _PickerRow extends StatefulWidget {
  final String rel;
  final VoidCallback onTap;
  const _PickerRow({required this.rel, required this.onTap});

  @override
  State<_PickerRow> createState() => _PickerRowState();
}

class _PickerRowState extends State<_PickerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final name = p.basename(widget.rel);
    final dir = p.dirname(widget.rel);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _hovered ? AppColors.surfaceHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              const Icon(Codicons.file, size: 13, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(name,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 12.5)),
              const SizedBox(width: 8),
              if (dir != '.')
                Expanded(
                  child: Text(dir,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 10.5)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  final String label;
  const _PickerHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SourceRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceRow(
      {required this.icon, required this.label, required this.onTap});

  @override
  State<_SourceRow> createState() => _SourceRowState();
}

class _SourceRowState extends State<_SourceRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _hovered ? AppColors.surfaceHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            children: [
              Icon(widget.icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}
