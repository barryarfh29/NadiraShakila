import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/chat_provider.dart';

/// Compact model selector chip used in headers.
class ModelSelectorChip extends ConsumerWidget {
  const ModelSelectorChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(selectedModelProvider);
    final availableModels = ref.watch(availableModelsProvider);

    return PopupMenuButton<String>(
      initialValue: model,
      onSelected: (m) => ref.read(selectedModelProvider.notifier).state = m,
      offset: const Offset(0, 32),
      color: AppColors.surfaceVariant,
      constraints: const BoxConstraints(maxHeight: 420, maxWidth: 320),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      itemBuilder: (context) => [
        _menuItem(ApiConstants.autoModelId, 'Auto',
            'Best model for the task', Icons.auto_awesome),
        const PopupMenuDivider(),
        ...availableModels.map((m) => _menuItem(
              m,
              _formatModelName(m),
              m,
              _iconFor(m),
            )),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined,
                size: 13, color: AppColors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _shortName(model),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
      String id, String name, String desc, IconData icon) {
    return PopupMenuItem(
      value: id,
      height: 38,
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 12)),
                if (desc != name)
                  Text(desc,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 9),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatModelName(String modelId) {
    final parts = modelId.split('/');
    final name = parts.length > 1 ? parts.sublist(1).join('/') : parts[0];
    return name.replaceAll('-', ' ').replaceAll('.', ' ');
  }

  IconData _iconFor(String modelId) {
    if (modelId.contains('claude')) return Icons.psychology;
    if (modelId.contains('gemini') || modelId.contains('gemma')) {
      return Icons.diamond;
    }
    if (modelId.contains('deepseek')) return Icons.explore;
    if (modelId.contains('qwen')) return Icons.auto_awesome;
    if (modelId.contains('glm')) return Icons.hub;
    return Icons.smart_toy;
  }

  String _shortName(String model) {
    if (model == ApiConstants.autoModelId) return 'Auto';
    final parts = model.split('/');
    final name = parts.last.split(':').first;
    if (name.length > 20) return '${name.substring(0, 18)}..';
    return name;
  }
}
