import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A tool exposed by an MCP server.
class McpTool {
  final String name;
  final String description;
  final Map<String, dynamic>? inputSchema;

  McpTool({required this.name, required this.description, this.inputSchema});
}

/// A minimal Model Context Protocol (MCP) client speaking JSON-RPC 2.0 over
/// the stdio transport (newline-delimited JSON messages).
class McpClient {
  final String command;
  final List<String> args;
  final Map<String, String> env;

  Process? _proc;
  int _id = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  String _buf = '';
  bool _closed = false;

  List<McpTool> tools = [];

  McpClient({
    required this.command,
    this.args = const [],
    this.env = const {},
  });

  bool get isRunning => _proc != null && !_closed;

  /// Spawns the server, performs the MCP handshake and lists its tools.
  Future<void> start() async {
    _proc = await Process.start(
      command,
      args,
      environment: {...Platform.environment, ...env},
      runInShell: true,
    );
    _closed = false;

    _proc!.stdout.transform(utf8.decoder).listen(_onData);
    // Drain stderr (server logs) so the pipe doesn't block.
    _proc!.stderr.transform(utf8.decoder).listen((_) {});
    _proc!.exitCode.then((_) => _markClosed());

    await _initialize();
    tools = await _listTools();
  }

  void _markClosed() {
    _closed = true;
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(StateError('MCP server exited'));
      }
    }
    _pending.clear();
  }

  void _onData(String chunk) {
    _buf += chunk;
    int idx;
    while ((idx = _buf.indexOf('\n')) >= 0) {
      final line = _buf.substring(0, idx).trim();
      _buf = _buf.substring(idx + 1);
      if (line.isEmpty) continue;
      try {
        final msg = jsonDecode(line);
        if (msg is Map<String, dynamic>) {
          final id = msg['id'];
          if (id is int) {
            final c = _pending.remove(id);
            c?.complete(msg);
          }
        }
      } catch (_) {
        // Non-JSON line (server log noise) — ignore.
      }
    }
  }

  Future<Map<String, dynamic>> _request(String method,
      [Map<String, dynamic>? params]) {
    if (!isRunning) {
      return Future.error(StateError('MCP server not running'));
    }
    final id = ++_id;
    final c = Completer<Map<String, dynamic>>();
    _pending[id] = c;
    _send({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params ?? {},
    });
    return c.future.timeout(const Duration(seconds: 30), onTimeout: () {
      _pending.remove(id);
      throw TimeoutException('MCP "$method" timed out');
    });
  }

  void _notify(String method, [Map<String, dynamic>? params]) {
    _send({'jsonrpc': '2.0', 'method': method, 'params': params ?? {}});
  }

  void _send(Map<String, dynamic> msg) {
    try {
      _proc?.stdin.write('${jsonEncode(msg)}\n');
    } catch (_) {}
  }

  Future<void> _initialize() async {
    final resp = await _request('initialize', {
      'protocolVersion': '2024-11-05',
      'capabilities': {},
      'clientInfo': {'name': 'Nadira Shakila', 'version': '1.0.0'},
    });
    if (resp['error'] != null) {
      throw Exception(resp['error']['message'] ?? 'initialize failed');
    }
    _notify('notifications/initialized');
  }

  Future<List<McpTool>> _listTools() async {
    final resp = await _request('tools/list');
    final result = resp['result'] as Map<String, dynamic>?;
    final list = (result?['tools'] as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((t) => McpTool(
              name: (t['name'] as String?) ?? '',
              description: (t['description'] as String?) ?? '',
              inputSchema: t['inputSchema'] as Map<String, dynamic>?,
            ))
        .where((t) => t.name.isNotEmpty)
        .toList();
  }

  /// Invokes a tool and returns its textual result.
  Future<String> callTool(String name, Map<String, dynamic> arguments) async {
    final resp =
        await _request('tools/call', {'name': name, 'arguments': arguments});
    if (resp['error'] != null) {
      return 'MCP error: ${resp['error']['message'] ?? resp['error']}';
    }
    final result = resp['result'] as Map<String, dynamic>?;
    final content = (result?['content'] as List?) ?? const [];
    final sb = StringBuffer();
    for (final c in content) {
      if (c is Map && c['type'] == 'text') {
        sb.writeln(c['text']);
      }
    }
    final text = sb.toString().trim();
    return text.isEmpty ? '(no output)' : text;
  }

  void dispose() {
    _closed = true;
    try {
      _proc?.kill();
    } catch (_) {}
    _proc = null;
  }
}
