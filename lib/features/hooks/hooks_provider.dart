import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../chat/presentation/providers/chat_provider.dart';
import '../ide/ide_providers.dart';
import '../terminal/terminal_provider.dart';
import '../workspace/providers/workspace_provider.dart';

/// When the hook fires.
enum HookEvent { fileSaved, manual }

/// What the hook does.
enum HookAction { askAgent, runCommand }

/// An automation rule stored under `.kiro/hooks/<id>.json`, modeled after
/// Kiro AI's Agent Hooks.
class AgentHook {
  final String id;
  final String path; // absolute json path
  final String name;
  final bool enabled;
  final HookEvent event;
  final List<String> patterns; // globs for fileSaved
  final HookAction action;
  final String prompt; // askAgent
  final String command; // runCommand

  AgentHook({
    required this.id,
    required this.path,
    required this.name,
    required this.enabled,
    required this.event,
    required this.patterns,
    required this.action,
    required this.prompt,
    required this.command,
  });

  AgentHook copyWith({String? name, bool? enabled}) => AgentHook(
        id: id,
        path: path,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        event: event,
        patterns: patterns,
        action: action,
        prompt: prompt,
        command: command,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'enabled': enabled,
        'event': event.name,
        'patterns': patterns,
        'action': action.name,
        'prompt': prompt,
        'command': command,
      };

  static AgentHook fromJson(String id, String path, Map<String, dynamic> j) {
    return AgentHook(
      id: id,
      path: path,
      name: (j['name'] as String?) ?? id,
      enabled: (j['enabled'] as bool?) ?? true,
      event: HookEvent.values.firstWhere(
        (e) => e.name == j['event'],
        orElse: () => HookEvent.manual,
      ),
      patterns: ((j['patterns'] as List?)?.cast<String>()) ?? const [],
      action: HookAction.values.firstWhere(
        (a) => a.name == j['action'],
        orElse: () => HookAction.askAgent,
      ),
      prompt: (j['prompt'] as String?) ?? '',
      command: (j['command'] as String?) ?? '',
    );
  }

  bool matchesFile(String fileName) {
    if (patterns.isEmpty) return true;
    return patterns.any((glob) => _globMatch(glob, fileName));
  }
}

bool _globMatch(String glob, String name) {
  // Convert a simple glob (with * and ?) into a regex.
  final sb = StringBuffer('^');
  for (final ch in glob.split('')) {
    switch (ch) {
      case '*':
        sb.write('.*');
        break;
      case '?':
        sb.write('.');
        break;
      default:
        sb.write(RegExp.escape(ch));
    }
  }
  sb.write(r'$');
  return RegExp(sb.toString(), caseSensitive: false).hasMatch(name);
}

String? _hooksRoot(String? workspace) {
  if (workspace == null) return null;
  return p.join(workspace, '.kiro', 'hooks');
}

final hooksProvider =
    StateNotifierProvider<HooksNotifier, List<AgentHook>>((ref) {
  final notifier = HooksNotifier(ref);
  ref.listen(workspaceProvider, (_, __) => notifier.refresh());
  return notifier;
});

class HooksNotifier extends StateNotifier<List<AgentHook>> {
  final Ref _ref;
  HooksNotifier(this._ref) : super([]) {
    refresh();
  }

  void refresh() {
    final root = _hooksRoot(_ref.read(workspaceProvider));
    if (root == null) {
      state = [];
      return;
    }
    final dir = Directory(root);
    if (!dir.existsSync()) {
      state = [];
      return;
    }
    final hooks = <AgentHook>[];
    for (final e in dir.listSync(followLinks: false)) {
      if (e is File && p.extension(e.path).toLowerCase() == '.json') {
        try {
          final j = jsonDecode(e.readAsStringSync()) as Map<String, dynamic>;
          hooks.add(AgentHook.fromJson(
              p.basenameWithoutExtension(e.path), e.path, j));
        } catch (_) {}
      }
    }
    hooks.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = hooks;
  }

  AgentHook? create(AgentHook hook) {
    final root = _hooksRoot(_ref.read(workspaceProvider));
    if (root == null) return null;
    final id = const Uuid().v4().substring(0, 8);
    final path = p.join(root, '$id.json');
    try {
      Directory(root).createSync(recursive: true);
      File(path)
          .writeAsStringSync(const JsonEncoder.withIndent('  ')
              .convert(hook.toJson()));
    } catch (_) {
      return null;
    }
    refresh();
    return state.firstWhere((h) => h.id == id, orElse: () => hook);
  }

  void toggle(AgentHook hook) {
    _save(hook.copyWith(enabled: !hook.enabled));
  }

  void _save(AgentHook hook) {
    try {
      File(hook.path).writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(hook.toJson()));
    } catch (_) {}
    refresh();
  }

  void delete(AgentHook hook) {
    try {
      File(hook.path).deleteSync();
    } catch (_) {}
    refresh();
  }
}

/// Runs all enabled `fileSaved` hooks whose patterns match the saved file.
void runSaveHooks(WidgetRef ref, String absPath) {
  final fileName = p.basename(absPath);
  final hooks = ref.read(hooksProvider);
  for (final hook in hooks) {
    if (!hook.enabled) continue;
    if (hook.event != HookEvent.fileSaved) continue;
    if (hook.matchesFile(fileName)) {
      runHook(ref, hook, filePath: absPath);
    }
  }
}

/// Executes a single hook's action.
void runHook(WidgetRef ref, AgentHook hook, {String? filePath}) {
  switch (hook.action) {
    case HookAction.askAgent:
      ref.read(agentModeProvider.notifier).state = true;
      ref.read(chatVisibleProvider.notifier).state = true;
      var prompt = hook.prompt;
      if (filePath != null) {
        prompt = '$prompt\n\n(Dipicu oleh perubahan file: $filePath)';
      }
      ref.read(chatControllerProvider).sendMessage(prompt);
      break;
    case HookAction.runCommand:
      ref.read(bottomPanelProvider.notifier).state = BottomTab.terminal;
      ref.read(pendingTerminalCommandProvider.notifier).state = hook.command;
      break;
  }
}
