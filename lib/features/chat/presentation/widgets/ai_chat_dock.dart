import 'dart:io';

import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/codicons.dart';
import '../../../agent/data/agent_approval.dart';
import '../../../agent/data/agent_changes.dart';
import '../../../agent/data/checkpoints_provider.dart';
import '../../../agent/widgets/approval_dialog.dart';
import '../../../workspace/providers/workspace_provider.dart';
import '../../data/models/conversation_model.dart';
import '../providers/attached_context.dart';
import '../providers/attached_images.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import 'chat_input.dart';
import 'chat_panel.dart';
import 'settings_dialog.dart';

/// Right-docked AI assistant panel (the signature Kiro chat panel).
class AiChatDock extends ConsumerWidget {
  final VoidCallback onClose;

  const AiChatDock({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKey = ref.watch(apiKeyProvider);

    return Container(
      width: 380,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: _ChatDropTarget(
        child: Column(
          children: [
            _DockHeader(onClose: onClose),
            Expanded(
              child: apiKey.isEmpty
                  ? _ApiKeyPrompt()
                  : const ChatPanel(),
            ),
            if (apiKey.isNotEmpty) const _ChangesBar(),
            if (apiKey.isNotEmpty) const _ApprovalBar(),
            if (apiKey.isNotEmpty) const _NewApprovalBar(),
            if (apiKey.isNotEmpty) const ChatInput(),
          ],
        ),
      ),
    );
  }
}

/// Wraps the chat panel so images/files can be dropped in (drag & drop).
class _ChatDropTarget extends ConsumerStatefulWidget {
  final Widget child;
  const _ChatDropTarget({required this.child});

  @override
  ConsumerState<_ChatDropTarget> createState() => _ChatDropTargetState();
}

class _ChatDropTargetState extends ConsumerState<_ChatDropTarget> {
  bool _dragging = false;

  static const _imageExts = {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.bmp'
  };

  Future<void> _onDrop(DropDoneDetails detail) async {
    for (final file in detail.files) {
      final path = file.path;
      final ext = p.extension(path).toLowerCase();
      if (_imageExts.contains(ext)) {
        try {
          final bytes = await file.readAsBytes();
          ref
              .read(attachedImagesProvider.notifier)
              .add(p.basename(path), bytes, ext);
        } catch (_) {}
      } else {
        // Attach as file/folder context.
        final isDir = FileSystemEntity.isDirectorySync(path);
        ref.read(attachedContextProvider.notifier).add(path, isDir);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        _onDrop(detail);
      },
      child: Stack(
        children: [
          widget.child,
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.file_download_outlined,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Lepas untuk lampirkan',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DockHeader extends ConsumerWidget {
  final VoidCallback onClose;
  const _DockHeader({required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Codicons.sparkle, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          const Text(
            'Nadira Shakila',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const _CheckpointsButton(),
          _HeaderIcon(
            icon: Codicons.history,
            tooltip: 'Chat History',
            onTap: () => _openHistory(context),
          ),
          _HeaderIcon(
            icon: Codicons.add,
            tooltip: 'New Chat',
            onTap: () => ref
                .read(currentConversationIdProvider.notifier)
                .state = null,
          ),
          _HeaderIcon(
            icon: Codicons.gear,
            tooltip: 'Settings',
            onTap: () => showDialog(
              context: context,
              builder: (_) => const SettingsDialog(),
            ),
          ),
          _HeaderIcon(
            icon: Codicons.close,
            tooltip: 'Close Panel',
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 15, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _CheckpointsButton extends ConsumerWidget {
  const _CheckpointsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(checkpointsProvider).length;
    return Tooltip(
      message: 'Checkpoints (restore points)',
      child: InkWell(
        onTap: count == 0
            ? null
            : () => showDialog(
                  context: context,
                  builder: (_) => const _CheckpointsDialog(),
                ),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.restore,
                  size: 16,
                  color: count == 0
                      ? AppColors.textMuted
                      : AppColors.textSecondary),
              if (count > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckpointsDialog extends ConsumerWidget {
  const _CheckpointsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkpoints = ref.watch(checkpointsProvider);

    void restore(Checkpoint cp) {
      final paths = ref.read(checkpointsProvider.notifier).restore(cp);
      for (final path in paths) {
        ref.read(editorProvider.notifier).reloadFromDisk(path);
      }
      ref.read(explorerRefreshProvider.notifier).state++;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Dipulihkan ke checkpoint (${paths.length} file).'),
        duration: const Duration(seconds: 2),
      ));
      Navigator.of(context).pop();
    }

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: SizedBox(
        width: 460,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
              child: Row(
                children: [
                  const Icon(Codicons.history,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Checkpoints',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: checkpoints.isEmpty
                        ? null
                        : () {
                            ref.read(checkpointsProvider.notifier).clear();
                            Navigator.of(context).pop();
                          },
                    child: const Text('Hapus semua',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: checkpoints.isEmpty
                  ? const Center(
                      child: Text('Belum ada checkpoint.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: checkpoints.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final cp = checkpoints[i];
                        return _CheckpointTile(
                          checkpoint: cp,
                          onRestore: () => restore(cp),
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

class _CheckpointTile extends StatelessWidget {
  final Checkpoint checkpoint;
  final VoidCallback onRestore;
  const _CheckpointTile({
    required this.checkpoint,
    required this.onRestore,
  });

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'baru saja';
    if (d.inMinutes < 60) return '${d.inMinutes} mnt lalu';
    if (d.inHours < 24) return '${d.inHours} jam lalu';
    return '${d.inDays} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checkpoint.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 12.5),
                ),
                const SizedBox(height: 3),
                Text(
                  '${checkpoint.fileCount} file • ${_timeAgo(checkpoint.time)}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRestore,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 30),
            ),
            child: const Text('Restore', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

void _openHistory(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black26,
    builder: (_) => const _HistoryPanel(),
  );
}

/// Kiro-style HISTORY panel anchored at the top-right of the chat dock.
class _HistoryPanel extends ConsumerWidget {
  const _HistoryPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final currentId = ref.watch(currentConversationIdProvider);

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final today = <ConversationModel>[];
    final yesterday = <ConversationModel>[];
    final older = <ConversationModel>[];
    for (final c in conversations) {
      final d = todayDate
          .difference(DateTime(c.updatedAt.year, c.updatedAt.month,
              c.updatedAt.day))
          .inDays;
      if (d <= 0) {
        today.add(c);
      } else if (d == 1) {
        yesterday.add(c);
      } else {
        older.add(c);
      }
    }

    void open(String id) {
      ref.read(currentConversationIdProvider.notifier).state = id;
      Navigator.of(context).pop();
    }

    void remove(String id) {
      ref.read(conversationsProvider.notifier).deleteConversation(id);
      if (id == currentId) {
        ref.read(currentConversationIdProvider.notifier).state = null;
      }
    }

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 42, right: 8, bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 300,
            decoration: BoxDecoration(
              color: AppColors.sidebarBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 16)
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('HISTORY',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                      ),
                      _HeaderIcon(
                        icon: Codicons.add,
                        tooltip: 'New Chat',
                        onTap: () {
                          ref
                              .read(currentConversationIdProvider.notifier)
                              .state = null;
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: conversations.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Belum ada percakapan.',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        )
                      : ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: 8),
                          children: [
                            _historyGroup('Today', today, currentId, open,
                                remove),
                            _historyGroup('Yesterday', yesterday, currentId,
                                open, remove),
                            _historyGroup('Older', older, currentId, open,
                                remove),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyGroup(
    String label,
    List<ConversationModel> items,
    String? currentId,
    void Function(String) onOpen,
    void Function(String) onDelete,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ),
        for (final c in items)
          _HistoryRow(
            title: c.title,
            selected: c.id == currentId,
            onTap: () => onOpen(c.id),
            onDelete: () => onDelete(c.id),
          ),
      ],
    );
  }
}

class _HistoryRow extends StatefulWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _HistoryRow({
    required this.title,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: widget.selected
              ? AppColors.surfaceVariant
              : (_hovered ? AppColors.surfaceHover : Colors.transparent),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            children: [
              const Icon(Codicons.commentDiscussion,
                  size: 13, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (_hovered)
                GestureDetector(
                  onTap: widget.onDelete,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Codicons.trash,
                        size: 12, color: AppColors.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApiKeyPrompt extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.key, size: 30, color: AppColors.primary),
            const SizedBox(height: 12),
            const Text(
              'Configure API Key',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter your HidePulsa API key to chat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const SettingsDialog(),
              ),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a confirmation prompt when the agent wants to run a shell command.
class _ApprovalBar extends ConsumerWidget {
  const _ApprovalBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingApprovalProvider);
    if (pending == null) return const SizedBox.shrink();

    void resolve(bool approved, {bool always = false}) {
      if (always) {
        ref.read(autoApproveCommandsProvider.notifier).state = true;
      }
      if (!pending.completer.isCompleted) {
        pending.completer.complete(approved);
      }
      ref.read(pendingApprovalProvider.notifier).state = null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        border: const Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.terminal, size: 14, color: AppColors.warning),
              SizedBox(width: 6),
              Text(
                'Run this command?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.codeBlock,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.codeBlockBorder),
            ),
            child: SelectableText(
              pending.command,
              style: const TextStyle(
                color: AppColors.primaryLight,
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => resolve(true),
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('Run'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => resolve(true, always: true),
                child: const Text('Always allow'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => resolve(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
                child: const Text('Reject'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// New approval bar with checklist support
class _NewApprovalBar extends ConsumerWidget {
  const _NewApprovalBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(approvalRequestProvider);
    if (request == null) return const SizedBox.shrink();
    return const AgentApprovalBar();
  }
}

/// Kiro-style summary of agent file changes with a Revert action.
class _ChangesBar extends ConsumerWidget {
  const _ChangesBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changes = ref.watch(agentChangesProvider);
    if (changes.isEmpty) return const SizedBox.shrink();
    final notifier = ref.read(agentChangesProvider.notifier);

    void revertAll() {
      final paths = notifier.revertAll();
      for (final path in paths) {
        ref.read(editorProvider.notifier).reloadFromDisk(path);
      }
      ref.read(explorerRefreshProvider.notifier).state++;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final c in changes)
                    _ChangeCard(
                      label: notifier.labelFor(c),
                      name: p.basename(c.path),
                      onOpen: () =>
                          ref.read(editorProvider.notifier).openFile(c.path),
                      onRevert: () {
                        notifier.revertOne(c.path);
                        ref
                            .read(editorProvider.notifier)
                            .reloadFromDisk(c.path);
                        ref.read(explorerRefreshProvider.notifier).state++;
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${changes.length} file${changes.length == 1 ? '' : 's'} changed',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
              const Spacer(),
              TextButton(
                onPressed: revertAll,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                ),
                child: const Text('Revert All', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: () => notifier.clear(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                ),
                child: const Text('Keep All', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChangeCard extends StatelessWidget {
  final String label;
  final String name;
  final VoidCallback onOpen;
  final VoidCallback onRevert;

  const _ChangeCard({
    required this.label,
    required this.name,
    required this.onOpen,
    required this.onRevert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Codicons.check, size: 13, color: AppColors.success),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11.5)),
          const SizedBox(width: 6),
          Flexible(
            child: GestureDetector(
              onTap: onOpen,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.5,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Revert',
            child: InkWell(
              onTap: onRevert,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.undo, size: 13, color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
