import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Vertical activity bar on the far left, similar to Kiro AI / VS Code
class ActivityBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTabChanged;

  const ActivityBar({
    super.key,
    required this.activeIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      color: AppColors.activityBar,
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Logo / Brand
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const Divider(indent: 8, endIndent: 8),
          const SizedBox(height: 4),

          // Chat tab
          _ActivityBarItem(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            tooltip: 'Chat',
            isActive: activeIndex == 0,
            onTap: () => onTabChanged(0),
          ),

          // History tab
          _ActivityBarItem(
            icon: Icons.history_outlined,
            activeIcon: Icons.history,
            tooltip: 'History',
            isActive: activeIndex == 1,
            onTap: () => onTabChanged(1),
          ),

          // Explorer (future)
          _ActivityBarItem(
            icon: Icons.folder_outlined,
            activeIcon: Icons.folder,
            tooltip: 'Explorer',
            isActive: activeIndex == 2,
            onTap: () => onTabChanged(2),
          ),

          const Spacer(),

          // Bottom items
          _ActivityBarItem(
            icon: Icons.terminal_outlined,
            activeIcon: Icons.terminal,
            tooltip: 'Terminal',
            isActive: activeIndex == 3,
            onTap: () => onTabChanged(3),
          ),

          _ActivityBarItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            tooltip: 'Settings',
            isActive: activeIndex == 4,
            onTap: () => onTabChanged(4),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ActivityBarItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _ActivityBarItem({
    required this.icon,
    required this.activeIcon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ActivityBarItem> createState() => _ActivityBarItemState();
}

class _ActivityBarItemState extends State<_ActivityBarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 48,
            height: 42,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: widget.isActive
                      ? AppColors.activityBarActive
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Center(
              child: Icon(
                widget.isActive ? widget.activeIcon : widget.icon,
                size: 20,
                color: widget.isActive
                    ? AppColors.textPrimary
                    : (_hovered
                        ? AppColors.textPrimary
                        : AppColors.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
