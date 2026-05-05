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
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final ctrl = VideoPlayerController.file(File(widget.shot.clipPath));
    await ctrl.initialize();
    ctrl.addListener(() {
      if (mounted) setState(() {});
    });

    final startMs = (widget.shot.shotOffsetMs - widget.preRollSec * 1000)
        .clamp(0, ctrl.value.duration.inMilliseconds);
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

  void _setSpeed(double s) {
    setState(() => _speed = s);
    _ctrl?.setPlaybackSpeed(s);
  }

  void _skip(int seconds) {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    final dur = ctrl.value.duration.inMilliseconds;
    final newMs = (ctrl.value.position.inMilliseconds + seconds * 1000).clamp(0, dur);
    ctrl.seekTo(Duration(milliseconds: newMs));
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    final playing = ctrl?.value.isPlaying ?? false;
    final position = ctrl?.value.position ?? Duration.zero;
    final duration = ctrl?.value.duration ?? Duration.zero;
    final durationMs = duration.inMilliseconds;

    final shotFraction = durationMs > 0
        ? (widget.shot.shotOffsetMs / durationMs).clamp(0.0, 1.0)
        : 0.0;
    final posFraction = durationMs > 0
        ? (position.inMilliseconds / durationMs).clamp(0.0, 1.0)
        : 0.0;

    return Material(
      color: const Color(0xFF050503),
      child: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Container(
              color: const Color(0xFF050503),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.chevron_left,
                        color: Color(0xFFE87722), size: 24),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Постріл #${widget.shot.shotNumber}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFC0B4AC),
                    ),
                  ),
                ],
              ),
            ),

            // ── Video ────────────────────────────────────────────────────
            Expanded(
              child: _ready && ctrl != null
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: ctrl.value.aspectRatio,
                        child: VideoPlayer(ctrl),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),

            // ── Progress panel ───────────────────────────────────────────
            if (_ready && ctrl != null)
              Container(
                color: const Color(0xFF0D0B09),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.shot.triggerDbfs != null)
                      Text(
                        '${widget.shot.triggerDbfs!.toStringAsFixed(1)} dBFS'
                        ' · ${(widget.shot.shotOffsetMs / 1000).toStringAsFixed(2)}с до пострілу',
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFF5A5450)),
                      ),
                    const SizedBox(height: 6),
                    // Progress track
                    LayoutBuilder(builder: (ctx, constraints) {
                      final w = constraints.maxWidth;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (d) {
                          final frac =
                              (d.localPosition.dx / w).clamp(0.0, 1.0);
                          ctrl.seekTo(Duration(
                              milliseconds: (frac * durationMs).toInt()));
                        },
                        onTapDown: (d) {
                          final frac =
                              (d.localPosition.dx / w).clamp(0.0, 1.0);
                          ctrl.seekTo(Duration(
                              milliseconds: (frac * durationMs).toInt()));
                        },
                        child: SizedBox(
                          height: 20,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Track background
                              Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A2420),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // Played fill
                              Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: posFraction,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE87722),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                              // Shot moment marker ▼
                              Positioned(
                                left: (w * shotFraction - 9).clamp(0, w - 18),
                                top: 0,
                                child: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Color(0xFFE87722),
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 3),
                    // Time labels: start | shot | end
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmtDur(Duration.zero),
                            style: const TextStyle(
                                fontSize: 9, color: Color(0xFF7A6E68))),
                        Text(
                            _fmtDur(Duration(
                                milliseconds: widget.shot.shotOffsetMs)),
                            style: const TextStyle(
                                fontSize: 9, color: Color(0xFF7A6E68))),
                        Text(_fmtDur(duration),
                            style: const TextStyle(
                                fontSize: 9, color: Color(0xFF7A6E68))),
                      ],
                    ),
                  ],
                ),
              ),

            // ── Playback controls ────────────────────────────────────────
            if (_ready && ctrl != null)
              Container(
                color: const Color(0xFF0D0B09),
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CtrlBtn(label: '–5с', onTap: () => _skip(-5)),
                        IconButton(
                          icon: const Icon(Icons.skip_previous,
                              color: Color(0xFF7A7470)),
                          iconSize: 28,
                          onPressed: () {
                            ctrl.seekTo(Duration.zero);
                            ctrl.play();
                          },
                        ),
                        _BigPlayButton(
                          playing: playing,
                          onTap: () =>
                              playing ? ctrl.pause() : ctrl.play(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next,
                              color: Color(0xFF7A7470)),
                          iconSize: 28,
                          onPressed: () => ctrl.seekTo(
                              Duration(milliseconds: widget.shot.shotOffsetMs)),
                        ),
                        _CtrlBtn(label: '+5с', onTap: () => _skip(5)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SpeedChip(
                            label: '0.5×',
                            active: _speed == 0.5,
                            onTap: () => _setSpeed(0.5)),
                        const SizedBox(width: 6),
                        _SpeedChip(
                            label: '1×',
                            active: _speed == 1.0,
                            onTap: () => _setSpeed(1.0)),
                        const SizedBox(width: 6),
                        _SpeedChip(
                            label: '2×',
                            active: _speed == 2.0,
                            onTap: () => _setSpeed(2.0)),
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

// ── Helper widgets ────────────────────────────────────────────────────────────

class _CtrlBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CtrlBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Text(label,
            style: const TextStyle(fontSize: 13, color: Color(0xFFC0B4AC))),
      ),
    );
  }
}

class _BigPlayButton extends StatelessWidget {
  final bool playing;
  final VoidCallback onTap;
  const _BigPlayButton({required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: Color(0xFFE87722),
          shape: BoxShape.circle,
        ),
        child: Icon(
          playing ? Icons.pause : Icons.play_arrow,
          color: const Color(0xFF1A0A00),
          size: 30,
        ),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SpeedChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE87722) : const Color(0xFF261E1A),
          borderRadius: BorderRadius.circular(10),
          border: active ? null : Border.all(color: const Color(0xFF33281F)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? const Color(0xFF1A0A00) : const Color(0xFFC89A6A),
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
