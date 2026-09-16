import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/video_file.dart';
import '../services/video_library_service.dart';
import 'player_screen.dart';

class FolderVideosScreen extends StatefulWidget {
  final VideoFolder folder;
  const FolderVideosScreen({super.key, required this.folder});
  @override State<FolderVideosScreen> createState() => _FolderVideosScreenState();
}

class _FolderVideosScreenState extends State<FolderVideosScreen> {
  late final List<VideoFile> _videos = List<VideoFile>.from(widget.folder.videos);
  bool _deleting = false;

  Future<void> _confirmDelete(VideoFile video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this video?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    final deleted = await VideoLibraryService.deleteVideo(video.path);
    if (!mounted) return;
    setState(() => _deleting = false);
    if (deleted) {
      ThumbnailCache.invalidate(video.path);
      setState(() => _videos.removeWhere((item) => item.path == video.path));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video deleted')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video delete nahi ho saka. Permission check karein.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.folder.name)),
    body: Stack(children: [
      if (_videos.isEmpty) const Center(child: Text('Is folder mein koi video nahi hai.'))
      else ListView.builder(
        itemCount: _videos.length,
        cacheExtent: 800,
        itemBuilder: (context, index) {
          final video = _videos[index];
          return ListTile(
            key: ValueKey(video.path),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: _Thumbnail(path: video.path),
            title: Text(video.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(video.sizeLabel),
            trailing: IconButton(icon: const Icon(Icons.more_vert), tooltip: 'More options', onPressed: () => _confirmDelete(video)),
            onLongPress: () => _confirmDelete(video),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(videos: _videos, startIndex: index))),
          );
        },
      ),
      if (_deleting) const Positioned.fill(child: ColoredBox(color: Color(0x66000000), child: Center(child: CircularProgressIndicator()))),
    ]),
  );
}

class _Thumbnail extends StatefulWidget {
  final String path;
  const _Thumbnail({required this.path});
  @override State<_Thumbnail> createState() => _ThumbnailState();
}
class _ThumbnailState extends State<_Thumbnail> {
  Uint8List? _bytes;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final cached = ThumbnailCache.get(widget.path);
    if (cached != null) { if (mounted) setState(() => _bytes = cached); return; }
    try {
      final bytes = await VideoThumbnail.thumbnailData(video: widget.path, imageFormat: ImageFormat.JPEG, maxWidth: 128, quality: 30);
      if (bytes != null) ThumbnailCache.put(widget.path, bytes);
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {}
  }
  @override Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: _bytes == null ? Container(width: 64, height: 56, color: Colors.white10, child: const Icon(Icons.movie, color: Colors.white54)) : Image.memory(_bytes!, width: 64, height: 56, fit: BoxFit.cover, gaplessPlayback: true),
  );
}
