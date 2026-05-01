import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/shot.dart';

class VideoPlayerOverlay extends StatefulWidget {
  final Shot shot;
  final int preRollSec;

  const VideoPlayerOverlay({super.key, required this.shot, required this.preRollSec});

  @override
  State<VideoPlayerOverlay> createState() => _VideoPlayerOverlayState();
}

class _VideoPlayerOverlayState extends State<VideoPlayerOverlay> {
  VideoPlayerController? _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final ctrl = VideoPlayerController.file(File(widget.shot.clipPath));
    await ctrl.initialize();

    final startMs = (widget.shot.shotOffsetMs - widget.preRollSec * 1000).clamp(0, ctrl.value.duration.inMilliseconds);
    await ctrl.seekTo(Duration(milliseconds: startMs));
    await ctrl.play();

    if (mounted) {
      setState(() {
        _ctrl = ctrl;
        _ready = true;
      });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: Stack(
        children: [
          if (_ready && _ctrl != null)
            Center(
              child: AspectRatio(
                aspectRatio: _ctrl!.value.aspectRatio,
                child: VideoPlayer(_ctrl!),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 32),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (_ready && _ctrl != null)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: _Controls(ctrl: _ctrl!),
            ),
        ],
      ),
    );
  }
}

class _Controls extends StatefulWidget {
  final VideoPlayerController ctrl;
  const _Controls({required this.ctrl});

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final playing = widget.ctrl.value.isPlaying;
    return Column(
      children: [
        VideoProgressIndicator(widget.ctrl, allowScrubbing: true,
            colors: const VideoProgressColors(playedColor: Colors.redAccent)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
              onPressed: () => playing ? widget.ctrl.pause() : widget.ctrl.play(),
            ),
            IconButton(
              icon: const Icon(Icons.replay, color: Colors.white),
              onPressed: () {
                widget.ctrl.seekTo(Duration.zero);
                widget.ctrl.play();
              },
            ),
          ],
        ),
      ],
    );
  }
}
