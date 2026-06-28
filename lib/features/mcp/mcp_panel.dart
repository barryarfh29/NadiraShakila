import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/codicons.dart';
import '../workspace/providers/workspace_provider.dart';
import 'mcp_provider.dart';

/// "MCP SERVERS" section for the Extensions panel: shows configured Model
/// Context Protocol servers, their connection status, and tool counts.
class McpSection extends ConsumerWidget {
  const McpSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider);
    final servers = ref.watch(mcpManagerProvider);

    void openConfig() {
      final path = ensureMcpConfig(workspace);
      if (path != null) {
        ref.read(editorProvider.notifier).openFile(path);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 6, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'MCP SERVERS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (workspace != null) ...[
                _MiniIcon(
                  icon: Codicons.add,
                  tooltip: 'Add Server',
                  onTap: () => _openAddDialog(context, ref),
                ),
                _MiniIcon(
                  icon: Codicons.refresh,
                  tooltip: 'Reconnect all',
                  onTap: () => ref.read(mcpManagerProvider.notifier).reload(),
                ),
                _MiniIcon(
                  icon: Codicons.gear,
                  tooltip: 'Edit mcp.json',
                  onTap: openConfig,
                ),
              ],
            ],
          ),
        ),
        if (workspace == null)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Buka folder untuk mengonfigurasi MCP server.',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12, height: 1.5),
            ),
          )
        else if (servers.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Belum ada MCP server. Server MCP memberi AI kemampuan baru (tool eksternal).',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openAddDialog(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.5)),
                    ),
                    child: const Text('+ Tambah Server',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
          )
        else
          for (final s in servers) _McpServerRow(state: s),
      ],
    );
  }
}

class _McpServerRow extends ConsumerWidget {
  final McpServerState state;
  const _McpServerRow({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, label) = switch (state.status) {
      McpStatus.connected => (AppColors.success, 'connected'),
      McpStatus.connecting => (AppColors.warning, 'connecting…'),
      McpStatus.error => (AppColors.error, 'error'),
      McpStatus.disabled => (AppColors.textMuted, 'disabled'),
    };

    final subtitle = state.status == McpStatus.connected
        ? '${state.tools.length} tools'
        : (state.status == McpStatus.error
            ? (state.error ?? 'failed')
            : label);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 7, 8, 7),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.config.name,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: state.status == McpStatus.error
                        ? AppColors.error
                        : AppColors.textMuted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          if (state.status != McpStatus.disabled)
            _MiniIcon(
              icon: Codicons.refresh,
              tooltip: 'Reconnect',
              onTap: () => ref
                  .read(mcpManagerProvider.notifier)
                  .reconnect(state.config.name),
            ),
          _MiniIcon(
            icon: Codicons.trash,
            tooltip: 'Remove',
            onTap: () => ref
                .read(mcpManagerProvider.notifier)
                .removeServer(state.config.name),
          ),
        ],
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _MiniIcon(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 14, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// A ready-made MCP server preset the user can add with one click.
class _McpPreset {
  final String label;
  final String name;
  final String command;
  final List<String> args;
  final String hint;
  const _McpPreset(this.label, this.name, this.command, this.args, this.hint);
}

const _mcpPresets = <_McpPreset>[
  _McpPreset('Fetch (ambil halaman web)', 'fetch', 'uvx',
      ['mcp-server-fetch'], 'Butuh: uv/uvx (Python). AI bisa membaca URL.'),
  _McpPreset('Filesystem', 'filesystem', 'npx',
      ['-y', '@modelcontextprotocol/server-filesystem', '.'],
      'Butuh: Node.js (npx). Akses file di folder.'),
  _McpPreset('Git', 'git', 'uvx', ['mcp-server-git'],
      'Butuh: uv/uvx (Python). Operasi git.'),
  _McpPreset('Memory (catatan AI)', 'memory', 'npx',
      ['-y', '@modelcontextprotocol/server-memory'],
      'Butuh: Node.js (npx). Ingatan jangka panjang.'),
  _McpPreset('Custom (isi sendiri)', '', '', [], 'Isi command & args manual.'),
];

Future<void> _openAddDialog(BuildContext context, WidgetRef ref) async {
  final cfg = await showDialog<McpServerConfig>(
    context: context,
    builder: (_) => const _AddServerDialog(),
  );
  if (cfg != null) {
    await ref.read(mcpManagerProvider.notifier).addServer(cfg);
  }
}

class _AddServerDialog extends StatefulWidget {
  const _AddServerDialog();

  @override
  State<_AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<_AddServerDialog> {
  _McpPreset _preset = _mcpPresets.first;
  final _nameCtrl = TextEditingController();
  final _cmdCtrl = TextEditingController();
  final _argsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _applyPreset(_mcpPresets.first);
  }

  void _applyPreset(_McpPreset p) {
    _preset = p;
    _nameCtrl.text = p.name;
    _cmdCtrl.text = p.command;
    _argsCtrl.text = p.args.join(' ');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cmdCtrl.dispose();
    _argsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: 500,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tambah MCP Server',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text(
                'Pilih preset siap pakai, atau isi sendiri. Server memberi AI kemampuan baru.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              _label('Preset'),
              DropdownButtonFormField<_McpPreset>(
                // ignore: deprecated_member_use
                value: _preset,
                isExpanded: true,
                dropdownColor: AppColors.surfaceVariant,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(isDense: true),
                items: [
                  for (final p in _mcpPresets)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (p) {
                  if (p != null) setState(() => _applyPreset(p));
                },
              ),
              if (_preset.hint.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(_preset.hint,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
              const SizedBox(height: 12),
              _label('Nama'),
              _field(_nameCtrl, 'mis. fetch'),
              const SizedBox(height: 12),
              _label('Command'),
              _field(_cmdCtrl, 'mis. uvx atau npx'),
              const SizedBox(height: 12),
              _label('Args (pisahkan dengan spasi)'),
              _field(_argsCtrl, 'mis. mcp-server-fetch'),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Tambah & Connect'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final cmd = _cmdCtrl.text.trim();
    if (name.isEmpty || cmd.isEmpty) return;
    final args = _argsCtrl.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    Navigator.of(context).pop(McpServerConfig(
      name: name,
      command: cmd,
      args: args,
      disabled: false,
    ));
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(t,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      );

  Widget _field(TextEditingController c, String hint) => TextField(
        controller: c,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(hintText: hint, isDense: true),
      );
}
