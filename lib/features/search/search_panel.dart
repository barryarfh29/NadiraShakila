import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/theme/app_theme.dart';
import '../../core/theme/codicons.dart';
import '../diagnostics/diagnostics_provider.dart';
import '../workspace/providers/workspace_provider.dart';
import 'search_provider.dart';

/// VS Code-style search panel: full-text search across the workspace.
class SearchPanel extends ConsumerStatefulWidget {
  const SearchPanel({super.key});

  @override
  ConsumerState<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends ConsumerState<SearchPanel> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _replaceController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  Future<void> _replaceAll() async {
    final changed =
        await ref.read(searchProvider.notifier).replaceAll(_replaceController.text);
    if (!mounted) return;
    for (final path in changed) {
      ref.read(editorProvider.notifier).reloadFromDisk(path);
      ref.read(diagnosticsProvider.notifier).analyze(path);
    }
    ref.read(explorerRefreshProvider.notifier).state++;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Replaced in ${changed.length} file(s)'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final hasWorkspace = ref.watch(workspaceProvider) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 35,
          padding: const EdgeInsets.only(left: 14),
          alignment: Alignment.centerLeft,
          child: const Text(
            'SEARCH',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: TextField(
            controller: _controller,
            autofocus: true,
            enabled: hasWorkspace,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5),
            decoration: InputDecoration(
              hintText: hasWorkspace ? 'Search' : 'Open a folder first',
              isDense: true,
              prefixIcon: const Icon(Codicons.search, size: 15),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
              suffixIcon: state.searching
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onSubmitted: (q) => ref.read(searchProvider.notifier).search(q),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replaceController,
                  enabled: hasWorkspace,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 12.5),
                  decoration: const InputDecoration(
                    hintText: 'Replace',
                    isDense: true,
                    prefixIcon: Icon(Icons.find_replace, size: 15),
                    prefixIconConstraints:
                        BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Replace All',
                child: InkWell(
                  onTap: (state.hits.isEmpty) ? null : _replaceAll,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.done_all,
                        size: 16,
                        color: state.hits.isEmpty
                            ? AppColors.textMuted
                            : AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (state.query.isNotEmpty && !state.searching)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Text(
              state.hits.isEmpty
                  ? 'No results'
                  : '${state.hits.length} results in ${state.fileCount} files'
                      '${state.truncated ? ' (truncated)' : ''}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 4),
            itemCount: state.hits.length,
            itemBuilder: (context, index) {
              final hit = state.hits[index];
              return _HitRow(hit: hit);
            },
          ),
        ),
      ],
    );
  }
}

class _HitRow extends ConsumerStatefulWidget {
  final SearchHit hit;
  const _HitRow({required this.hit});

  @override
  ConsumerState<_HitRow> createState() => _HitRowState();
}

class _HitRowState extends ConsumerState<_HitRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hit = widget.hit;
    final root = ref.read(workspaceProvider);
    final rel =
        root != null ? p.relative(hit.path, from: root) : p.basename(hit.path);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          ref.read(editorProvider.notifier).openFile(hit.path);
        },
        child: Container(
          color: _hovered ? AppColors.surfaceHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      p.basename(hit.path),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ':${hit.line}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                hit.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                rel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
