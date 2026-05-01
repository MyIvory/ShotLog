import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
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

  @override
  void initState() {
    super.initState();
    _svc.load().then((s) => setState(() {
          _s = s;
          _loading = false;
        }));
  }

  Future<void> _save() async {
    await _svc.save(_s);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Збережено')));
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
            onChanged: (v) => setState(() => _s = _s.copyWith(countdownSec: v)),
          ),
          _IntSlider(
            label: 'Таймаут без пострілу',
            value: _s.timeoutSec,
            min: 5,
            max: 30,
            unit: 'с',
            onChanged: (v) => setState(() => _s = _s.copyWith(timeoutSec: v)),
          ),
          _IntSlider(
            label: 'Запис після пострілу (post-roll)',
            value: _s.postRollSec,
            min: 1,
            max: 10,
            unit: 'с',
            onChanged: (v) => setState(() => _s = _s.copyWith(postRollSec: v)),
          ),
          _IntSlider(
            label: 'Перегляд до пострілу (pre-roll)',
            value: _s.preRollSec,
            min: 0,
            max: 5,
            unit: 'с',
            onChanged: (v) => setState(() => _s = _s.copyWith(preRollSec: v)),
          ),
          const Divider(height: 32),
          _Section('Детекція пострілу'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Поріг гучності: ${_s.detectionDbfs.toStringAsFixed(0)} dBFS',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Text(
                  '0 = найгучніше, -80 = тиша. Чим ближче до 0 — тим голосніше повинен бути постріл.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Slider(
                  value: _s.detectionDbfs,
                  min: -80,
                  max: -5,
                  divisions: 75,
                  label: '${_s.detectionDbfs.toStringAsFixed(0)} dBFS',
                  onChanged: (v) => setState(() => _s = _s.copyWith(detectionDbfs: v)),
                ),
              ],
            ),
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
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Зберегти налаштування'),
            onPressed: _save,
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
        child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey)),
      );
}

class _IntSlider extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  const _IntSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value $unit', style: Theme.of(context).textTheme.bodyMedium),
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
