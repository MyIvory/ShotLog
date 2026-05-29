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
const int    _kLines   =  18;
const double _kPadTop  =  20.0;
const double _kPadBot  =   8.0;

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

  void _handleDragAt(double localY, double canvasH) {
    final effectiveH = canvasH - _kPadTop - _kPadBot;
    final adjusted = (localY - _kPadTop).clamp(0.0, effectiveH);
    final db = (_kDbMax - (adjusted / effectiveH) * (_kDbMax - _kDbMin))
        .clamp(_kDbMin, _kDbMax);
    setState(() => _threshDb = db.roundToDouble());
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
              // Waveform — fills all available height
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: LayoutBuilder(
                      builder: (_, constraints) {
                        final canvasH = constraints.maxHeight;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragUpdate: (d) =>
                              _handleDragAt(d.localPosition.dy, canvasH),
                          onTapDown: (d) =>
                              _handleDragAt(d.localPosition.dy, canvasH),
                          child: SizedBox(
                            width: double.infinity,
                            height: canvasH,
                            child: CustomPaint(
                              painter: _WaveformPainter(
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
                                    '${_threshDb.toStringAsFixed(0)} dBFS · тягніть лінію',
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

// ── Waveform painter ──────────────────────────────────────────────────────────

class _WaveformPainter extends CustomPainter {
  final List<double> history;
  final double threshDb;
  final double phase;

  const _WaveformPainter({
    required this.history,
    required this.threshDb,
    required this.phase,
  });

  double _dbToY(double db, double h) {
    final f = (db - _kDbMin) / (_kDbMax - _kDbMin);
    final effectiveH = h - _kPadTop - _kPadBot;
    return _kPadTop + effectiveH - f * effectiveH;
  }

  Color _levelColor(double db, double alpha) {
    final margin = threshDb - db;
    int r, g, b;
    if (margin > 15) {
      r = 110; g = 224; b = 160;
    } else if (margin > 5) {
      final t = (15 - margin) / 10;
      r = (110 + t * (232 - 110)).round();
      g = (224 + t * (119 - 224)).round();
      b = (160 + t * (34  - 160)).round();
    } else if (margin > 0) {
      r = 232; g = 119; b = 34;
    } else {
      r = 255; g = 80; b = 60;
    }
    return Color.fromRGBO(r, g, b, alpha);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // dB grid lines + labels
    for (int db = -80; db <= 0; db += 10) {
      final y = _dbToY(db.toDouble(), h);
      canvas.drawLine(
        Offset(0, y), Offset(w, y),
        Paint()..color = const Color(0x0AFFFFFF)..strokeWidth = 0.5,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: db == 0 ? '0' : db.toString(),
          style: const TextStyle(fontSize: 11, color: Color(0x59F0EAE5)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, y - 13));
    }

    // Waveform — 18 layered lines
    final lastDb = history.last;
    for (int li = 0; li < _kLines; li++) {
      final t        = li / (_kLines - 1);
      final spread   = 0.6 + t * 0.4;
      final lineAlpha = 0.05 + t * 0.55;
      final phaseOff = (li - _kLines / 2) * 0.18;

      final path = Path();
      bool started = false;

      for (int i = 0; i < history.length; i++) {
        final x       = (i / (history.length - 1)) * w;
        final histDb  = history[i];
        final histAmp = ((histDb - _kDbMin) / (_kDbMax - _kDbMin)).clamp(0.0, 1.0);
        final centerY = _dbToY(histDb, h);
        final waveAmp = histAmp * h * 0.18 * spread;

        final wave =
            math.sin(i * 0.045 * 2.5 + phase + phaseOff)               * waveAmp * 0.60 +
            math.sin(i * 0.045 * 5.1 + phase * 1.3 + phaseOff * 0.7)   * waveAmp * 0.25 +
            math.sin(i * 0.045 * 8.3 + phase * 0.7 + phaseOff * 1.3)   * waveAmp * 0.15;

        final y = centerY + wave;
        if (!started) { path.moveTo(x, y); started = true; }
        else          { path.lineTo(x, y); }
      }

      canvas.drawPath(
        path,
        Paint()
          ..color      = _levelColor(lastDb, lineAlpha)
          ..strokeWidth = t < 0.3 ? 0.4 : t < 0.7 ? 0.7 : 1.0
          ..style      = PaintingStyle.stroke,
      );
    }

    // Glow at right edge (current level)
    final glowY = _dbToY(lastDb, h);
    final glowColor = _levelColor(lastDb, 1.0);
    canvas.drawCircle(
      Offset(w - 4, glowY),
      28,
      Paint()
        ..shader = RadialGradient(
          colors: [glowColor.withValues(alpha: 0.7), glowColor.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: Offset(w - 4, glowY), radius: 28)),
    );

    // Threshold line
    final threshY = _dbToY(threshDb, h);

    // Danger zone above threshold
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, threshY),
      Paint()..color = const Color(0x0AFF503C),
    );

    // Dashed line
    const dash = 8.0, gap = 5.0;
    double x = 0;
    final dashPaint = Paint()
      ..color = const Color(0xE6E87722)
      ..strokeWidth = 1.5;
    while (x < w) {
      canvas.drawLine(
          Offset(x, threshY), Offset(math.min(x + dash, w), threshY), dashPaint);
      x += dash + gap;
    }

    // Threshold glow band
    canvas.drawRect(
      Rect.fromLTWH(0, threshY - 12, w, 24),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0x00E87722),
            const Color(0x1FE87722),
            const Color(0x00E87722),
          ],
        ).createShader(Rect.fromLTWH(0, threshY - 12, w, 24)),
    );

    // Drag pill on right side of threshold line
    const pillW = 48.0, pillH = 22.0;
    final pillX = w - pillW - 8;
    final pillY = threshY - pillH / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(pillX, pillY, pillW, pillH), const Radius.circular(11)),
      Paint()..color = const Color(0xFFE87722),
    );
    for (int ri = 0; ri < 3; ri++) {
      final rx = pillX + pillW / 2 - 5 + ri * 5.0;
      canvas.drawRect(
        Rect.fromLTWH(rx - 0.5, pillY + 5, 1, pillH - 10),
        Paint()..color = const Color(0x8CFFFFFF),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.phase != phase || old.threshDb != threshDb;
}
