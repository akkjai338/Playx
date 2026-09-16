import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Bridges safe MediaStore deletion to Android. The native implementation
/// deletes by MediaStore URI rather than directly unlinking a shared-storage file.
class VideoLibraryService {
  static const _channel = MethodChannel('com.ankit.playx/media_store');

  static Future<bool> deleteVideo(String path) async {
    try {
      return await _channel.invokeMethod<bool>('deleteVideo', {'path': path}) ?? false;
    } on PlatformException {
      return false;
    }
  }
}

class ThumbnailCache {
  static const int _maxEntries = 120;
  static final Map<String, Uint8List> _items = <String, Uint8List>{};

  static Uint8List? get(String key) {
    final value = _items.remove(key);
    if (value != null) _items[key] = value;
    return value;
  }

  static void put(String key, Uint8List value) {
    _items.remove(key);
    _items[key] = value;
    while (_items.length > _maxEntries) {
      _items.remove(_items.keys.first);
    }
  }

  static void invalidate(String key) => _items.remove(key);
}
