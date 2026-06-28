import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'updater_provider.dart';
import 'updater_service.dart';

/// Banner/dialog yang muncul kalau ada update tersedia.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateProvider);

    if (updateState.status != UpdateStatus.available) {
      return const SizedBox.shrink();
    }

    final info = updateState.updateInfo!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1A365D),
        border: Border(
          bottom: BorderSide(color: AppColors.primary, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.system_update, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Update v${info.version} tersedia (${info.sizeMB} MB)',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _showUpdateDialog(context, ref, info),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child:
                const Text('Update', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => ref.read(updateProvider.notifier).dismiss(),
            child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  void _showUpdateDialog(
      BuildContext context, WidgetRef ref, UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(info: info),
    );
  }
}

class _UpdateDialog extends ConsumerWidget {
  final UpdateInfo info;
  const _UpdateDialog({required this.info});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateState = ref.watch(updateProvider);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Row(
        children: [
          const Icon(Icons.upgrade, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Text(
            'Update v${info.version}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versi baru tersedia! (${info.sizeMB} MB)',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            if (info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
            if (updateState.status == UpdateStatus.downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: updateState.downloadProgress,
                backgroundColor: AppColors.border,
                color: AppColors.primary,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 6),
              Text(
                'Downloading... ${(updateState.downloadProgress * 100).toInt()}%',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ],
            if (updateState.status == UpdateStatus.installing) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Installing... App akan restart otomatis.',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
            if (updateState.status == UpdateStatus.error) ...[
              const SizedBox(height: 12),
              Text(
                updateState.errorMessage ?? 'Update gagal.',
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (updateState.status == UpdateStatus.available ||
            updateState.status == UpdateStatus.error) ...[
          TextButton(
            onPressed: () {
              ref.read(updateProvider.notifier).dismiss();
              Navigator.of(context).pop();
            },
            child: const Text('Nanti',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () =>
                ref.read(updateProvider.notifier).installUpdate(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Sekarang'),
          ),
        ],
      ],
    );
  }
}
