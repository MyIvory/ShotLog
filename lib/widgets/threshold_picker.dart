import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../widgets/parallax_bg.dart';

const double _kDbMin   = -80.0;
const double _kDbMax   =   0.0;
const int    _kHistory = 220;

const _kText = Color(0xFFF0EAE5);
const _kHint = Color(0x61F0EAE5);

/// Opens the threshold screen as a full-screen push.
/// Returns the selected dBFS value, or null if cancelled.
Future<double?> showThresholdPicker(BuildContext context, double currentThreshold) {
  return Navigator.push<double>(
    context,
    MaterialPageRoute(
      builder: (_) => ThresholdScreen(initialThreshold: currentThreshold),
    ),
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ThresholdScreen extends StatefulWidget {
  final double initialThreshold;
  const ThresholdScreen({super.key, required this.initialThreshold});

  @override
  State<ThresholdScreen> createState() => _ThresholdScreenState();
}

class _ThresholdScreenState extends State<ThresholdScreen>
    with SingleTickerProviderStateMixin {

  final _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _sub;
  String? _tempPath;
  late final Ticker _ticker;

  late double _threshDb;
  double _phase = 0.0;
  int    _lastMs = 0;

  final List<double> _history = List.filled(_kHistory, -70.0, growable: true);

  @override
  void initState() {
    super.initState();
    _threshDb = widget.initialThreshold.clamp(_kDbMin, _kDbMax);
    _startListening();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final ms = elapsed.inMilliseconds;
    final dt = ((ms - _lastMs) / 1000.0).clamp(0.0, 0.1);
    _lastMs = ms;
    setState(() => _phase += dt * 1.8);
  }

  Future<void> _startListening() async {
    try {
      final dir = await getTemporaryDirectory();
      _tempPath = '${dir.path}/thresh_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          numChannels: 1,
          sampleRate: 44100,
          autoGain: false,
          noiseSuppress: true,
          echoCancel: false,
        ),
        path: _tempPath!,
      );
      _sub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 50))
          .listen((amp) {
        if (!mounted) return;
        final db = amp.current.clamp(_kDbMin, _kDbMax);
        setState(() {
          _history.removeAt(0);
          _history.add(db);
        });
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sub?.cancel();
    _recorder.stop().then((_) {
      if (_tempPath != null) {
        try { File(_tempPath!).deleteSync(); } catch (_) {}
      }
      _recorder.dispose();
    });
    super.dispose();
  }

  void _handleRadialDrag(DragUpdateDetails d, double canvasW, double canvasH) {
    final center = Offset(canvasW / 2, canvasH / 2);
    final fromCenter = d.localPosition - center;
    final dist = fromCenter.distance;
    if (dist < 1) return;
    // Radial component of delta (positive = outward, negative = inward)
    final radialDelta =
        (d.delta.dx * fromCenter.dx + d.delta.dy * fromCenter.dy) / dist;
    final maxR = canvasW * 0.47;
    final dbDelta = (radialDelta / maxR) * (_kDbMax - _kDbMin) ;
    setState(() {
      _threshDb = (_threshDb + dbDelta).clamp(_kDbMin, _kDbMax);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq     = MediaQuery.of(context);
    final top    = mq.padding.top;
    final bot    = mq.padding.bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Background ────────────────────────────────────────────
          const Positioned.fill(
            child: ParallaxBg(
              asset: 'assets/images/bg_rifle.webp',
              baseAlignment: Alignment(0.2, -1.0),
            ),
          ),
          Positioned.fill(child: Container(color: const Color(0xB8120E0C))),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE60C0A08)],
                  stops: [0.25, 1.0],
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────
          Column(
            children: [
              SizedBox(height: top + 76 + 8),
              // Radial visualizer — fills all available height
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final canvasH = constraints.maxHeight;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (d) => _handleRadialDrag(
                            d, constraints.maxWidth, canvasH),
                        child: SizedBox(
                          width: double.infinity,
                          height: canvasH,
                          child: CustomPaint(
                            painter: _RadialPainter(
                              history:  List.unmodifiable(_history),
                              threshDb: _threshDb,
                              phase:    _phase,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: bot + 16),
            ],
          ),

          // ── Glass header ──────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: top),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Поріг детекції',
                                      style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          color: _kText,
                                          letterSpacing: -0.5)),
                                  SizedBox(height: 2),
                                  Text('тягніть від центру',
                                      style: TextStyle(fontSize: 12, color: _kHint)),
                                ],
                              ),
                            ),
                            _HdrBtn(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(Icons.west, color: _kText, size: 18),
                            ),
                            const SizedBox(width: 8),
                            _HdrBtn(
                              onTap: () => Navigator.pop(context, _threshDb),
                              child: const Icon(Icons.check, color: _kText, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header button ─────────────────────────────────────────────────────────────

class _HdrBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _HdrBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          border: Border.all(color: const Color(0x1EFFFFFF), width: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: child),
      ),
    );
  }
}


// ── Radial glow wave painter ──────────────────────────────────────────────────

class _RadialPainter extends CustomPainter {
  final List<double> history;
  final double threshDb;
  final double phase;

  // Two colour families alternating between layers (warm + cool)
  static const _kWarm = Color(0xFFE87722); // amber — near threshold
  static const _kHot  = Color(0xFFFF6050); // above threshold

  static const _kLayers = 7;
  static const _kPoints = 200; // points per closed curve

  const _RadialPainter({
    required this.history,
    required this.threshDb,
    required this.phase,
  });

  // Spatial variation per angle (multi-harmonic, returns ≈ −1..+1)
  double _vary(double angle, int layer) {
    final po = layer * 0.55;
    return 0.46 * math.sin(angle * 2 + phase * 1.30 + po) +
           0.28 * math.sin(angle * 3 + phase * 0.85 + po * 1.6) +
           0.16 * math.sin(angle * 5 + phase * 2.20 + po * 0.8) +
           0.10 * math.sin(angle * 8 + phase * 1.55 + po * 1.3);
  }

  Path _buildPath(Offset center, double baseR, double maxDisp,
      double amp, int layer) {
    final path = Path();
    for (int i = 0; i <= _kPoints; i++) {
      final angle = (i / _kPoints) * 2 * math.pi - math.pi / 2;
      final v = _vary(angle, layer); // −1..+1
      final dispFactor = (v + 1.0) / 2.0; // 0..1
      // Minimum visible radius even at silence (subtle ambient shape)
      final r = baseR + (0.08 + amp * 0.92) * maxDisp * dispFactor;
      final px = center.dx + r * math.cos(angle);
      final py = center.dy + r * math.sin(angle);
      if (i == 0) { path.moveTo(px, py); } else { path.lineTo(px, py); }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w      = size.width;
    final center = Offset(w / 2, size.height / 2);
    final baseR  = w * 0.18;
    final maxDisp = w * 0.30;

    // Smooth amplitude over last 4 samples
    final n = history.length;
    final recentDb = n >= 4
        ? (history[n-1] + history[n-2] + history[n-3] + history[n-4]) / 4
        : history.last;
    final amp = ((recentDb - _kDbMin) / (_kDbMax - _kDbMin)).clamp(0.0, 1.0);

    final margin     = threshDb - recentDb;
    final waveColor  = margin > 15 ? const Color(0xFF5AB4E8)
                     : margin > 0  ? _kWarm
                     : _kHot;

    final threshNorm = ((threshDb - _kDbMin) / (_kDbMax - _kDbMin)).clamp(0.0, 1.0);
    final threshR    = baseR + threshNorm * maxDisp;

    // ── Current level in center ───────────────────────────────
    final tpNum = TextPainter(
      text: TextSpan(
        text: history.last.abs().toStringAsFixed(0),
        style: TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          color: waveColor.withValues(alpha: 0.9),
          letterSpacing: -1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final tpUnit = TextPainter(
      text: TextSpan(
        text: 'dB',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: waveColor.withValues(alpha: 0.5),
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const gap = 2.0;
    final totalH = tpNum.height + gap + tpUnit.height;
    tpNum.paint(canvas,
        Offset(center.dx - tpNum.width / 2, center.dy - totalH / 2));
    tpUnit.paint(canvas,
        Offset(center.dx - tpUnit.width / 2,
            center.dy - totalH / 2 + tpNum.height + gap));

    // ── Wave layers ───────────────────────────────────────────
    for (int li = 0; li < _kLayers; li++) {
      final t    = li / (_kLayers - 1); // 0..1
      final path = _buildPath(center, baseR, maxDisp, amp, li);

      final color = waveColor;

      final envelope = (0.25 + amp * 0.75).clamp(0.0, 1.0);
      // Pass 1 — outer halo (wide, very transparent)
      canvas.drawPath(path,
          Paint()
            ..color = color.withValues(alpha: ((0.04 + t * 0.04) * envelope).clamp(0.0, 1.0))
            ..strokeWidth = 28.0 + t * 16.0
            ..style = PaintingStyle.stroke);
      // Pass 2 — mid glow
      canvas.drawPath(path,
          Paint()
            ..color = color.withValues(alpha: ((0.10 + t * 0.10) * envelope).clamp(0.0, 1.0))
            ..strokeWidth = 10.0 + t * 6.0
            ..style = PaintingStyle.stroke);
      // Pass 3 — inner glow
      canvas.drawPath(path,
          Paint()
            ..color = color.withValues(alpha: ((0.20 + t * 0.16) * envelope).clamp(0.0, 1.0))
            ..strokeWidth = 3.5 + t * 2.0
            ..style = PaintingStyle.stroke);
      // Pass 4 — sharp core
      canvas.drawPath(path,
          Paint()
            ..color = color.withValues(alpha: ((0.50 + t * 0.40) * (0.2 + amp * 0.8)).clamp(0.0, 1.0))
            ..strokeWidth = 0.8 + t * 0.5
            ..style = PaintingStyle.stroke);
    }

    // ── Threshold ring — frosted glass, matches chip style ───────
    canvas.drawCircle(center, threshR,
        Paint()
          ..color = const Color(0x44FFFFFF)
          ..strokeWidth = 20
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawCircle(center, threshR,
        Paint()
          ..color = const Color(0x42FFFFFF)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke);

    // ── Threshold chip — frosted glass, above all layers ──────
    const angle11   = -math.pi / 2 - math.pi / 6; // 11 o'clock
    const cPadH = 7.0, cPadV = 4.0;
    final tpChip = TextPainter(
      text: const TextSpan(
        text: 'ПОРІГ',
        style: TextStyle(
          fontSize: 9,
          color: Color(0x80F0EAE5),
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final tpChipVal = TextPainter(
      text: TextSpan(
        text: '${threshDb.abs().toStringAsFixed(0)} dB',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xCCF0EAE5),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final chipW = math.max(tpChip.width, tpChipVal.width) + cPadH * 2;
    final chipH = tpChip.height + 2 + tpChipVal.height + cPadV * 2;
    // Offset center outward + nudge left&up so circle doesn't intersect chip
    final chipCx = center.dx + (threshR + chipH / 2 + 10) * math.cos(angle11) - 6;
    final chipCy = center.dy + (threshR + chipH / 2 + 10) * math.sin(angle11) - 6;
    final chipRect = Rect.fromCenter(
        center: Offset(chipCx, chipCy), width: chipW, height: chipH);
    final chipRRect = RRect.fromRectAndRadius(chipRect, const Radius.circular(9));
    canvas.drawRRect(chipRRect, Paint()..color = const Color(0x26FFFFFF));
    canvas.drawRRect(chipRRect,
        Paint()
          ..color = const Color(0x28FFFFFF)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke);
    tpChip.paint(canvas,
        Offset(chipRect.left + cPadH, chipRect.top + cPadV));
    tpChipVal.paint(canvas,
        Offset(chipRect.left + cPadH, chipRect.top + cPadV + tpChip.height + 2));
  }

  @override
  bool shouldRepaint(covariant _RadialPainter old) =>
      old.phase != phase ||
      old.threshDb != threshDb ||
      old.history.last != history.last;
}
