import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/codicons.dart';
import '../../chat/presentation/providers/chat_provider.dart';
import '../../diagnostics/diagnostics_provider.dart';
import '../../hooks/hooks_provider.dart';
import '../../ide/quick_open.dart';
import '../data/editor_file.dart';
import '../providers/workspace_provider.dart';
import 'code_highlight_controller.dart';
import 'file_explorer.dart';
import 'file_icon.dart';

/// Tracks the caret position (line, column) of the active editor for the
/// status bar. 1-based.
final cursorPositionProvider =
    StateProvider<({int line, int col})>((ref) => (line: 1, col: 1));

/// When set, the active editor inserts this text at its caret (used by the
/// "Insert" button on AI code blocks). Cleared after insertion.
final editorInsertProvider = StateProvider<String?>((ref) => null);

/// The editor group: tab bar + active code editor.
class EditorArea extends ConsumerWidget {
  const EditorArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editor = ref.watch(editorProvider);

    if (editor.openFiles.isEmpty) {
      return const _EmptyEditor();
    }

    return Column(
      children: [
        _TabBar(
          files: editor.openFiles,
          activePath: editor.activePath,
        ),
        if (editor.activeFile != null)
          _Breadcrumb(path: editor.activeFile!.path),
        Expanded(
          child: editor.activeFile == null
              ? const _EmptyEditor()
              : editor.splitFile == null
                  ? _CodeEditor(
                      key: ValueKey(editor.activeFile!.path),
                      file: editor.activeFile!,
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _CodeEditor(
                            key: ValueKey(editor.activeFile!.path),
                            file: editor.activeFile!,
                          ),
                        ),
                        const VerticalDivider(
                            width: 1, color: AppColors.border),
                        Expanded(
                          child: _SplitPane(file: editor.splitFile!),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

/// The right-hand split editor pane with a small header.
class _SplitPane extends ConsumerWidget {
  final EditorFile file;
  const _SplitPane({required this.file});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Container(
          height: 28,
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              FileIcon(fileName: file.name, size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  file.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              Tooltip(
                message: 'Close split',
                child: InkWell(
                  onTap: () => ref.read(editorProvider.notifier).closeSplit(),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(Codicons.close,
                        size: 13, color: AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _CodeEditor(
            key: ValueKey('split-${file.path}'),
            file: file,
          ),
        ),
      ],
    );
  }
}

/// VS Code-style breadcrumb showing the path of the active file.
class _Breadcrumb extends ConsumerWidget {
  final String path;
  const _Breadcrumb({required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final root = ref.watch(workspaceProvider);
    final rel = root != null ? p.relative(path, from: root) : path;
    final segments = p.split(rel);

    return Container(
      height: 24,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i == segments.length - 1)
              FileIcon(fileName: segments[i], size: 13)
            else
              const Icon(Codicons.folder,
                  size: 12, color: Color(0xFF90A4AE)),
            const SizedBox(width: 4),
            Text(
              segments[i],
              style: TextStyle(
                color: i == segments.length - 1
                    ? AppColors.textSecondary
                    : AppColors.textMuted,
                fontSize: 12,
              ),
            ),
            if (i < segments.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Codicons.chevronRight,
                    size: 12, color: AppColors.textMuted),
              ),
          ],
        ],
      ),
    );
  }
}

class _EmptyEditor extends ConsumerWidget {
  const _EmptyEditor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.background,
      alignment: const Alignment(0, -0.18),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                ),
                const SizedBox(width: 14),
                const _Wordmark(),
              ],
            ),
            const SizedBox(height: 14),
            Transform.translate(
              offset: const Offset(-34, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ShortcutRow(
                    label: 'Open Folder',
                    keys: const ['Ctrl', 'O'],
                    highlight: true,
                    onTap: () => openWorkspaceFolder(context, ref),
                  ),
                  _ShortcutRow(
                    label: 'Go to File',
                    keys: const ['Ctrl', 'P'],
                    onTap: () => showQuickOpen(context, ref),
                  ),
                  const _ShortcutRow(label: 'Find', keys: ['Ctrl', 'F']),
                  const _ShortcutRow(label: 'Replace', keys: ['Ctrl', 'H']),
                  const _ShortcutRow(label: 'Save File', keys: ['Ctrl', 'S']),
                  const _ShortcutRow(
                      label: 'Toggle Terminal', keys: ['Ctrl', '`']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/wordmark.png',
      height: 54,
      fit: BoxFit.contain,
    );
  }
}

class _ShortcutRow extends StatefulWidget {
  final String label;
  final List<String> keys;
  final VoidCallback? onTap;
  final bool highlight;

  const _ShortcutRow({
    required this.label,
    required this.keys,
    this.onTap,
    this.highlight = false,
  });

  @override
  State<_ShortcutRow> createState() => _ShortcutRowState();
}

class _ShortcutRowState extends State<_ShortcutRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final clickable = widget.onTap != null;
    final Color labelColor = widget.highlight
        ? (_hovered ? AppColors.primaryLight : AppColors.primary)
        : (_hovered ? AppColors.textPrimary : AppColors.textSecondary);
    return MouseRegion(
      cursor: clickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 200,
                child: Text(
                  widget.label,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              for (int i = 0; i < widget.keys.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _KeyCap(widget.keys[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  final String label;
  const _KeyCap(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Closes a tab, prompting to save first if it has unsaved changes.
Future<void> _confirmCloseTab(
    BuildContext context, WidgetRef ref, EditorFile file) async {
  if (!file.isDirty) {
    ref.read(editorProvider.notifier).closeFile(file.path);
    return;
  }
  final choice = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text('Simpan perubahan pada ${file.name}?',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      content: const Text(
        'Perubahan Anda akan hilang jika tidak disimpan.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('cancel'),
          child: const Text('Batal',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop('discard'),
          child: const Text('Jangan Simpan',
              style: TextStyle(color: AppColors.error)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop('save'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
  if (choice == null || choice == 'cancel') return;
  final notifier = ref.read(editorProvider.notifier);
  if (choice == 'save') {
    notifier.saveFile(file.path);
  }
  notifier.closeFile(file.path);
}

class _TabBar extends ConsumerWidget {
  final List<EditorFile> files;
  final String? activePath;

  const _TabBar({required this.files, required this.activePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) => ref
                  .read(editorProvider.notifier)
                  .reorderTabs(oldIndex, newIndex),
              itemCount: files.length,
              itemBuilder: (context, i) {
                final file = files[i];
                return ReorderableDragStartListener(
                  key: ValueKey(file.path),
                  index: i,
                  child: _Tab(
                    file: file,
                    isActive: file.path == activePath,
                    onTap: () =>
                        ref.read(editorProvider.notifier).setActive(file.path),
                    onClose: () => _confirmCloseTab(context, ref, file),
                    onCloseOthers: () => ref
                        .read(editorProvider.notifier)
                        .closeOthers(file.path),
                    onCloseAll: () =>
                        ref.read(editorProvider.notifier).closeAll(),
                    onSplit: () =>
                        ref.read(editorProvider.notifier).toggleSplit(),
                  ),
                );
              },
            ),
          ),
          Tooltip(
            message: 'Split Editor',
            child: InkWell(
              onTap: () => ref.read(editorProvider.notifier).toggleSplit(),
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.splitscreen_outlined,
                    size: 15, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  final EditorFile file;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onCloseOthers;
  final VoidCallback onCloseAll;
  final VoidCallback onSplit;

  const _Tab({
    required this.file,
    required this.isActive,
    required this.onTap,
    required this.onClose,
    required this.onCloseOthers,
    required this.onCloseAll,
    required this.onSplit,
  });

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hovered = false;

  Future<void> _showMenu(BuildContext context, Offset pos) async {
    final selected = await showMenu<String>(
      context: context,
      color: AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
      items: const [
        PopupMenuItem(
            value: 'close',
            height: 34,
            child: Text('Close',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5))),
        PopupMenuItem(
            value: 'others',
            height: 34,
            child: Text('Close Others',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5))),
        PopupMenuItem(
            value: 'all',
            height: 34,
            child: Text('Close All',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5))),
        PopupMenuDivider(),
        PopupMenuItem(
            value: 'split',
            height: 34,
            child: Text('Split Editor',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5))),
      ],
    );
    switch (selected) {
      case 'close':
        widget.onClose();
        break;
      case 'others':
        widget.onCloseOthers();
        break;
      case 'all':
        widget.onCloseAll();
        break;
      case 'split':
        widget.onSplit();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: (d) => _showMenu(context, d.globalPosition),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.background
                : AppColors.surface,
            border: Border(
              right: const BorderSide(color: AppColors.border),
              top: BorderSide(
                color: widget.isActive
                    ? AppColors.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FileIcon(fileName: widget.file.name, size: 15),
              const SizedBox(width: 6),
              Text(
                widget.file.name,
                style: TextStyle(
                  color: widget.isActive
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 16,
                height: 16,
                child: (widget.file.isDirty && !_hovered)
                    ? const Center(
                        child: Icon(Icons.circle,
                            size: 8, color: AppColors.textSecondary),
                      )
                    : InkWell(
                        onTap: widget.onClose,
                        borderRadius: BorderRadius.circular(4),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: _hovered
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeEditor extends ConsumerStatefulWidget {
  final EditorFile file;
  const _CodeEditor({super.key, required this.file});

  @override
  ConsumerState<_CodeEditor> createState() => _CodeEditorState();
}

class _CodeEditorState extends ConsumerState<_CodeEditor> {
  late final CodeHighlightController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scroll = ScrollController();

  // Find / Replace state.
  bool _showFind = false;
  bool _showReplace = false;
  final TextEditingController _findController = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();
  final FocusNode _findFocus = FocusNode();
  List<int> _matches = [];
  int _matchIndex = 0;

  // Auto-indent / auto-close support.
  bool _autoGuard = false;
  String _prevText = '';

  // Inline AI edit (Ctrl+I) state.
  bool _showInline = false;
  bool _inlineBusy = false;
  final TextEditingController _inlineController = TextEditingController();
  final FocusNode _inlineFocus = FocusNode();

  // Ghost text (autocomplete) state.
  Timer? _ghostTimer;
  bool _ghostFetching = false;
  String? _ghostText;
  // ignore: unused_field
  int _ghostOffset = -1;

  // Markdown preview toggle (for .md files).
  bool _mdPreview = false;
  bool get _isMarkdown =>
      p.extension(widget.file.name).toLowerCase() == '.md';

  @override
  void initState() {
    super.initState();
    _controller = CodeHighlightController(
      text: widget.file.content,
      language: CodeHighlightController.languageForFile(widget.file.name),
    );
    _controller.addListener(_onChanged);
    _prevText = widget.file.content;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(diagnosticsProvider.notifier).analyze(widget.file.path);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the file content changed underneath us (e.g. the agent edited it),
    // sync the controller without clobbering the user's caret unnecessarily.
    if (widget.file.content != _controller.text) {
      final offset =
          _controller.selection.baseOffset.clamp(0, widget.file.content.length);
      _controller.value = TextEditingValue(
        text: widget.file.content,
        selection: TextSelection.collapsed(offset: offset),
      );
      _prevText = widget.file.content;
    }
  }

  void _onChanged() {
    if (!_autoGuard) {
      _applyAutoEdits();
    }
    ref.read(editorProvider.notifier).updateContent(
          widget.file.path,
          _controller.text,
        );
    _updateCursor();
    _prevText = _controller.text;

    // Schedule ghost text suggestion after typing stops
    _dismissGhost();
    _ghostTimer?.cancel();
    _ghostTimer = Timer(const Duration(milliseconds: 1500), _fetchGhostText);
  }

  /// Detects a single typed character and applies auto-indent (Enter) and
  /// auto-close brackets.
  void _applyAutoEdits() {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isCollapsed) {
      return;
    }
    if (text.length != _prevText.length + 1) {
      return;
    }
    final pos = sel.baseOffset;
    if (pos <= 0 || pos > text.length) return;
    final ch = text[pos - 1];

    if (ch == '\n') {
      _autoIndent(pos);
    } else if (ch == '(' || ch == '[' || ch == '{') {
      _autoClose(pos, ch);
    }
  }

  void _autoIndent(int pos) {
    final text = _controller.text;
    final before = text.substring(0, pos - 1);
    final lineStart = before.lastIndexOf('\n') + 1;
    final prevLine = before.substring(lineStart);
    var indent = RegExp(r'^[ \t]*').firstMatch(prevLine)?.group(0) ?? '';
    final trimmed = prevLine.trimRight();
    if (trimmed.endsWith('{') ||
        trimmed.endsWith('(') ||
        trimmed.endsWith('[') ||
        trimmed.endsWith(':')) {
      indent += '  ';
    }
    if (indent.isEmpty) return;
    _autoGuard = true;
    _controller.value = TextEditingValue(
      text: text.substring(0, pos) + indent + text.substring(pos),
      selection: TextSelection.collapsed(offset: pos + indent.length),
    );
    _autoGuard = false;
  }

  void _autoClose(int pos, String open) {
    const pairs = {'(': ')', '[': ']', '{': '}'};
    final text = _controller.text;
    // Only auto-close when followed by whitespace, a closing char, or EOL.
    final next = pos < text.length ? text[pos] : '\n';
    if (!(next == '\n' ||
        next == ' ' ||
        next == '\t' ||
        ')]}'.contains(next))) {
      return;
    }
    _autoGuard = true;
    _controller.value = TextEditingValue(
      text: text.substring(0, pos) + pairs[open]! + text.substring(pos),
      selection: TextSelection.collapsed(offset: pos),
    );
    _autoGuard = false;
  }

  void _updateCursor() {
    final sel = _controller.selection;
    if (!sel.isValid) return;
    final offset = sel.baseOffset.clamp(0, _controller.text.length);
    final before = _controller.text.substring(0, offset);
    final line = '\n'.allMatches(before).length + 1;
    final lastNewline = before.lastIndexOf('\n');
    final col = offset - lastNewline;
    ref.read(cursorPositionProvider.notifier).state = (line: line, col: col);
  }

  // === Ghost text (inline autocomplete) ===

  void _dismissGhost() {
    setState(() {
      _ghostText = null;
      _ghostOffset = -1;
    });
  }

  bool _acceptGhost() {
    if (_ghostText == null || _ghostText!.isEmpty) return false;
    _insertAtCaret(_ghostText!);
    _dismissGhost();
    return true;
  }

  Future<void> _fetchGhostText() async {
    final api = ref.read(apiServiceProvider);
    if (api == null || _ghostFetching) return;
    _ghostFetching = true;

    try {
      final text = _controller.text;
      final sel = _controller.selection;
      if (!sel.isValid) return;
      final offset = sel.baseOffset.clamp(0, text.length);

      // Context: last 30 lines before cursor
      final before = text.substring(0, offset);
      final lines = before.split('\n');
      final ctx = (lines.length > 30 ? lines.sublist(lines.length - 30) : lines)
          .join('\n');

      // A few lines after cursor
      final after = text.substring(offset);
      final afterLines = after.split('\n');
      final afterCtx = (afterLines.length > 5
              ? afterLines.sublist(0, 5)
              : afterLines)
          .join('\n');

      final ext = p.extension(widget.file.name).replaceFirst('.', '');
      final prompt =
          'Continue this $ext code. Output ONLY the next 1-3 lines. '
          'No explanation, no fences, just raw code.\n\n'
          '```$ext\n$ctx\n```\n\nAfter cursor:\n```\n$afterCtx\n```';

      final model = _resolveModel();
      final result = await api.chatCompletion(
        messages: [
          {'role': 'user', 'content': prompt}
        ],
        model: model,
        temperature: 0.2,
        maxTokens: 100,
      );

      if (!mounted) return;

      var suggestion = result.trim();
      if (suggestion.startsWith('```')) {
        final nl = suggestion.indexOf('\n');
        if (nl != -1) suggestion = suggestion.substring(nl + 1);
        if (suggestion.endsWith('```')) {
          suggestion = suggestion.substring(0, suggestion.length - 3);
        }
      }
      suggestion = suggestion.trimRight();

      // Only show if cursor hasn't moved
      final curSel = _controller.selection;
      if (curSel.isValid && curSel.baseOffset == offset && suggestion.isNotEmpty) {
        setState(() {
          _ghostText = suggestion;
          _ghostOffset = offset;
        });
      }
    } catch (_) {
      // Silent fail
    } finally {
      _ghostFetching = false;
    }
  }

  // === End ghost text ===

  /// Moves the caret to the start of [line] (1-based) and focuses the editor.
  void _gotoLine(int line) {
    final lines = _controller.text.split('\n');
    var offset = 0;
    for (var i = 0; i < line - 1 && i < lines.length; i++) {
      offset += lines[i].length + 1;
    }
    offset = offset.clamp(0, _controller.text.length);
    _controller.selection = TextSelection.collapsed(offset: offset);
    _focusNode.requestFocus();
    // Approximate scroll to the matched line.
    if (_scroll.hasClients) {
      final lh = ref.read(editorFontSizeProvider) * 1.5;
      final target = ((line - 3) * lh)
          .clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _insertAtCaret(String text) {
    final base = _controller.text;
    final sel = _controller.selection;
    final start = sel.start < 0 ? base.length : sel.start;
    final end = sel.end < 0 ? base.length : sel.end;
    _controller.value = TextEditingValue(
      text: base.replaceRange(start, end, text),
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _focusNode.requestFocus();
  }

  // === Inline AI edit (Ctrl+I) ===

  void _openInline() {
    setState(() {
      _showInline = true;
      _inlineController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inlineFocus.requestFocus();
    });
  }

  void _closeInline() {
    setState(() {
      _showInline = false;
      _inlineBusy = false;
    });
    _focusNode.requestFocus();
  }

  /// Returns the currently selected range, or the whole document if there is
  /// no selection.
  (int, int, String, bool) _inlineTarget() {
    final sel = _controller.selection;
    final full = _controller.text;
    if (sel.isValid && !sel.isCollapsed) {
      final s = sel.start.clamp(0, full.length);
      final e = sel.end.clamp(0, full.length);
      return (s, e, full.substring(s, e), false);
    }
    return (0, full.length, full, true);
  }

  Future<void> _submitInline() async {
    final instruction = _inlineController.text.trim();
    if (instruction.isEmpty || _inlineBusy) return;

    final api = ref.read(apiServiceProvider);
    if (api == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('API key belum dikonfigurasi.'),
        duration: Duration(seconds: 2),
      ));
      return;
    }

    final (start, end, target, wholeFile) = _inlineTarget();
    setState(() => _inlineBusy = true);

    final lang = CodeHighlightController.languageForFile(widget.file.name);
    final region = wholeFile ? 'entire file' : 'selected region';
    final prompt = 'You are editing a code file. Apply the user\'s '
        'instruction to the code below.\n\n'
        'Instruction: $instruction\n\n'
        'Code ($region, language: $lang):\n'
        '```\n$target\n```\n\n'
        'Return ONLY the rewritten code that should replace the $region. '
        'Do NOT add explanations. Do NOT wrap it in markdown fences.';

    String result;
    try {
      result = await api.chatCompletion(
        messages: [
          {'role': 'user', 'content': prompt}
        ],
        model: _resolveModel(),
        maxTokens: 4096,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _inlineBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal: $e'),
        duration: const Duration(seconds: 2),
      ));
      return;
    }

    if (!mounted) return;
    final newCode = _stripFences(result.trim());
    setState(() => _inlineBusy = false);

    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => _InlineDiffDialog(
        oldCode: target,
        newCode: newCode,
        instruction: instruction,
      ),
    );

    if (accepted == true && mounted) {
      final full = _controller.text;
      final s = start.clamp(0, full.length);
      final e = end.clamp(0, full.length);
      _controller.value = TextEditingValue(
        text: full.substring(0, s) + newCode + full.substring(e),
        selection: TextSelection.collapsed(offset: s + newCode.length),
      );
      _closeInline();
    }
  }

  String _resolveModel() {
    final m = ref.read(selectedModelProvider);
    return m == 'auto' ? 'kr/claude-sonnet-4.5' : m;
  }

  String _stripFences(String s) {
    if (s.startsWith('```')) {
      final nl = s.indexOf('\n');
      if (nl != -1) s = s.substring(nl + 1);
      if (s.endsWith('```')) s = s.substring(0, s.length - 3);
    }
    return s.trim();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    // Tab: accept ghost text suggestion
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.tab &&
        _ghostText != null) {
      _acceptGhost();
      return KeyEventResult.handled;
    }

    // Escape: dismiss ghost text
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _ghostText != null) {
      _dismissGhost();
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent &&
        isCtrl &&
        event.logicalKey == LogicalKeyboardKey.keyI) {
      _openInline();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        isCtrl &&
        event.logicalKey == LogicalKeyboardKey.keyS) {
      final err =
          ref.read(editorProvider.notifier).saveFile(widget.file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Saved ${widget.file.name}'),
            duration: const Duration(seconds: 1),
          ),
        );
        ref.read(diagnosticsProvider.notifier).analyze(widget.file.path);
      }
      runSaveHooks(ref, widget.file.path);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        isCtrl &&
        event.logicalKey == LogicalKeyboardKey.keyF) {
      _openFind(replace: false);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        isCtrl &&
        event.logicalKey == LogicalKeyboardKey.keyH) {
      _openFind(replace: true);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _showInline) {
      _closeInline();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _showFind) {
      setState(() => _showFind = false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _openFind({required bool replace}) {
    setState(() {
      _showFind = true;
      _showReplace = replace;
    });
    // Seed with current selection if any.
    final sel = _controller.selection;
    if (sel.isValid && !sel.isCollapsed) {
      _findController.text = _controller.text.substring(
          sel.start.clamp(0, _controller.text.length),
          sel.end.clamp(0, _controller.text.length));
      _computeMatches();
    }
    _findFocus.requestFocus();
  }

  void _computeMatches() {
    final query = _findController.text;
    if (query.isEmpty) {
      setState(() {
        _matches = [];
        _matchIndex = 0;
      });
      return;
    }
    final text = _controller.text.toLowerCase();
    final q = query.toLowerCase();
    final found = <int>[];
    var start = 0;
    while (true) {
      final idx = text.indexOf(q, start);
      if (idx < 0) break;
      found.add(idx);
      start = idx + q.length;
    }
    setState(() {
      _matches = found;
      _matchIndex = 0;
    });
    if (found.isNotEmpty) _goToMatch(0);
  }

  void _goToMatch(int i) {
    if (_matches.isEmpty) return;
    final clamped = i % _matches.length;
    final offset = _matches[clamped];
    final len = _findController.text.length;
    _controller.selection =
        TextSelection(baseOffset: offset, extentOffset: offset + len);
    // Scroll the editor to the matched line.
    final before = _controller.text.substring(0, offset);
    final line = '\n'.allMatches(before).length + 1;
    if (_scroll.hasClients) {
      final lh = ref.read(editorFontSizeProvider) * 1.5;
      final target = ((line - 4) * lh)
          .clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    }
    setState(() => _matchIndex = clamped);
  }

  void _nextMatch() => _goToMatch(_matchIndex + 1);
  void _prevMatch() =>
      _goToMatch(_matchIndex - 1 + (_matches.isEmpty ? 0 : _matches.length));

  void _replaceCurrent() {
    if (_matches.isEmpty) return;
    final offset = _matches[_matchIndex % _matches.length];
    final len = _findController.text.length;
    final text = _controller.text;
    final updated = text.replaceRange(
        offset, (offset + len).clamp(0, text.length), _replaceController.text);
    _controller.text = updated;
    _computeMatches();
  }

  void _replaceAll() {
    if (_findController.text.isEmpty) return;
    // Case-insensitive replace-all.
    final pattern =
        RegExp(RegExp.escape(_findController.text), caseSensitive: false);
    _controller.text =
        _controller.text.replaceAll(pattern, _replaceController.text);
    _computeMatches();
  }

  @override
  void dispose() {
    _ghostTimer?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scroll.dispose();
    _findController.dispose();
    _replaceController.dispose();
    _findFocus.dispose();
    _inlineController.dispose();
    _inlineFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Jump to a line when requested (e.g. clicking a problem).
    ref.listen<GotoLine?>(gotoLineProvider, (prev, next) {
      if (next != null && next.path == widget.file.path) {
        _gotoLine(next.line);
        ref.read(gotoLineProvider.notifier).state = null;
      }
    });

    // Insert AI code into the active editor at the caret.
    ref.listen<String?>(editorInsertProvider, (prev, next) {
      if (next != null &&
          widget.file.path == ref.read(editorProvider).activePath) {
        _insertAtCaret(next);
        ref.read(editorInsertProvider.notifier).state = null;
      }
    });

    final diags =
        ref.watch(diagnosticsProvider)[widget.file.path] ?? const [];
    final markers = <int, DiagSeverity>{};
    for (final d in diags) {
      final cur = markers[d.line];
      if (cur == null || d.severity.index < cur.index) {
        markers[d.line] = d.severity;
      }
    }
    final caretLine = ref.watch(cursorPositionProvider).line;
    final fontSize = ref.watch(editorFontSizeProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
      color: AppColors.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Focus(
        onKeyEvent: _onKey,
        child: Scrollbar(
          controller: _scroll,
          child: SingleChildScrollView(
            controller: _scroll,
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LineGutter(
                    controller: _controller,
                    markers: markers,
                    currentLine: caretLine,
                    fontSize: fontSize,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, top: 8, right: 16),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: null,
                        expands: false,
                        textAlignVertical: TextAlignVertical.top,
                        cursorColor: AppColors.primary,
                        cursorWidth: 1.5,
                        onTap: _updateCursor,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'JetBrains Mono',
                          fontSize: fontSize,
                          height: 1.5,
                        ),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ),
        ),
      ),
          ),
          _Minimap(controller: _controller, scroll: _scroll),
        ],
      ),
        ),
        if (_isMarkdown && _mdPreview)
          Positioned.fill(child: _buildMarkdownPreview()),
        if (_isMarkdown && !_showInline)
          Positioned(
            top: 6,
            right: _showFind ? 320 : 18,
            child: _MdToggle(
              preview: _mdPreview,
              onTap: () => setState(() => _mdPreview = !_mdPreview),
            ),
          ),
        if (_showFind)
          Positioned(top: 6, right: 18, child: _buildFindBar()),
        if (_showInline)
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: Center(child: _buildInlineBar()),
          ),
      ],
    );
  }

  Widget _buildInlineBar() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)],
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _inlineController,
                focusNode: _inlineFocus,
                enabled: !_inlineBusy,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText:
                      'Edit dengan AI… (pilih kode dulu, atau biarkan untuk seluruh file)',
                  hintStyle:
                      TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
                onSubmitted: (_) => _submitInline(),
              ),
            ),
            const SizedBox(width: 6),
            if (_inlineBusy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            else ...[
              _findIcon(Icons.send, 'Kirim (Enter)', _submitInline),
              _findIcon(Icons.close, 'Tutup (Esc)', _closeInline),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdownPreview() {
    final fontSize = ref.read(editorFontSizeProvider);
    return Container(
      color: AppColors.background,
      child: Markdown(
        data: _controller.text,
        selectable: true,
        padding: const EdgeInsets.fromLTRB(28, 18, 28, 28),
        styleSheet: MarkdownStyleSheet(
          p: TextStyle(
              color: AppColors.textPrimary,
              fontSize: fontSize,
              height: 1.6),
          h1: TextStyle(
              color: AppColors.textPrimary,
              fontSize: fontSize + 12,
              fontWeight: FontWeight.w700),
          h2: TextStyle(
              color: AppColors.textPrimary,
              fontSize: fontSize + 7,
              fontWeight: FontWeight.w700),
          h3: TextStyle(
              color: AppColors.textPrimary,
              fontSize: fontSize + 3,
              fontWeight: FontWeight.w600),
          listBullet:
              TextStyle(color: AppColors.textPrimary, fontSize: fontSize),
          a: const TextStyle(color: AppColors.primary),
          strong: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          em: const TextStyle(
              color: AppColors.textPrimary, fontStyle: FontStyle.italic),
          code: TextStyle(
            color: AppColors.primaryLight,
            backgroundColor: AppColors.surfaceVariant,
            fontFamily: 'JetBrains Mono',
            fontSize: fontSize - 1,
          ),
          codeblockDecoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          codeblockPadding: const EdgeInsets.all(12),
          blockquoteDecoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: const Border(
                left: BorderSide(color: AppColors.primary, width: 3)),
          ),
          blockquotePadding: const EdgeInsets.all(10),
          horizontalRuleDecoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
        ),
      ),
    );
  }

  Widget _buildFindBar() {
    final count = _matches.isEmpty
        ? 'No results'
        : '${_matchIndex + 1} of ${_matches.length}';
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _findField(
                  controller: _findController,
                  focusNode: _findFocus,
                  hint: 'Find',
                  onChanged: (_) => _computeMatches(),
                  onSubmitted: (_) => _nextMatch(),
                ),
                const SizedBox(width: 6),
                Text(count,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(width: 4),
                _findIcon(Icons.keyboard_arrow_up, 'Previous', _prevMatch),
                _findIcon(Icons.keyboard_arrow_down, 'Next', _nextMatch),
                _findIcon(Icons.close, 'Close',
                    () => setState(() => _showFind = false)),
              ],
            ),
            if (_showReplace) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _findField(
                    controller: _replaceController,
                    hint: 'Replace',
                    onSubmitted: (_) => _replaceCurrent(),
                  ),
                  const SizedBox(width: 6),
                  _findIcon(Icons.find_replace, 'Replace', _replaceCurrent),
                  _findIcon(Icons.done_all, 'Replace All', _replaceAll),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _findField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String hint,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return SizedBox(
      width: 200,
      height: 28,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }

  Widget _findIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 14, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// Line-number gutter that grows with the line count and shows diagnostic
/// markers (red/yellow) and highlights the current line.
class _LineGutter extends StatelessWidget {
  final TextEditingController controller;
  final Map<int, DiagSeverity> markers;
  final int currentLine;
  final double fontSize;

  const _LineGutter({
    required this.controller,
    this.markers = const {},
    this.currentLine = 1,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final lineCount = '\n'.allMatches(controller.text).length + 1;
        return Container(
          padding: const EdgeInsets.only(top: 8, left: 12, right: 8),
          color: AppColors.surface.withValues(alpha: 0.4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 1; i <= lineCount; i++)
                Text(
                  '$i',
                  style: TextStyle(
                    color: markers[i] == DiagSeverity.error
                        ? AppColors.error
                        : markers[i] == DiagSeverity.warning
                            ? AppColors.warning
                            : (i == currentLine
                                ? AppColors.textPrimary
                                : AppColors.textMuted),
                    fontFamily: 'JetBrains Mono',
                    fontSize: fontSize,
                    height: 1.5,
                    fontWeight: markers.containsKey(i) || i == currentLine
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A lightweight code minimap: each line is drawn as a small bar proportional
/// to its length, with a viewport indicator. Click/drag to scroll.
class _Minimap extends StatelessWidget {
  final TextEditingController controller;
  final ScrollController scroll;

  const _Minimap({required this.controller, required this.scroll});

  void _jump(double localY, double height) {
    if (!scroll.hasClients) return;
    final max = scroll.position.maxScrollExtent;
    if (max <= 0) return;
    final frac = (localY / height).clamp(0.0, 1.0);
    scroll.jumpTo(frac * max);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          return GestureDetector(
            onTapDown: (d) => _jump(d.localPosition.dy, h),
            onVerticalDragUpdate: (d) => _jump(d.localPosition.dy, h),
            child: AnimatedBuilder(
              animation: Listenable.merge([controller, scroll]),
              builder: (context, _) {
                return CustomPaint(
                  size: Size(76, h),
                  painter: _MinimapPainter(
                    lines: controller.text.split('\n'),
                    scroll: scroll,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  final List<String> lines;
  final ScrollController scroll;

  _MinimapPainter({required this.lines, required this.scroll});

  @override
  void paint(Canvas canvas, Size size) {
    final lineCount = lines.length;
    if (lineCount == 0) return;
    final lineSlot = size.height / lineCount;
    final barH = (lineSlot * 0.7).clamp(0.4, 3.0);
    final paint = Paint()..color = AppColors.textMuted.withValues(alpha: 0.55);
    const charW = 0.9;

    final maxLines = lineCount.clamp(1, 6000);
    for (var i = 0; i < maxLines; i++) {
      final line = lines[i];
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty) continue;
      final indent = (line.length - trimmed.length) * charW;
      final w = (trimmed.length * charW).clamp(0.0, size.width - indent - 4);
      final y = i * lineSlot;
      canvas.drawRect(
        Rect.fromLTWH(4 + indent, y + (lineSlot - barH) / 2, w, barH),
        paint,
      );
    }

    // Viewport indicator.
    if (scroll.hasClients) {
      final pos = scroll.position;
      final content = pos.viewportDimension + pos.maxScrollExtent;
      if (content > 0) {
        final visFrac = (pos.viewportDimension / content).clamp(0.0, 1.0);
        final indH = size.height * visFrac;
        final top = pos.maxScrollExtent > 0
            ? (pos.pixels / pos.maxScrollExtent) * (size.height - indH)
            : 0.0;
        final vpPaint = Paint()
          ..color = AppColors.primary.withValues(alpha: 0.12);
        canvas.drawRect(Rect.fromLTWH(0, top, size.width, indH), vpPaint);
        canvas.drawRect(
          Rect.fromLTWH(0, top, size.width, indH),
          Paint()
            ..color = AppColors.primary.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) => true;
}

/// Preview dialog for an inline AI edit: shows the old vs proposed code with
/// Accept / Reject actions.
class _InlineDiffDialog extends StatelessWidget {
  final String oldCode;
  final String newCode;
  final String instruction;
  const _InlineDiffDialog({
    required this.oldCode,
    required this.newCode,
    required this.instruction,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: 760,
        height: 540,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Inline Edit: $instruction',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _codeBox('Sebelum', oldCode, AppColors.error),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _codeBox('Sesudah', newCode, AppColors.success),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Tolak',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Terima'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _codeBox(String title, String code, Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Text(title,
                style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: SelectableText(
                code.isEmpty ? '(kosong)' : code,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle button shown on Markdown files to switch between source and preview.
class _MdToggle extends StatelessWidget {
  final bool preview;
  final VoidCallback onTap;
  const _MdToggle({required this.preview, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: preview ? 'Edit source' : 'Preview markdown',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: preview ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: preview ? AppColors.primary : AppColors.border),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 6)
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(preview ? Icons.code : Icons.visibility_outlined,
                    size: 13,
                    color:
                        preview ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 5),
                Text(
                  preview ? 'Source' : 'Preview',
                  style: TextStyle(
                    color: preview ? Colors.white : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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
