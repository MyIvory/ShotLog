import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
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
            onChanged: (v) => _onChange(_s.copyWith(countdownSec: v)),
          ),
          _IntSlider(
            label: 'Таймаут без пострілу',
            value: _s.timeoutSec,
            min: 5,
            max: 30,
            unit: 'с',
            onChanged: (v) => _onChange(_s.copyWith(timeoutSec: v)),
          ),
          _IntSlider(
            label: 'Запис після пострілу (post-roll)',
            value: _s.postRollSec,
            min: 1,
            max: 10,
            unit: 'с',
            helpText: 'Скільки секунд відео записується після пострілу',
            onChanged: (v) => _onChange(_s.copyWith(postRollSec: v)),
          ),
          _IntSlider(
            label: 'Перегляд до пострілу (pre-roll)',
            value: _s.preRollSec,
            min: 0,
            max: 5,
            unit: 'с',
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
          _Section('Спорядження'),
          ListTile(
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
  final ValueChanged<int> onChanged;

  const _IntSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    this.helpText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value $unit', style: Theme.of(context).textTheme.bodyMedium),
        if (helpText != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              helpText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
    );
  }
}
