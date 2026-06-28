import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Auto-updater that checks GitHub Releases for new versions.
/// Flow: check → download ZIP → extract → replace files → restart app.
class UpdaterService {
  /// GitHub repo info
  static const String _owner = 'barryarfh29';
  static const String _repo = 'NadiraShakila';
  static const String _currentVersion = '1.0.0';

  /// Get current app version
  static String get currentVersion => _currentVersion;

  /// Check GitHub Releases for a newer version.
  /// Returns [UpdateInfo] if available, null if up-to-date.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.github.com/repos/$_owner/$_repo/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String?) ?? '';
      final remoteVersion = tagName.replaceFirst('v', '');

      if (!_isNewer(remoteVersion, _currentVersion)) return null;

      // Find the portable ZIP asset
      final assets = data['assets'] as List? ?? [];
      String? downloadUrl;
      int? size;
      for (final asset in assets) {
        final name = (asset['name'] as String?) ?? '';
        if (name.contains('Portable') && name.endsWith('.zip')) {
          downloadUrl = asset['browser_download_url'] as String?;
          size = asset['size'] as int?;
          break;
        }
      }

      if (downloadUrl == null) return null;

      return UpdateInfo(
        version: remoteVersion,
        downloadUrl: downloadUrl,
        releaseNotes: (data['body'] as String?) ?? '',
        publishedAt: (data['published_at'] as String?) ?? '',
        sizeBytes: size ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Download and apply update. Returns true on success.
  /// The app should restart after this returns true.
  static Future<bool> downloadAndApply(
    UpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final tempDir = Directory.systemTemp.createTempSync('ai_desktop_update_');
      final zipPath = p.join(tempDir.path, 'update.zip');

      // Download ZIP with progress
      final request = http.Request('GET', Uri.parse(update.downloadUrl));
      final response = await http.Client().send(request);

      final totalBytes = response.contentLength ?? update.sizeBytes;
      int receivedBytes = 0;
      final sink = File(zipPath).openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call(receivedBytes / totalBytes);
        }
      }
      await sink.close();

      // Extract ZIP to temp folder
      final extractDir = p.join(tempDir.path, 'extracted');
      Directory(extractDir).createSync();

      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Expand-Archive -Path "$zipPath" -DestinationPath "$extractDir" -Force'
              .replaceAll(r'$zipPath', zipPath)
              .replaceAll(r'$extractDir', extractDir),
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) return false;

      // Create updater batch script that will:
      // 1. Wait for current app to close
      // 2. Copy new files over
      // 3. Restart app
      final installDir = _getInstallDir();
      final updaterBat = p.join(tempDir.path, 'do_update.bat');

      File(updaterBat).writeAsStringSync('''
@echo off
echo Updating Nadira Shakila...
timeout /t 2 /nobreak >nul
xcopy /E /Y /I "$extractDir\\*" "$installDir\\"
start "" "$installDir\\ai_desktop.exe"
rmdir /s /q "${tempDir.path}"
exit
'''
          .replaceAll(r'$extractDir', extractDir)
          .replaceAll(r'$installDir', installDir)
          .replaceAll(r'${tempDir.path}', tempDir.path));

      // Launch updater script and exit current app
      await Process.start(
        'cmd',
        ['/c', updaterBat],
        mode: ProcessStartMode.detached,
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get the install directory of the running app
  static String _getInstallDir() {
    final exePath = Platform.resolvedExecutable;
    return p.dirname(exePath);
  }

  /// Compare version strings (e.g., "1.1.0" > "1.0.0")
  static bool _isNewer(String remote, String current) {
    final r = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad to same length
    while (r.length < 3) {
      r.add(0);
    }
    while (c.length < 3) {
      c.add(0);
    }

    for (var i = 0; i < 3; i++) {
      if (r[i] > c[i]) return true;
      if (r[i] < c[i]) return false;
    }
    return false;
  }
}

/// Info about an available update.
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final String publishedAt;
  final int sizeBytes;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.publishedAt,
    required this.sizeBytes,
  });

  String get sizeMB => (sizeBytes / 1024 / 1024).toStringAsFixed(1);
}
