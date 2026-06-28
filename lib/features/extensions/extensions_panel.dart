import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../ide/panel_widgets.dart';
import '../mcp/mcp_panel.dart';

class _Feature {
  final IconData icon;
  final Color color;
  final String name;
  final String description;
  final String author;
  const _Feature(
      this.icon, this.color, this.name, this.description, this.author);
}

/// Extensions-style panel showing the built-in capabilities of the app,
/// laid out like the VS Code / Kiro extensions list. The search box filters
/// the built-in features (there is no external marketplace).
class ExtensionsPanel extends StatefulWidget {
  const ExtensionsPanel({super.key});

  @override
  State<ExtensionsPanel> createState() => _ExtensionsPanelState();
}

class _ExtensionsPanelState extends State<ExtensionsPanel> {
  static const _author = 'Nadira Shakila';

  static const _features = [
    _Feature(Icons.bolt, AppColors.primary, 'AI Agent',
        'Autonomous file editing and command execution.', _author),
    _Feature(Icons.auto_awesome, AppColors.primary, 'Inline Edit (Ctrl+I)',
        'Edit selected code with AI, preview & accept.', _author),
    _Feature(Icons.checklist_rounded, AppColors.info, 'Specs',
        'Plan features: Requirements → Design → Tasks.', _author),
    _Feature(Icons.policy_outlined, AppColors.accent, 'Steering',
        'Project rules always sent to the AI.', _author),
    _Feature(Icons.bolt_outlined, AppColors.warning, 'Agent Hooks',
        'Event-driven automation (on save, manual).', _author),
    _Feature(Icons.restore, AppColors.success, 'Checkpoints',
        'Restore points to roll back agent changes.', _author),
    _Feature(Icons.terminal, AppColors.success, 'Integrated Terminal',
        'Real PTY shell inside the editor.', _author),
    _Feature(Icons.account_tree, AppColors.warning, 'Source Control',
        'Git status, commit, push and pull.', _author),
    _Feature(Icons.search, AppColors.info, 'Workspace Search',
        'Full-text search across your files.', _author),
    _Feature(Icons.code, AppColors.accent, 'Syntax Highlighting',
        'Color highlighting for many languages.', _author),
  ];

  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _features
        : _features
            .where((f) =>
                f.name.toLowerCase().contains(q) ||
                f.description.toLowerCase().contains(q))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PanelHeader(title: 'Extensions'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 12),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: 'Search built-in features',
                      hintStyle: TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ],
            ),
          ),
        ),
        const PanelSectionHeader(title: 'Installed'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            children: [
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Tidak ada fitur cocok.',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                )
              else
                for (final f in filtered) _FeatureCard(feature: f),
              const SizedBox(height: 6),
              const Divider(height: 1),
              const McpSection(),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.feature;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: _hovered ? AppColors.surfaceHover : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: f.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(f.icon, size: 20, color: f.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    f.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'by ${f.author}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
