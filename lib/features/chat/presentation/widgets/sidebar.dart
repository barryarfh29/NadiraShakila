import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../providers/chat_provider.dart';

/// Sidebar panel that changes content based on active tab
class Sidebar extends ConsumerWidget {
  final int activeTab;
  final VoidCallback onNewChat;
  final VoidCallback onSettingsPressed;

  const Sidebar({
    super.key,
    required this.activeTab,
    required this.onNewChat,
    required this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          _buildSidebarHeader(context),
          Expanded(child: _buildContent(context, ref)),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context) {
    String title;
    switch (activeTab) {
      case 0:
        title = 'CHAT';
        break;
      case 1:
        title = 'HISTORY';
        break;
      case 2:
        title = 'EXPLORER';
        break;
      case 3:
        title = 'TERMINAL';
        break;
      case 4:
        title = 'SETTINGS';
        break;
      default:
        title = 'CHAT';
    }

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppColors.sidebarHeader,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          if (activeTab == 0 || activeTab == 1)
            _SidebarHeaderAction(
              icon: Icons.add,
              tooltip: 'New Chat',
              onTap: onNewChat,
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    switch (activeTab) {
      case 0:
      case 1:
        return _ChatHistoryList(onNewChat: onNewChat);
      case 4:
        return _SettingsPanel(onSettingsPressed: onSettingsPressed);
      default:
        return _ComingSoonPanel(feature: _getTabName(activeTab));
    }
  }

  String _getTabName(int tab) {
    switch (tab) {
      case 2:
        return 'File Explorer';
      case 3:
        return 'Terminal';
      default:
        return 'Feature';
    }
  }
}

class _SidebarHeaderAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SidebarHeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_SidebarHeaderAction> createState() => _SidebarHeaderActionState();
}

class _SidebarHeaderActionState extends State<_SidebarHeaderAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _hovered ? AppColors.surfaceHover : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatHistoryList extends ConsumerWidget {
  final VoidCallback onNewChat;

  const _ChatHistoryList({required this.onNewChat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final currentId = ref.watch(currentConversationIdProvider);

    if (conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline,
                  size: 24, color: AppColors.textMuted),
              const SizedBox(height: 10),
              const Text(
                'No conversations',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onNewChat,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Start a chat'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group conversations by date
    final today = DateTime.now();
    final todayConvos = <dynamic>[];
    final yesterdayConvos = <dynamic>[];
    final olderConvos = <dynamic>[];

    for (final c in conversations) {
      final diff = today.difference(c.updatedAt).inDays;
      if (diff == 0) {
        todayConvos.add(c);
      } else if (diff == 1) {
        yesterdayConvos.add(c);
      } else {
        olderConvos.add(c);
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        if (todayConvos.isNotEmpty) ...[
          _buildSectionHeader('Today'),
          ...todayConvos.map((c) => _ConversationItem(
                conversation: c,
                isSelected: c.id == currentId,
                onTap: () => ref
                    .read(currentConversationIdProvider.notifier)
                    .state = c.id,
                onDelete: () {
                  ref
                      .read(conversationsProvider.notifier)
                      .deleteConversation(c.id);
                  if (c.id == currentId) {
                    ref.read(currentConversationIdProvider.notifier).state =
                        null;
                  }
                },
              )),
        ],
        if (yesterdayConvos.isNotEmpty) ...[
          _buildSectionHeader('Yesterday'),
          ...yesterdayConvos.map((c) => _ConversationItem(
                conversation: c,
                isSelected: c.id == currentId,
                onTap: () => ref
                    .read(currentConversationIdProvider.notifier)
                    .state = c.id,
                onDelete: () {
                  ref
                      .read(conversationsProvider.notifier)
                      .deleteConversation(c.id);
                  if (c.id == currentId) {
                    ref.read(currentConversationIdProvider.notifier).state =
                        null;
                  }
                },
              )),
        ],
        if (olderConvos.isNotEmpty) ...[
          _buildSectionHeader('Older'),
          ...olderConvos.map((c) => _ConversationItem(
                conversation: c,
                isSelected: c.id == currentId,
                onTap: () => ref
                    .read(currentConversationIdProvider.notifier)
                    .state = c.id,
                onDelete: () {
                  ref
                      .read(conversationsProvider.notifier)
                      .deleteConversation(c.id);
                  if (c.id == currentId) {
                    ref.read(currentConversationIdProvider.notifier).state =
                        null;
                  }
                },
              )),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ConversationItem extends StatefulWidget {
  final dynamic conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationItem({
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends State<_ConversationItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.surfaceVariant
                : (_hovered ? AppColors.surfaceHover : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 13,
                color: widget.isSelected
                    ? AppColors.primary
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (_hovered || widget.isSelected)
                GestureDetector(
                  onTap: widget.onDelete,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.close, size: 13, color: AppColors.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  final VoidCallback onSettingsPressed;

  const _SettingsPanel({required this.onSettingsPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsItem(
            icon: Icons.key_outlined,
            label: 'API Configuration',
            onTap: onSettingsPressed,
          ),
          _buildSettingsItem(
            icon: Icons.palette_outlined,
            label: 'Appearance',
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.tune_outlined,
            label: 'Model Parameters',
            onTap: () {},
          ),
          _buildSettingsItem(
            icon: Icons.info_outline,
            label: 'About',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonPanel extends StatelessWidget {
  final String feature;

  const _ComingSoonPanel({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction_outlined,
              size: 24, color: AppColors.textMuted),
          const SizedBox(height: 8),
          Text(
            feature,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            'Coming soon',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
