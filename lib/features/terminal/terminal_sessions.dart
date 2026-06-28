import 'dart:convert';
import 'dart:io';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../workspace/providers/workspace_provider.dart';

/// One terminal instance: an xterm buffer backed by a real PTY.
class TerminalSession {
  final int id;
  final Terminal terminal;
  final String shellPath;
  Pty? pty;
  String title;

  TerminalSession(this.id, this.terminal, this.shellPath,
      {this.title = 'shell'});
}

/// A shell option offered when creating a new terminal.
class ShellOption {
  final String label;
  final String path;
  const ShellOption(this.label, this.path);
}

class TerminalSessionsState {
  final List<TerminalSession> sessions;
  final int? activeId;

  const TerminalSessionsState({this.sessions = const [], this.activeId});

  TerminalSession? get active {
    if (activeId == null) return null;
    for (final s in sessions) {
      if (s.id == activeId) return s;
    }
    return null;
  }
}

final terminalSessionsProvider =
    StateNotifierProvider<TerminalSessionsNotifier, TerminalSessionsState>(
        (ref) {
  return TerminalSessionsNotifier(ref);
});

class TerminalSessionsNotifier extends StateNotifier<TerminalSessionsState> {
  final Ref _ref;
  int _nextId = 1;

  TerminalSessionsNotifier(this._ref) : super(const TerminalSessionsState());

  String get _defaultShell {
    if (Platform.isWindows) {
      return Platform.environment['COMSPEC'] ?? 'cmd.exe';
    }
    return Platform.environment['SHELL'] ?? '/bin/bash';
  }

  /// Available shells the user can launch.
  List<ShellOption> availableShells() {
    if (Platform.isWindows) {
      // Only offer CMD to avoid PowerShell 0x8009001d error
      return <ShellOption>[
        ShellOption('Command Prompt', Platform.environment['COMSPEC'] ?? 'cmd.exe'),
      ];
    }
    return [
      ShellOption('Shell', Platform.environment['SHELL'] ?? '/bin/bash'),
      const ShellOption('Bash', '/bin/bash'),
    ];
  }

  /// Ensures at least one terminal exists; returns the active session.
  TerminalSession ensureSession() {
    if (state.active != null) return state.active!;
    return newSession();
  }

  TerminalSession newSession({String? shellPath}) {
    final shell = shellPath ?? _defaultShell;
    final terminal = Terminal(maxLines: 10000);
    final session =
        TerminalSession(_nextId++, terminal, shell, title: _shellName(shell));
    _startPty(session);
    state = TerminalSessionsState(
      sessions: [...state.sessions, session],
      activeId: session.id,
    );
    return session;
  }

  /// Friendly shell name for the tab label (e.g. cmd, powershell, bash).
  String _shellName(String shell) {
    final exe = shell.replaceAll('\\', '/').split('/').last;
    final dot = exe.lastIndexOf('.');
    return (dot > 0 ? exe.substring(0, dot) : exe).toLowerCase();
  }

  void _startPty(TerminalSession session) {
    final workspace = _ref.read(workspaceProvider);
    final cwd = (workspace != null && Directory(workspace).existsSync())
        ? workspace
        : (Platform.environment['USERPROFILE'] ?? Directory.current.path);

    final pty = Pty.start(
      session.shellPath,
      columns: session.terminal.viewWidth,
      rows: session.terminal.viewHeight,
      workingDirectory: cwd,
    );
    pty.output
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(session.terminal.write);
    pty.exitCode.then((code) {
      session.terminal
          .write('\r\n\x1b[90m[process exited with code $code]\x1b[0m\r\n');
    });
    session.terminal.onOutput = (data) {
      pty.write(const Utf8Encoder().convert(data));
    };
    session.terminal.onResize = (w, h, pw, ph) => pty.resize(h, w);
    session.pty = pty;
  }

  void setActive(int id) {
    state = TerminalSessionsState(sessions: state.sessions, activeId: id);
  }

  void close(int id) {
    final session = state.sessions.where((s) => s.id == id).toList();
    if (session.isNotEmpty) session.first.pty?.kill();
    final remaining = state.sessions.where((s) => s.id != id).toList();
    int? newActive = state.activeId;
    if (state.activeId == id) {
      newActive = remaining.isNotEmpty ? remaining.last.id : null;
    }
    state = TerminalSessionsState(sessions: remaining, activeId: newActive);
  }

  /// Writes a command (with newline) into the active terminal, creating one
  /// if necessary.
  void runCommand(String command) {
    final session = ensureSession();
    session.pty?.write(const Utf8Encoder().convert('$command\r'));
  }

  @override
  void dispose() {
    for (final s in state.sessions) {
      s.pty?.kill();
    }
    super.dispose();
  }
}
