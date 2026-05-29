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

  double _currentDbfs = -60.0;
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
          _currentDbfs = db;
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
    final margin = _threshDb - _currentDbfs;

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
              // Stats chips
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    _StatChip(
                      label: 'Зараз',
                      value: '${_currentDbfs.toStringAsFixed(0)} dBFS',
                      valueColor: const Color(0xFF6EE0A0),
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'Поріг',
                      value: '${_threshDb.toStringAsFixed(0)} dBFS',
                      valueColor: const Color(0xFFE87722),
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'Запас',
                      value: '${margin >= 0 ? '+' : ''}${margin.toStringAsFixed(0)} dB',
                      valueColor: margin >= 10
                          ? const Color(0xFF6EE0A0)
                          : margin >= 3
                              ? const Color(0xFFE87722)
                              : const Color(0xFFFF6050),
                    ),
                  ],
                ),
              ),
              SizedBox(height: bot),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Поріг детекції',
                                      style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          color: _kText,
                                          letterSpacing: -0.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_threshDb.toStringAsFixed(0)} dBFS · тягніть вгору/вниз',
                                    style: const TextStyle(
                                        fontSize: 12, color: _kHint),
                                  ),
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

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color  valueColor;
  const _StatChip({required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF),
          border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10, color: Color(0x59F0EAE5), letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
          ],
        ),
      ),
    );
  }
}

// ── Radial dot painter ────────────────────────────────────────────────────────

class _RadialPainter extends CustomPainter {
  final List<double> history;
  final double threshDb;
  final double phase;

  static const _kBars = 72;

  const _RadialPainter({
    required this.history,
    required this.threshDb,
    required this.phase,
  });

  Color _barColor(double db) {
    final margin = threshDb - db;
    if (margin > 15) return const Color(0xFF6EE0A0);
    if (margin > 5) {
      final t = (15 - margin) / 10;
      return Color.fromRGBO(
        (110 + t * (232 - 110)).round(),
        (224 + t * (119 - 224)).round(),
        (160 + t * (34  - 160)).round(),
        1.0,
      );
    }
    if (margin > 0) return const Color(0xFFE87722);
    return const Color(0xFFFF6050);
  }

  Path _dashedCircle(Offset center, double r) {
    final path         = Path();
    final circumference = 2 * math.pi * r;
    final totalDashes  = (circumference / 14.0).floor().clamp(1, 999);
    final stepAngle    = 2 * math.pi / totalDashes;
    final dashAngle    = (8.0 / circumference) * 2 * math.pi;
    final rect         = Rect.fromCircle(center: center, radius: r);
    for (int i = 0; i < totalDashes; i++) {
      path.addArc(rect, -math.pi / 2 + i * stepAngle, dashAngle);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w      = size.width;
    final h      = size.height;
    final center = Offset(w / 2, h / 2);

    final baseR   = w * 0.19;
    final maxDisp = w * 0.28;
    final dotR    = w * 0.0085;
    final dotStep = dotR * 2 + w * 0.005;
    final maxDots = (maxDisp / dotStep).floor();

    final threshNorm = ((threshDb - _kDbMin) / (_kDbMax - _kDbMin)).clamp(0.0, 1.0);
    final threshR    = baseR + threshNorm * maxDisp;

    // ── Inner ring pulse ─────────────────────────────────────
    final pulseA = 0.07 + 0.04 * math.sin(phase * 1.5);
    canvas.drawCircle(center, baseR,
        Paint()..color = Color.fromRGBO(110, 224, 160, pulseA));
    canvas.drawCircle(center, baseR,
        Paint()
          ..color = const Color(0x33FFFFFF)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke);

    // ── Danger zone fill ─────────────────────────────────────
    canvas.drawCircle(center, threshR,
        Paint()..color = const Color(0x08FF503C));

    // ── Dot bars — all react to current level simultaneously ──
    // Smooth current level over last 3 samples
    final recentDb = history.length >= 3
        ? (history[history.length - 1] +
               history[history.length - 2] +
               history[history.length - 3]) /
              3
        : history.last;
    final currentAmp =
        ((recentDb - _kDbMin) / (_kDbMax - _kDbMin)).clamp(0.0, 1.0);
    final barColor = _barColor(recentDb);

    for (int i = 0; i < _kBars; i++) {
      final barAngle = (i / _kBars) * 2 * math.pi;

      // Animated per-bar ripple — multi-harmonic sine on top of global level
      final v = 0.50 * math.sin(barAngle * 2  + phase * 1.4) +
                0.28 * math.sin(barAngle * 5  + phase * 2.1) +
                0.14 * math.sin(barAngle * 9  + phase * 0.9) +
                0.08 * math.sin(barAngle * 17 + phase * 3.0);
      // v ≈ −1..+1 → factor 0.15..1.0
      final factor = ((v + 1.0) * 0.425 + 0.15).clamp(0.15, 1.0);

      final numDots = (currentAmp * maxDots * factor).round();
      if (numDots == 0) continue;

      final drawAngle = barAngle - math.pi / 2;
      final cosA = math.cos(drawAngle);
      final sinA = math.sin(drawAngle);

      for (int d = 0; d < numDots; d++) {
        final r = baseR + (d + 0.5) * dotStep;
        canvas.drawCircle(
          Offset(center.dx + r * cosA, center.dy + r * sinA),
          dotR,
          Paint()..color = barColor,
        );
      }
    }

    // ── Threshold ring ───────────────────────────────────────
    // Soft glow stroke
    canvas.drawCircle(center, threshR,
        Paint()
          ..color = const Color(0x22E87722)
          ..strokeWidth = 20
          ..style = PaintingStyle.stroke);

    // Dashed amber ring
    canvas.drawPath(
      _dashedCircle(center, threshR),
      Paint()
        ..color = const Color(0xE6E87722)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // ── Drag pill at 12 o'clock on threshold ring ────────────
    final gripCenter = Offset(center.dx, center.dy - threshR);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: gripCenter, width: 40, height: 20),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFFE87722),
    );
    for (int ri = 0; ri < 3; ri++) {
      final rx = gripCenter.dx - 4 + ri * 4.0;
      canvas.drawRect(
        Rect.fromLTWH(rx - 0.5, gripCenter.dy - 4, 1, 8),
        Paint()..color = const Color(0x8CFFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadialPainter old) =>
      old.phase != phase ||
      old.threshDb != threshDb ||
      old.history.last != history.last;
}
