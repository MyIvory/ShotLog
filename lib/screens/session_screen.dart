import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../providers/session_provider.dart';
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
              Expanded(child: _CameraView(sp: sp)),
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

class _CameraView extends StatelessWidget {
  final SessionProvider sp;
  const _CameraView({required this.sp});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (sp.hasCameraPreview && sp.cameraController != null)
          Positioned.fill(
            child: CameraPreview(sp.cameraController as CameraController),
          )
        else
          const Center(child: CircularProgressIndicator()),
        SessionStateOverlay(
          state: sp.state,
          countdownRemaining: sp.countdownRemaining,
          shotCount: sp.shots.length,
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
        // Map dBFS [-80, 0] → [0.0, 1.0]
        final level = ((_dbfs + 80) / 80).clamp(0.0, 1.0);
        final threshPos = ((threshold + 80) / 80).clamp(0.0, 1.0);
        final triggered = _dbfs >= threshold;
        final barColor = triggered ? Colors.redAccent : Colors.greenAccent;

        return Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    active ? Icons.mic : Icons.mic_off,
                    size: 14,
                    color: active ? Colors.greenAccent : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    active
                        ? 'Мікрофон: ${_dbfs.toStringAsFixed(1)} dBFS'
                        : 'Мікрофон неактивний',
                    style: TextStyle(
                      color: active ? Colors.white70 : Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  if (triggered)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text('🔴 ПОСТРІЛ!',
                          style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final w = constraints.maxWidth;
                  return Stack(
                    children: [
                      // Background
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey[850],
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // Level bar
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 50),
                        height: 12,
                        width: w * level,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // Threshold marker
                      Positioned(
                        left: w * threshPos - 1,
                        child: Container(
                          width: 2,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('-80', style: TextStyle(color: Colors.grey, fontSize: 9)),
                  Text(
                    '▲ поріг ${threshold.toStringAsFixed(0)} dBFS',
                    style: const TextStyle(color: Colors.orange, fontSize: 9),
                  ),
                  const Text('0', style: TextStyle(color: Colors.grey, fontSize: 9)),
                ],
              ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
            label: const Text('Завершити', style: TextStyle(color: Colors.redAccent)),
            onPressed: () => _confirmEnd(context),
          ),
          // TODO: remove before release
          if (sp.state == SessionState.ready)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              icon: const Icon(Icons.radio_button_on, color: Colors.white),
              label: const Text('BT тест', style: TextStyle(color: Colors.white)),
              onPressed: () => context.read<SessionProvider>().triggerButton(),
            ),
          if (sp.shots.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.play_circle_outline, color: Colors.white),
              label: const Text('Останній постріл', style: TextStyle(color: Colors.white)),
              onPressed: () => _openLastShot(context),
            )
          else if (sp.state != SessionState.ready)
            const Text('Очікування...', style: TextStyle(color: Colors.grey)),
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
