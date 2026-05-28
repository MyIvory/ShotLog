import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Background image with accelerometer-driven parallax effect.
/// Uses ClipRect + Transform.translate so the effect works regardless
/// of image aspect ratio. Transform.scale(1.12) provides a 6% buffer
/// on each side to prevent edge reveal at maximum tilt.
class ParallaxBg extends StatefulWidget {
  final String asset;
  final BoxFit fit;
  final Alignment baseAlignment;

  const ParallaxBg({
    super.key,
    required this.asset,
    this.fit = BoxFit.cover,
    this.baseAlignment = Alignment.topCenter,
  });

  @override
  State<ParallaxBg> createState() => _ParallaxBgState();
}

class _ParallaxBgState extends State<ParallaxBg> {
  // Low-pass smoothing factor (higher = smoother / slower)
  static const _alpha = 0.88;
  // Max translation in logical pixels
  static const _shift = 18.0;

  double _ax = 0; // normalized horizontal tilt [-1..1]
  double _ay = 0; // normalized vertical tilt [-1..1]

  StreamSubscription<AccelerometerEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onAccelerometer);
  }

  void _onAccelerometer(AccelerometerEvent e) {
    if (!mounted) return;
    setState(() {
      // e.x: left/right tilt (−9.8..9.8). Negate → tilt right shifts image right.
      // e.y − 9.8: deviation from upright; forward tilt shifts image up.
      _ax = _ax * _alpha + (-e.x / 9.8) * (1 - _alpha);
      _ay = _ay * _alpha + ((e.y - 9.8) / 5.0) * (1 - _alpha);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dx = (_ax * _shift).clamp(-_shift, _shift);
    final dy = (_ay * _shift).clamp(-_shift, _shift);

    return ClipRect(
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.scale(
          scale: 1.12,
          child: Image.asset(
            widget.asset,
            fit: widget.fit,
            alignment: widget.baseAlignment,
          ),
        ),
      ),
    );
  }
}
