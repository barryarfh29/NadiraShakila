import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/codicons.dart';
import 'hooks_provider.dart';

/// "AGENT HOOKS" section: event-driven automations (Kiro-style).
class HooksSection extends ConsumerWidget {
  const HooksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hooks = ref.watch(hooksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 6, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'AGENT HOOKS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              InkWell(
                onTap: () => _create(context, ref),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Codicons.add,
                      size: 15, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        if (hooks.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Otomasi berbasis event. Mis. saat simpan *.dart → jalankan format, atau minta AI review. Klik + untuk membuat.',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12, height: 1.5),
            ),
          )
        else
          for (final hook in hooks) _HookRow(hook: hook),
      ],
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final hook = await showDialog<AgentHook>(
      context: context,
      builder: (_) => const _HookDialog(),
    );
    if (hook != null) {
      ref.read(hooksProvider.notifier).create(hook);
    }
  }
}

class _HookRow extends ConsumerStatefulWidget {
  final AgentHook hook;
  const _HookRow({required this.hook});

  @override
  ConsumerState<_HookRow> createState() => _HookRowState();
}

class _HookRowState extends ConsumerState<_HookRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hook = widget.hook;
    final subtitle = hook.event == HookEvent.fileSaved
        ? 'On save: ${hook.patterns.isEmpty ? '*' : hook.patterns.join(', ')}'
        : 'Manual';
    final actionLabel =
        hook.action == HookAction.askAgent ? 'Ask Agent' : 'Run Command';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: _hovered ? AppColors.surfaceHover : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => ref.read(hooksProvider.notifier).toggle(hook),
              child: Icon(
                hook.enabled ? Icons.toggle_on : Icons.toggle_off,
                size: 20,
                color: hook.enabled ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hook.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hook.enabled
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    '$subtitle • $actionLabel',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10.5),
                  ),
                ],
              ),
            ),
            if (hook.event == HookEvent.manual)
              Tooltip(
                message: 'Run now',
                child: GestureDetector(
                  onTap: () => runHook(ref, hook),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.play_arrow_rounded,
                        size: 18, color: AppColors.primary),
                  ),
                ),
              ),
            if (_hovered)
              GestureDetector(
                onTap: () => ref.read(hooksProvider.notifier).delete(hook),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child:
                      Icon(Codicons.trash, size: 13, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HookDialog extends StatefulWidget {
  const _HookDialog();

  @override
  State<_HookDialog> createState() => _HookDialogState();
}

class _HookDialogState extends State<_HookDialog> {
  final _nameCtrl = TextEditingController();
  final _patternsCtrl = TextEditingController(text: '*.dart');
  final _promptCtrl = TextEditingController();
  final _commandCtrl = TextEditingController();
  HookEvent _event = HookEvent.fileSaved;
  HookAction _action = HookAction.askAgent;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _patternsCtrl.dispose();
    _promptCtrl.dispose();
    _commandCtrl.dispose();
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
              const Text('Agent Hook Baru',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _label('Nama'),
              _field(_nameCtrl, 'mis. Format on save'),
              const SizedBox(height: 12),
              _label('Pemicu (event)'),
              _eventDropdown(),
              if (_event == HookEvent.fileSaved) ...[
                const SizedBox(height: 12),
                _label('Pola file (pisahkan dengan koma)'),
                _field(_patternsCtrl, '*.dart, *.ts'),
              ],
              const SizedBox(height: 12),
              _label('Aksi'),
              _actionDropdown(),
              const SizedBox(height: 12),
              if (_action == HookAction.askAgent) ...[
                _label('Prompt untuk AI'),
                _field(_promptCtrl,
                    'mis. Review perubahan ini dan perbaiki bug yang terlihat.',
                    maxLines: 3),
              ] else ...[
                _label('Perintah shell'),
                _field(_commandCtrl, 'mis. flutter analyze'),
              ],
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
                    child: const Text('Buat Hook'),
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
    if (name.isEmpty) return;
    final patterns = _patternsCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (_action == HookAction.askAgent && _promptCtrl.text.trim().isEmpty) {
      return;
    }
    if (_action == HookAction.runCommand && _commandCtrl.text.trim().isEmpty) {
      return;
    }
    Navigator.of(context).pop(AgentHook(
      id: '',
      path: '',
      name: name,
      enabled: true,
      event: _event,
      patterns: patterns,
      action: _action,
      prompt: _promptCtrl.text.trim(),
      command: _commandCtrl.text.trim(),
    ));
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(t,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      );

  Widget _field(TextEditingController c, String hint, {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(hintText: hint, isDense: true),
    );
  }

  Widget _eventDropdown() {
    return DropdownButtonFormField<HookEvent>(
      // ignore: deprecated_member_use
      value: _event,
      dropdownColor: AppColors.surfaceVariant,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: const InputDecoration(isDense: true),
      items: const [
        DropdownMenuItem(
            value: HookEvent.fileSaved, child: Text('Saat file disimpan')),
        DropdownMenuItem(
            value: HookEvent.manual, child: Text('Manual (tombol)')),
      ],
      onChanged: (v) => setState(() => _event = v ?? _event),
    );
  }

  Widget _actionDropdown() {
    return DropdownButtonFormField<HookAction>(
      // ignore: deprecated_member_use
      value: _action,
      dropdownColor: AppColors.surfaceVariant,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: const InputDecoration(isDense: true),
      items: const [
        DropdownMenuItem(
            value: HookAction.askAgent, child: Text('Minta AI Agent')),
        DropdownMenuItem(
            value: HookAction.runCommand, child: Text('Jalankan perintah')),
      ],
      onChanged: (v) => setState(() => _action = v ?? _action),
    );
  }
}
