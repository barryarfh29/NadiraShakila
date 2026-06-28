import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/codicons.dart';
import '../chat/presentation/providers/settings_provider.dart';
import '../workspace/providers/workspace_provider.dart';
import 'github_service.dart';

Future<void> showGitHubClone(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (_) => const _GitHubDialog(),
  );
}

class _GitHubDialog extends ConsumerStatefulWidget {
  const _GitHubDialog();

  @override
  ConsumerState<_GitHubDialog> createState() => _GitHubDialogState();
}

class _GitHubDialogState extends ConsumerState<_GitHubDialog> {
  final _tokenController = TextEditingController();
  List<GitHubRepo> _repos = [];
  bool _loading = false;
  String? _error;
  String _query = '';
  String? _cloning;

  @override
  void initState() {
    super.initState();
    final token = ref.read(githubTokenProvider);
    _tokenController.text = token;
    if (token.isNotEmpty) {
      _fetch();
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;
    ref.read(githubTokenProvider.notifier).setToken(token);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repos = await GitHubService.fetchRepos(token);
      setState(() {
        _repos = repos;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _clone(GitHubRepo repo) async {
    final dest = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose where to clone "${repo.name}"',
    );
    if (dest == null) return;
    setState(() => _cloning = repo.fullName);
    try {
      final path = await GitHubService.clone(
          repo, dest, ref.read(githubTokenProvider));
      if (!mounted) return;
      ref.read(workspaceProvider.notifier).openFolder(path);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cloning = null;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasToken = ref.watch(githubTokenProvider).isNotEmpty;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: 560,
        height: 520,
        child: Column(
          children: [
            _header(),
            const Divider(height: 1),
            Expanded(child: _body(hasToken)),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const Icon(Codicons.github, size: 16, color: AppColors.textPrimary),
          const SizedBox(width: 8),
          const Text('Clone from GitHub',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            icon: const Icon(Codicons.close, size: 14),
            color: AppColors.textSecondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _body(bool hasToken) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Token row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tokenController,
                  obscureText: true,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 12.5),
                  decoration: const InputDecoration(
                    hintText: 'GitHub personal access token (ghp_...)',
                    isDense: true,
                    prefixIcon: Icon(Codicons.key, size: 15),
                    prefixIconConstraints:
                        BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  onSubmitted: (_) => _fetch(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loading ? null : _fetch,
                child: const Text('Connect'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Create a token at github.com → Settings → Developer settings → '
            'Personal access tokens (scope: repo).',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
          ),
          const SizedBox(height: 10),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 11)),
            ),
          if (hasToken && _repos.isNotEmpty)
            TextField(
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 12.5),
              decoration: const InputDecoration(
                hintText: 'Filter repositories...',
                isDense: true,
                prefixIcon: Icon(Codicons.search, size: 15),
                prefixIconConstraints:
                    BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          const SizedBox(height: 8),
          Expanded(child: _repoList()),
        ],
      ),
    );
  }

  Widget _repoList() {
    if (_loading) {
      return const Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2)));
    }
    final filtered = _query.isEmpty
        ? _repos
        : _repos
            .where((r) => r.fullName.toLowerCase().contains(_query))
            .toList();
    if (filtered.isEmpty) {
      return const Center(
        child: Text('No repositories',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      );
    }
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) => _RepoRow(
        repo: filtered[i],
        cloning: _cloning == filtered[i].fullName,
        onClone: () => _clone(filtered[i]),
      ),
    );
  }
}

class _RepoRow extends StatefulWidget {
  final GitHubRepo repo;
  final bool cloning;
  final VoidCallback onClone;

  const _RepoRow(
      {required this.repo, required this.cloning, required this.onClone});

  @override
  State<_RepoRow> createState() => _RepoRowState();
}

class _RepoRowState extends State<_RepoRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.repo;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: _hovered ? AppColors.surfaceHover : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(r.private ? Codicons.key : Codicons.github,
                size: 14, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500)),
                  if (r.description != null && r.description!.isNotEmpty)
                    Text(r.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            widget.cloning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : OutlinedButton(
                    onPressed: widget.onClone,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      minimumSize: const Size(0, 30),
                    ),
                    child: const Text('Clone', style: TextStyle(fontSize: 12)),
                  ),
          ],
        ),
      ),
    );
  }
}
