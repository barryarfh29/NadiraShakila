import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/app_theme.dart';
import 'features/ide/ide_shell.dart';
import 'features/workspace/providers/workspace_provider.dart';

class AiDesktopApp extends ConsumerWidget {
  const AiDesktopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Nadira Shakila',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _CloseGuard(child: IdeShell()),
    );
  }
}

/// Intercepts window close to warn about unsaved files before exiting.
class _CloseGuard extends ConsumerStatefulWidget {
  final Widget child;
  const _CloseGuard({required this.child});

  @override
  ConsumerState<_CloseGuard> createState() => _CloseGuardState();
}

class _CloseGuardState extends ConsumerState<_CloseGuard>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final dirty =
        ref.read(editorProvider).openFiles.where((f) => f.isDirty).toList();
    if (dirty.isEmpty) {
      await windowManager.destroy();
      return;
    }
    if (!mounted) {
      await windowManager.destroy();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          '${dirty.length} file belum disimpan',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        ),
        content: Text(
          'File: ${dirty.map((f) => f.name).join(', ')}\n\n'
          'Tutup aplikasi tanpa menyimpan?',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Batal',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('discard'),
            child: const Text('Tutup Tanpa Simpan',
                style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan Semua & Tutup'),
          ),
        ],
      ),
    );
    if (choice == null || choice == 'cancel') return;
    if (choice == 'save') {
      final notifier = ref.read(editorProvider.notifier);
      for (final f in dirty) {
        notifier.saveFile(f.path);
      }
    }
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
