import 'package:flutter/material.dart';
import '../models/video_file.dart';
import '../services/video_scanner.dart';
import 'folder_videos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  bool _permissionDenied = false;
  List<VideoFolder> _folders = const [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final granted = await VideoScanner.requestPermissions();
    if (!granted) {
      if (mounted) setState(() { _loading = false; _permissionDenied = true; });
      return;
    }
    final folders = await VideoScanner.scanDevice();
    if (mounted) setState(() { _folders = folders; _loading = false; _permissionDenied = false; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('PlayX'),
      actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Rescan')],
    ),
    body: _buildBody(),
  );

  Widget _buildBody() {
    if (_loading) return const _LibrarySkeleton();
    if (_permissionDenied) return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.folder_off, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        const Text('Videos dikhane ke liye storage permission zaroori hai.', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: _load, child: const Text('Permission Dobara Do')),
      ]),
    ));
    if (_folders.isEmpty) return const Center(child: Text('Koi video nahi mila.'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _folders.length,
        itemBuilder: (context, index) {
          final folder = _folders[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            leading: const CircleAvatar(backgroundColor: Color(0xff1e3a5f), child: Icon(Icons.folder, color: Colors.lightBlueAccent)),
            title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${folder.videos.length} videos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FolderVideosScreen(folder: folder))),
          );
        },
      ),
    );
  }
}

class _LibrarySkeleton extends StatelessWidget {
  const _LibrarySkeleton();
  @override Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.symmetric(vertical: 10), itemCount: 8,
    itemBuilder: (_, __) => const ListTile(leading: CircleAvatar(backgroundColor: Colors.white12), title: _ShimmerBar(width: 180), subtitle: _ShimmerBar(width: 90)),
  );
}
class _ShimmerBar extends StatelessWidget {
  final double width;
  const _ShimmerBar({required this.width});
  @override Widget build(BuildContext context) => Container(width: width, height: 12, margin: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)));
}
