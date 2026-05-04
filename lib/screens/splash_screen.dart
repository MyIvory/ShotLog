import 'package:flutter/material.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Two expanding "sonar ping" rings
  late final Animation<double> _ping1Scale, _ping1Opacity;
  late final Animation<double> _ping2Scale, _ping2Opacity;

  // Main reticle — scales in from 0.82 with a slight spring
  late final Animation<double> _reticleScale, _reticleOpacity;

  // Wordmark slides up and fades in
  late final Animation<double> _wordmarkY, _wordmarkOpacity;

  // Global fade-out at the end
  late final Animation<double> _masterOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2700),
    );

    // Helper to reduce boilerplate
    Animation<double> anim(double b, double e, double i0, double i1, Curve c) =>
        Tween<double>(begin: b, end: e).animate(
          CurvedAnimation(parent: _ctrl, curve: Interval(i0, i1, curve: c)));

    _ping1Scale   = anim(0.50, 1.90, 0.00, 0.32, Curves.easeOut);
    _ping1Opacity = anim(0.70, 0.00, 0.00, 0.32, Curves.easeOut);

    _ping2Scale   = anim(0.40, 1.60, 0.07, 0.38, Curves.easeOut);
    _ping2Opacity = anim(0.50, 0.00, 0.07, 0.38, Curves.easeOut);

    _reticleScale   = anim(0.80, 1.00, 0.14, 0.46, Curves.easeOutCubic);
    _reticleOpacity = anim(0.00, 1.00, 0.14, 0.36, Curves.easeOut);

    _wordmarkY       = anim(28.00, 0.00, 0.28, 0.56, Curves.easeOutCubic);
    _wordmarkOpacity = anim(0.00,  1.00, 0.28, 0.52, Curves.easeOut);

    _masterOpacity = anim(1.00, 0.00, 0.74, 1.00, Curves.easeIn);

    _ctrl.forward();
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _navigate();
    });
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const OnboardingScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1210),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Opacity(
          opacity: _masterOpacity.value,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Ping ring 1 ────────────────────────────────────────────
              Transform.scale(
                scale: _ping1Scale.value,
                child: Opacity(
                  opacity: _ping1Opacity.value,
                  child: const _PingRing(size: 200),
                ),
              ),
              // ── Ping ring 2 (slightly smaller, offset timing) ──────────
              Transform.scale(
                scale: _ping2Scale.value,
                child: Opacity(
                  opacity: _ping2Opacity.value,
                  child: const _PingRing(size: 160),
                ),
              ),
              // ── Reticle ────────────────────────────────────────────────
              Transform.scale(
                scale: _reticleScale.value,
                child: Opacity(
                  opacity: _reticleOpacity.value,
                  child: const CustomPaint(
                    size: Size(190, 190),
                    painter: _ReticlePainter(),
                  ),
                ),
              ),
              // ── Wordmark ───────────────────────────────────────────────
              Align(
                alignment: const Alignment(0, 0.40),
                child: Transform.translate(
                  offset: Offset(0, _wordmarkY.value),
                  child: Opacity(
                    opacity: _wordmarkOpacity.value,
                    child: const _Wordmark(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _PingRing extends StatelessWidget {
  final double size;
  const _PingRing({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE87722), width: 1.5),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SHOTLOG',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF0EAE5),
            letterSpacing: 6.0,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'SESSION TRACKER',
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFF5A5040),
            letterSpacing: 4.0,
          ),
        ),
      ],
    );
  }
}

// ── Reticle painter (splash proportions) ────────────────────────────────────

class _ReticlePainter extends CustomPainter {
  const _ReticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // Scale factor: design reference 180px = r72 outer, r45 inner
    final s = size.width / 180.0;

    final outerR  = 72.0 * s;
    final innerR  = 45.0 * s;
    final armNear = 50.0 * s; // arm starts here from center
    final armFar  = 72.0 * s; // arm ends here (= outerR)

    final paint = Paint()..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;

    // Outer ring
    paint
      ..color = const Color(0xFFE87722)
      ..strokeWidth = 5 * s;
    canvas.drawCircle(Offset(cx, cy), outerR, paint);

    // Inner ring (50% opacity)
    paint
      ..color = const Color(0xFFE87722).withValues(alpha: 0.5)
      ..strokeWidth = 3 * s;
    canvas.drawCircle(Offset(cx, cy), innerR, paint);

    // Crosshair arms
    paint
      ..color = const Color(0xFFE87722)
      ..strokeWidth = 5 * s;
    canvas.drawLine(Offset(cx, cy - armFar), Offset(cx, cy - armNear), paint);
    canvas.drawLine(Offset(cx, cy + armNear), Offset(cx, cy + armFar), paint);
    canvas.drawLine(Offset(cx - armFar, cy), Offset(cx - armNear, cy), paint);
    canvas.drawLine(Offset(cx + armNear, cy), Offset(cx + armFar, cy), paint);

    // Play triangle: offsets from SVG center = (-16,-18), (-16,+18), (+20, 0)
    final tp = Path()
      ..moveTo(cx - 16 * s, cy - 18 * s)
      ..lineTo(cx - 16 * s, cy + 18 * s)
      ..lineTo(cx + 20 * s, cy)
      ..close();
    canvas.drawPath(tp, Paint()..color = Colors.white..style = PaintingStyle.fill);

    // REC dot: offset from center = (+54, -54), r=13, inner r=5.5
    final dotOff = Offset(cx + 54 * s, cy - 54 * s);
    canvas.drawCircle(dotOff, 13 * s, Paint()..color = const Color(0xFFE87722));
    canvas.drawCircle(dotOff, 5.5 * s, Paint()..color = const Color(0xFF1A1210));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
