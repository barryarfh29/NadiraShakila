import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../workspace/providers/workspace_provider.dart';

enum DiagSeverity { error, warning, info }

class Diagnostic {
  final String filePath;
  final int line; // 1-based
  final int col; // 1-based
  final DiagSeverity severity;
  final String message;
  final String? code;

  Diagnostic({
    required this.filePath,
    required this.line,
    required this.col,
    required this.severity,
    required this.message,
    this.code,
  });
}

/// Diagnostics for all analyzed files, keyed by absolute file path.
final diagnosticsProvider =
    StateNotifierProvider<DiagnosticsNotifier, Map<String, List<Diagnostic>>>(
        (ref) {
  return DiagnosticsNotifier(ref);
});

/// Whether the bottom Problems panel is visible.
final problemsVisibleProvider = StateProvider<bool>((ref) => false);

/// Flat, sorted list of all current diagnostics.
final allDiagnosticsProvider = Provider<List<Diagnostic>>((ref) {
  final map = ref.watch(diagnosticsProvider);
  final all = map.values.expand((e) => e).toList();
  all.sort((a, b) {
    final byFile = a.filePath.compareTo(b.filePath);
    if (byFile != 0) return byFile;
    return a.line.compareTo(b.line);
  });
  return all;
});

class DiagnosticsNotifier
    extends StateNotifier<Map<String, List<Diagnostic>>> {
  final Ref _ref;
  DiagnosticsNotifier(this._ref) : super({});

  /// Analyze a file's current on-disk content and update diagnostics.
  Future<void> analyze(String path) async {
    final ext = p.extension(path).toLowerCase();
    List<Diagnostic> results = [];

    if (ext == '.dart') {
      final dartDiags = await _dartAnalyze(path);
      if (_dartExe != null) {
        // Analyzer ran; it is authoritative (empty == clean).
        results = dartDiags;
      } else {
        // Analyzer unavailable → fall back to structural checks.
        results = _safeBasic(path, ext);
      }
    } else if (ext == '.py') {
      final pyDiags = await _pythonAnalyze(path);
      results = _pythonExe != null ? pyDiags : _safeBasic(path, ext);
    } else if (const {'.js', '.mjs', '.cjs', '.jsx', '.ts', '.tsx'}
        .contains(ext)) {
      final jsDiags = await _jsAnalyze(path, ext);
      results = _jsToolUsed ? jsDiags : _safeBasic(path, ext);
    } else {
      results = _safeBasic(path, ext);
    }

    final next = Map<String, List<Diagnostic>>.from(state);
    if (results.isEmpty) {
      next.remove(path);
    } else {
      next[path] = results;
    }
    state = next;
  }

  List<Diagnostic> _safeBasic(String path, String ext) {
    try {
      return _basicChecks(path, File(path).readAsStringSync(), ext);
    } catch (_) {
      return [];
    }
  }

  void clear(String path) {
    if (!state.containsKey(path)) return;
    final next = Map<String, List<Diagnostic>>.from(state)..remove(path);
    state = next;
  }

  // === Universal structural checks ===

  static const _quoteLangs = {
    '.dart', '.js', '.ts', '.tsx', '.jsx', '.json', '.py', '.java',
    '.c', '.cpp', '.cs', '.go', '.rs', '.kt', '.php', '.css', '.scss',
  };

  List<Diagnostic> _basicChecks(String path, String content, String ext) {
    if (!_quoteLangs.contains(ext)) return [];
    final diags = <Diagnostic>[];
    final pairs = {')': '(', ']': '[', '}': '{'};
    final opens = {'(', '[', '{'};
    final stack = <_Tok>[];
    final lines = content.split('\n');

    var inBlockComment = false;
    for (var li = 0; li < lines.length; li++) {
      final line = lines[li];
      var inStr = false;
      String? strChar;
      for (var ci = 0; ci < line.length; ci++) {
        final ch = line[ci];
        final next = ci + 1 < line.length ? line[ci + 1] : '';

        if (inBlockComment) {
          if (ch == '*' && next == '/') {
            inBlockComment = false;
            ci++;
          }
          continue;
        }
        if (inStr) {
          if (ch == '\\') {
            ci++; // skip escaped char
          } else if (ch == strChar) {
            inStr = false;
          }
          continue;
        }
        // line comment
        if (ch == '/' && next == '/') break;
        if (ch == '#' && (ext == '.py')) break;
        if (ch == '/' && next == '*') {
          inBlockComment = true;
          ci++;
          continue;
        }
        if (ch == '"' || ch == "'" || ch == '`') {
          inStr = true;
          strChar = ch;
          continue;
        }
        if (opens.contains(ch)) {
          stack.add(_Tok(ch, li + 1, ci + 1));
        } else if (pairs.containsKey(ch)) {
          if (stack.isEmpty || stack.last.ch != pairs[ch]) {
            diags.add(Diagnostic(
              filePath: path,
              line: li + 1,
              col: ci + 1,
              severity: DiagSeverity.error,
              message: "Unmatched closing '$ch'.",
              code: 'bracket',
            ));
          } else {
            stack.removeLast();
          }
        }
      }
      // Unterminated string on a line (most languages don't allow multiline
      // with plain quotes; skip backtick which can be multiline).
      if (inStr && strChar != '`') {
        diags.add(Diagnostic(
          filePath: path,
          line: li + 1,
          col: line.length,
          severity: DiagSeverity.warning,
          message: 'Unterminated string literal.',
          code: 'string',
        ));
      }
    }
    for (final tok in stack) {
      diags.add(Diagnostic(
        filePath: path,
        line: tok.line,
        col: tok.col,
        severity: DiagSeverity.error,
        message: "Unclosed '${tok.ch}'.",
        code: 'bracket',
      ));
    }
    return diags;
  }

  // === Dart analyzer (best-effort) ===

  String? _dartExe;
  bool _dartChecked = false;

  Future<String?> _resolveDart() async {
    if (_dartChecked) return _dartExe;
    _dartChecked = true;
    final candidates = [
      'dart',
      r'D:\ai_desktop\flutter\bin\dart.bat',
      if (Platform.environment['FLUTTER_ROOT'] != null)
        p.join(Platform.environment['FLUTTER_ROOT']!, 'bin', 'dart.bat'),
    ];
    for (final c in candidates) {
      try {
        final res = await Process.run(c, ['--version'], runInShell: true);
        if (res.exitCode == 0) {
          _dartExe = c;
          return c;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<List<Diagnostic>> _dartAnalyze(String path) async {
    final dart = await _resolveDart();
    if (dart == null) return [];
    final root = _ref.read(workspaceProvider);
    try {
      final res = await Process.run(
        dart,
        ['analyze', '--format=machine', path],
        workingDirectory: root,
        runInShell: true,
      );
      final out = '${res.stdout}\n${res.stderr}';
      final diags = <Diagnostic>[];
      for (final line in out.split('\n')) {
        // SEVERITY|TYPE|CODE|FILE|LINE|COL|LENGTH|MESSAGE
        final parts = line.split('|');
        if (parts.length < 8) continue;
        final sev = parts[0].trim().toUpperCase();
        final file = parts[3].replaceAll(r'\\', r'\');
        final ln = int.tryParse(parts[4]) ?? 1;
        final col = int.tryParse(parts[5]) ?? 1;
        final msg = parts.sublist(7).join('|').trim();
        if (!p.equals(file, path)) continue;
        diags.add(Diagnostic(
          filePath: path,
          line: ln,
          col: col,
          severity: sev == 'ERROR'
              ? DiagSeverity.error
              : (sev == 'WARNING' ? DiagSeverity.warning : DiagSeverity.info),
          message: msg,
          code: parts[2].trim(),
        ));
      }
      // Dart analyzer is authoritative; drop our bracket guesses for .dart.
      return diags;
    } catch (_) {
      return [];
    }
  }

  // === Python analyzer (pyflakes / py_compile, best-effort) ===

  String? _pythonExe;
  bool _pythonChecked = false;

  Future<String?> _resolvePython() async {
    if (_pythonChecked) return _pythonExe;
    _pythonChecked = true;
    for (final c in ['python', 'python3', 'py']) {
      try {
        final res = await Process.run(c, ['--version'], runInShell: true);
        if (res.exitCode == 0) {
          _pythonExe = c;
          return c;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<List<Diagnostic>> _pythonAnalyze(String path) async {
    final py = await _resolvePython();
    if (py == null) return [];
    final root = _ref.read(workspaceProvider);

    // Prefer pyflakes for lint + syntax errors.
    try {
      final res = await Process.run(
        py,
        ['-m', 'pyflakes', path],
        workingDirectory: root,
        runInShell: true,
      );
      final out = '${res.stdout}\n${res.stderr}';
      if (!out.contains('No module named pyflakes')) {
        return _parsePyflakes(out, path);
      }
    } catch (_) {}

    // Fallback: py_compile catches syntax errors only.
    try {
      final res = await Process.run(
        py,
        ['-m', 'py_compile', path],
        workingDirectory: root,
        runInShell: true,
      );
      if (res.exitCode == 0) return [];
      return _parsePyCompile('${res.stdout}\n${res.stderr}', path);
    } catch (_) {}

    return [];
  }

  List<Diagnostic> _parsePyflakes(String out, String path) {
    final diags = <Diagnostic>[];
    // Matches "...:line: message" or "...:line:col: message" at end of line.
    final re = RegExp(r':(\d+)(?::(\d+))?:\s(.*)$');
    for (final line in out.split('\n')) {
      final m = re.firstMatch(line.trimRight());
      if (m == null) continue;
      final ln = int.tryParse(m.group(1)!) ?? 1;
      final col = int.tryParse(m.group(2) ?? '') ?? 1;
      final msg = m.group(3)!.trim();
      // Lines with a column are syntax errors; otherwise lint warnings.
      final isError = m.group(2) != null ||
          msg.toLowerCase().contains('syntax') ||
          msg.toLowerCase().contains('undefined');
      diags.add(Diagnostic(
        filePath: path,
        line: ln,
        col: col,
        severity: isError ? DiagSeverity.error : DiagSeverity.warning,
        message: msg,
        code: 'pyflakes',
      ));
    }
    return diags;
  }

  List<Diagnostic> _parsePyCompile(String out, String path) {
    var line = 1;
    final lineMatch = RegExp(r'line (\d+)').firstMatch(out);
    if (lineMatch != null) line = int.tryParse(lineMatch.group(1)!) ?? 1;
    var msg = 'Syntax error';
    final errMatch =
        RegExp(r'(SyntaxError|IndentationError|TabError):\s*(.*)').firstMatch(out);
    if (errMatch != null) msg = '${errMatch.group(1)}: ${errMatch.group(2)}'.trim();
    return [
      Diagnostic(
        filePath: path,
        line: line,
        col: 1,
        severity: DiagSeverity.error,
        message: msg,
        code: 'py_compile',
      ),
    ];
  }

  // === JavaScript / TypeScript analyzer (ESLint / node --check) ===

  String? _nodeExe;
  bool _nodeChecked = false;
  bool _jsToolUsed = false;

  Future<String?> _resolveNode() async {
    if (_nodeChecked) return _nodeExe;
    _nodeChecked = true;
    try {
      final res = await Process.run('node', ['--version'], runInShell: true);
      if (res.exitCode == 0) _nodeExe = 'node';
    } catch (_) {}
    return _nodeExe;
  }

  Future<List<Diagnostic>> _jsAnalyze(String path, String ext) async {
    _jsToolUsed = false;
    final node = await _resolveNode();
    if (node == null) return [];
    final root = _ref.read(workspaceProvider);

    // Prefer ESLint if available in the project (covers JS + TS).
    try {
      final res = await Process.run(
        'npx',
        ['--no-install', 'eslint', '--format', 'json', path],
        workingDirectory: root,
        runInShell: true,
      );
      final out = (res.stdout as String).trim();
      if (out.startsWith('[')) {
        _jsToolUsed = true;
        return _parseEslint(out, path);
      }
    } catch (_) {}

    // Fallback: Node syntax check (JS only; TS isn't valid JS).
    if (ext == '.js' || ext == '.mjs' || ext == '.cjs') {
      try {
        final res = await Process.run(node, ['--check', path],
            workingDirectory: root, runInShell: true);
        _jsToolUsed = true;
        if (res.exitCode == 0) return [];
        return _parseNodeCheck('${res.stdout}\n${res.stderr}', path);
      } catch (_) {}
    }
    return [];
  }

  List<Diagnostic> _parseEslint(String jsonOut, String path) {
    final diags = <Diagnostic>[];
    try {
      final data = jsonDecode(jsonOut);
      if (data is List) {
        for (final file in data) {
          final messages = (file['messages'] as List?) ?? [];
          for (final m in messages) {
            diags.add(Diagnostic(
              filePath: path,
              line: (m['line'] as num?)?.toInt() ?? 1,
              col: (m['column'] as num?)?.toInt() ?? 1,
              severity: (m['severity'] == 2)
                  ? DiagSeverity.error
                  : DiagSeverity.warning,
              message: (m['message'] as String?) ?? '',
              code: m['ruleId'] as String?,
            ));
          }
        }
      }
    } catch (_) {}
    return diags;
  }

  List<Diagnostic> _parseNodeCheck(String out, String path) {
    // Node prints: "file:line\n...\nSyntaxError: message"
    var line = 1;
    final lineMatch = RegExp(r':(\d+)').firstMatch(out);
    if (lineMatch != null) line = int.tryParse(lineMatch.group(1)!) ?? 1;
    final errMatch = RegExp(r'(SyntaxError|ReferenceError):\s*(.*)')
        .firstMatch(out.replaceAll('\r', ''));
    final msg = errMatch != null
        ? '${errMatch.group(1)}: ${errMatch.group(2)}'.trim()
        : 'Syntax error';
    return [
      Diagnostic(
        filePath: path,
        line: line,
        col: 1,
        severity: DiagSeverity.error,
        message: msg,
        code: 'node',
      ),
    ];
  }
}

class _Tok {
  final String ch;
  final int line;
  final int col;
  _Tok(this.ch, this.line, this.col);
}
