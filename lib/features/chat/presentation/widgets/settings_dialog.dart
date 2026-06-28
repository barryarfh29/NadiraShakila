import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../workspace/providers/workspace_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late TextEditingController _apiKeyController;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(
      text: ref.read(apiKeyProvider),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.settings, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // API Key section
            const Text(
              'API Configuration',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your HidePulsa AI API key to enable chat functionality.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),

            // API Key input
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                labelText: 'API Key',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                hintText: 'sk-...',
                prefixIcon:
                    const Icon(Icons.key, size: 18, color: AppColors.textMuted),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureKey
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () {
                    setState(() => _obscureKey = !_obscureKey);
                  },
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Base URL info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Base URL: https://ai.hidepulsa.com/v1',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Behavior section
            const Text(
              'Assistant Behavior',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _TemperatureSlider(),
            const SizedBox(height: 4),
            _ToggleRow(
              label: 'Agent mode by default',
              description: 'Let the AI edit files & run commands.',
              provider: agentModeProvider,
            ),
            _ToggleRow(
              label: 'Auto-approve commands',
              description: 'Run shell commands without confirmation.',
              provider: autoApproveCommandsProvider,
            ),

            const SizedBox(height: 20),

            // Editor section
            const Text(
              'Editor',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _EditorFontSize(),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saveSettings,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _saveSettings() {
    final apiKey = _apiKeyController.text.trim();
    ref.read(apiKeyProvider.notifier).setApiKey(apiKey);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _TemperatureSlider extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final temp = ref.watch(temperatureProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Temperature',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            const Spacer(),
            Text(temp.toStringAsFixed(2),
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontFamily: 'monospace')),
          ],
        ),
        Slider(
          value: temp,
          min: 0,
          max: 1.5,
          divisions: 30,
          activeColor: AppColors.primary,
          onChanged: (v) =>
              ref.read(temperatureProvider.notifier).state = v,
        ),
        const Text(
          'Lower = focused & deterministic, higher = more creative.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _ToggleRow extends ConsumerWidget {
  final String label;
  final String description;
  final StateProvider<bool> provider;

  const _ToggleRow({
    required this.label,
    required this.description,
    required this.provider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(provider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13)),
                Text(description,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => ref.read(provider.notifier).state = v,
          ),
        ],
      ),
    );
  }
}

class _EditorFontSize extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(editorFontSizeProvider);
    void set(double v) =>
        ref.read(editorFontSizeProvider.notifier).state = v.clamp(10.0, 24.0);

    return Row(
      children: [
        const Expanded(
          child: Text('Font size',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        ),
        IconButton(
          onPressed: () => set(size - 1),
          icon: const Icon(Icons.remove, size: 16),
          color: AppColors.textSecondary,
          visualDensity: VisualDensity.compact,
        ),
        Container(
          width: 36,
          alignment: Alignment.center,
          child: Text(size.toStringAsFixed(0),
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: 'JetBrains Mono')),
        ),
        IconButton(
          onPressed: () => set(size + 1),
          icon: const Icon(Icons.add, size: 16),
          color: AppColors.textSecondary,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
