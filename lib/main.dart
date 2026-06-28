import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/storage/hive_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();
  await HiveStorage.initialize();

  // Frameless window with a custom VS Code-style title bar.
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1000, 680),
    minimumSize: Size(720, 480),
    center: true,
    backgroundColor: Color(0xFF1E1A27),
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAlignment(Alignment.center);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    const ProviderScope(
      child: AiDesktopApp(),
    ),
  );
}
