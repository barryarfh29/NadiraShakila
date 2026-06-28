import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/api_constants.dart';
import '../chat/presentation/providers/attached_context.dart';
import '../chat/presentation/providers/chat_provider.dart';
import '../ide/ide_providers.dart';
import '../workspace/providers/workspace_provider.dart';
import 'spec_prompts.dart';

/// One spec = a folder under `.kiro/specs/<name>/` containing up to three
/// documents: requirements.md, design.md, tasks.md.
class Spec {
  final String name;
  final String dirPath;

  Spec(this.name, this.dirPath);

  String get requirementsPath => p.join(dirPath, 'requirements.md');
  String get designPath => p.join(dirPath, 'design.md');
  String get tasksPath => p.join(dirPath, 'tasks.md');

  bool get hasRequirements => File(requirementsPath).existsSync();
  bool get hasDesign => File(designPath).existsSync();
  bool get hasTasks => File(tasksPath).existsSync();

  String readRequirements() => _read(requirementsPath);
  String readDesign() => _read(designPath);
  String readTasks() => _read(tasksPath);

  String _read(String path) {
    try {
      return File(path).readAsStringSync();
    } catch (_) {
      return '';
    }
  }
}

/// A single task parsed from tasks.md.
class SpecTask {
  final int lineIndex; // 0-based line in tasks.md
  final String title;
  final bool done;
  const SpecTask(this.lineIndex, this.title, this.done);
}

/// The `.kiro/specs` directory for the current workspace, or null.
String? _specsRoot(String? workspace) {
  if (workspace == null) return null;
  return p.join(workspace, '.kiro', 'specs');
}

final specsProvider =
    StateNotifierProvider<SpecsNotifier, List<Spec>>((ref) {
  final notifier = SpecsNotifier(ref);
  ref.listen(workspaceProvider, (_, __) => notifier.refresh());
  return notifier;
});

class SpecsNotifier extends StateNotifier<List<Spec>> {
  final Ref _ref;
  SpecsNotifier(this._ref) : super([]) {
    refresh();
  }

  void refresh() {
    final root = _specsRoot(_ref.read(workspaceProvider));
    if (root == null) {
      state = [];
      return;
    }
    final dir = Directory(root);
    if (!dir.existsSync()) {
      state = [];
      return;
    }
    final specs = <Spec>[];
    for (final e in dir.listSync(followLinks: false)) {
      if (e is Directory) {
        specs.add(Spec(p.basename(e.path), e.path));
      }
    }
    specs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = specs;
  }

  /// Creates a new empty spec folder. Returns the Spec, or null on failure.
  Spec? create(String rawName) {
    final root = _specsRoot(_ref.read(workspaceProvider));
    if (root == null) return null;
    final name = _slug(rawName);
    if (name.isEmpty) return null;
    final dirPath = p.join(root, name);
    try {
      Directory(dirPath).createSync(recursive: true);
    } catch (_) {
      return null;
    }
    refresh();
    return Spec(name, dirPath);
  }

  void delete(Spec spec) {
    try {
      Directory(spec.dirPath).deleteSync(recursive: true);
    } catch (_) {}
    refresh();
  }

  String _slug(String s) {
    return s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}

/// Parses the top-level checklist items from tasks.md content.
List<SpecTask> parseTasks(String content) {
  final tasks = <SpecTask>[];
  final lines = content.split('\n');
  final re = RegExp(r'^\s*-\s*\[( |x|X)\]\s*(.+)$');
  for (var i = 0; i < lines.length; i++) {
    final m = re.firstMatch(lines[i]);
    if (m != null) {
      // Only treat numbered top-level items as tasks (skip sub-bullets).
      final title = m.group(2)!.trim();
      final isTopLevel = !lines[i].startsWith('  ');
      if (isTopLevel) {
        tasks.add(SpecTask(i, title, m.group(1)!.toLowerCase() == 'x'));
      }
    }
  }
  return tasks;
}

/// Which spec operation is currently running (e.g. 'design:my-spec'), or null.
final specBusyProvider = StateProvider<String?>((ref) => null);

final specsControllerProvider = Provider<SpecsController>((ref) {
  return SpecsController(ref);
});

class SpecsController {
  final Ref _ref;
  SpecsController(this._ref);

  String _model() {
    final m = _ref.read(selectedModelProvider);
    if (m == ApiConstants.autoModelId) {
      return ApiConstants.autoModelPriority.first;
    }
    return m;
  }

  String? _workspaceContext() {
    final workspace = _ref.read(workspaceProvider);
    if (workspace == null) return null;
    final files = listWorkspaceFiles(workspace, max: 200);
    final sb = StringBuffer();
    sb.writeln('Project context (for grounding):');
    sb.writeln('Workspace root: $workspace');
    sb.writeln('Files: ${files.take(120).join(', ')}');
    return sb.toString();
  }

  Future<String> _complete(String prompt) async {
    final api = _ref.read(apiServiceProvider);
    if (api == null) {
      throw StateError('API key belum dikonfigurasi.');
    }
    final result = await api.chatCompletion(
      messages: [
        {'role': 'user', 'content': prompt}
      ],
      model: _model(),
      maxTokens: 4096,
    );
    return _stripFences(result.trim());
  }

  /// Removes a wrapping ```markdown ... ``` fence if the model added one.
  String _stripFences(String s) {
    if (s.startsWith('```')) {
      final firstNl = s.indexOf('\n');
      if (firstNl != -1) {
        s = s.substring(firstNl + 1);
      }
      if (s.endsWith('```')) {
        s = s.substring(0, s.length - 3);
      }
    }
    return s.trim();
  }

  Future<void> generateRequirements(Spec spec, String feature) async {
    _ref.read(specBusyProvider.notifier).state = 'requirements:${spec.name}';
    try {
      final md = await _complete(
          SpecPrompts.requirements(feature, _workspaceContext()));
      File(spec.requirementsPath).writeAsStringSync(md);
      _ref.read(specsProvider.notifier).refresh();
    } finally {
      _ref.read(specBusyProvider.notifier).state = null;
    }
  }

  Future<void> generateDesign(Spec spec) async {
    _ref.read(specBusyProvider.notifier).state = 'design:${spec.name}';
    try {
      final md = await _complete(
          SpecPrompts.design(spec.readRequirements(), _workspaceContext()));
      File(spec.designPath).writeAsStringSync(md);
      _ref.read(specsProvider.notifier).refresh();
    } finally {
      _ref.read(specBusyProvider.notifier).state = null;
    }
  }

  Future<void> generateTasks(Spec spec) async {
    _ref.read(specBusyProvider.notifier).state = 'tasks:${spec.name}';
    try {
      final md = await _complete(
          SpecPrompts.tasks(spec.readRequirements(), spec.readDesign()));
      File(spec.tasksPath).writeAsStringSync(md);
      _ref.read(specsProvider.notifier).refresh();
    } finally {
      _ref.read(specBusyProvider.notifier).state = null;
    }
  }

  /// Toggles a task's checkbox in tasks.md and saves.
  void toggleTask(Spec spec, SpecTask task) {
    final content = spec.readTasks();
    final lines = content.split('\n');
    if (task.lineIndex < 0 || task.lineIndex >= lines.length) return;
    final line = lines[task.lineIndex];
    lines[task.lineIndex] = task.done
        ? line.replaceFirst(RegExp(r'\[(x|X)\]'), '[ ]')
        : line.replaceFirst('[ ]', '[x]');
    try {
      File(spec.tasksPath).writeAsStringSync(lines.join('\n'));
      _ref.read(specsProvider.notifier).refresh();
    } catch (_) {}
  }

  /// Sends a task to the AI agent for implementation. Forces Agent mode and
  /// attaches the spec docs as context.
  void executeTask(Spec spec, SpecTask task) {
    // Ensure agent mode is on so the AI can actually edit files.
    _ref.read(agentModeProvider.notifier).state = true;

    // Attach the spec's requirements/design/tasks as context.
    final attach = _ref.read(attachedContextProvider.notifier);
    if (spec.hasRequirements) attach.add(spec.requirementsPath, false);
    if (spec.hasDesign) attach.add(spec.designPath, false);
    if (spec.hasTasks) attach.add(spec.tasksPath, false);

    final prompt =
        'Kerjakan task berikut dari spec "${spec.name}". Implementasikan '
        'sesuai requirements dan design yang terlampir, lalu tandai task ini '
        'selesai.\n\nTask: ${task.title}';

    _ref.read(chatVisibleProvider.notifier).state = true;
    _ref.read(chatControllerProvider).sendMessage(prompt);
  }
}
