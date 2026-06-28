import 'dart:io';

import 'package:path/path.dart' as p;

/// Result of executing a single agent tool.
class ToolResult {
  /// Human/LLM-readable output that is fed back to the model.
  final String output;

  /// Whether the tool failed.
  final bool isError;

  /// Absolute path of a file that was created or modified (for editor refresh).
  final String? changedPath;

  const ToolResult(this.output, {this.isError = false, this.changedPath});
}

/// A description of a tool, used to build the system prompt.
class ToolSpec {
  final String name;
  final String description;
  final String args;

  const ToolSpec(this.name, this.description, this.args);
}

/// Executes agent tool calls against the workspace. All file operations are
/// sandboxed to [workspaceRoot] to prevent path traversal outside the project.
class AgentToolExecutor {
  final String workspaceRoot;
  final void Function(String)? onExecuteCommand;
  final String Function()? onReadTerminal;

  AgentToolExecutor(this.workspaceRoot, {this.onExecuteCommand, this.onReadTerminal});

  /// Catalog of available tools, surfaced to the model in the system prompt.
  static const List<ToolSpec> specs = [
    ToolSpec(
      'list_dir',
      'List files and folders. Use to explore the project structure.',
      '{"path": "<relative dir, \\"\\" or \\.\\" for root>"}',
    ),
    ToolSpec(
      'read_file',
      'Read the full contents of a text file.',
      '{"path": "<relative file path>"}',
    ),
    ToolSpec(
      'write_file',
      'Create a new file or completely overwrite an existing one.',
      '{"path": "<relative file path>", "content": "<full file content>"}',
    ),
    ToolSpec(
      'str_replace',
      'Replace an exact substring in a file. old_str must appear exactly once.',
      '{"path": "<relative file path>", "old_str": "<exact text>", "new_str": "<replacement>"}',
    ),
    ToolSpec(
      'delete_file',
      'Delete a file from the workspace.',
      '{"path": "<relative file path>"}',
    ),
    ToolSpec(
      'run_command',
      'Run a shell command in the workspace root and return its output.',
      '{"command": "<shell command>"}',
    ),
    ToolSpec(
      'read_terminal',
      'Read the current visible output from the terminal. Use this to see logs, build output, or results of previously run commands.',
      '{}',
    ),
  ];

  /// Builds the tool reference section for the system prompt.
  static String toolsDoc() {
    final sb = StringBuffer();
    for (final t in specs) {
      sb.writeln('- ${t.name}: ${t.description}');
      sb.writeln('  args: ${t.args}');
    }
    return sb.toString();
  }

  Future<ToolResult> execute(String tool, Map<String, dynamic> args) async {
    try {
      switch (tool) {
        case 'list_dir':
          return _listDir((args['path'] as String?) ?? '');
        case 'read_file':
          return _readFile(args['path'] as String? ?? '');
        case 'write_file':
          return _writeFile(
            args['path'] as String? ?? '',
            args['content'] as String? ?? '',
          );
        case 'str_replace':
          return _strReplace(
            args['path'] as String? ?? '',
            args['old_str'] as String? ?? '',
            args['new_str'] as String? ?? '',
          );
        case 'delete_file':
          return _deleteFile(args['path'] as String? ?? '');
        case 'run_command':
          return _runCommand(args['command'] as String? ?? '');
        case 'read_terminal':
          return _readTerminal();
        default:
          return ToolResult('Unknown tool: $tool', isError: true);
      }
    } catch (e) {
      return ToolResult('Tool "$tool" failed: $e', isError: true);
    }
  }

  /// Resolves a workspace-relative path, rejecting anything outside the root.
  String? _resolve(String relPath) {
    final cleaned = relPath.trim().replaceAll('\\', '/');
    final joined = p.normalize(p.join(workspaceRoot, cleaned));
    if (joined == workspaceRoot || p.isWithin(workspaceRoot, joined)) {
      return joined;
    }
    return null;
  }

  String _rel(String absPath) =>
      p.relative(absPath, from: workspaceRoot).replaceAll('\\', '/');

  ToolResult _listDir(String relPath) {
    final dir = _resolve(relPath.isEmpty ? '.' : relPath);
    if (dir == null) {
      return ToolResult('Path is outside the workspace: $relPath',
          isError: true);
    }
    final d = Directory(dir);
    if (!d.existsSync()) {
      return ToolResult('Directory not found: $relPath', isError: true);
    }
    const skip = {'.git', '.dart_tool', 'build', 'node_modules', '.idea'};
    final entries = d.listSync(followLinks: false)
      ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    final sb = StringBuffer();
    sb.writeln('Contents of "${relPath.isEmpty ? "." : relPath}":');
    for (final e in entries) {
      final name = p.basename(e.path);
      if (skip.contains(name)) continue;
      sb.writeln(e is Directory ? '  [dir]  $name/' : '  [file] $name');
    }
    return ToolResult(sb.toString());
  }

  ToolResult _readFile(String relPath) {
    final path = _resolve(relPath);
    if (path == null) {
      return ToolResult('Path is outside the workspace: $relPath',
          isError: true);
    }
    final f = File(path);
    if (!f.existsSync()) {
      return ToolResult('File not found: $relPath', isError: true);
    }
    final content = f.readAsStringSync();
    const maxChars = 30000;
    if (content.length > maxChars) {
      return ToolResult(
          '${content.substring(0, maxChars)}\n... (truncated, file is ${content.length} chars)');
    }
    return ToolResult(content);
  }

  ToolResult _writeFile(String relPath, String content) {
    final path = _resolve(relPath);
    if (path == null) {
      return ToolResult('Path is outside the workspace: $relPath',
          isError: true);
    }
    final f = File(path);
    final existed = f.existsSync();
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
    return ToolResult(
      '${existed ? "Overwrote" : "Created"} ${_rel(path)} (${content.length} chars).',
      changedPath: path,
    );
  }

  ToolResult _strReplace(String relPath, String oldStr, String newStr) {
    final path = _resolve(relPath);
    if (path == null) {
      return ToolResult('Path is outside the workspace: $relPath',
          isError: true);
    }
    final f = File(path);
    if (!f.existsSync()) {
      return ToolResult('File not found: $relPath', isError: true);
    }
    final content = f.readAsStringSync();
    if (oldStr.isEmpty) {
      return const ToolResult('old_str must not be empty.', isError: true);
    }
    final count = oldStr.allMatches(content).length;
    if (count == 0) {
      return ToolResult(
          'old_str not found in ${_rel(path)}. Read the file again to copy exact text.',
          isError: true);
    }
    if (count > 1) {
      return ToolResult(
          'old_str matches $count places in ${_rel(path)}. Add more context to make it unique.',
          isError: true);
    }
    final updated = content.replaceFirst(oldStr, newStr);
    f.writeAsStringSync(updated);
    return ToolResult('Edited ${_rel(path)}.', changedPath: path);
  }

  ToolResult _deleteFile(String relPath) {
    final path = _resolve(relPath);
    if (path == null) {
      return ToolResult('Path is outside the workspace: $relPath',
          isError: true);
    }
    final f = File(path);
    if (!f.existsSync()) {
      return ToolResult('File not found: $relPath', isError: true);
    }
    f.deleteSync();
    return ToolResult('Deleted ${_rel(path)}.', changedPath: path);
  }

  ToolResult _readTerminal() {
    if (onReadTerminal == null) {
      return const ToolResult('No terminal session is open.', isError: true);
    }
    final output = onReadTerminal!();
    if (output.trim().isEmpty) {
      return const ToolResult('Terminal is empty (no output).');
    }
    return ToolResult(output);
  }

  Future<ToolResult> _runCommand(String command) async {
    if (command.trim().isEmpty) {
      return const ToolResult('Empty command.', isError: true);
    }

    // Execute command via Process.run to capture output for the AI
    final result = await Process.run(
      Platform.isWindows ? 'cmd' : 'sh',
      Platform.isWindows ? ['/c', command] : ['-c', command],
      workingDirectory: workspaceRoot,
      runInShell: true,
    );

    final out = (result.stdout as String).trim();
    final err = (result.stderr as String).trim();
    final sb = StringBuffer();
    sb.writeln('Exit code: ${result.exitCode}');
    if (out.isNotEmpty) sb.writeln('stdout:\n$out');
    if (err.isNotEmpty) sb.writeln('stderr:\n$err');
    const maxChars = 8000;
    var text = sb.toString();
    if (text.length > maxChars) {
      text = '${text.substring(0, maxChars)}\n... (output truncated)';
    }

    // Show command + output in terminal UI so user can see what happened
    if (onExecuteCommand != null) {
      onExecuteCommand!(command);
    }

    return ToolResult(text, isError: result.exitCode != 0);
  }
}
