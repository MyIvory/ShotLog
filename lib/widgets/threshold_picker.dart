import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Opens the VU-meter threshold picker as a modal bottom sheet.
/// Returns the selected dBFS value, or null if dismissed.
Future<double?> showThresholdPicker(BuildContext context, double currentThreshold) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ThresholdPickerSheet(initialThreshold: currentThreshold),
  );
}

// ---------------------------------------------------------------------------
// Sheet
// ---------------------------------------------------------------------------

class _ThresholdPickerSheet extends StatefulWidget {
  final double initialThreshold;
  const _ThresholdPickerSheet({required this.initialThreshold});

  @override
  State<_ThresholdPickerSheet> createState() => _ThresholdPickerSheetState();
}

class _ThresholdPickerSheetState extends State<_ThresholdPickerSheet> {
  final _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _sub;
  String? _tempPath;

  // Fixed hardware range: -80 dBFS (silence) … 0 dBFS (clipping ceiling)
  static const double _minDb = -80.0;
  static const double _maxDb = 0.0;
  static const double _rangeDb = _maxDb - _minDb; // 80

  double _currentDbfs = -60.0;

  // Screen fraction [0 = bottom / -80 dBFS, 1 = top / 0 dBFS].
  // Only changes on user drag.
  late double _thresholdFraction;

  double get _thresholdDbfs => _minDb + _thresholdFraction * _rangeDb;

  bool _showTooltip = false;
  Timer? _tooltipTimer;

  @override
  void initState() {
    super.initState();
    _thresholdFraction =
        ((widget.initialThreshold.clamp(_minDb, _maxDb) - _minDb) / _rangeDb)
            .clamp(0.0, 1.0);
    _startListening();
  }

  Future<void> _startListening() async {
    try {
      final dir = await getTemporaryDirectory();
      _tempPath =
          '${dir.path}/thresh_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(
            encoder: AudioEncoder.wav, numChannels: 1, sampleRate: 44100),
        path: _tempPath!,
      );
      _sub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 50))
          .listen((amp) {
        if (!mounted) return;
        setState(() => _currentDbfs = amp.current.clamp(_minDb, _maxDb));
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    _sub?.cancel();
    _recorder.stop().then((_) {
      if (_tempPath != null) {
        try { File(_tempPath!).deleteSync(); } catch (_) {}
      }
      _recorder.dispose();
    });
    super.dispose();
  }

  double _dbfsToFraction(double dbfs) =>
      ((dbfs - _minDb) / _rangeDb).clamp(0.0, 1.0);

  void _handleTouch(double localY, double height) =>
      setState(() =>
          _thresholdFraction = (1.0 - localY / height).clamp(0.0, 1.0));

  void _onDragStart(DragStartDetails _) =>
      setState(() { _tooltipTimer?.cancel(); _showTooltip = true; });

  void _onDragEnd(DragEndDetails _) =>
      setState(() => _showTooltip = false);

  void _onTapDown(TapDownDetails d, double height) {
    _handleTouch(d.localPosition.dy, height);
    _tooltipTimer?.cancel();
    setState(() => _showTooltip = true);
    _tooltipTimer = Timer(const Duration(milliseconds: 1500),
        () { if (mounted) setState(() => _showTooltip = false); });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text('Поріг детекції пострілу',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Перетягніть лінію вище рівня фонового шуму',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // VU meter
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final h = constraints.maxHeight;
                  final w = constraints.maxWidth;

                  return GestureDetector(
                    onVerticalDragStart: _onDragStart,
                    onVerticalDragUpdate: (d) =>
                        _handleTouch(d.localPosition.dy, h),
                    onVerticalDragEnd: _onDragEnd,
                    onTapDown: (d) => _onTapDown(d, h),
                    child: Stack(
                      children: [
                        CustomPaint(
                          painter: _VuMeterPainter(
                            levelFraction: _dbfsToFraction(_currentDbfs),
                            thresholdFraction: _thresholdFraction,
                            aboveThreshold: _currentDbfs >= _thresholdDbfs,
                          ),
                          size: Size(w, h),
                        ),
                        IgnorePointer(child: _DbLabels(totalHeight: h)),
                        if (_showTooltip)
                          for (final side in [_TooltipSide.left, _TooltipSide.right])
                            Positioned(
                              top: (h * (1.0 - _thresholdFraction) - 16)
                                  .clamp(0, h - 32),
                              left: side == _TooltipSide.left ? 12 : null,
                              right: side == _TooltipSide.right ? 12 : null,
                              child: IgnorePointer(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_thresholdDbfs.toStringAsFixed(0)} dBFS',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Row(
              children: [
                Text(
                  'Поріг: ${_thresholdDbfs.toStringAsFixed(0)} dBFS',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_thresholdDbfs),
                  child: const Text('Зберегти'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _TooltipSide { left, right }

// ---------------------------------------------------------------------------
// dB axis labels — fixed -80…0, every 10 dB
// ---------------------------------------------------------------------------

class _DbLabels extends StatelessWidget {
  final double totalHeight;
  const _DbLabels({required this.totalHeight});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: totalHeight,
      child: Stack(
        children: [
          for (int db = -80; db <= 0; db += 10)
            Positioned(
              top: totalHeight * (1.0 - (db + 80) / 80) - 8,
              left: 6,
              child: Text(
                '$db',
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey, height: 1),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VU meter painter — fixed -80…0 range
// ---------------------------------------------------------------------------

class _VuMeterPainter extends CustomPainter {
  final double levelFraction;      // 0 = -80 dBFS, 1 = 0 dBFS
  final double thresholdFraction;
  final bool aboveThreshold;

  const _VuMeterPainter({
    required this.levelFraction,
    required this.thresholdFraction,
    required this.aboveThreshold,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, w, h), const Radius.circular(8)),
      Paint()..color = const Color(0xFF1A1A2E),
    );

    // Grid lines every 10 dB (= every 1/8 of height)
    final gridPaint = Paint()..color = Colors.white12..strokeWidth = 1;
    for (int db = -80; db <= 0; db += 10) {
      final y = h * (1.0 - (db + 80) / 80);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Level bar (from bottom up)
    final barH = levelFraction * h;
    if (barH > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, h - barH, w, barH),
          const Radius.circular(4),
        ),
        Paint()
          ..color = (aboveThreshold ? Colors.redAccent : Colors.greenAccent)
              .withValues(alpha: 0.85),
      );
    }

    // Threshold line (dashed)
    final threshY = h * (1.0 - thresholdFraction);
    final threshPaint = Paint()..color = Colors.orange..strokeWidth = 2;
    const dash = 10.0;
    const gap = 5.0;
    double x = 0;
    while (x < w) {
      canvas.drawLine(
        Offset(x, threshY),
        Offset(math.min(x + dash, w), threshY),
        threshPaint,
      );
      x += dash + gap;
    }

    // Drag handle touch zone (semi-transparent band)
    canvas.drawRect(
      Rect.fromLTWH(0, threshY - 24, w, 48),
      Paint()..color = Colors.orange.withValues(alpha: 0.10),
    );
    // Drag handle circle
    canvas.drawCircle(Offset(w / 2, threshY), 12,
        Paint()..color = Colors.orange);
    canvas.drawCircle(
      Offset(w / 2, threshY),
      12,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_VuMeterPainter old) =>
      old.levelFraction != levelFraction ||
      old.thresholdFraction != thresholdFraction ||
      old.aboveThreshold != aboveThreshold;
}
