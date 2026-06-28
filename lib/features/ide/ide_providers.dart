import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which left side panel is showing.
enum SidePanel {
  explorer,
  search,
  sourceControl,
  runDebug,
  specs,
  extensions,
  history,
  settings,
  none
}

/// The currently active side panel.
final sidePanelProvider =
    StateProvider<SidePanel>((ref) => SidePanel.explorer);

/// Whether the right-docked AI chat panel is visible.
final chatVisibleProvider = StateProvider<bool>((ref) => true);
