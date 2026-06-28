import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/codicons.dart';
import '../data/agent_approval.dart';

/// Rich approval bar with checklist support (like Kiro's confirm dialogs)
class AgentApprovalBar extends ConsumerStatefulWidget {
  const AgentApprovalBar({super.key});

  @override
  ConsumerState<AgentApprovalBar> createState() => _AgentApprovalBarState();
}

class _AgentApprovalBarState extends ConsumerState<AgentApprovalBar> {
  @override
  Widget build(BuildContext context) {
    final request = ref.watch(approvalRequestProvider);
    if (request == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: _bgColor(request.type),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(_icon(request.type), size: 15, color: _iconColor(request.type)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          if (request.description != null) ...[
            const SizedBox(height: 6),
            Text(
              request.description!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
            ),
          ],

          const SizedBox(height: 10),

          // Checklist items
          if (request.items.length == 1 && request.type == ApprovalType.command)
            // Single command — show code block
            _CommandBlock(command: request.items.first.label)
          else
            // Multiple items — show checklist
            _ChecklistItems(items: request.items, onChanged: () => setState(() {})),

          const SizedBox(height: 12),

          // Action buttons
          _ActionButtons(
            request: request,
            onApprove: () => _resolve(request, true),
            onAlwaysAllow: () => _resolve(request, true, always: true),
            onReject: () => _resolve(request, false),
          ),
        ],
      ),
    );
  }

  void _resolve(ApprovalRequest request, bool approved, {bool always = false}) {
    final checkedItems = request.items.where((i) => i.checked).toList();

    if (always) {
      final settings = ref.read(autoApproveSettingsProvider.notifier);
      switch (request.type) {
        case ApprovalType.command:
          settings.allowCommands();
          break;
        case ApprovalType.install:
          settings.allowInstalls();
          break;
        default:
          break;
      }
    }

    if (!request.completer.isCompleted) {
      request.completer.complete(ApprovalResult(
        approved: approved,
        alwaysAllow: always,
        approvedItems: checkedItems,
      ));
    }
    ref.read(approvalRequestProvider.notifier).state = null;
  }

  IconData _icon(ApprovalType type) {
    switch (type) {
      case ApprovalType.command:
        return Codicons.terminal;
      case ApprovalType.install:
        return Icons.download_rounded;
      case ApprovalType.writeFile:
        return Codicons.newFile;
      case ApprovalType.deleteFile:
        return Codicons.trash;
      case ApprovalType.multiStep:
        return Codicons.check;
    }
  }

  Color _iconColor(ApprovalType type) {
    switch (type) {
      case ApprovalType.command:
        return AppColors.warning;
      case ApprovalType.install:
        return AppColors.primary;
      case ApprovalType.writeFile:
        return AppColors.secondary;
      case ApprovalType.deleteFile:
        return AppColors.error;
      case ApprovalType.multiStep:
        return AppColors.primary;
    }
  }

  Color _bgColor(ApprovalType type) {
    switch (type) {
      case ApprovalType.deleteFile:
        return AppColors.error.withValues(alpha: 0.06);
      case ApprovalType.install:
        return AppColors.primary.withValues(alpha: 0.06);
      default:
        return AppColors.warning.withValues(alpha: 0.06);
    }
  }
}

class _CommandBlock extends StatelessWidget {
  final String command;
  const _CommandBlock({required this.command});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.codeBlock,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.codeBlockBorder),
      ),
      child: SelectableText(
        command,
        style: const TextStyle(
          color: AppColors.primaryLight,
          fontFamily: 'JetBrains Mono',
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ChecklistItems extends StatelessWidget {
  final List<ApprovalItem> items;
  final VoidCallback onChanged;

  const _ChecklistItems({required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          color: AppColors.border,
          indent: 12,
          endIndent: 12,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return InkWell(
            onTap: () {
              item.checked = !item.checked;
              onChanged();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    item.checked ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 18,
                    color: item.checked ? AppColors.primary : AppColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    _itemIcon(item.type),
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            color: item.checked
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontSize: 12,
                            fontFamily: 'JetBrains Mono',
                            decoration: item.checked
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        if (item.detail != null)
                          Text(
                            item.detail!,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _itemIcon(ApprovalType type) {
    switch (type) {
      case ApprovalType.command:
        return Codicons.terminal;
      case ApprovalType.install:
        return Icons.download_rounded;
      case ApprovalType.writeFile:
        return Codicons.newFile;
      case ApprovalType.deleteFile:
        return Codicons.trash;
      case ApprovalType.multiStep:
        return Codicons.check;
    }
  }
}

class _ActionButtons extends StatelessWidget {
  final ApprovalRequest request;
  final VoidCallback onApprove;
  final VoidCallback onAlwaysAllow;
  final VoidCallback onReject;

  const _ActionButtons({
    required this.request,
    required this.onApprove,
    required this.onAlwaysAllow,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final checkedCount = request.items.where((i) => i.checked).length;
    final hasChecked = checkedCount > 0;

    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: hasChecked ? onApprove : null,
          icon: const Icon(Icons.check_rounded, size: 16),
          label: Text(
            request.items.length > 1
                ? 'Approve ($checkedCount/${request.items.length})'
                : 'Approve',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: onAlwaysAllow,
          child: Text(
            'Selalu izinkan ${_typeLabel(request.type)}',
            style: const TextStyle(fontSize: 11),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onReject,
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Tolak', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  String _typeLabel(ApprovalType type) {
    switch (type) {
      case ApprovalType.command:
        return 'commands';
      case ApprovalType.install:
        return 'installs';
      case ApprovalType.writeFile:
        return 'file writes';
      case ApprovalType.deleteFile:
        return 'deletes';
      case ApprovalType.multiStep:
        return 'actions';
    }
  }
}
