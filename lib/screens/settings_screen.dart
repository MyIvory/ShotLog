import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/physical_camera_service.dart';
import '../services/settings_service.dart';
import '../widgets/threshold_picker.dart';
import 'equipment_screen.dart';

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

  void _onChange(AppSettings newSettings) {
    setState(() => _s = newSettings);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () async {
      await _svc.save(_s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Збережено'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section('Таймінги'),
          _IntSlider(
            label: 'Відлік перед записом',
            value: _s.countdownSec,
            min: 1,
            max: 10,
            unit: 'с',
            icon: Icons.timer_outlined,
            onChanged: (v) => _onChange(_s.copyWith(countdownSec: v)),
          ),
          _IntSlider(
            label: 'Таймаут без пострілу',
            value: _s.timeoutSec,
            min: 10,
            max: 60,
            unit: 'с',
            icon: Icons.timer_outlined,
            onChanged: (v) => _onChange(_s.copyWith(timeoutSec: v)),
          ),
          _IntSlider(
            label: 'Запис після пострілу (post-roll)',
            value: _s.postRollSec,
            min: 1,
            max: 10,
            unit: 'с',
            icon: Icons.timer_outlined,
            helpText: 'Скільки секунд відео записується після пострілу',
            onChanged: (v) => _onChange(_s.copyWith(postRollSec: v)),
          ),
          _IntSlider(
            label: 'Перегляд до пострілу (pre-roll)',
            value: _s.preRollSec,
            min: 0,
            max: 5,
            unit: 'с',
            icon: Icons.timer_outlined,
            helpText: 'З якого моменту розпочинати відтворення при перегляді кліпу',
            onChanged: (v) => _onChange(_s.copyWith(preRollSec: v)),
          ),
          const Divider(height: 32),
          _Section('Запуск запису'),
          _TriggerModeTile(
            value: _s.triggerMode,
            onChanged: (v) => _onChange(_s.copyWith(triggerMode: v)),
          ),
          const Divider(height: 32),
          _Section('Детекція пострілу'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.graphic_eq),
            title: const Text('Поріг гучності'),
            subtitle: Text(
              '${_s.detectionDbfs.toStringAsFixed(0)} dBFS — натисніть для налаштування',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final result = await showThresholdPicker(context, _s.detectionDbfs);
              if (result != null) {
                _onChange(_s.copyWith(detectionDbfs: result));
              }
            },
          ),
          const Divider(height: 32),
          _Section('Камера'),
          _CameraTile(
            selectedId: _s.selectedCameraId,
            zoomMin: _s.cameraZoomMin,
            zoomMax: _s.cameraZoomMax,
            onChanged: (id, zoomMin, zoomMax) => _onChange(_s.copyWith(
              selectedCameraId: id,
              cameraZoomMin: zoomMin,
              cameraZoomMax: zoomMax,
            )),
          ),
          const Divider(height: 32),
          _Section('Спорядження'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Гвинтівки та набої'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EquipmentScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

class _TriggerModeTile extends StatelessWidget {
  final TriggerMode value;
  final ValueChanged<TriggerMode> onChanged;

  const _TriggerModeTile({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SegmentedButton<TriggerMode>(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        segments: const [
          ButtonSegment(
            value: TriggerMode.button,
            label: Text('Кнопка в застосунку'),
            icon: Icon(Icons.touch_app),
          ),
          ButtonSegment(
            value: TriggerMode.bluetooth,
            label: Text('Bluetooth брелок'),
            icon: Icon(Icons.bluetooth),
          ),
        ],
        selected: {value},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

class _IntSlider extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final String? helpText;
  final IconData? icon;
  final ValueChanged<int> onChanged;

  const _IntSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    this.helpText,
    this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 16),
            child: Icon(icon, color: cs.onSurfaceVariant, size: 24),
          ),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label: $value $unit', style: tt.bodyMedium),
              if (helpText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    helpText!,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: max - min,
                label: '$value $unit',
                onChanged: (v) => onChanged(v.round()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

typedef _CameraSelectedCallback = void Function(String id, double zoomMin, double zoomMax);

class _CameraTile extends StatelessWidget {
  final String selectedId;
  final double zoomMin;
  final double zoomMax;
  final _CameraSelectedCallback onChanged;

  const _CameraTile({
    required this.selectedId,
    required this.zoomMin,
    required this.zoomMax,
    required this.onChanged,
  });

  String _zoomLabel(double z) =>
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
    final cs = Theme.of(context).colorScheme;
    String subtitle;
    if (selectedId.isEmpty) {
      subtitle = 'Автоматично — повний діапазон зуму';
    } else if (zoomMin > 0 && zoomMax > 0) {
      subtitle = 'ID: $selectedId · ${_zoomLabel(zoomMin)} – ${_zoomLabel(zoomMax)}';
    } else {
      subtitle = 'ID: $selectedId';
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.camera_alt_outlined),
      title: const Text('Камера для запису'),
      subtitle: Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showPicker(context),
    );
  }
}

class _CameraPickerSheet extends StatefulWidget {
  final String selectedId;
  final _CameraSelectedCallback onChanged;

  const _CameraPickerSheet({
    required this.selectedId,
    required this.onChanged,
  });

  @override
  State<_CameraPickerSheet> createState() => _CameraPickerSheetState();
}

class _CameraPickerSheetState extends State<_CameraPickerSheet> {
  final _svc = SettingsService();
  List<PhysicalCameraInfo>? _cameras;
  String? _error;
  String _selId = '';
  // Per-camera adjusted ranges — each bounded by that camera's own auto range.
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
      await _svc.saveCameraZoomRange(entry.key, entry.value.$1, entry.value.$2);
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
                child: Text('Помилка: $_error', style: TextStyle(color: cs.error)),
              )
            else if (_cameras == null)
              const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              ListTile(
                leading: Radio<String>(
                  value: '',
                  groupValue: _selId,
                  onChanged: (v) => setState(() => _selId = v ?? ''),
                ),
                title: Text('Авто (за замовчуванням)', style: tt.bodyMedium),
                subtitle: Text(
                  'Повний діапазон, без обмежень',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
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

  Widget _buildCameraRow(PhysicalCameraInfo cam, TextTheme tt, ColorScheme cs) {
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
              ? Text(
                  '${_zl(lo)} – ${_zl(hi)}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                )
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

class _ZoomRangeSlider extends StatelessWidget {
  final double min;
  final double max;
  final double zoomMin;
  final double zoomMax;
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
              Text(_zl(min), style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              Text(_zl(max), style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}
