import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/codicons.dart';

const String _iconDir = 'assets/file_icons';

/// Maps a file name to a Material-Icon-Theme SVG asset, or null if none.
String? _assetForFile(String fileName) {
  final lower = fileName.toLowerCase();

  // Exact file names.
  const byName = {
    'pubspec.yaml': 'dart',
    'pubspec.lock': 'lock',
    'package.json': 'nodejs',
    'package-lock.json': 'nodejs',
    '.gitignore': 'git',
    '.gitattributes': 'git',
    'dockerfile': 'document',
    'makefile': 'settings',
    '.env': 'settings',
  };
  if (byName.containsKey(lower)) return '$_iconDir/${byName[lower]}.svg';

  final ext = p.extension(lower);
  const byExt = {
    '.dart': 'dart',
    '.py': 'python',
    '.js': 'javascript',
    '.mjs': 'javascript',
    '.cjs': 'javascript',
    '.ts': 'typescript',
    '.tsx': 'react',
    '.jsx': 'react',
    '.json': 'json',
    '.yaml': 'yaml',
    '.yml': 'yaml',
    '.md': 'markdown',
    '.html': 'html',
    '.htm': 'html',
    '.css': 'css',
    '.scss': 'sass',
    '.sass': 'sass',
    '.xml': 'xml',
    '.svg': 'image',
    '.png': 'image',
    '.jpg': 'image',
    '.jpeg': 'image',
    '.gif': 'image',
    '.ico': 'image',
    '.webp': 'image',
    '.db': 'database',
    '.sqlite': 'database',
    '.sql': 'database',
    '.sh': 'console',
    '.bash': 'console',
    '.bat': 'console',
    '.cmd': 'console',
    '.ps1': 'powershell',
    '.exe': 'exe',
    '.zip': 'zip',
    '.rar': 'zip',
    '.7z': 'zip',
    '.tar': 'zip',
    '.gz': 'zip',
    '.lock': 'lock',
  };
  final name = byExt[ext];
  if (name != null) return '$_iconDir/$name.svg';
  return '$_iconDir/document.svg'; // generic file fallback
}

/// Renders the colored SVG icon for a file, falling back to a codicon glyph.
class FileIcon extends StatelessWidget {
  final String fileName;
  final double size;

  const FileIcon({super.key, required this.fileName, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final asset = _assetForFile(fileName);
    if (asset == null) {
      return Icon(Codicons.file, size: size, color: const Color(0xFF8A929E));
    }
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      placeholderBuilder: (_) =>
          Icon(Codicons.file, size: size, color: const Color(0xFF8A929E)),
    );
  }
}

/// Renders the folder SVG icon (same glyph for open/closed; chevron shows state).
class FolderIcon extends StatelessWidget {
  final double size;
  const FolderIcon({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      '$_iconDir/folder.svg',
      width: size,
      height: size,
      placeholderBuilder: (_) =>
          Icon(Codicons.folder, size: size, color: const Color(0xFF90A4AE)),
    );
  }
}
