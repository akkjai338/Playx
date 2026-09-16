import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:floating/floating.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/video_file.dart';

enum _DragMode { none, brightness, volume, seek }

class PlayerScreen extends StatefulWidget {
  final List<VideoFile> videos;
  final int startIndex;
  const PlayerScreen({super.key, required this.videos, required this.startIndex});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late int _index;
  VideoPlayerController? _controller;
  final Floating _floating = Floating();

  bool _controlsVisible = true;
  Timer? _hideTimer;

  _DragMode _dragMode = _DragMode.none;
  double _dragStartX = 0;
  double _dragStartY = 0;
  double _startBrightness = 0.5;
  double _startVolume = 0.5;
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  Duration _seekPreview = Duration.zero;
  Duration _dragStartPosition = Duration.zero;

  double? _brightnessOverlay;
  double? _volumeOverlay;
  bool _showSeekOverlay = false;
  double _doubleTapX = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.enable();
    VolumeController().showSystemUI = false;
    _primeGestureValues();
    _loadVideo(widget.videos[_index].path);
    _scheduleHideControls();
  }

  Future<void> _loadVideo(String path) async {
    final old = _controller;
    final newController = VideoPlayerController.file(File(path));
    await newController.initialize();
    await newController.play();
    setState(() {
      _controller = newController;
    });
    old?.dispose();
  }

  Future<void> _primeGestureValues() async {
    try {
      _currentBrightness = await ScreenBrightness().current;
      _currentVolume = await VolumeController().getVolume();
    } catch (_) {}
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _playNext() {
    if (_index < widget.videos.length - 1) {
      setState(() => _index++);
      _loadVideo(widget.videos[_index].path);
    }
  }

  void _playPrevious() {
    if (_index > 0) {
      setState(() => _index--);
      _loadVideo(widget.videos[_index].path);
    }
  }

  Future<void> _enterPiP() async {
    try {
      final status = await _floating.pipStatus;
      if (status == PiPStatus.enabled || status == PiPStatus.unavailable) return;
      await _floating.enable(const ImmediatePiP());
    } catch (_) {
      // PiP not supported on this device/OS version - ignore silently.
    }
  }

  void _onPanStart(DragStartDetails details) {
    _dragStartX = details.localPosition.dx;
    _dragStartY = details.localPosition.dy;
    _dragMode = _DragMode.none;
    // Do not await platform calls on pointer-down; this keeps the first frame
    // of every gesture responsive. Values are refreshed in the background.
    _startBrightness = _currentBrightness;
    _startVolume = _currentVolume;
    _dragStartPosition = _controller?.value.position ?? Duration.zero;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final width = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx - _dragStartX;
    final dy = details.localPosition.dy - _dragStartY;

    if (_dragMode == _DragMode.none) {
      if (dx.abs() < 8 && dy.abs() < 8) return;
      if (dx.abs() > dy.abs()) {
        _dragMode = _DragMode.seek;
      } else {
        _dragMode = _dragStartX < width / 2 ? _DragMode.brightness : _DragMode.volume;
      }
    }

    switch (_dragMode) {
      case _DragMode.brightness:
        final delta = -dy / 300;
        final newValue = (_startBrightness + delta).clamp(0.0, 1.0);
        _currentBrightness = newValue;
        ScreenBrightness().setScreenBrightness(newValue);
        setState(() => _brightnessOverlay = newValue);
        break;
      case _DragMode.volume:
        final delta = -dy / 300;
        final newValue = (_startVolume + delta).clamp(0.0, 1.0);
        _currentVolume = newValue;
        VolumeController().setVolume(newValue);
        setState(() => _volumeOverlay = newValue);
        break;
      case _DragMode.seek:
        if (_controller == null) return;
        final total = _controller!.value.duration;
        final seekDeltaMs = (dx / width) * 90000; // ~90s across full screen width
        final newMs = (_dragStartPosition.inMilliseconds + seekDeltaMs)
            .clamp(0, total.inMilliseconds.toDouble());
        setState(() {
          _seekPreview = Duration(milliseconds: newMs.toInt());
          _showSeekOverlay = true;
        });
        break;
      case _DragMode.none:
        break;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragMode == _DragMode.seek && _controller != null) {
      _controller!.seekTo(_seekPreview);
    }
    setState(() {
      _dragMode = _DragMode.none;
      _brightnessOverlay = null;
      _volumeOverlay = null;
      _showSeekOverlay = false;
    });
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: GestureDetector(
          onTap: () => setState(() {
            _controlsVisible = !_controlsVisible;
            if (_controlsVisible) _scheduleHideControls();
          }),
          onDoubleTapDown: (details) => _doubleTapX = details.localPosition.dx,
          onDoubleTap: () {
            final controller = _controller;
            if (controller == null || !controller.value.isInitialized) return;
            final half = MediaQuery.of(context).size.width / 2;
            final current = controller.value.position;
            final duration = controller.value.duration;
            final delta = _doubleTapX < half ? const Duration(seconds: -10) : const Duration(seconds: 10);
            final target = current + delta;
            controller.seekTo(target < Duration.zero ? Duration.zero : (target > duration ? duration : target));
          },
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: controller != null && controller.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      )
                    : const CircularProgressIndicator(),
              ),
              if (_brightnessOverlay != null)
                _InfoOverlay(
                  icon: Icons.brightness_6,
                  label: '${(_brightnessOverlay! * 100).round()}%',
                ),
              if (_volumeOverlay != null)
                _InfoOverlay(
                  icon: Icons.volume_up,
                  label: '${(_volumeOverlay! * 100).round()}%',
                ),
              if (_showSeekOverlay)
                _InfoOverlay(
                  icon: Icons.fast_forward,
                  label: _formatDuration(_seekPreview),
                ),
              if (_controlsVisible) _buildControls(controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(VideoPlayerController? controller) {
    return Positioned.fill(
      child: Container(
        color: Colors.black26,
        child: Column(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        widget.videos[_index].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
                      onPressed: _enterPiP,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 36,
                  icon: const Icon(Icons.skip_previous, color: Colors.white),
                  onPressed: _playPrevious,
                ),
                const SizedBox(width: 12),
                IconButton(
                  iconSize: 56,
                  icon: Icon(
                    controller != null && controller.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (controller == null) return;
                    setState(() {
                      controller.value.isPlaying ? controller.pause() : controller.play();
                    });
                  },
                ),
                const SizedBox(width: 12),
                IconButton(
                  iconSize: 36,
                  icon: const Icon(Icons.skip_next, color: Colors.white),
                  onPressed: _playNext,
                ),
              ],
            ),
            const Spacer(),
            if (controller != null && controller.value.isInitialized)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.redAccent,
                        bufferedColor: Colors.white30,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(controller.value.position),
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(_formatDuration(controller.value.duration),
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoOverlay extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoOverlay({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
