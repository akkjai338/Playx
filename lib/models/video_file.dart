import 'dart:io';

class VideoFile {
  final String path;
  final String name;
  final String folderPath;
  final String folderName;
  final int sizeBytes;
  final DateTime modified;

  VideoFile({
    required this.path,
    required this.name,
    required this.folderPath,
    required this.folderName,
    required this.sizeBytes,
    required this.modified,
  });

  static VideoFile fromFile(File file) {
    final folder = file.parent;
    return VideoFile(
      path: file.path,
      name: file.uri.pathSegments.last,
      folderPath: folder.path,
      folderName: folder.path.split('/').where((s) => s.isNotEmpty).isEmpty
          ? '/'
          : folder.path.split('/').where((s) => s.isNotEmpty).last,
      sizeBytes: file.statSync().size,
      modified: file.statSync().modified,
    );
  }

  String get sizeLabel {
    if (sizeBytes <= 0) return '0 MB';
    final mb = sizeBytes / (1024 * 1024);
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }
}

class VideoFolder {
  final String path;
  final String name;
  final List<VideoFile> videos;

  VideoFolder({required this.path, required this.name, required this.videos});
}
