import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_theme.dart';
import '../chat/presentation/providers/attached_context.dart';
import '../workspace/providers/workspace_provider.dart';
import '../workspace/widgets/file_icon.dart';

/// Opens the VS Code-style Quick Open palette (Ctrl+P) to fuzzy-find and open
/// a workspace file.
Future<void> showQuickOpen(BuildContext context, WidgetRef ref) async {
  final root = ref.read(workspaceProvider);
  if (root == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Open a folder first'),
          duration: Duration(seconds: 1)),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black26,
    builder: (_) => _QuickOpenDialog(root: root),
  );
}

/// Returns a score for fuzzy-matching [query] against [text] (lower = better),
/// or null if it doesn't match (query chars must appear in order).
int? _fuzzyScore(String query, String text) {
  if (query.isEmpty) return 0;
  var qi = 0;
  var score = 0;
  var lastMatch = -1;
  for (var ti = 0; ti < text.length && qi < query.length; ti++) {
    if (text[ti] == query[qi]) {
      // Penalize gaps between matched characters.
      if (lastMatch >= 0) score += (ti - lastMatch - 1);
      lastMatch = ti;
      qi++;
    }
  }
  if (qi < query.length) return null;
  return score;
}

class _QuickOpenDialog extends ConsumerStatefulWidget {
  final String root;
  const _QuickOpenDialog({required this.root});

  @override
  ConsumerState<_QuickOpenDialog> createState() => _QuickOpenDialogState();
}

class _QuickOpenDialogState extends ConsumerState<_QuickOpenDialog> {
  late final List<String> _all;
  final FocusNode _keyboardFocus = FocusNode();
  String _query = '';
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _all = listWorkspaceFiles(widget.root);
  }

  @override
  void dispose() {
    _keyboardFocus.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return _all.take(50).toList();
    final scored = <MapEntry<String, int>>[];
    for (final f in _all) {
      final lower = f.toLowerCase();
      // Prefer matches on the basename.
      final baseScore = _fuzzyScore(q, p.basename(lower));
      final pathScore = _fuzzyScore(q, lower);
      final score = baseScore ??
          (pathScore != null ? pathScore + 100 : null);
      if (score != null) scored.add(MapEntry(f, score));
    }
    scored.sort((a, b) => a.value.compareTo(b.value));
    return scored.take(50).map((e) => e.key).toList();
  }

  void _open(String rel) {
    final abs = p.join(widget.root, rel);
    ref.read(editorProvider.notifier).openFile(abs);
    Navigator.of(context).pop();
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final list = _filtered;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _selected = (_selected + 1).clamp(0, list.length - 1));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _selected = (_selected - 1).clamp(0, list.length - 1));
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (list.isNotEmpty) _open(list[_selected.clamp(0, list.length - 1)]);
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    if (_selected >= list.length) _selected = 0;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Material(
          color: Colors.transparent,
          child: KeyboardListener(
            focusNode: _keyboardFocus,
            onKeyEvent: _onKey,
            child: Container(
              width: 560,
              constraints: const BoxConstraints(maxHeight: 420),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 16)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: TextField(
                      autofocus: true,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Go to file by name...',
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() {
                        _query = v;
                        _selected = 0;
                      }),
                      onSubmitted: (_) {
                        if (list.isNotEmpty) {
                          _open(list[_selected.clamp(0, list.length - 1)]);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: list.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No matching files',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 12)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: list.length,
                            itemBuilder: (context, i) {
                              final rel = list[i];
                              return _Row(
                                rel: rel,
                                selected: i == _selected,
                                onTap: () => _open(rel),
                                onHover: () => setState(() => _selected = i),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String rel;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onHover;

  const _Row({
    required this.rel,
    required this.selected,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final name = p.basename(rel);
    final dir = p.dirname(rel);
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: selected ? AppColors.surfaceVariant : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              FileIcon(fileName: name, size: 14),
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
