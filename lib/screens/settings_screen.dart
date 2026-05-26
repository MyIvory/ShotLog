import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/physical_camera_service.dart';
import '../services/settings_service.dart';
import '../widgets/threshold_picker.dart';
import 'equipment_screen.dart';

// ── Color constants ───────────────────────────────────────────────────────────

const _kAccent    = Color(0xFFE87722);
const _kBlue      = Color(0xFF5A8FB8);
const _kGreen     = Color(0xFF6EE0A0);
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
const _kBgGreen   = Color(0xCC1E7048);

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const _PhotoBg(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
                  child: const Text(
                    'Налаштування',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
                              Icons.graphic_eq, _kBgAmber),
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
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const EquipmentScreen()),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),

                // ── Sticky footer ──────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text(
                      'Зміни зберігаються автоматично',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0x40F0EAE5),
                        letterSpacing: 0.3,
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

// ── Photo background ──────────────────────────────────────────────────────────

class _PhotoBg extends StatelessWidget {
  const _PhotoBg();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg_rifle.webp',
            fit: BoxFit.cover,
            alignment: const Alignment(0.2, -1.0),
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
        Offset(tx, cy), 13, Paint()..color = colors.last.withOpacity(0.22));
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

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CameraPickerSheet(
        selectedId: selectedId,
        onChanged: onChanged,
      ),
    );
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
  final _CameraSelectedCallback onChanged;
  const _CameraPickerSheet(
      {required this.selectedId, required this.onChanged});

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
      setState(() {
        _cameras = list;
        _adjustedRanges = ranges;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  String _zl(double z) =>
      z == z.roundToDouble() ? '${z.toInt()}×' : '${z.toStringAsFixed(1)}×';

  Future<void> _apply() async {
    for (final entry in _adjustedRanges.entries) {
      await _svc.saveCameraZoomRange(
          entry.key, entry.value.$1, entry.value.$2);
    }
    final range = _selId.isNotEmpty ? _adjustedRanges[_selId] : null;
    widget.onChanged(_selId, range?.$1 ?? 0.0, range?.$2 ?? 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text('Вибір камери', style: tt.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Виберіть лінзу суміщену з окуляром прицілу. '
                'Слайдер кожної камери обмежений її фізичним діапазоном.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Помилка: $_error',
                    style: TextStyle(color: cs.error)),
              )
            else if (_cameras == null)
              const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()))
            else ...[
              ListTile(
                leading: Radio<String>(
                  value: '',
                  groupValue: _selId,
                  onChanged: (v) => setState(() => _selId = v ?? ''),
                ),
                title: Text('Авто (за замовчуванням)',
                    style: tt.bodyMedium),
                subtitle: Text('Повний діапазон, без обмежень',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
                onTap: () => setState(() => _selId = ''),
              ),
              const Divider(height: 1),
              for (final cam in _cameras!) ...[
                _buildCameraRow(cam, tt, cs),
                const Divider(height: 1),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await _apply();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Зберегти'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCameraRow(
      PhysicalCameraInfo cam, TextTheme tt, ColorScheme cs) {
    final range = _adjustedRanges[cam.id];
    final hasSlider = cam.zoomMin != null &&
        cam.zoomMax != null &&
        cam.zoomMax! > cam.zoomMin!;
    final lo = range?.$1 ?? cam.zoomMin ?? 1.0;
    final hi = range?.$2 ?? cam.zoomMax ?? 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Radio<String>(
            value: cam.id,
            groupValue: _selId,
            onChanged: (v) => setState(() => _selId = v ?? ''),
          ),
          title: Text(
            cam.focalLength > 0
                ? '${cam.focalLength.toStringAsFixed(1)} мм'
                    '${cam.isPhysical ? "  •  ID: ${cam.id}" : ""}'
                : 'ID: ${cam.id}',
            style: tt.bodyMedium,
          ),
          subtitle: hasSlider
              ? Text('${_zl(lo)} – ${_zl(hi)}',
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant))
              : null,
          onTap: () => setState(() => _selId = cam.id),
        ),
        if (hasSlider)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _ZoomRangeSlider(
              min: cam.zoomMin!,
              max: cam.zoomMax!,
              zoomMin: lo,
              zoomMax: hi,
              onChanged: (min, max) =>
                  setState(() => _adjustedRanges[cam.id] = (min, max)),
            ),
          ),
      ],
    );
  }
}

// ── Zoom range slider ─────────────────────────────────────────────────────────

class _ZoomRangeSlider extends StatelessWidget {
  final double min, max, zoomMin, zoomMax;
  final void Function(double min, double max) onChanged;

  const _ZoomRangeSlider({
    required this.min,
    required this.max,
    required this.zoomMin,
    required this.zoomMax,
    required this.onChanged,
  });

  String _zl(double z) =>
      z == z.roundToDouble() ? '${z.toInt()}×' : '${z.toStringAsFixed(1)}×';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final range = max - min;
    if (range <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Text('Мін: ${_zl(zoomMin)}', style: tt.bodySmall),
              const Spacer(),
              Text('Макс: ${_zl(zoomMax)}', style: tt.bodySmall),
            ],
          ),
          RangeSlider(
            min: min,
            max: max,
            values: RangeValues(
              zoomMin.clamp(min, max),
              zoomMax.clamp(min, max),
            ),
            divisions: (range * 2).round().clamp(2, 100),
            activeColor: cs.primary,
            onChanged: (v) => onChanged(
              double.parse(v.start.toStringAsFixed(1)),
              double.parse(v.end.toStringAsFixed(1)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_zl(min),
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
              Text(_zl(max),
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}
