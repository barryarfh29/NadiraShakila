import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage/hive_storage.dart';
import '../data/editor_file.dart';

// === Workspace root folder ===

/// The currently opened workspace folder path (null if none open).
final workspaceProvider =
    StateNotifierProvider<WorkspaceNotifier, String?>((ref) {
  return WorkspaceNotifier();
});

class WorkspaceNotifier extends StateNotifier<String?> {
  static const _key = 'workspace_path';

  WorkspaceNotifier() : super(null) {
    _restore();
  }

  void _restore() {
    final saved =
        HiveStorage.settings.get(_key, defaultValue: '') as String;
    if (saved.isNotEmpty && Directory(saved).existsSync()) {
      state = saved;
    }
  }

  /// Open a folder as the active workspace. Returns true if valid.
  bool openFolder(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) return false;
    HiveStorage.settings.put(_key, path);
    state = path;
    return true;
  }

  void closeFolder() {
    HiveStorage.settings.delete(_key);
    state = null;
  }
}

/// Directories the user has expanded in the file explorer.
final expandedDirsProvider =
    StateNotifierProvider<ExpandedDirsNotifier, Set<String>>((ref) {
  // Reset expansion whenever the workspace changes.
  ref.watch(workspaceProvider);
  return ExpandedDirsNotifier();
});

class ExpandedDirsNotifier extends StateNotifier<Set<String>> {
  ExpandedDirsNotifier() : super({});

  void toggle(String path) {
    final next = Set<String>.from(state);
    if (next.contains(path)) {
      next.remove(path);
    } else {
      next.add(path);
    }
    state = next;
  }

  bool isExpanded(String path) => state.contains(path);

  void collapseAll() => state = {};
}

/// Lists the immediate children of a directory, folders first then files,
/// each sorted alphabetically. Hidden entries (starting with '.') and common
/// heavy build folders are skipped.
List<FileSystemEntity> listDirectory(String dirPath) {
  const skip = {
    '.git',
    '.dart_tool',
    'build',
    'node_modules',
    '.idea',
    '.vscode',
  };
  try {
    final entries = Directory(dirPath).listSync(followLinks: false);
    final dirs = <Directory>[];
    final files = <File>[];
    for (final e in entries) {
      final name = p.basename(e.path);
      if (skip.contains(name)) continue;
      if (e is Directory) {
        dirs.add(e);
      } else if (e is File) {
        files.add(e);
      }
    }
    dirs.sort((a, b) => p
        .basename(a.path)
        .toLowerCase()
        .compareTo(p.basename(b.path).toLowerCase()));
    files.sort((a, b) => p
        .basename(a.path)
        .toLowerCase()
        .compareTo(p.basename(b.path).toLowerCase()));
    return [...dirs, ...files];
  } catch (_) {
    return [];
  }
}

// === Editor tabs ===

final editorProvider =
    StateNotifierProvider<EditorNotifier, EditorState>((ref) {
  return EditorNotifier();
});

class EditorState {
  final List<EditorFile> openFiles;
  final String? activePath;
  final String? splitPath; // file shown in the right (split) pane

  const EditorState({
    this.openFiles = const [],
    this.activePath,
    this.splitPath,
  });

  EditorFile? get activeFile {
    if (activePath == null) return null;
    for (final f in openFiles) {
      if (f.path == activePath) return f;
    }
    return null;
  }

  EditorFile? get splitFile {
    if (splitPath == null) return null;
    for (final f in openFiles) {
      if (f.path == splitPath) return f;
    }
    return null;
  }

  EditorState copyWith({
    List<EditorFile>? openFiles,
    String? activePath,
    Object? splitPath = _sentinel,
  }) {
    return EditorState(
      openFiles: openFiles ?? this.openFiles,
      activePath: activePath ?? this.activePath,
      splitPath:
          splitPath == _sentinel ? this.splitPath : splitPath as String?,
    );
  }
}

const Object _sentinel = Object();

/// Max file size we will open in the editor (1 MB).
const _maxEditableBytes = 1024 * 1024;

class EditorNotifier extends StateNotifier<EditorState> {
  EditorNotifier() : super(const EditorState()) {
    _restore();
  }

  static const _openKey = 'open_files';
  static const _activeKey = 'active_file';

  void _restore() {
    final paths = (HiveStorage.settings.get(_openKey, defaultValue: <String>[])
            as List)
        .cast<String>();
    if (paths.isEmpty) return;
    final active = HiveStorage.settings.get(_activeKey) as String?;
    final files = <EditorFile>[];
    for (final path in paths) {
      final f = File(path);
      if (!f.existsSync()) continue;
      try {
        if (f.lengthSync() > _maxEditableBytes) continue;
        final content = f.readAsStringSync();
        files.add(EditorFile(
            path: path, savedContent: content, content: content));
      } catch (_) {}
    }
    if (files.isNotEmpty) {
      final activePath =
          files.any((f) => f.path == active) ? active : files.last.path;
      state = EditorState(openFiles: files, activePath: activePath);
    }
  }

  void _persist() {
    HiveStorage.settings
        .put(_openKey, state.openFiles.map((f) => f.path).toList());
    HiveStorage.settings.put(_activeKey, state.activePath);
  }

  /// Open a file in a tab. If already open, just activates it.
  /// Returns an error message on failure, null on success.
  String? openFile(String path) {
    final existing = state.openFiles.where((f) => f.path == path).toList();
    if (existing.isNotEmpty) {
      state = state.copyWith(activePath: path);
      _persist();
      return null;
    }

    final file = File(path);
    try {
      final length = file.lengthSync();
      if (length > _maxEditableBytes) {
        return 'File too large to open (${(length / 1024).round()} KB).';
      }
      final content = file.readAsStringSync();
      final editorFile = EditorFile(
        path: path,
        savedContent: content,
        content: content,
      );
      state = state.copyWith(
        openFiles: [...state.openFiles, editorFile],
        activePath: path,
      );
      _persist();
      return null;
    } catch (e) {
      return 'Cannot open file: $e';
    }
  }

  void setActive(String path) {
    state = state.copyWith(activePath: path);
    _persist();
  }

  /// Toggles the split (right) editor pane showing the active file.
  void toggleSplit() {
    if (state.splitPath != null) {
      state = state.copyWith(splitPath: null);
    } else if (state.activePath != null) {
      state = state.copyWith(splitPath: state.activePath);
    }
  }

  void closeSplit() {
    state = state.copyWith(splitPath: null);
  }

  /// Reorders open tabs (drag-and-drop). [newIndex] is already adjusted for the
  /// removal at [oldIndex] (ReorderableListView.onReorderItem semantics).
  void reorderTabs(int oldIndex, int newIndex) {
    final files = [...state.openFiles];
    if (oldIndex < 0 || oldIndex >= files.length) return;
    final item = files.removeAt(oldIndex);
    final target = newIndex.clamp(0, files.length);
    files.insert(target, item);
    state = state.copyWith(openFiles: files);
    _persist();
  }

  void updateContent(String path, String content) {
    final files = state.openFiles.map((f) {
      if (f.path == path) return f.copyWith(content: content);
      return f;
    }).toList();
    state = state.copyWith(openFiles: files);
  }

  /// Persist a file to disk and clear its dirty flag.
  String? saveFile(String path) {
    final file = state.openFiles.where((f) => f.path == path).toList();
    if (file.isEmpty) return null;
    try {
      File(path).writeAsStringSync(file.first.content);
      final files = state.openFiles.map((f) {
        if (f.path == path) return f.copyWith(savedContent: f.content);
        return f;
      }).toList();
      state = state.copyWith(openFiles: files);
      return null;
    } catch (e) {
      return 'Cannot save file: $e';
    }
  }

  void closeFile(String path) {
    final remaining =
        state.openFiles.where((f) => f.path != path).toList();
    String? newActive = state.activePath;
    if (state.activePath == path) {
      newActive = remaining.isNotEmpty ? remaining.last.path : null;
    }
    final newSplit = state.splitPath == path ? null : state.splitPath;
    state = EditorState(
        openFiles: remaining, activePath: newActive, splitPath: newSplit);
    _persist();
  }

  void closeAll() {
    state = const EditorState();
    _persist();
  }

  /// Closes every tab except [path].
  void closeOthers(String path) {
    final kept = state.openFiles.where((f) => f.path == path).toList();
    state = EditorState(
      openFiles: kept,
      activePath: kept.isNotEmpty ? path : null,
      splitPath: state.splitPath == path ? path : null,
    );
    _persist();
  }

  /// Reloads a file's content from disk (e.g. after the agent edits it).
  /// If the file is not currently open, this is a no-op.
  void reloadFromDisk(String path) {
    final isOpen = state.openFiles.any((f) => f.path == path);
    if (!isOpen) return;
    try {
      final file = File(path);
      if (!file.existsSync()) {
        // File was deleted by the agent → close the tab.
        closeFile(path);
        return;
      }
      final content = file.readAsStringSync();
      final files = state.openFiles.map((f) {
        if (f.path == path) {
          return EditorFile(
            path: path,
            savedContent: content,
            content: content,
          );
        }
        return f;
      }).toList();
      state = state.copyWith(openFiles: files);
    } catch (_) {
      // ignore reload failures
    }
  }
}

/// Incremented to force the file explorer to re-read the directory tree,
/// e.g. after the agent creates or deletes files.
final explorerRefreshProvider = StateProvider<int>((ref) => 0);

/// A request to move the editor caret to a specific line of a file.
class GotoLine {
  final String path;
  final int line; // 1-based
  GotoLine(this.path, this.line);
}

final gotoLineProvider = StateProvider<GotoLine?>((ref) => null);

/// Editor font size (persisted). Affects code text + line gutter.
final editorFontSizeProvider = StateProvider<double>((ref) {
  // ignore: deprecated_member_use
  ref.listenSelf((_, next) => HiveStorage.settings.put('editor_font_size', next));
  return HiveStorage.settings.get('editor_font_size', defaultValue: 14.0)
      as double;
});
