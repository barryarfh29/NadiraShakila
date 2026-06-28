import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/hive_storage.dart';

/// Tabs available in the bottom panel.
enum BottomTab { problems, terminal }

/// The active bottom-panel tab, or null when the panel is hidden.
final bottomPanelProvider = StateProvider<BottomTab?>((ref) => null);

/// Convenience: whether the terminal tab is currently shown.
final terminalVisibleProvider = Provider<bool>((ref) {
  return ref.watch(bottomPanelProvider) == BottomTab.terminal;
});

/// Height of the bottom panel in logical pixels.
final terminalHeightProvider = StateProvider<double>((ref) {
  // ignore: deprecated_member_use
  ref.listenSelf((_, next) => HiveStorage.settings.put('terminal_height', next));
  return HiveStorage.settings.get('terminal_height', defaultValue: 260.0)
      as double;
});

/// A command to be written into the integrated terminal (e.g. from the
/// Run & Debug panel). The terminal consumes and clears it.
final pendingTerminalCommandProvider = StateProvider<String?>((ref) => null);

/// Controller for terminal operations from agent tools
class TerminalProvider {
  final Ref _ref;

  TerminalProvider(this._ref);

  /// Execute a command in the terminal and show terminal panel
  Future<void> executeCommand(String command) async {
    // Show terminal panel
    _ref.read(bottomPanelProvider.notifier).state = BottomTab.terminal;
    
    // Set pending command to be executed
    _ref.read(pendingTerminalCommandProvider.notifier).state = command;
  }

  /// Toggle terminal visibility
  void setTerminalVisibility(bool visible) {
    _ref.read(bottomPanelProvider.notifier).state = 
        visible ? BottomTab.terminal : null;
  }
}

/// Provider for TerminalProvider
final terminalProvider = Provider<TerminalProvider>((ref) {
  return TerminalProvider(ref);
});
