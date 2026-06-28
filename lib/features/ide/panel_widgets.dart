import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Standard side-panel header: UPPERCASE title (11px / w600 / letterspaced)
/// with optional trailing action icons, matching VS Code / Kiro.
class PanelHeader extends StatelessWidget {
  final String title;
  final List<Widget> actions;

  const PanelHeader({super.key, required this.title, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      padding: const EdgeInsets.only(left: 14, right: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Small icon button used in panel headers.
class PanelIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const PanelIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<PanelIconButton> createState() => _PanelIconButtonState();
}

class _PanelIconButtonState extends State<PanelIconButton> {
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
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _hovered ? AppColors.surfaceHover : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 15,
              color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Collapsible section header like "INSTALLED" / "AVAILABLE".
class PanelSectionHeader extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback? onTap;
  final Widget? trailing;

  const PanelSectionHeader({
    super.key,
    required this.title,
    this.expanded = true,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.expand_more : Icons.chevron_right,
              size: 16,
              color: AppColors.textMuted,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Full-width primary (purple) button used inside panels, matching VS Code's
/// "Initialize Repository" / "Run and Debug" buttons.
class PanelPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;

  const PanelPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = AppColors.primaryHover,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: onPressed == null ? AppColors.surfaceLight : color,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon,
                      size: 15,
                      color: onPressed == null
                          ? AppColors.textMuted
                          : Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: onPressed == null
                        ? AppColors.textMuted
                        : Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Body paragraph text used in panels (13px, secondary).
class PanelText extends StatelessWidget {
  final String text;
  const PanelText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        height: 1.5,
      ),
    );
  }
}
