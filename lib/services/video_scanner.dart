import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../models/video_file.dart';

class VideoScanner {
  static const List<String> _extensions = [
    '.mp4', '.mkv', '.avi', '.mov', '.3gp', '.webm', '.flv', '.wmv', '.m4v', '.ts'
  ];

  static Future<bool> requestPermissions() async {
    final videos = await Permission.videos.request();
    if (videos.isGranted) return true;
    final manage = await Permission.manageExternalStorage.request();
    if (manage.isGranted) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  /// The directory walk is cooperative: yielding between directories keeps
  /// frames available while the library is being discovered.
  static Future<List<VideoFolder>> scanDevice() async {
    final grouped = <String, List<VideoFile>>{};
    final root = Directory('/storage/emulated/0');
    if (await root.exists()) await _scanDirectory(root, grouped, depth: 0);
    final folders = grouped.entries.map((entry) {
      final parts = entry.key.split('/').where((part) => part.isNotEmpty).toList();
      entry.value.sort((a, b) => b.modified.compareTo(a.modified));
      return VideoFolder(
        path: entry.key,
        name: parts.isEmpty ? 'Internal Storage' : parts.last,
        videos: entry.value,
      );
    }).toList()..sort((a, b) => b.videos.length.compareTo(a.videos.length));
    return folders;
  }

  static Future<void> _scanDirectory(
    Directory dir,
    Map<String, List<VideoFile>> grouped, {
    required int depth,
  }) async {
    if (depth > 8) return;
    final name = dir.path.split('/').last.toLowerCase();
    if ({'android', '.thumbnails', '.cache', 'cache', 'lost.dir'}.contains(name)) return;
    Stream<FileSystemEntity> entries;
    try {
      entries = dir.list(followLinks: false);
    } catch (_) {
      return;
    }
    await for (final entity in entries) {
      try {
        if (entity is Directory) {
          await _scanDirectory(entity, grouped, depth: depth + 1);
        } else if (entity is File && _extensions.any(entity.path.toLowerCase().endsWith)) {
          final stat = await entity.stat();
          if (stat.size > 0) {
            final video = VideoFile(
              path: entity.path,
              name: entity.uri.pathSegments.last,
              folderPath: entity.parent.path,
              folderName: entity.parent.path.split('/').where((s) => s.isNotEmpty).last,
              sizeBytes: stat.size,
              modified: stat.modified,
            );
            grouped.putIfAbsent(video.folderPath, () => <VideoFile>[]).add(video);
          }
        }
      } catch (_) {}
      // Give the event loop a chance to render and process input on huge stores.
      await Future<void>.delayed(Duration.zero);
    }
  }
}
