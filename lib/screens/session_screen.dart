import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/session_provider.dart';
import '../services/physical_camera_service.dart';
import '../widgets/session_state_overlay.dart';
import '../widgets/video_player_overlay.dart';

class SessionScreen extends StatelessWidget {
  final AppSettings settings;

  const SessionScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SessionProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Завершити сесію?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ні')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Так')),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          await context.read<SessionProvider>().endSession();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: _CameraView(sp: sp, settings: settings)),
              _AmplitudePanel(sp: sp),
              _BottomBar(sp: sp, settings: settings),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Camera preview + state overlay ──────────────────────────────────────────

class _CameraView extends StatefulWidget {
  final SessionProvider sp;
  final AppSettings settings;
  const _CameraView({required this.sp, required this.settings});

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> {
  bool _flashVisible = false;
  Timer? _flashTimer;
  int _prevShotCount = 0;

  @override
  void didUpdateWidget(_CameraView old) {
    super.didUpdateWidget(old);
    if (widget.sp.shots.length > _prevShotCount) {
      _prevShotCount = widget.sp.shots.length;
      _triggerFlash();
      HapticFeedback.mediumImpact();
    }
  }

  void _triggerFlash() {
    setState(() => _flashVisible = true);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _flashVisible = false);
    });
  }

  void _showCameraPicker(BuildContext context, SessionProvider sp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SessionCameraSheet(sp: sp),
    );
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sp = widget.sp;
    return Stack(
      children: [
        if (sp.hasCameraPreview && sp.cameraController != null)
          Positioned.fill(
            child: CameraPreview(sp.cameraController as CameraController),
          )
        else
          const Center(child: CircularProgressIndicator()),
        if (sp.hasCameraPreview && sp.cameraController != null)
          Positioned(
            right: 12,
            bottom: 16,
            child: _ZoomWheel(
              key: ValueKey(sp.cameraController.hashCode),
              sp: sp,
            ),
          ),
        if (sp.state == SessionState.ready && sp.hasCameraPreview)
          Positioned(
            bottom: 16,
            left: 12,
            child: GestureDetector(
              onTap: () => _showCameraPicker(context, sp),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt_outlined,
                    color: Colors.white70, size: 22),
              ),
            ),
          ),
        SessionStateOverlay(
          state: sp.state,
          countdownRemaining: sp.countdownRemaining,
          shotCount: sp.shots.length,
          timeoutSec: widget.settings.timeoutSec,
          lastTriggerDbfs: sp.shots.lastOrNull?.triggerDbfs,
        ),
        // Countdown full-screen overlay
        if (sp.state == SessionState.countdown)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Text(
                      '${sp.countdownRemaining}',
                      key: ValueKey(sp.countdownRemaining),
                      style: const TextStyle(
                        fontSize: 96,
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Shot detection flash
        if (_flashVisible)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
      ],
    );
  }
}

// ── Live amplitude equalizer panel ───────────────────────────────────────────

class _AmplitudePanel extends StatefulWidget {
  final SessionProvider sp;
  const _AmplitudePanel({required this.sp});

  @override
  State<_AmplitudePanel> createState() => _AmplitudePanelState();
}

class _AmplitudePanelState extends State<_AmplitudePanel> {
  double _dbfs = -80.0;

  @override
  Widget build(BuildContext context) {
    final active = widget.sp.state == SessionState.recordingArmed;

    return StreamBuilder<double>(
      stream: active ? widget.sp.amplitudeStream : const Stream.empty(),
      builder: (ctx, snap) {
        if (snap.hasData) _dbfs = snap.data!;
        if (!active) _dbfs = -80.0;

        final threshold = widget.sp.detectionThreshold;
        final level     = ((_dbfs + 80) / 80).clamp(0.0, 1.0);
        final threshPos = ((threshold + 80) / 80).clamp(0.0, 1.0);

        return Container(
          color: const Color(0xFF0A0D08),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Рівень звуку',
                style: TextStyle(color: Color(0xFF5A5450), fontSize: 8),
              ),
              const SizedBox(height: 4),
              // ── Bar ──────────────────────────────────────────────────
              LayoutBuilder(builder: (ctx, box) {
                final w = box.maxWidth;
                final threshX = (w * threshPos).clamp(0.0, w);
                return Column(
                  children: [
                    SizedBox(
                      height: 14,
                      child: Stack(children: [
                        // Track background
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A0A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Level fill
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 50),
                          width: w * level,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A3A10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Threshold line
                        Positioned(
                          left: threshX - 0.75,
                          top: 0, bottom: 0,
                          child: Container(
                            width: 1.5,
                            color: const Color(0xFFE87722),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 3),
                    // ── Labels ───────────────────────────────────────
                    SizedBox(
                      height: 10,
                      child: Stack(children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('–60 dBFS',
                              style: TextStyle(
                                  color: Color(0xFF3A3430), fontSize: 7)),
                        ),
                        // Threshold label at dynamic position
                        if (w > 24)
                        Positioned(
                          left: (threshX - 12).clamp(0.0, w - 24),
                          child: Text(
                            threshold.toStringAsFixed(0),
                            style: const TextStyle(
                                color: Color(0xFFE87722), fontSize: 7),
                          ),
                        ),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text('0',
                              style: TextStyle(
                                  color: Color(0xFF3A3430), fontSize: 7)),
                        ),
                      ]),
                    ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ── Bottom action bar ────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final SessionProvider sp;
  final AppSettings settings;

  const _BottomBar({required this.sp, required this.settings});

  static const _btnStyle = (
    bg: Color(0xFFE87722),
    fg: Color(0xFF1A0A00),
  );

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final hasShots = sp.shots.isNotEmpty;
    final inButtonMode = settings.triggerMode == TriggerMode.button;
    final isReady = sp.state == SessionState.ready;

    final btnStyle = FilledButton.styleFrom(
      backgroundColor: _btnStyle.bg,
      foregroundColor: _btnStyle.fg,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      padding: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size(0, 0),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Container(
      color: const Color(0xFF0A0D08),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 10 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (inButtonMode) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isReady ? const Color(0xFF3A6B1A) : const Color(0xFF1E1E1E),
                  foregroundColor: isReady ? Colors.white : const Color(0xFF555555),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: isReady ? sp.triggerButton : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 24),
                label: const Text('ПУСК'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (hasShots) ...[
                Expanded(
                  child: FilledButton.icon(
                    style: btnStyle,
                    onPressed: () => _openLastShot(context),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Перегляд'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton.icon(
                  style: btnStyle,
                  onPressed: () => _confirmEnd(context),
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: const Text('Завершити'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmEnd(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Завершити сесію?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ні')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Так')),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<SessionProvider>().endSession();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  void _openLastShot(BuildContext context) {
    final sp = context.read<SessionProvider>();
    if (sp.shots.isEmpty) return;
    final shot = sp.shots.last;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VideoPlayerOverlay(shot: shot, preRollSec: settings.preRollSec),
      ),
    );
  }
}

// ── Zoom drum picker ─────────────────────────────────────────────────────────

class _ZoomWheel extends StatefulWidget {
  final SessionProvider sp;
  const _ZoomWheel({super.key, required this.sp});

  @override
  State<_ZoomWheel> createState() => _ZoomWheelState();
}

class _ZoomWheelState extends State<_ZoomWheel> {
  final _scrollCtrl = FixedExtentScrollController();
  List<double> _levels = [1.0];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initLevels();
  }

  Future<void> _initLevels() async {
    final ctrl = widget.sp.cameraController as CameraController?;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final ctrlMin = await ctrl.getMinZoomLevel();
    final ctrlMax = await ctrl.getMaxZoomLevel();
    final minOverride = widget.sp.cameraZoomMin > 0 ? widget.sp.cameraZoomMin : null;
    final maxOverride = widget.sp.cameraZoomMax > 0 ? widget.sp.cameraZoomMax : null;
    final min = (minOverride ?? ctrlMin).clamp(ctrlMin, ctrlMax);
    final max = (maxOverride ?? ctrlMax).clamp(ctrlMin, ctrlMax);
    if (!mounted) return;
    final levels = _buildLevels(min, max);
    setState(() => _levels = levels);
    // Apply initial zoom so the camera uses the correct physical lens from the start.
    if (levels.isNotEmpty) widget.sp.setZoom(levels.first);
  }

  List<double> _buildLevels(double min, double max) {
    final step = max <= 4.0 ? 0.5 : 1.0;
    final result = <double>[];
    // Start at the first clean step that is >= min (e.g. min=0.6 → start at 1.0)
    var z = (min / step).ceil() * step;
    while (z <= max + 0.001) {
      result.add(double.parse(z.toStringAsFixed(1)));
      z = double.parse((z + step).toStringAsFixed(1)); // avoid float drift
    }
    return result.isEmpty ? [min] : result;
  }

  String _label(double z) =>
      z == z.roundToDouble() ? '${z.toInt()}×' : '$z×';

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const itemH = 40.0;
    const visibleItems = 4;

    return Container(
      width: 60,
      height: itemH * visibleItems,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListWheelScrollView.useDelegate(
          controller: _scrollCtrl,
          itemExtent: itemH,
          diameterRatio: 1.5,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (i) {
            setState(() => _selectedIndex = i);
            widget.sp.setZoom(_levels[i]);
          },
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: _levels.length,
            builder: (_, i) {
              final sel = i == _selectedIndex;
              return Center(
                child: Text(
                  _label(_levels[i]),
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.white38,
                    fontSize: sel ? 20 : 15,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    shadows: sel
                        ? const [Shadow(color: Colors.black54, blurRadius: 6)]
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Session-screen camera picker (no slider) ─────────────────────────────────

class _SessionCameraSheet extends StatefulWidget {
  final SessionProvider sp;
  const _SessionCameraSheet({required this.sp});

  @override
  State<_SessionCameraSheet> createState() => _SessionCameraSheetState();
}

class _SessionCameraSheetState extends State<_SessionCameraSheet> {
  List<PhysicalCameraInfo>? _cameras;

  @override
  void initState() {
    super.initState();
    PhysicalCameraService().getBackCameras().then((list) {
      if (mounted) setState(() => _cameras = list);
    });
  }

  String _rangeLabel(PhysicalCameraInfo c) {
    if (c.zoomMin == null || c.zoomMax == null) return '';
    final lo = c.zoomMin!;
    final hi = c.zoomMax!;
    String fmt(double v) =>
        v == v.roundToDouble() ? '${v.toInt()}×' : '${v.toStringAsFixed(1)}×';
    return '${fmt(lo)} – ${fmt(hi)}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Вибір камери',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Діапазон зуму підлаштується автоматично',
              style: TextStyle(color: Color(0xFF888888), fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_cameras == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              ..._cameras!.map((cam) {
                final isSelected =
                    widget.sp.settings.selectedCameraId == cam.id;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(
                    Icons.camera_alt_outlined,
                    color: isSelected
                        ? const Color(0xFFE87722)
                        : const Color(0xFF888888),
                  ),
                  title: Text(
                    cam.focalLength > 0
                        ? '${cam.focalLength.toStringAsFixed(1)} mm'
                        : 'ID: ${cam.id}',
                    style: TextStyle(
                      color:
                          isSelected ? const Color(0xFFE87722) : Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  subtitle: Text(
                    _rangeLabel(cam),
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 12),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Color(0xFFE87722))
                      : null,
                  onTap: () async {
                    Navigator.pop(context);
                    await widget.sp.switchCamera(
                      cam.id,
                      cam.zoomMin ?? 0.0,
                      cam.zoomMax ?? 0.0,
                    );
                  },
                );
              }),
          ],
        ),
      ),
    );
  }
}

