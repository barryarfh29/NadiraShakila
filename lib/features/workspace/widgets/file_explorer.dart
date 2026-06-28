import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/codicons.dart';
import '../../github/github_dialog.dart';
import '../providers/workspace_provider.dart';
import 'file_icon.dart';

/// VS Code-style file explorer tree for the active workspace.
class FileExplorer extends ConsumerWidget {
  const FileExplorer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final root = ref.watch(workspaceProvider);

    if (root == null) {
      return _NoFolderView();
    }

    return Column(
      children: [
        _ExplorerHeader(rootPath: root),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: [
              _DirChildren(dirPath: root, depth: 0),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExplorerHeader extends ConsumerWidget {
  final String rootPath;
  const _ExplorerHeader({required this.rootPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 35,
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p.basename(rootPath).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _IconAction(
            icon: Codicons.newFile,
            tooltip: 'New File',
            onTap: () => _createEntry(context, ref, isFolder: false),
          ),
          _IconAction(
            icon: Codicons.newFolder,
            tooltip: 'New Folder',
            onTap: () => _createEntry(context, ref, isFolder: true),
          ),
          _IconAction(
            icon: Codicons.refresh,
            tooltip: 'Refresh Explorer',
            onTap: () => ref.read(explorerRefreshProvider.notifier).state++,
          ),
          _IconAction(
            icon: Codicons.collapseAll,
            tooltip: 'Collapse Folders',
            onTap: () => ref.read(expandedDirsProvider.notifier).collapseAll(),
          ),
          _MoreMenu(rootPath: rootPath),
        ],
      ),
    );
  }
}

/// "..." overflow menu with folder-level actions.
class _MoreMenu extends ConsumerWidget {
  final String rootPath;
  const _MoreMenu({required this.rootPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'More Actions',
      offset: const Offset(0, 28),
      color: AppColors.surfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      onSelected: (v) {
        switch (v) {
          case 'open':
            openWorkspaceFolder(context, ref);
            break;
          case 'close':
            ref.read(workspaceProvider.notifier).closeFolder();
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'open',
          height: 34,
          child: Text('Open Folder...',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5)),
        ),
        PopupMenuItem(
          value: 'close',
          height: 34,
          child: Text('Close Folder',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5)),
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(Codicons.ellipsis, size: 16, color: AppColors.textMuted),
      ),
    );
  }
}

/// Prompts for a name and creates a file or folder in the workspace root.
Future<void> _createEntry(BuildContext context, WidgetRef ref,
    {required bool isFolder}) async {
  final root = ref.read(workspaceProvider);
  if (root == null) return;
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final controller = TextEditingController();
      return AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(isFolder ? 'New Folder' : 'New File',
            style: const TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: isFolder ? 'e.g. widgets' : 'e.g. main.dart',
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Create')),
        ],
      );
    },
  );
  if (name == null || name.isEmpty) return;

  final target = p.join(root, name);
  try {
    if (isFolder) {
      Directory(target).createSync(recursive: true);
    } else {
      final file = File(target);
      if (file.existsSync()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File already exists')),
          );
        }
        return;
      }
      file.createSync(recursive: true);
      ref.read(editorProvider.notifier).openFile(target);
    }
    ref.read(explorerRefreshProvider.notifier).state++;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot create: $e')),
      );
    }
  }
}

class _NoFolderView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_off_outlined,
                size: 28, color: AppColors.textMuted),
            const SizedBox(height: 10),
            const Text(
              'No folder opened',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => openWorkspaceFolder(context, ref),
              icon: const Icon(Icons.folder_open, size: 14),
              label: const Text('Open Folder'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => showGitHubClone(context, ref),
              icon: const Icon(Codicons.github, size: 14),
              label: const Text('Clone from GitHub'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recursively renders the children of a directory.
class _DirChildren extends ConsumerWidget {
  final String dirPath;
  final int depth;

  const _DirChildren({required this.dirPath, required this.depth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(explorerRefreshProvider); // rebuild when agent changes files
    final entries = listDirectory(dirPath);
    final expanded = ref.watch(expandedDirsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries)
          if (entry is Directory)
            _DirRow(
              dirPath: entry.path,
              depth: depth,
              isExpanded: expanded.contains(entry.path),
            )
          else
            _FileRow(filePath: entry.path, depth: depth),
      ],
    );
  }
}

class _DirRow extends ConsumerWidget {
  final String dirPath;
  final int depth;
  final bool isExpanded;

  const _DirRow({
    required this.dirPath,
    required this.depth,
    required this.isExpanded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TreeRow(
          depth: depth,
          icon: const FolderIcon(size: 16),
          leading: Icon(
            isExpanded ? Codicons.chevronDown : Codicons.chevronRight,
            size: 14,
            color: AppColors.textMuted,
          ),
          label: p.basename(dirPath),
          onTap: () =>
              ref.read(expandedDirsProvider.notifier).toggle(dirPath),
          onContext: (pos) =>
              _showEntryMenu(context, ref, dirPath, true, pos),
        ),
        if (isExpanded) _DirChildren(dirPath: dirPath, depth: depth + 1),
      ],
    );
  }
}

class _FileRow extends ConsumerWidget {
  final String filePath;
  final int depth;

  const _FileRow({required this.filePath, required this.depth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(editorProvider).activePath;
    return _TreeRow(
      depth: depth,
      icon: FileIcon(fileName: p.basename(filePath), size: 16),
      label: p.basename(filePath),
      selected: active == filePath,
      onTap: () {
        final err = ref.read(editorProvider.notifier).openFile(filePath);
        if (err != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err)),
          );
        }
      },
      onContext: (pos) => _showEntryMenu(context, ref, filePath, false, pos),
    );
  }
}

class _TreeRow extends StatefulWidget {
  final int depth;
  final Widget icon;
  final Widget? leading;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final void Function(Offset globalPosition)? onContext;

  const _TreeRow({
    required this.depth,
    required this.icon,
    this.leading,
    required this.label,
    this.selected = false,
    required this.onTap,
    this.onContext,
  });

  @override
  State<_TreeRow> createState() => _TreeRowState();
}

class _TreeRowState extends State<_TreeRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: widget.onContext == null
            ? null
            : (d) => widget.onContext!(d.globalPosition),
        child: Container(
          height: 22,
          color: widget.selected
              ? AppColors.surfaceVariant
              : (_hovered ? AppColors.surfaceHover : Colors.transparent),
          padding: EdgeInsets.only(left: 8.0 + widget.depth * 12, right: 8),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                child: widget.leading ?? const SizedBox.shrink(),
              ),
              widget.icon,
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.label,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconAction({
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
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

// === File icon helpers ===

/// Opens the native folder picker and sets the chosen folder as workspace.
/// Falls back to a manual path-entry dialog if the native picker is unavailable.
Future<void> openWorkspaceFolder(BuildContext context, WidgetRef ref) async {
  String? path;
  try {
    path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Open Folder as Workspace',
      initialDirectory: ref.read(workspaceProvider),
    );
  } catch (_) {
    // Native picker failed (rare on some setups) → fall back to manual entry.
    if (context.mounted) {
      path = await _promptOpenFolderManual(context, ref);
    }
  }

  if (path == null || path.isEmpty) return;
  final ok = ref.read(workspaceProvider.notifier).openFolder(path);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder not found: $path')),
    );
  }
}

/// Fallback dialog to type/paste an absolute folder path.
Future<String?> _promptOpenFolderManual(
    BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController(
    text: ref.read(workspaceProvider) ?? Directory.current.path,
  );
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      title: const Text('Open Folder', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste the absolute path of the folder to open as workspace.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                hintText: r'e.g. D:\projects\my_app',
                prefixIcon: Icon(Icons.folder_outlined, size: 18),
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('Open'),
        ),
      ],
    ),
  );
}

// === Explorer context menu (right-click) ===

PopupMenuItem<String> _menuItem(String value, String label,
    {Color? color}) {
  return PopupMenuItem<String>(
    value: value,
    height: 34,
    child: Text(label,
        style: TextStyle(
            color: color ?? AppColors.textPrimary, fontSize: 12.5)),
  );
}

Future<void> _showEntryMenu(BuildContext context, WidgetRef ref, String path,
    bool isFolder, Offset pos) async {
  final selected = await showMenu<String>(
    context: context,
    color: AppColors.surfaceVariant,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: AppColors.border),
    ),
    position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
    items: [
      if (isFolder) ...[
        _menuItem('newFile', 'New File'),
        _menuItem('newFolder', 'New Folder'),
        const PopupMenuDivider(),
      ],
      _menuItem('rename', 'Rename'),
      _menuItem('delete', 'Delete', color: AppColors.error),
      const PopupMenuDivider(),
      _menuItem('copyPath', 'Copy Path'),
    ],
  );
  if (selected == null || !context.mounted) return;
  switch (selected) {
    case 'newFile':
      await _newEntryIn(context, ref, path, isFolder: false);
      break;
    case 'newFolder':
      await _newEntryIn(context, ref, path, isFolder: true);
      break;
    case 'rename':
      await _renameEntry(context, ref, path, isFolder);
      break;
    case 'delete':
      await _deleteEntry(context, ref, path, isFolder);
      break;
    case 'copyPath':
      await Clipboard.setData(ClipboardData(text: path));
      break;
  }
}

Future<String?> _promptName(
    BuildContext context, String title, String initial) {
  final ctrl = TextEditingController(text: initial);
  ctrl.selection =
      TextSelection(baseOffset: 0, extentOffset: initial.length);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text(title,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: const InputDecoration(isDense: true),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<void> _newEntryIn(BuildContext context, WidgetRef ref, String parentDir,
    {required bool isFolder}) async {
  final name =
      await _promptName(context, isFolder ? 'New Folder' : 'New File', '');
  if (name == null || name.isEmpty) return;
  final target = p.join(parentDir, name);
  try {
    if (isFolder) {
      Directory(target).createSync(recursive: true);
    } else {
      File(target).createSync(recursive: true);
    }
  } catch (_) {}
  // Ensure the parent folder is expanded so the new entry is visible.
  final expanded = ref.read(expandedDirsProvider.notifier);
  if (!expanded.isExpanded(parentDir)) expanded.toggle(parentDir);
  ref.read(explorerRefreshProvider.notifier).state++;
  if (!isFolder && context.mounted) {
    ref.read(editorProvider.notifier).openFile(target);
  }
}

Future<void> _renameEntry(
    BuildContext context, WidgetRef ref, String path, bool isFolder) async {
  final newName = await _promptName(context, 'Rename', p.basename(path));
  if (newName == null || newName.isEmpty || newName == p.basename(path)) {
    return;
  }
  final newPath = p.join(p.dirname(path), newName);
  final editor = ref.read(editorProvider.notifier);
  final openFiles = ref.read(editorProvider).openFiles;
  try {
    if (isFolder) {
      Directory(path).renameSync(newPath);
      // Close any open tabs that lived under the renamed folder.
      for (final f in openFiles) {
        if (p.isWithin(path, f.path)) editor.closeFile(f.path);
      }
    } else {
      File(path).renameSync(newPath);
      if (openFiles.any((f) => f.path == path)) {
        editor.closeFile(path);
        editor.openFile(newPath);
      }
    }
  } catch (_) {}
  ref.read(explorerRefreshProvider.notifier).state++;
}

Future<void> _deleteEntry(
    BuildContext context, WidgetRef ref, String path, bool isFolder) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text('Hapus ${p.basename(path)}?',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
      content: Text(
        isFolder
            ? 'Folder dan seluruh isinya akan dihapus permanen.'
            : 'File akan dihapus permanen.',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  if (confirm != true) return;
  final editor = ref.read(editorProvider.notifier);
  final openFiles = ref.read(editorProvider).openFiles;
  try {
    if (isFolder) {
      for (final f in openFiles) {
        if (p.isWithin(path, f.path)) editor.closeFile(f.path);
      }
      Directory(path).deleteSync(recursive: true);
    } else {
      if (openFiles.any((f) => f.path == path)) editor.closeFile(path);
      File(path).deleteSync();
    }
  } catch (_) {}
  ref.read(explorerRefreshProvider.notifier).state++;
}
