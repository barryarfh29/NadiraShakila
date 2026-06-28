import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/codicons.dart';
import '../hooks/hooks_panel.dart';
import '../steering/steering_provider.dart';
import '../workspace/providers/workspace_provider.dart';
import 'specs_provider.dart';

/// Kiro-style Specs panel: spec-driven development
/// (Requirements -> Design -> Tasks).
class SpecsPanel extends ConsumerWidget {
  const SpecsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(workspaceProvider);
    final specs = ref.watch(specsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          height: 35,
          padding: const EdgeInsets.only(left: 16, right: 6),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'SPECS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (workspace != null) ...[
                _IconBtn(
                  icon: Codicons.add,
                  tooltip: 'New Spec',
                  onTap: () => _createSpec(context, ref),
                ),
                _IconBtn(
                  icon: Codicons.refresh,
                  tooltip: 'Refresh',
                  onTap: () => ref.read(specsProvider.notifier).refresh(),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: workspace == null
              ? const _EmptyHint(
                  'Buka folder untuk memakai Specs & Steering.\nSpecs membantu merencanakan fitur (Requirements → Design → Tasks). Steering menyimpan aturan proyek yang selalu disertakan ke AI.')
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    if (specs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          'Belum ada spec. Klik + di atas untuk membuat spec baru dari sebuah ide fitur.',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              height: 1.5),
                        ),
                      )
                    else
                      for (final spec in specs) _SpecTile(spec: spec),
                    const SizedBox(height: 8),
                    const _SteeringSection(),
                    const SizedBox(height: 8),
                    const HooksSection(),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _createSpec(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({String name, String feature})>(
      context: context,
      builder: (_) => const _CreateSpecDialog(),
    );
    if (result == null) return;
    final spec = ref.read(specsProvider.notifier).create(result.name);
    if (spec == null) return;
    // Kick off requirements generation immediately.
    try {
      await ref
          .read(specsControllerProvider)
          .generateRequirements(spec, result.feature);
      ref.read(editorProvider.notifier).openFile(spec.requirementsPath);
    } catch (_) {}
  }
}

class _SpecTile extends ConsumerStatefulWidget {
  final Spec spec;
  const _SpecTile({required this.spec});

  @override
  ConsumerState<_SpecTile> createState() => _SpecTileState();
}

class _SpecTileState extends ConsumerState<_SpecTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final busy = ref.watch(specBusyProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Spec name row
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(_expanded ? Codicons.chevronDown : Codicons.chevronRight,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                const Icon(Icons.auto_awesome_outlined,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    spec.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                _IconBtn(
                  icon: Codicons.trash,
                  tooltip: 'Delete spec',
                  onTap: () => ref.read(specsProvider.notifier).delete(spec),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 10, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StageRow(
                  label: 'Requirements',
                  done: spec.hasRequirements,
                  busy: busy == 'requirements:${spec.name}',
                  enabled: true,
                  onOpen: spec.hasRequirements
                      ? () => ref
                          .read(editorProvider.notifier)
                          .openFile(spec.requirementsPath)
                      : null,
                  actionLabel: spec.hasRequirements ? 'Regenerate' : null,
                ),
                _StageRow(
                  label: 'Design',
                  done: spec.hasDesign,
                  busy: busy == 'design:${spec.name}',
                  enabled: spec.hasRequirements,
                  onOpen: spec.hasDesign
                      ? () => ref
                          .read(editorProvider.notifier)
                          .openFile(spec.designPath)
                      : null,
                  actionLabel: spec.hasDesign ? 'Regenerate' : 'Generate',
                  onAction: spec.hasRequirements
                      ? () =>
                          ref.read(specsControllerProvider).generateDesign(spec)
                      : null,
                ),
                _StageRow(
                  label: 'Tasks',
                  done: spec.hasTasks,
                  busy: busy == 'tasks:${spec.name}',
                  enabled: spec.hasDesign,
                  onOpen: spec.hasTasks
                      ? () => ref
                          .read(editorProvider.notifier)
                          .openFile(spec.tasksPath)
                      : null,
                  actionLabel: spec.hasTasks ? 'Regenerate' : 'Generate',
                  onAction: spec.hasDesign
                      ? () =>
                          ref.read(specsControllerProvider).generateTasks(spec)
                      : null,
                ),
                if (spec.hasTasks) ...[
                  const SizedBox(height: 6),
                  _TaskList(spec: spec),
                ],
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

/// One workflow stage row with Generate / Open actions.
class _StageRow extends StatelessWidget {
  final String label;
  final bool done;
  final bool busy;
  final bool enabled;
  final VoidCallback? onOpen;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StageRow({
    required this.label,
    required this.done,
    required this.busy,
    required this.enabled,
    this.onOpen,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 13,
            color: done ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: enabled ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 12.5,
              ),
            ),
          ),
          if (busy)
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                  strokeWidth: 1.6, color: AppColors.primary),
            )
          else ...[
            if (onOpen != null)
              _MiniBtn(label: 'Open', onTap: onOpen!),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 4),
              _MiniBtn(
                label: actionLabel!,
                primary: true,
                onTap: enabled ? onAction! : null,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  final Spec spec;
  const _TaskList({required this.spec});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch specs to rebuild after file changes.
    ref.watch(specsProvider);
    final tasks = parseTasks(spec.readTasks());
    if (tasks.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final task in tasks)
            _TaskRow(
              task: task,
              onToggle: () =>
                  ref.read(specsControllerProvider).toggleTask(spec, task),
              onRun: () =>
                  ref.read(specsControllerProvider).executeTask(spec, task),
            ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatefulWidget {
  final SpecTask task;
  final VoidCallback onToggle;
  final VoidCallback onRun;
  const _TaskRow(
      {required this.task, required this.onToggle, required this.onRun});

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: widget.onToggle,
              child: Icon(
                t.done
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank,
                size: 15,
                color: t.done ? AppColors.success : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                t.title,
                style: TextStyle(
                  color:
                      t.done ? AppColors.textMuted : AppColors.textSecondary,
                  fontSize: 12,
                  decoration: t.done ? TextDecoration.lineThrough : null,
                  height: 1.3,
                ),
              ),
            ),
            if (_hovered && !t.done)
              GestureDetector(
                onTap: widget.onRun,
                child: const Tooltip(
                  message: 'Kerjakan dengan AI Agent',
                  child: Padding(
                    padding: EdgeInsets.only(left: 4, top: 1),
                    child: Icon(Icons.play_arrow_rounded,
                        size: 16, color: AppColors.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CreateSpecDialog extends StatefulWidget {
  const _CreateSpecDialog();

  @override
  State<_CreateSpecDialog> createState() => _CreateSpecDialogState();
}

class _CreateSpecDialogState extends State<_CreateSpecDialog> {
  final _nameCtrl = TextEditingController();
  final _featureCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _featureCtrl.dispose();
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
        width: 460,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Spec Baru',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text(
                'AI akan membuat dokumen Requirements dari ide fitur Anda.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text('Nama spec',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'mis. user-authentication',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              const Text('Deskripsi fitur',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _featureCtrl,
                maxLines: 4,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  hintText:
                      'Jelaskan fitur yang ingin dibangun, mis. "Sistem login dengan email & Google, dengan reset password".',
                  isDense: true,
                ),
              ),
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
                    onPressed: () {
                      final name = _nameCtrl.text.trim();
                      final feature = _featureCtrl.text.trim();
                      if (name.isEmpty || feature.isEmpty) return;
                      Navigator.of(context)
                          .pop((name: name, feature: feature));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Buat & Generate'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppColors.textMuted, fontSize: 12, height: 1.5),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn(
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
          child: Icon(icon, size: 15, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback? onTap;
  const _MiniBtn(
      {required this.label, this.primary = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: primary && !disabled
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: primary && !disabled
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: disabled
                ? AppColors.textMuted
                : (primary ? AppColors.primary : AppColors.textSecondary),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Steering files section (project rules always sent to the AI).
class _SteeringSection extends ConsumerWidget {
  const _SteeringSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(steeringProvider);

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
                  'STEERING',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _IconBtn(
                icon: Codicons.add,
                tooltip: 'New Steering File',
                onTap: () => _create(context, ref),
              ),
            ],
          ),
        ),
        if (files.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Aturan proyek yang selalu disertakan ke AI. Klik + untuk membuat (mis. coding-style, tech-stack).',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12, height: 1.5),
            ),
          )
        else
          for (final f in files)
            _SteeringRow(
              file: f,
              onOpen: () =>
                  ref.read(editorProvider.notifier).openFile(f.path),
              onDelete: () =>
                  ref.read(steeringProvider.notifier).delete(f),
            ),
      ],
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NameDialog(
        title: 'Steering File Baru',
        hint: 'mis. coding-style',
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final file = ref.read(steeringProvider.notifier).create(name);
    if (file != null) {
      ref.read(editorProvider.notifier).openFile(file.path);
    }
  }
}

class _SteeringRow extends StatefulWidget {
  final SteeringFile file;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  const _SteeringRow(
      {required this.file, required this.onOpen, required this.onDelete});

  @override
  State<_SteeringRow> createState() => _SteeringRowState();
}

class _SteeringRowState extends State<_SteeringRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final manual = widget.file.inclusion == 'manual';
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: Container(
          color: _hovered ? AppColors.surfaceHover : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Row(
            children: [
              const Icon(Icons.policy_outlined,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.file.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 12.5),
                ),
              ),
              if (manual)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text('manual',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 10)),
                ),
              if (_hovered)
                GestureDetector(
                  onTap: widget.onDelete,
                  child: const Icon(Codicons.trash,
                      size: 13, color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple single-field name dialog reused for steering files.
class _NameDialog extends StatefulWidget {
  final String title;
  final String hint;
  const _NameDialog({required this.title, required this.hint});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
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
        width: 420,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(hintText: widget.hint, isDense: true),
                onSubmitted: (v) => Navigator.of(context).pop(v),
              ),
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
                    onPressed: () =>
                        Navigator.of(context).pop(_ctrl.text.trim()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Buat'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
