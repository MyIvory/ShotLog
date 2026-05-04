import 'package:flutter/material.dart';
import 'main_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  static const _pages = [
    _PageData(
      tag: 'КОНЦЕПЦІЯ',
      title: 'Телефон на трубі —\nавтозапис кожного пострілу.',
      body: 'ShotLog кріпиться на зрительну трубу і\nпише відеокліп на кожен постріл.',
      badgeTitle: 'Без хмари',
      badgeBody: 'Дані не покидають телефон',
    ),
    _PageData(
      tag: 'ДИСТАНЦІЙНИЙ СТАРТ',
      title: 'BT-кнопка запускає\nцикл запису з позиції.',
      body: 'Натиснув кнопку — пішов таймер.\nТривалість налаштовується під твій ритм.',
      badgeTitle: 'Bluetooth',
      badgeBody: 'Сумісна будь-яка BT-кнопка',
    ),
    _PageData(
      tag: 'ЦИКЛ ЗАПИСУ',
      title: 'Pre-roll, постріл, post-roll —\nодин чіткий кліп.',
      body: 'Після збереження — чекає наступного\nтригера. Серія без вставання.',
      badgeTitle: 'Серія',
      badgeBody: 'Скільки пострілів — стільки кліпів',
    ),
    _PageData(
      tag: 'ДОЗВОЛИ',
      title: 'Камера, мікрофон і\nBluetooth — більше нічого.',
      body: 'ShotLog запитує лише три системні дозволи.\nДоступ до геолокації не потрібен.',
      badgeTitle: 'Приватність',
      badgeBody: 'Нульовий мережевий трафік',
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1210),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Page content ─────────────────────────────────────────────
            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageCtrl,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _PageContent(data: _pages[i], index: i),
                  ),
                ),
                // ── Bottom controls ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: isLast
                      ? Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed: _finish,
                                child: const Text(
                                  'Надати доступ і почати',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _DotIndicator(count: _pages.length, current: _page),
                          ],
                        )
                      : Row(
                          children: [
                            _DotIndicator(count: _pages.length, current: _page),
                            const Spacer(),
                            SizedBox(
                              height: 40,
                              child: FilledButton(
                                onPressed: _next,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 28),
                                ),
                                child: const Text(
                                  'Далі',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
            // ── Skip button (slides 1–3) ──────────────────────────────
            if (!isLast)
              Positioned(
                top: 4,
                right: 8,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text(
                    'Пропустити',
                    style: TextStyle(color: Color(0xFF5A5040), fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────

class _PageData {
  final String tag, title, body, badgeTitle, badgeBody;
  const _PageData({
    required this.tag,
    required this.title,
    required this.body,
    required this.badgeTitle,
    required this.badgeBody,
  });
}

// ── Page content ──────────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final _PageData data;
  final int index;
  const _PageContent({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration
          Expanded(
            flex: 5,
            child: Center(child: _illustration()),
          ),
          // Category tag
          Text(
            data.tag,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFFE87722),
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // Title
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFFF0EAE5),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          // Body
          Text(
            data.body,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7A6A58),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // Info badge
          _InfoBadge(title: data.badgeTitle, body: data.badgeBody),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _illustration() {
    switch (index) {
      case 0: return const _Slide1Reticle();
      case 1: return const _Slide2Bt();
      case 2: return const _Slide3Cycle();
      case 3: return const _Slide4Permissions();
      default: return const SizedBox.shrink();
    }
  }
}

// ── Info badge ─────────────────────────────────────────────────────────────────

class _InfoBadge extends StatelessWidget {
  final String title, body;
  const _InfoBadge({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF201810),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A2E1A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.bolt, color: Color(0xFFC09060), size: 14),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC09060))),
              const SizedBox(height: 2),
              Text(body,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF7A6A58))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Dot indicator ─────────────────────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  final int count, current;
  const _DotIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(right: 6),
          width: i == current ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: i == current
                ? const Color(0xFFE87722)
                : const Color(0xFF2E2018),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Illustrations
// ════════════════════════════════════════════════════════════════════════════

// ── Slide 1: Reticle (CustomPainter) ──────────────────────────────────────

class _Slide1Reticle extends StatelessWidget {
  const _Slide1Reticle();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      size: Size(180, 180),
      painter: _ObReticlePainter(),
    );
  }
}

class _ObReticlePainter extends CustomPainter {
  const _ObReticlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // OB slide 1: outer r=68, inner r=42 (relative to 220px half-width = 110)
    final s = size.width / 180.0;
    final outerR = 68.0 * s;
    final innerR = 42.0 * s;

    final paint = Paint()..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;

    paint.color = const Color(0xFFE87722);
    paint.strokeWidth = 4 * s;
    canvas.drawCircle(Offset(cx, cy), outerR, paint);

    paint.color = const Color(0xFFE87722).withValues(alpha: 0.45);
    paint.strokeWidth = 2.5 * s;
    canvas.drawCircle(Offset(cx, cy), innerR, paint);

    paint.color = const Color(0xFFE87722);
    paint.strokeWidth = 4 * s;

    // Arms: from (inner+4) to outer from center
    // SVG: top y1=62(cy-68), y2=84(cy-46) → near=46, far=68
    final armNear = 46.0 * s;
    final armFar  = 68.0 * s;
    canvas.drawLine(Offset(cx, cy - armFar), Offset(cx, cy - armNear), paint);
    canvas.drawLine(Offset(cx, cy + armNear), Offset(cx, cy + armFar), paint);
    canvas.drawLine(Offset(cx - armFar, cy), Offset(cx - armNear, cy), paint);
    canvas.drawLine(Offset(cx + armNear, cy), Offset(cx + armFar, cy), paint);

    // Play triangle: offsets (-14,-16), (-14,+16), (+18, 0)
    final tp = Path()
      ..moveTo(cx - 14 * s, cy - 16 * s)
      ..lineTo(cx - 14 * s, cy + 16 * s)
      ..lineTo(cx + 18 * s, cy)
      ..close();
    canvas.drawPath(tp, Paint()..color = Colors.white..style = PaintingStyle.fill);

    // REC dot: offset (+50, -54), r=12, inner r=5.5
    final dotOff = Offset(cx + 50 * s, cy - 54 * s);
    canvas.drawCircle(dotOff, 12 * s, Paint()..color = const Color(0xFFE87722));
    canvas.drawCircle(dotOff, 5.5 * s, Paint()..color = const Color(0xFF1A1210));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Slide 2: BT Remote + flow diagram ────────────────────────────────────

class _Slide2Bt extends StatelessWidget {
  const _Slide2Bt();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // BT remote body
        Container(
          width: 64, height: 94,
          decoration: BoxDecoration(
            color: const Color(0xFF201810),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFF3A2E1A), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40, height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFE87722), width: 1.5),
                ),
                child: const Center(
                  child: Text('BT',
                      style: TextStyle(
                          color: Color(0xFFE87722),
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2A1E14),
                  border: Border.all(
                      color: const Color(0xFFE87722), width: 1.2),
                ),
              ),
            ],
          ),
        ),
        // Dashed connector
        const _DashedLine(),
        // Flow steps
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: const [
            _FlowStep(label: 'таймер', active: false),
            _FlowArrow(),
            _FlowStep(label: 'слухає', active: true),
            _FlowArrow(),
            _FlowStep(label: 'постріл', active: false),
            _FlowArrow(),
            _FlowStep(label: 'кліп', active: false, dim: true),
          ],
        ),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1.5, height: 18,
      child: CustomPaint(painter: _DashPainter()),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3A3020)
      ..strokeWidth = 1.5;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, (y + 3).clamp(0, size.height)), paint);
      y += 6;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _FlowStep extends StatelessWidget {
  final String label;
  final bool active;
  final bool dim;
  const _FlowStep({required this.label, required this.active, this.dim = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF3A2010) : const Color(0xFF2A3818).withValues(alpha: dim ? 0.5 : 1.0),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: active ? const Color(0xFFE87722) : const Color(0xFF3A5020).withValues(alpha: dim ? 0.5 : 1.0),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: active
              ? const Color(0xFFE87722)
              : const Color(0xFF7A9A50).withValues(alpha: dim ? 0.5 : 1.0),
        ),
      ),
    );
  }
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Icon(Icons.chevron_right, color: Color(0xFF3A3020), size: 14),
    );
  }
}

// ── Slide 3: Recording cycle diagram ─────────────────────────────────────

class _Slide3Cycle extends StatelessWidget {
  const _Slide3Cycle();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'ОДИН ЦИКЛ',
          style: TextStyle(
            fontSize: 8, color: Color(0xFF4A4038), letterSpacing: 3),
        ),
        const SizedBox(height: 10),
        // Timeline row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _CycleBox(label: 'pre-roll',
                bg: const Color(0xFF243018),
                border: const Color(0xFF3A5020)),
            // Shot box — wider, orange
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1808),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE87722), width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE87722).withValues(alpha: 0.15),
                    ),
                    child: const Center(
                      child: CircleAvatar(
                          radius: 5, backgroundColor: Color(0xFFE87722)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('ПОСТРІЛ',
                      style: TextStyle(
                          fontSize: 7,
                          color: Color(0xFFE87722),
                          letterSpacing: 1)),
                ],
              ),
            ),
            _CycleBox(label: 'post-roll',
                bg: const Color(0xFF243018),
                border: const Color(0xFF3A5020)),
          ],
        ),
        // Arrow down
        const Icon(Icons.keyboard_arrow_down, color: Color(0xFFE87722), size: 22),
        // Mini clip preview
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF201810),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF3A2E1A), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow, color: Color(0xFFE87722), size: 14),
              const SizedBox(width: 6),
              SizedBox(
                width: 60, height: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1.5),
                  child: Row(
                    children: [
                      Expanded(flex: 2,
                          child: Container(color: const Color(0xFFE87722))),
                      Expanded(flex: 3,
                          child: Container(color: const Color(0xFF3A2E1A))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CycleBox extends StatelessWidget {
  final String label;
  final Color bg, border;
  const _CycleBox({required this.label, required this.bg, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF7A9A50))),
    );
  }
}

// ── Slide 4: Permissions ──────────────────────────────────────────────────

class _Slide4Permissions extends StatelessWidget {
  const _Slide4Permissions();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Small reticle at top
        CustomPaint(
          size: const Size(68, 68),
          painter: _SmallReticlePainter(),
        ),
        const SizedBox(height: 20),
        // 3 permission boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PermBox(
              icon: Icons.camera_alt_outlined,
              label: 'Камера',
              sub: '+ Мікрофон',
              iconColor: const Color(0xFFE87722),
              borderColor: const Color(0xFFE87722),
            ),
            const SizedBox(width: 10),
            _PermBox(
              icon: Icons.bluetooth,
              label: 'Bluetooth',
              sub: 'для кнопки',
              iconColor: const Color(0xFF4A9EE0),
              borderColor: const Color(0xFF4A7AAA),
            ),
            const SizedBox(width: 10),
            _PermBoxDisabled(),
          ],
        ),
      ],
    );
  }
}

class _PermBox extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color iconColor, borderColor;

  const _PermBox({
    required this.icon,
    required this.label,
    required this.sub,
    required this.iconColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72, height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF201810),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFFC09060),
                  fontWeight: FontWeight.w500)),
          Text(sub,
              style: const TextStyle(
                  fontSize: 8, color: Color(0xFF5A5040))),
        ],
      ),
    );
  }
}

class _PermBoxDisabled extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 72, height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFF201810),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF3A2E1A), width: 1.2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1210),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: const Color(0xFF4A4038)),
                ),
              ),
              const SizedBox(height: 5),
              const Text('Геолокація',
                  style: TextStyle(fontSize: 8, color: Color(0xFF4A4038))),
            ],
          ),
        ),
        // Cross overlay
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CustomPaint(painter: _CrossPainter()),
          ),
        ),
      ],
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6A2020)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(4, 4), Offset(size.width - 4, size.height - 4), paint);
    canvas.drawLine(Offset(size.width - 4, 4), Offset(4, size.height - 4), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// Small reticle for slide 4 top ───────────────────────────────────────────

class _SmallReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = size.width / 68.0;

    final outerR = 34.0 * s;
    final innerR = 20.0 * s;

    final paint = Paint()..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;

    paint
      ..color = const Color(0xFFE87722)
      ..strokeWidth = 2 * s;
    canvas.drawCircle(Offset(cx, cy), outerR, paint);

    paint
      ..color = const Color(0xFFE87722).withValues(alpha: 0.5)
      ..strokeWidth = 1.5 * s;
    canvas.drawCircle(Offset(cx, cy), innerR, paint);

    paint
      ..color = const Color(0xFFE87722)
      ..strokeWidth = 2 * s;

    final near = 22.0 * s;
    final far  = 34.0 * s;
    canvas.drawLine(Offset(cx, cy - far), Offset(cx, cy - near), paint);
    canvas.drawLine(Offset(cx, cy + near), Offset(cx, cy + far), paint);
    canvas.drawLine(Offset(cx - far, cy), Offset(cx - near, cy), paint);
    canvas.drawLine(Offset(cx + near, cy), Offset(cx + far, cy), paint);

    canvas.drawCircle(Offset(cx, cy), 7 * s, Paint()..color = const Color(0xFFE87722));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
