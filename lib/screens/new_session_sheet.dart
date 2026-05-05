import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session.dart';
import '../models/rifle.dart';
import '../models/bullet.dart';
import '../providers/equipment_provider.dart';

class NewSessionSheet extends StatefulWidget {
  const NewSessionSheet({super.key});

  @override
  State<NewSessionSheet> createState() => _NewSessionSheetState();
}

class _NewSessionSheetState extends State<NewSessionSheet> {
  Rifle? _rifle;
  Bullet? _bullet;
  final _nameCtrl = TextEditingController();
  final _distCtrl = TextEditingController();
  final _weatherCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _distCtrl.dispose();
    _weatherCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ep = context.watch<EquipmentProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
              children: [
                Text('Нова сесія', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Назва сесії',
                    hintText: 'напр. Тренування на 100м',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _DropdownRow<Rifle>(
                  label: 'Гвинтівка',
                  items: ep.rifles,
                  value: _rifle,
                  displayString: (r) => r.displayName,
                  onChanged: (r) => setState(() => _rifle = r),
                  onAdd: () => _addRifleDialog(context, ep),
                ),
                const SizedBox(height: 12),
                _DropdownRow<Bullet>(
                  label: 'Набій',
                  items: ep.bullets,
                  value: _bullet,
                  displayString: (b) => b.displayName,
                  onChanged: (b) => setState(() => _bullet = b),
                  onAdd: () => _addBulletDialog(context, ep),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _distCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Дистанція, м',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _weatherCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Погода / умови',
                    hintText: 'напр. вітер 3 м/с, +12°C',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Нотатки',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Почати сесію'),
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final now = DateTime.now();
    final autoName =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    final session = Session(
      name: _nameCtrl.text.trim().isEmpty ? autoName : _nameCtrl.text.trim(),
      createdAt: DateTime.now(),
      rifleId: _rifle?.id,
      bulletId: _bullet?.id,
      distanceM: double.tryParse(_distCtrl.text.trim()),
      weather: _weatherCtrl.text.trim().isEmpty ? null : _weatherCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    Navigator.of(context).pop(session);
  }

  Future<void> _addRifleDialog(BuildContext ctx, EquipmentProvider ep) async {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    await showDialog<void>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Нова гвинтівка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Назва *')),
            TextField(controller: calCtrl, decoration: const InputDecoration(labelText: 'Калібр')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Скасувати')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final rifle = await ep.addRifle(Rifle(
                name: nameCtrl.text.trim(),
                caliber: calCtrl.text.trim().isEmpty ? null : calCtrl.text.trim(),
              ));
              if (mounted) setState(() => _rifle = rifle);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
  }

  Future<void> _addBulletDialog(BuildContext ctx, EquipmentProvider ep) async {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    await showDialog<void>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Новий набій'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Назва *')),
            TextField(controller: calCtrl, decoration: const InputDecoration(labelText: 'Калібр')),
            TextField(
              controller: weightCtrl,
              decoration: const InputDecoration(labelText: 'Вага, gr'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Скасувати')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final bullet = await ep.addBullet(Bullet(
                name: nameCtrl.text.trim(),
                caliber: calCtrl.text.trim().isEmpty ? null : calCtrl.text.trim(),
                weightGr: double.tryParse(weightCtrl.text.trim()),
              ));
              if (mounted) setState(() => _bullet = bullet);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final T? value;
  final String Function(T) displayString;
  final ValueChanged<T?> onChanged;
  final VoidCallback onAdd;

  const _DropdownRow({
    required this.label,
    required this.items,
    required this.value,
    required this.displayString,
    required this.onChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: items
                  .map((item) => DropdownMenuItem(value: item, child: Text(displayString(item))))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          icon: const Icon(Icons.add),
          tooltip: 'Додати',
          onPressed: onAdd,
          style: IconButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
