import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../workspace/providers/workspace_provider.dart';
import 'mcp_client.dart';

enum McpStatus { disabled, connecting, connected, error }

/// Configuration for a single MCP server (Kiro-compatible mcp.json schema).
class McpServerConfig {
  final String name;
  final String command;
  final List<String> args;
  final Map<String, String> env;
  final bool disabled;
  final List<String> autoApprove;

  McpServerConfig({
    required this.name,
    required this.command,
    this.args = const [],
    this.env = const {},
    this.disabled = false,
    this.autoApprove = const [],
  });

  static McpServerConfig fromJson(String name, Map<String, dynamic> j) {
    return McpServerConfig(
      name: name,
      command: (j['command'] as String?) ?? '',
      args: ((j['args'] as List?)?.map((e) => e.toString()).toList()) ??
          const [],
      env: ((j['env'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          )) ??
          const {},
      disabled: (j['disabled'] as bool?) ?? false,
      autoApprove:
          ((j['autoApprove'] as List?)?.map((e) => e.toString()).toList()) ??
              const [],
    );
  }
}

/// Live state of a configured MCP server.
class McpServerState {
  final McpServerConfig config;
  final McpStatus status;
  final List<McpTool> tools;
  final String? error;
  final McpClient? client;

  McpServerState({
    required this.config,
    required this.status,
    this.tools = const [],
    this.error,
    this.client,
  });

  McpServerState copyWith({
    McpStatus? status,
    List<McpTool>? tools,
    String? error,
    McpClient? client,
  }) {
    return McpServerState(
      config: config,
      status: status ?? this.status,
      tools: tools ?? this.tools,
      error: error,
      client: client ?? this.client,
    );
  }
}

/// Absolute path of the workspace MCP config file.
String? mcpConfigPath(String? workspace) {
  if (workspace == null) return null;
  return p.join(workspace, '.kiro', 'settings', 'mcp.json');
}

/// User-level MCP config path (~/.kiro/settings/mcp.json).
String? _userMcpConfigPath() {
  final home = Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'];
  if (home == null) return null;
  return p.join(home, '.kiro', 'settings', 'mcp.json');
}

List<McpServerConfig> _loadConfigs(String? workspace) {
  final result = <String, McpServerConfig>{};
  // User-level first, workspace overrides.
  for (final path in [_userMcpConfigPath(), mcpConfigPath(workspace)]) {
    if (path == null) continue;
    final f = File(path);
    if (!f.existsSync()) continue;
    try {
      final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final servers = (j['mcpServers'] as Map?) ?? const {};
      servers.forEach((name, cfg) {
        if (cfg is Map<String, dynamic>) {
          result[name.toString()] =
              McpServerConfig.fromJson(name.toString(), cfg);
        }
      });
    } catch (_) {}
  }
  return result.values.toList();
}

final mcpManagerProvider =
    StateNotifierProvider<McpManager, List<McpServerState>>((ref) {
  final m = McpManager(ref);
  ref.listen(workspaceProvider, (_, __) => m.reload());
  ref.onDispose(m.disposeAll);
  return m;
});

class McpManager extends StateNotifier<List<McpServerState>> {
  final Ref _ref;
  McpManager(this._ref) : super([]) {
    reload();
  }

  /// Reloads config from disk and (re)connects enabled servers.
  Future<void> reload() async {
    disposeAll();
    final configs = _loadConfigs(_ref.read(workspaceProvider));
    state = configs
        .map((c) => McpServerState(
              config: c,
              status: c.disabled ? McpStatus.disabled : McpStatus.connecting,
            ))
        .toList();
    for (final c in configs) {
      if (!c.disabled) {
        _connect(c);
      }
    }
  }

  Future<void> _connect(McpServerConfig cfg) async {
    final client = McpClient(
      command: cfg.command,
      args: cfg.args,
      env: cfg.env,
    );
    try {
      await client.start();
      _update(cfg.name, (s) => s.copyWith(
            status: McpStatus.connected,
            tools: client.tools,
            client: client,
          ));
    } catch (e) {
      client.dispose();
      _update(cfg.name,
          (s) => s.copyWith(status: McpStatus.error, error: e.toString()));
    }
  }

  void _update(String name, McpServerState Function(McpServerState) fn) {
    state = [
      for (final s in state)
        if (s.config.name == name) fn(s) else s,
    ];
  }

  /// Reconnects a single server.
  Future<void> reconnect(String name) async {
    final match = state.where((s) => s.config.name == name).toList();
    if (match.isEmpty) return;
    match.first.client?.dispose();
    _update(name, (s) => s.copyWith(status: McpStatus.connecting, tools: []));
    await _connect(match.first.config);
  }

  /// All connected tools, keyed by their routable agent name
  /// (`mcp_<server>_<tool>`).
  Map<String, ({String server, String tool})> toolRouteMap() {
    final map = <String, ({String server, String tool})>{};
    for (final s in state) {
      if (s.status != McpStatus.connected) continue;
      for (final t in s.tools) {
        map[_routeName(s.config.name, t.name)] =
            (server: s.config.name, tool: t.name);
      }
    }
    return map;
  }

  String _routeName(String server, String tool) {
    String sane(String x) => x.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    return 'mcp_${sane(server)}_${sane(tool)}';
  }

  /// Builds the tool catalog section for the agent system prompt.
  String toolsDoc() {
    final sb = StringBuffer();
    for (final s in state) {
      if (s.status != McpStatus.connected) continue;
      for (final t in s.tools) {
        final route = _routeName(s.config.name, t.name);
        final desc = t.description.isEmpty ? t.name : t.description;
        sb.writeln('- $route: [MCP:${s.config.name}] $desc');
        final schema =
            t.inputSchema != null ? jsonEncode(t.inputSchema) : '{}';
        sb.writeln('  args (JSON matching this schema): $schema');
      }
    }
    return sb.toString();
  }

  bool hasTool(String routeName) => toolRouteMap().containsKey(routeName);

  /// Calls an MCP tool by its routable name.
  Future<String> callRoutedTool(
      String routeName, Map<String, dynamic> args) async {
    final route = toolRouteMap()[routeName];
    if (route == null) return 'Unknown MCP tool: $routeName';
    final match =
        state.where((s) => s.config.name == route.server).toList();
    if (match.isEmpty || match.first.client == null) {
      return 'MCP server "${route.server}" is not connected.';
    }
    try {
      return await match.first.client!.callTool(route.tool, args);
    } catch (e) {
      return 'MCP call failed: $e';
    }
  }

  void disposeAll() {
    for (final s in state) {
      s.client?.dispose();
    }
  }

  /// Adds (or replaces) a server in the workspace mcp.json, then reloads.
  /// Returns false if there is no workspace open.
  Future<bool> addServer(McpServerConfig cfg) async {
    final path = mcpConfigPath(_ref.read(workspaceProvider));
    if (path == null) return false;
    Map<String, dynamic> root = {};
    final f = File(path);
    if (f.existsSync()) {
      try {
        root = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      } catch (_) {
        root = {};
      }
    }
    final servers = (root['mcpServers'] as Map?)?.cast<String, dynamic>() ?? {};
    servers[cfg.name] = {
      'command': cfg.command,
      'args': cfg.args,
      if (cfg.env.isNotEmpty) 'env': cfg.env,
      'disabled': cfg.disabled,
      'autoApprove': cfg.autoApprove,
    };
    root['mcpServers'] = servers;
    try {
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(root));
    } catch (_) {
      return false;
    }
    await reload();
    return true;
  }

  /// Removes a server from mcp.json and reloads.
  Future<void> removeServer(String name) async {
    final path = mcpConfigPath(_ref.read(workspaceProvider));
    if (path == null) return;
    final f = File(path);
    if (!f.existsSync()) return;
    try {
      final root = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final servers =
          (root['mcpServers'] as Map?)?.cast<String, dynamic>() ?? {};
      servers.remove(name);
      root['mcpServers'] = servers;
      f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(root));
    } catch (_) {}
    await reload();
  }
}

/// Creates a starter mcp.json (if missing) and returns its path.
String? ensureMcpConfig(String? workspace) {
  final path = mcpConfigPath(workspace);
  if (path == null) return null;
  final f = File(path);
  if (!f.existsSync()) {
    try {
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
        'mcpServers': {
          'fetch': {
            'command': 'uvx',
            'args': ['mcp-server-fetch'],
            'env': {'FASTMCP_LOG_LEVEL': 'ERROR'},
            'disabled': true,
            'autoApprove': <String>[],
          }
        }
      }));
    } catch (_) {
      return null;
    }
  }
  return path;
}
