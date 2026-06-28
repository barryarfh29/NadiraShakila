import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

/// An image attached to the next chat message, sent to the AI as a vision
/// input (base64 data URL).
class AttachedImage {
  final String name;
  final String dataUrl; // data:image/<type>;base64,<...>

  AttachedImage(this.name, this.dataUrl);
}

final attachedImagesProvider =
    StateNotifierProvider<AttachedImagesNotifier, List<AttachedImage>>((ref) {
  return AttachedImagesNotifier();
});

class AttachedImagesNotifier extends StateNotifier<List<AttachedImage>> {
  AttachedImagesNotifier() : super([]);

  /// Max dimension (px) sent to the model. Large screenshots are downscaled to
  /// keep the request small and fast (vision models don't need full res).
  static const int _maxDim = 1568;

  void add(String name, List<int> bytes, String ext) {
    final processed = _compress(bytes);
    if (processed != null) {
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(processed)}';
      state = [...state, AttachedImage(name, dataUrl)];
      return;
    }
    // Fallback: send original bytes with detected mime.
    final mime = switch (ext.toLowerCase().replaceFirst('.', '')) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      _ => 'image/png',
    };
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    state = [...state, AttachedImage(name, dataUrl)];
  }

  /// Decodes, downscales (if needed) and re-encodes as JPEG. Returns null on
  /// failure so the caller can fall back to the original bytes.
  List<int>? _compress(List<int> bytes) {
    try {
      final decoded = img.decodeImage(Uint8List.fromList(bytes));
      if (decoded == null) return null;
      var image = decoded;
      final longest =
          image.width > image.height ? image.width : image.height;
      if (longest > _maxDim) {
        if (image.width >= image.height) {
          image = img.copyResize(image, width: _maxDim);
        } else {
          image = img.copyResize(image, height: _maxDim);
        }
      }
      return img.encodeJpg(image, quality: 82);
    } catch (_) {
      return null;
    }
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    state = [
      for (var i = 0; i < state.length; i++)
        if (i != index) state[i],
    ];
  }

  void clear() => state = [];
}

