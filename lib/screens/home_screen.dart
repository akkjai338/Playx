import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/video_file.dart';
import '../services/video_scanner.dart';
import '../services/video_library_service.dart';
import 'folder_videos_screen.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _loading = true, _permissionDenied = false, _grid = true;
  int _tab = 0;
  String _query = '';
  List<VideoFolder> _folders = const [];
  late final TextEditingController _search = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final ok = await VideoScanner.requestPermissions();
    if (!ok) { if (mounted) setState(() { _loading = false; _permissionDenied = true; }); return; }
    final folders = await VideoScanner.scanDevice();
    if (mounted) setState(() { _folders = folders; _loading = false; _permissionDenied = false; });
  }

  List<VideoFile> get _allVideos => _folders.expand((f) => f.videos).toList();
  List<VideoFile> get _filteredVideos => _allVideos.where((v) => v.name.toLowerCase().contains(_query.toLowerCase())).toList();

  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar.large(
          pinned: true, expandedHeight: 170,
          title: Image.asset('assets/images/playx_logo.png', width: 82, height: 52, fit: BoxFit.contain),
          actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)), const SizedBox(width: 8)],
          flexibleSpace: FlexibleSpaceBar(background: Padding(
            padding: const EdgeInsets.fromLTRB(20, 104, 20, 14),
            child: Row(children: [
              Icon(Icons.video_library_rounded, color: cs.primary, size: 22), const SizedBox(width: 8),
              Text('${_allVideos.length} videos on this device', style: TextStyle(color: cs.onSurfaceVariant)),
            ]),
          )),
        ),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), child: _SearchBox(
          controller: _search, onChanged: (v) => setState(() => _query = v),
        ))),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 10), child: Row(children: [
          _Tab(text: 'All videos', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
          const SizedBox(width: 10), _Tab(text: 'Folders', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
          const Spacer(), IconButton(onPressed: () => setState(() => _grid = !_grid), icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded)),
        ]))),
        if (_loading) const SliverFillRemaining(hasScrollBody: false, child: _Skeleton())
        else if (_permissionDenied) SliverFillRemaining(hasScrollBody: false, child: _Permission(onRetry: _load))
        else if (_tab == 1) _folderSliver()
        else _videoSliver(),
      ]),
    );
  }

  Widget _folderSliver() => _folders.isEmpty ? const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('No folders found'))) : SliverPadding(
    padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
    sliver: SliverList(delegate: SliverChildBuilderDelegate((context, i) {
      final f = _folders[i];
      return Padding(padding: const EdgeInsets.only(bottom: 10), child: _FolderCard(folder: f, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FolderVideosScreen(folder: f)))));
    }, childCount: _folders.length)),
  );

  Widget _videoSliver() {
    final videos = _filteredVideos;
    if (videos.isEmpty) return const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('No videos found')));
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      sliver: _grid ? SliverGrid(delegate: SliverChildBuilderDelegate((context, i) => _VideoTile(video: videos[i], videos: videos, index: i), childCount: videos.length), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: .78)) : SliverList(delegate: SliverChildBuilderDelegate((context, i) => _VideoRow(video: videos[i], videos: videos, index: i), childCount: videos.length)),
    );
  }
}

class _SearchBox extends StatelessWidget { final TextEditingController controller; final ValueChanged<String> onChanged; const _SearchBox({required this.controller, required this.onChanged}); @override Widget build(BuildContext context) => TextField(controller: controller, onChanged: onChanged, decoration: InputDecoration(hintText: 'Search your videos', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: controller.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { controller.clear(); onChanged(''); }) : null)); }
class _Tab extends StatelessWidget { final String text; final bool selected; final VoidCallback onTap; const _Tab({required this.text, required this.selected, required this.onTap}); @override Widget build(BuildContext context) => ChoiceChip(label: Text(text), selected: selected, onSelected: (_) => onTap()); }
class _FolderCard extends StatelessWidget { final VideoFolder folder; final VoidCallback onTap; const _FolderCard({required this.folder, required this.onTap}); @override Widget build(BuildContext context) => Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7), leading: const CircleAvatar(radius: 24, child: Icon(Icons.folder_rounded)), title: Text(folder.name, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text('${folder.videos.length} videos'), trailing: const Icon(Icons.chevron_right_rounded), onTap: onTap)); }
class _VideoTile extends StatelessWidget { final VideoFile video; final List<VideoFile> videos; final int index; const _VideoTile({required this.video, required this.videos, required this.index}); @override Widget build(BuildContext context) => Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(videos: videos, startIndex: index))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_Thumb(path: video.path, height: 118, width: double.infinity), Padding(padding: const EdgeInsets.fromLTRB(12, 10, 10, 2), child: Text(video.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))), Padding(padding: const EdgeInsets.fromLTRB(12, 3, 10, 10), child: Text(video.sizeLabel, style: Theme.of(context).textTheme.bodySmall))]))); }
class _VideoRow extends StatelessWidget { final VideoFile video; final List<VideoFile> videos; final int index; const _VideoRow({required this.video, required this.videos, required this.index}); @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(contentPadding: const EdgeInsets.all(8), leading: _Thumb(path: video.path, height: 66, width: 96), title: Text(video.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(video.sizeLabel), trailing: const Icon(Icons.play_circle_outline_rounded), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(videos: videos, startIndex: index))))); }
class _Thumb extends StatefulWidget { final String path; final double height, width; const _Thumb({required this.path, required this.height, required this.width}); @override State<_Thumb> createState() => _ThumbState(); }
class _ThumbState extends State<_Thumb> { Uint8List? bytes; @override void initState() { super.initState(); _load(); } Future<void> _load() async { final x = ThumbnailCache.get(widget.path); if (x != null) { if (mounted) setState(() => bytes = x); return; } try { final b = await VideoThumbnail.thumbnailData(video: widget.path, imageFormat: ImageFormat.JPEG, maxWidth: 360, quality: 55); if (b != null) ThumbnailCache.put(widget.path, b); if (mounted) setState(() => bytes = b); } catch (_) {} } @override Widget build(BuildContext context) => Container(width: widget.width, height: widget.height, color: Colors.white10, child: bytes == null ? const Center(child: Icon(Icons.movie_outlined, color: Colors.white38)) : Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true)); }
class _Skeleton extends StatelessWidget { const _Skeleton(); @override Widget build(BuildContext context) => ListView.builder(itemCount: 6, itemBuilder: (_, __) => const ListTile(leading: CircleAvatar(backgroundColor: Colors.white10), title: _Bar(), subtitle: _Bar())); }
class _Bar extends StatelessWidget { const _Bar(); @override Widget build(BuildContext context) => Container(height: 12, width: 160, margin: const EdgeInsets.symmetric(vertical: 5), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8))); }
class _Permission extends StatelessWidget { final VoidCallback onRetry; const _Permission({required this.onRetry}); @override Widget build(BuildContext context) => Center(child: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.lock_open_rounded), label: const Text('Allow video access'))); }
