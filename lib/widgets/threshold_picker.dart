import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

const double _kDbMin    = -80.0;
const double _kDbMax    =   0.0;
const int    _kHistory  = 220;
const int    _kLines    =  18;
const double _kCanvasH  = 280.0;
const double _kPadTop   =  20.0;
const double _kPadBot   =   8.0;

/// Opens the waveform threshold picker as a modal bottom sheet.
/// Returns the selected dBFS value, or null if cancelled.
Future<double?> showThresholdPicker(BuildContext context, double currentThreshold) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ThresholdPickerSheet(initialThreshold: currentThreshold),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _ThresholdPickerSheet extends StatefulWidget {
  final double initialThreshold;
  const _ThresholdPickerSheet({required this.initialThreshold});

  @override
  State<_ThresholdPickerSheet> createState() => _ThresholdPickerSheetState();
}

class _ThresholdPickerSheetState extends State<_ThresholdPickerSheet>
    with SingleTickerProviderStateMixin {

  final _recorder  = AudioRecorder();
  StreamSubscription<Amplitude>? _sub;
  String? _tempPath;
  late final Ticker _ticker;

  double _currentDbfs = -60.0;
  late double _threshDb;
  double _phase    = 0.0;
  int    _lastMs   = 0;

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

  void _handleDrag(double localY) {
    const effectiveH = _kCanvasH - _kPadTop - _kPadBot;
    final adjusted = (localY - _kPadTop).clamp(0.0, effectiveH);
    final db = (_kDbMax - (adjusted / effectiveH) * (_kDbMax - _kDbMin))
        .clamp(_kDbMin, _kDbMax);
    setState(() => _threshDb = db.roundToDouble());
  }

  @override
  Widget build(BuildContext context) {
    final margin = _threshDb - _currentDbfs;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF100C0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top:   BorderSide(color: Color(0x1AFFFFFF), width: 0.5),
          left:  BorderSide(color: Color(0x1AFFFFFF), width: 0.5),
          right: BorderSide(color: Color(0x1AFFFFFF), width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ───────────────────────────────────────────────
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: const Color(0x2EFFFFFF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Поріг детекції',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600,
                              color: Color(0xFFF0EAE5), letterSpacing: -0.2)),
                      SizedBox(height: 3),
                      Text('Тягніть горизонтальну лінію',
                          style: TextStyle(fontSize: 12, color: Color(0x66F0EAE5))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x26E87722),
                    border: Border.all(color: const Color(0x66E87722), width: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_threshDb.toStringAsFixed(0)} dBFS',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: Color(0xFFE87722)),
                  ),
                ),
              ],
            ),
          ),

          // ── Waveform canvas ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (d) => _handleDrag(d.localPosition.dy),
                onTapDown:            (d) => _handleDrag(d.localPosition.dy),
                child: SizedBox(
                  width: double.infinity,
                  height: _kCanvasH,
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      history:  List.unmodifiable(_history),
                      threshDb: _threshDb,
                      phase:    _phase,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Stats chips ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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

          // ── Buttons ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0x12FFFFFF),
                        border: Border.all(color: const Color(0x1EFFFFFF), width: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('Скасувати',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500,
                                color: Color(0xA6F0EAE5))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(_threshDb),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE87722),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('Зберегти',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: Color(0xFF1A0A00))),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0806), Color(0xFF0F0C09)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

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
            math.sin(i * 0.045 * 2.5 + phase + phaseOff)          * waveAmp * 0.60 +
            math.sin(i * 0.045 * 5.1 + phase * 1.3 + phaseOff * 0.7) * waveAmp * 0.25 +
            math.sin(i * 0.045 * 8.3 + phase * 0.7 + phaseOff * 1.3) * waveAmp * 0.15;

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
