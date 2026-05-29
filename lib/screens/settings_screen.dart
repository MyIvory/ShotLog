import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/physical_camera_service.dart';
import '../services/settings_service.dart';
import '../widgets/parallax_bg.dart';
import '../widgets/threshold_picker.dart';
import 'equipment_screen.dart';

// ── Color constants ───────────────────────────────────────────────────────────

const _kAccent    = Color(0xFFE87722);
const _kBlue      = Color(0xFF5A8FB8);
const _kText      = Color(0xFFF0EAE5);
const _kHint      = Color(0x73F0EAE5);   // 45 %
const _kLabel     = Color(0x99F0EAE5);   // 60 % — section labels
const _kBadgeIcon = Color(0xFFF0EAE5);   // icon badge icons
const _kSurface   = Color(0x26FFFFFF);
const _kBorder    = Color(0x28FFFFFF);
const _kDiv       = Color(0x1EFFFFFF);
const _kBadgeBdr  = Color(0x33FFFFFF);   // 1px badge border

const _kBgAmber   = Color(0xCCB05010);
const _kBgBlue    = Color(0xCC2A5F88);

// ── Screen ────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _svc = SettingsService();
  AppSettings _s = const AppSettings();
  bool _loading = true;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _svc.load().then((s) => setState(() {
          _s = s;
          _loading = false;
        }));
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  void _onChange(AppSettings v) {
    setState(() => _s = v);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(milliseconds: 600),
      () => _svc.save(_s),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF130E0C),
        body: Center(child: CircularProgressIndicator(color: _kAccent)),
      );
    }

    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const _PhotoBg(),
          // ── List (full screen, scrolls under header) ──
          ListView(
            padding: EdgeInsets.fromLTRB(16, top + 76 + 8, 16, 16),
                    children: [

                      // ── До пострілу ───────────────────────────────
                      const _SectionLabel('До пострілу'),
                      _GlassCard(children: [
                        _SliderRow(
                          label: 'Відлік перед записом',
                          hint: 'Час до початку запису',
                          value: _s.countdownSec,
                          min: 1, max: 10, unit: 'с',
                          icon: Icons.access_time_outlined,
                          iconBg: _kBgAmber,
                          gradColors: const [Color(0xFFFFB347), _kAccent],
                          onChanged: (v) => _onChange(_s.copyWith(countdownSec: v)),
                        ),
                        _SliderRow(
                          label: 'Запис до пострілу',
                          hint: 'Час кліпу до пострілу',
                          value: _s.preRollSec,
                          min: 0, max: 5, unit: 'с',
                          icon: Icons.fast_rewind_outlined,
                          iconBg: _kBgBlue,
                          gradColors: const [Color(0xFF3A6F98), _kBlue],
                          onChanged: (v) => _onChange(_s.copyWith(preRollSec: v)),
                        ),
                      ]),

                      // ── Після пострілу ────────────────────────────
                      const _SectionLabel('Після пострілу'),
                      _GlassCard(children: [
                        _SliderRow(
                          label: 'Таймаут без пострілу',
                          hint: 'Скасування запису',
                          value: _s.timeoutSec,
                          min: 10, max: 60, unit: 'с',
                          icon: Icons.timer_off_outlined,
                          iconBg: _kBgAmber,
                          gradColors: const [Color(0xFFFFB347), _kAccent],
                          onChanged: (v) => _onChange(_s.copyWith(timeoutSec: v)),
                        ),
                        _SliderRow(
                          label: 'Запис після пострілу',
                          hint: 'Час кліпу після пострілу',
                          value: _s.postRollSec,
                          min: 1, max: 10, unit: 'с',
                          icon: Icons.fast_forward_outlined,
                          iconBg: _kBgBlue,
                          gradColors: const [Color(0xFF3A6F98), _kBlue],
                          onChanged: (v) => _onChange(_s.copyWith(postRollSec: v)),
                        ),
                      ]),

                      // ── Активація ─────────────────────────────────
                      const _SectionLabel('Активація'),
                      _GlassCard(children: [
                        _TriggerRow(
                          value: _s.triggerMode,
                          onChanged: (v) => _onChange(_s.copyWith(triggerMode: v)),
                        ),
                        _GlassRow(
                          icon: const _IconBadge(
                              Icons.graphic_eq, _kBgBlue),
                          label: 'Поріг гучності',
                          hint: 'Натисніть для налаштування',
                          value: '${_s.detectionDbfs.toStringAsFixed(0)} dBFS',
                          onTap: () async {
                            final r = await showThresholdPicker(
                                context, _s.detectionDbfs);
                            if (r != null) _onChange(_s.copyWith(detectionDbfs: r));
                          },
                        ),
                      ]),

                      // ── Камера ─────────────────────────────────────
                      const _SectionLabel('Камера'),
                      _GlassCard(children: [
                        _CameraGlassRow(
                          selectedId: _s.selectedCameraId,
                          zoomMin: _s.cameraZoomMin,
                          zoomMax: _s.cameraZoomMax,
                          onChanged: (id, zMin, zMax) => _onChange(_s.copyWith(
                            selectedCameraId: id,
                            cameraZoomMin: zMin,
                            cameraZoomMax: zMax,
                          )),
                        ),
                      ]),

                      // ── Спорядження ────────────────────────────────
                      const _SectionLabel('Спорядження'),
                      _GlassCard(children: [
                        _GlassRow(
                          icon: const _IconBadge(
                              Icons.inventory_2_outlined, _kBgAmber),
                          label: 'Гвинтівки та набої',
                          hint: 'Керування спорядженням',
                          onTap: () => showEquipmentSheet(context),
                        ),
                      ]),
            ],
          ),
          // ── Glass header (floats on top) ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.transparent,
                  child: Column(
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
                                  Text(
                                    'Налаштування',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: _kText,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Зміни зберігаються автоматично',
                                    style: TextStyle(fontSize: 12, color: _kHint),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0x1AFFFFFF),
                                  border: Border.all(
                                      color: const Color(0x1EFFFFFF), width: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(Icons.west, color: _kText, size: 18),
                                ),
                              ),
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

// ── Photo background ──────────────────────────────────────────────────────────

class _PhotoBg extends StatelessWidget {
  const _PhotoBg();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ParallaxBg(
            asset: 'assets/images/bg_rifle.webp',
            baseAlignment: Alignment(0.2, -1.0),
          ),
          // Flat dark overlay
          Container(color: const Color(0xB8120E0C)),
          // Gradient: clear at top → nearly opaque at bottom
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xE60C0A08)],
                stops: [0.25, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6, left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: _kLabel,
        ),
      ),
    );
  }
}

// ── Glass card ────────────────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final List<Widget> children;
  const _GlassCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0)
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: _kDiv,
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

// ── Icon badge ────────────────────────────────────────────────────────────────

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color bg;
  const _IconBadge(this.icon, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBadgeBdr, width: 1),
      ),
      child: Icon(icon, color: _kBadgeIcon, size: 17),
    );
  }
}

// ── Glass row ─────────────────────────────────────────────────────────────────

class _GlassRow extends StatelessWidget {
  final Widget icon;
  final String label;
  final String? hint;
  final String? value;
  final VoidCallback? onTap;
  const _GlassRow({
    required this.icon,
    required this.label,
    this.hint,
    this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _kText)),
                  if (hint != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(hint!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: _kHint)),
                    ),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Text(value!,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kText)),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: Color(0x4DF0EAE5), size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Slider row ────────────────────────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  final String label;
  final String hint;
  final int value;
  final int min, max;
  final String unit;
  final IconData icon;
  final Color iconBg;
  final List<Color> gradColors;
  final ValueChanged<int> onChanged;

  const _SliderRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.icon,
    required this.iconBg,
    required this.gradColors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              _IconBadge(icon, iconBg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _kText)),
                    Text(hint,
                        style: const TextStyle(
                            fontSize: 13, color: _kHint)),
                  ],
                ),
              ),
              Text(
                '$value $unit',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kText),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _GradientSlider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            colors: gradColors,
            onChanged: (v) => onChanged(v.round()),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$min $unit',
                  style: const TextStyle(
                      fontSize: 10, color: _kHint)),
              Text('$max $unit',
                  style: const TextStyle(
                      fontSize: 10, color: _kHint)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Gradient slider ───────────────────────────────────────────────────────────

class _GradientSlider extends StatelessWidget {
  final double value, min, max;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  const _GradientSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final w = constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) {
          final f = (d.localPosition.dx / w).clamp(0.0, 1.0);
          onChanged(min + f * (max - min));
        },
        onTapDown: (d) {
          final f = (d.localPosition.dx / w).clamp(0.0, 1.0);
          onChanged(min + f * (max - min));
        },
        child: SizedBox(
          height: 44,
          width: w,
          child: CustomPaint(
            painter: _SliderPainter(
              frac: max > min
                  ? ((value - min) / (max - min)).clamp(0.0, 1.0)
                  : 0.0,
              colors: colors,
            ),
          ),
        ),
      );
    });
  }
}

class _SliderPainter extends CustomPainter {
  final double frac;
  final List<Color> colors;
  const _SliderPainter({required this.frac, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const trackH = 6.0;
    const r = Radius.circular(2);

    canvas.drawRRect(
      RRect.fromLTRBR(0, cy - trackH / 2, size.width, cy + trackH / 2, r),
      Paint()..color = const Color(0x1AFFFFFF),
    );

    final fillW = size.width * frac;
    if (fillW > 0) {
      final fillRect =
          Rect.fromLTRB(0, cy - trackH / 2, fillW, cy + trackH / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(fillRect, r),
        Paint()
          ..shader = LinearGradient(colors: colors)
              .createShader(Rect.fromLTWH(0, 0, size.width, trackH)),
      );
    }

    // Clamp thumb so it never clips at edges
    final tx = (size.width * frac).clamp(9.0, size.width - 9.0);

    canvas.drawCircle(
        Offset(tx, cy), 13, Paint()..color = colors.last.withValues(alpha: 0.22));
    canvas.drawCircle(Offset(tx, cy), 9, Paint()..color = colors.last);
    canvas.drawCircle(
      Offset(tx, cy),
      6.5,
      Paint()
        ..color = const Color(0xFF1A1210)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SliderPainter old) =>
      old.frac != frac || old.colors != colors;
}

// ── Trigger row ───────────────────────────────────────────────────────────────

class _TriggerRow extends StatelessWidget {
  final TriggerMode value;
  final ValueChanged<TriggerMode> onChanged;
  const _TriggerRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(Icons.settings_input_component, _kBgAmber),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Режим тригера',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _kText)),
                  SizedBox(height: 2),
                  Text('Спосіб запуску відліку',
                      style: TextStyle(fontSize: 13, color: _kHint)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x26FFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _SegBtn(
                      label: 'Кнопка',
                      icon: Icons.touch_app_outlined,
                      active: value == TriggerMode.button,
                      onTap: () => onChanged(TriggerMode.button),
                      radius: const BorderRadius.only(
                        topLeft: Radius.circular(11),
                        bottomLeft: Radius.circular(11),
                      ),
                    ),
                    Container(width: 0.5, color: const Color(0x33FFFFFF)),
                    _SegBtn(
                      label: 'Bluetooth',
                      icon: Icons.bluetooth,
                      active: value == TriggerMode.bluetooth,
                      onTap: () => onChanged(TriggerMode.bluetooth),
                      radius: const BorderRadius.only(
                        topRight: Radius.circular(11),
                        bottomRight: Radius.circular(11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final BorderRadius radius;
  const _SegBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xCCB05010) : Colors.transparent,
            borderRadius: radius,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: _kText),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: _kText,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Camera glass row ──────────────────────────────────────────────────────────

typedef _CameraSelectedCallback = void Function(
    String id, double zoomMin, double zoomMax);

class _CameraGlassRow extends StatelessWidget {
  final String selectedId;
  final double zoomMin, zoomMax;
  final _CameraSelectedCallback onChanged;

  const _CameraGlassRow({
    required this.selectedId,
    required this.zoomMin,
    required this.zoomMax,
    required this.onChanged,
  });

  String _zl(double z) =>
      z == z.roundToDouble() ? '${z.toInt()}×' : '${z.toStringAsFixed(1)}×';

  Future<void> _showPicker(BuildContext context) async {
    final result = await Navigator.push<(String, double, double)?>(
      context,
      MaterialPageRoute(
        builder: (_) => _CameraPickerSheet(selectedId: selectedId),
      ),
    );
    if (result != null) {
      onChanged(result.$1, result.$2, result.$3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hint = selectedId.isEmpty
        ? 'Автоматично — повний діапазон зуму'
        : (zoomMin > 0 && zoomMax > 0)
            ? 'ID: $selectedId · ${_zl(zoomMin)} – ${_zl(zoomMax)}'
            : 'ID: $selectedId';

    return _GlassRow(
      icon: const _IconBadge(Icons.camera_alt_outlined, _kBgBlue),
      label: 'Камера для запису',
      hint: hint,
      onTap: () => _showPicker(context),
    );
  }
}

// ── Camera picker sheet ───────────────────────────────────────────────────────

class _CameraPickerSheet extends StatefulWidget {
  final String selectedId;
  const _CameraPickerSheet({required this.selectedId});

  @override
  State<_CameraPickerSheet> createState() => _CameraPickerSheetState();
}

class _CameraPickerSheetState extends State<_CameraPickerSheet> {
  final _svc = SettingsService();
  List<PhysicalCameraInfo>? _cameras;
  String? _error;
  String _selId = '';
  Map<String, (double, double)> _adjustedRanges = {};

  @override
  void initState() {
    super.initState();
    _selId = widget.selectedId;
    _loadCameras();
  }

  Future<void> _loadCameras() async {
    try {
      final list = await PhysicalCameraService().getBackCameras();
      final Map<String, (double, double)> ranges = {};
      for (final cam in list) {
        final saved = await _svc.loadCameraZoomRange(cam.id);
        if (saved != null && cam.zoomMin != null && cam.zoomMax != null) {
          ranges[cam.id] = (
            saved.$1.clamp(cam.zoomMin!, cam.zoomMax!),
            saved.$2.clamp(cam.zoomMin!, cam.zoomMax!),
          );
        } else if (cam.zoomMin != null && cam.zoomMax != null) {
          ranges[cam.id] = (cam.zoomMin!, cam.zoomMax!);
        }
      }
      if (!mounted) return;
      setState(() { _cameras = list; _adjustedRanges = ranges; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _saveAndPop() async {
    for (final entry in _adjustedRanges.entries) {
      await _svc.saveCameraZoomRange(entry.key, entry.value.$1, entry.value.$2);
    }
    final range = _selId.isNotEmpty ? _adjustedRanges[_selId] : null;
    if (mounted) {
      Navigator.pop(context, (_selId, range?.$1 ?? 0.0, range?.$2 ?? 0.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq  = MediaQuery.of(context);
    final top = mq.padding.top;
    final bot = mq.padding.bottom;
    final topPad = top + 76.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_rifle.webp',
              fit: BoxFit.cover,
              alignment: const Alignment(0.2, -1.0),
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
          // Scrollable content
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, bot + 24),
              child: _buildContent(),
            ),
          ),
          // Transparent blur header
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
                                  Text('Камера для запису',
                                      style: TextStyle(
                                        fontSize: 26, fontWeight: FontWeight.w700,
                                        color: Color(0xFFF0EAE5), letterSpacing: -0.5,
                                      )),
                                  SizedBox(height: 2),
                                  Text('Оберіть лінзу для запису',
                                      style: TextStyle(fontSize: 12, color: Color(0x61F0EAE5))),
                                ],
                              ),
                            ),
                            _CamBtn(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(Icons.west, color: Color(0xFFF0EAE5), size: 18),
                            ),
                            const SizedBox(width: 8),
                            _CamBtn(
                              onTap: _saveAndPop,
                              child: const Icon(Icons.check, color: Color(0xFFF0EAE5), size: 18),
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

  Widget _buildContent() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('Помилка: $_error',
            style: const TextStyle(color: Color(0xFFFF6050))),
      );
    }
    if (_cameras == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: Color(0xFFE87722))),
      );
    }
    return Column(
      children: [
        _CamCard(
          id: '',
          name: 'Авто',
          subtitle: 'Повний діапазон · без обмежень',
          focalLength: -1,
          selected: _selId.isEmpty,
          onTap: () => setState(() => _selId = ''),
        ),
        for (final cam in _cameras!) ...[
          const SizedBox(height: 8),
          Builder(builder: (_) {
            final range = _adjustedRanges[cam.id];
            final lo = range?.$1 ?? cam.zoomMin ?? 1.0;
            final hi = range?.$2 ?? cam.zoomMax ?? 10.0;
            return _CamCard(
              id: cam.id,
              name: cam.focalLength > 0
                  ? '${cam.focalLength.toStringAsFixed(1)} мм'
                  : 'Камера ${cam.id}',
              subtitle: cam.isPhysical
                  ? 'ID: ${cam.id} · фізична лінза'
                  : 'ID: ${cam.id}',
              focalLength: cam.focalLength,
              selected: _selId == cam.id,
              zoomMin: cam.zoomMin,
              zoomMax: cam.zoomMax,
              selectedZoomMin: lo,
              selectedZoomMax: hi,
              onTap: () => setState(() => _selId = cam.id),
              onRangeChanged: (min, max) =>
                  setState(() => _adjustedRanges[cam.id] = (min, max)),
            );
          }),
        ],
      ],
    );
  }
}

// ── Camera card ───────────────────────────────────────────────────────────────

class _CamCard extends StatelessWidget {
  final String id;
  final String name;
  final String subtitle;
  final double focalLength;
  final bool selected;
  final double? zoomMin, zoomMax, selectedZoomMin, selectedZoomMax;
  final VoidCallback onTap;
  final void Function(double, double)? onRangeChanged;

  const _CamCard({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.focalLength,
    required this.selected,
    this.zoomMin,
    this.zoomMax,
    this.selectedZoomMin,
    this.selectedZoomMax,
    required this.onTap,
    this.onRangeChanged,
  });

  Color get _accent => id.isEmpty
      ? const Color(0xFF5A8FB8)
      : const Color(0xFFE87722);

  Color get _iconBg => id.isEmpty
      ? const Color(0xCC2A5F88)
      : focalLength > 50
          ? const Color(0xCC1E7048)
          : const Color(0xCCB05010);

  String _zl(double z) =>
      z == z.roundToDouble() ? '${z.toInt()}×' : '${z.toStringAsFixed(1)}×';

  @override
  Widget build(BuildContext context) {
    final hasSlider = zoomMin != null && zoomMax != null && zoomMax! > zoomMin!;
    final lo = selectedZoomMin ?? zoomMin ?? 1.0;
    final hi = selectedZoomMax ?? zoomMax ?? 10.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(alpha: 0.20)
              : const Color(0x26FFFFFF),
          border: Border.all(
            color: selected
                ? _accent.withValues(alpha: 0.55)
                : const Color(0x28FFFFFF),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  _LensIcon(bg: _iconBg, focalLength: focalLength),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF0EAE5))),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(fontSize: 12,
                                color: Color(0x6BF0EAE5))),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? _accent : Colors.transparent,
                      border: Border.all(
                        color: selected ? _accent : const Color(0x33FFFFFF),
                        width: 1.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
            if (hasSlider) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Row(
                  children: [
                    _ZoomBadge(_zl(lo), active: selected, accent: _accent),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('→',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0x33F0EAE5))),
                    ),
                    _ZoomBadge(_zl(hi), active: selected, accent: _accent),
                    const Spacer(),
                    _ZoomBadge('${_zl(zoomMin!)}–${_zl(zoomMax!)}',
                        active: false, accent: _accent, small: true),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: _DualThumbSlider(
                  min: zoomMin!,
                  max: zoomMax!,
                  lo: lo,
                  hi: hi,
                  accent: _accent,
                  onChanged: onRangeChanged ?? (_, __) {},
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Lens icon ─────────────────────────────────────────────────────────────────

class _LensIcon extends StatelessWidget {
  final Color bg;
  final double focalLength;
  const _LensIcon({required this.bg, required this.focalLength});

  @override
  Widget build(BuildContext context) {
    final dotSize = focalLength > 50 ? 6.0 : focalLength > 20 ? 8.0 : 10.0;
    final ring1   = focalLength > 50 ? 30.0 : 32.0;
    final ring2   = focalLength > 50 ? 18.0 : 22.0;

    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: ring1, height: ring1,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x59FFFFFF), width: 1),
            ),
          ),
          Container(
            width: ring2, height: ring2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x59FFFFFF), width: 1),
            ),
          ),
          Container(
            width: dotSize, height: dotSize,
            decoration: const BoxDecoration(
              color: Color(0x73FFFFFF), shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

// ── Zoom badge ────────────────────────────────────────────────────────────────

class _ZoomBadge extends StatelessWidget {
  final String text;
  final bool active;
  final Color accent;
  final bool small;
  const _ZoomBadge(this.text,
      {required this.active, required this.accent, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: active ? accent.withValues(alpha: 0.15) : const Color(0x12FFFFFF),
        border: Border.all(
          color: active ? accent.withValues(alpha: 0.3) : const Color(0x1AFFFFFF),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: small ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: active ? accent : const Color(0x8CF0EAE5),
        ),
      ),
    );
  }
}

// ── Dual thumb slider ─────────────────────────────────────────────────────────

enum _Thumb { lo, hi }

class _DualThumbSlider extends StatefulWidget {
  final double min, max, lo, hi;
  final Color accent;
  final void Function(double lo, double hi) onChanged;

  const _DualThumbSlider({
    required this.min,
    required this.max,
    required this.lo,
    required this.hi,
    required this.accent,
    required this.onChanged,
  });

  @override
  State<_DualThumbSlider> createState() => _DualThumbSliderState();
}

class _DualThumbSliderState extends State<_DualThumbSlider> {
  _Thumb? _dragging;
  double _width = 1;

  double _valToX(double val) {
    final range = widget.max - widget.min;
    return range <= 0 ? 0 : ((val - widget.min) / range) * _width;
  }

  double _xToVal(double x) {
    final frac = (x / _width).clamp(0.0, 1.0);
    final raw  = widget.min + frac * (widget.max - widget.min);
    return (raw * 10).round() / 10.0;
  }

  void _onDragStart(DragStartDetails d) {
    final x   = d.localPosition.dx;
    final loX = _valToX(widget.lo);
    final hiX = _valToX(widget.hi);
    _dragging = (x - loX).abs() <= (x - hiX).abs() ? _Thumb.lo : _Thumb.hi;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dragging == null) return;
    final val = _xToVal(d.localPosition.dx);
    if (_dragging == _Thumb.lo) {
      widget.onChanged(val.clamp(widget.min, widget.hi - 0.5), widget.hi);
    } else {
      widget.onChanged(widget.lo, val.clamp(widget.lo + 0.5, widget.max));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticks = List.generate(
        5, (i) => widget.min + i * (widget.max - widget.min) / 4);

    return LayoutBuilder(builder: (_, c) {
      _width = c.maxWidth;
      return Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart:  _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd:    (_) => _dragging = null,
            child: SizedBox(
              height: 28, width: _width,
              child: CustomPaint(
                painter: _DualSliderPainter(
                  min: widget.min, max: widget.max,
                  lo: widget.lo,   hi: widget.hi,
                  accent: widget.accent,
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ticks.map((v) {
              final s = v == v.roundToDouble()
                  ? '${v.toInt()}×'
                  : '${v.toStringAsFixed(1)}×';
              return Text(s,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0x33F0EAE5)));
            }).toList(),
          ),
        ],
      );
    });
  }
}

class _DualSliderPainter extends CustomPainter {
  final double min, max, lo, hi;
  final Color accent;
  const _DualSliderPainter({
    required this.min, required this.max,
    required this.lo,  required this.hi,
    required this.accent,
  });

  double _toX(double val, double w) {
    final range = max - min;
    return range <= 0 ? 0 : ((val - min) / range) * w;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w  = size.width;
    final cy = size.height / 2;
    const trackH = 4.0;
    const r = Radius.circular(2);

    canvas.drawRRect(
      RRect.fromLTRBR(0, cy - trackH/2, w, cy + trackH/2, r),
      Paint()..color = const Color(0x14FFFFFF),
    );

    final loX = _toX(lo, w).clamp(0.0, w);
    final hiX = _toX(hi, w).clamp(0.0, w);

    if (hiX > loX) {
      canvas.drawRRect(
        RRect.fromLTRBR(loX, cy - trackH/2, hiX, cy + trackH/2, r),
        Paint()
          ..shader = LinearGradient(
            colors: [accent.withValues(alpha: 0.5), accent],
          ).createShader(Rect.fromLTWH(loX, 0, hiX - loX, trackH)),
      );
    }

    for (final x in [loX, hiX]) {
      canvas.drawCircle(Offset(x, cy), 11,
          Paint()..color = accent.withValues(alpha: 0.22));
      canvas.drawCircle(Offset(x, cy), 9, Paint()..color = accent);
      canvas.drawCircle(Offset(x, cy), 6.5,
          Paint()
            ..color = const Color(0xFF1A1210)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
    }
  }

  @override
  bool shouldRepaint(covariant _DualSliderPainter old) =>
      old.lo != lo || old.hi != hi || old.accent != accent;
}

// ── Camera picker header button ───────────────────────────────────────────────

class _CamBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _CamBtn({required this.onTap, required this.child});

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
