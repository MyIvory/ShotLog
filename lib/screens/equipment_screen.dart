import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../models/rifle.dart';
import '../models/bullet.dart';
import '../providers/equipment_provider.dart';

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Спорядження'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(
              icon: SvgPicture.asset(
                _tabCtrl.index == 0
                    ? 'assets/icons/active/ic_rifle_active.svg'
                    : 'assets/icons/inactive/ic_rifle_inactive.svg',
                width: 24,
                height: 24,
              ),
              text: 'Гвинтівки',
            ),
            Tab(
              icon: SvgPicture.asset(
                _tabCtrl.index == 1
                    ? 'assets/icons/active/ic_bullet_active.svg'
                    : 'assets/icons/inactive/ic_bullet_inactive.svg',
                width: 24,
                height: 24,
              ),
              text: 'Набої',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [_RifleTab(), _BulletTab()],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'equipment_fab',
        child: const Icon(Icons.add),
        onPressed: () {
          if (_tabCtrl.index == 0) {
            _showRifleDialog(context);
          } else {
            _showBulletDialog(context);
          }
        },
      ),
    );
  }
}

// ── Shared dialog functions ──────────────────────────────────────────────────

Future<void> _showRifleDialog(BuildContext context, [Rifle? existing]) async {
  final nameCtrl = TextEditingController(text: existing?.name);
  final calCtrl = TextEditingController(text: existing?.caliber);
  final notesCtrl = TextEditingController(text: existing?.notes);
  final ep = context.read<EquipmentProvider>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(existing == null ? 'Нова гвинтівка' : 'Редагувати гвинтівку'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Назва *')),
            const SizedBox(height: 8),
            TextField(controller: calCtrl, decoration: const InputDecoration(labelText: 'Калібр')),
            const SizedBox(height: 8),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Нотатки')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Скасувати')),
        FilledButton(
          onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            final rifle = Rifle(
              id: existing?.id,
              name: nameCtrl.text.trim(),
              caliber: calCtrl.text.trim().isEmpty ? null : calCtrl.text.trim(),
              notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
            );
            if (existing == null) {
              await ep.addRifle(rifle);
            } else {
              await ep.updateRifle(rifle);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Зберегти'),
        ),
      ],
    ),
  );
}

Future<void> _showBulletDialog(BuildContext context, [Bullet? existing]) async {
  final nameCtrl = TextEditingController(text: existing?.name);
  final calCtrl = TextEditingController(text: existing?.caliber);
  final weightCtrl = TextEditingController(
      text: existing?.weightGr != null ? existing!.weightGr!.toStringAsFixed(1) : '');
  final velocityCtrl = TextEditingController(
      text: existing?.velocityMs != null ? existing!.velocityMs!.toStringAsFixed(0) : '');
  final notesCtrl = TextEditingController(text: existing?.notes);
  final ep = context.read<EquipmentProvider>();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(existing == null ? 'Новий набій' : 'Редагувати набій'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Назва *')),
            const SizedBox(height: 8),
            TextField(controller: calCtrl, decoration: const InputDecoration(labelText: 'Калібр')),
            const SizedBox(height: 8),
            TextField(
              controller: weightCtrl,
              decoration: const InputDecoration(labelText: 'Вага, gr'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: velocityCtrl,
              decoration: const InputDecoration(labelText: 'Швидкість, м/с'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Нотатки')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Скасувати')),
        FilledButton(
          onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            final bullet = Bullet(
              id: existing?.id,
              name: nameCtrl.text.trim(),
              caliber: calCtrl.text.trim().isEmpty ? null : calCtrl.text.trim(),
              weightGr: double.tryParse(weightCtrl.text.trim()),
              velocityMs: double.tryParse(velocityCtrl.text.trim()),
              notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
            );
            if (existing == null) {
              await ep.addBullet(bullet);
            } else {
              await ep.updateBullet(bullet);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Зберегти'),
        ),
      ],
    ),
  );
}

// ── Rifles ──────────────────────────────────────────────────────────────────

class _RifleTab extends StatelessWidget {
  const _RifleTab();

  @override
  Widget build(BuildContext context) {
    final ep = context.watch<EquipmentProvider>();
    if (ep.rifles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/inactive/ic_rifle_inactive.svg',
              width: 64,
              height: 64,
              colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
            ),
            const SizedBox(height: 16),
            const Text('Немає гвинтівок', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Натисніть + щоб додати першу', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: ep.rifles.length,
      itemBuilder: (ctx, i) => _RifleItem(rifle: ep.rifles[i]),
    );
  }
}

class _RifleItem extends StatelessWidget {
  final Rifle rifle;
  const _RifleItem({required this.rifle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SvgPicture.asset(
        'assets/icons/active/ic_rifle_active.svg',
        width: 24,
        height: 24,
      ),
      title: Text(rifle.name),
      subtitle: _rifleSubtitle(rifle) != null ? Text(_rifleSubtitle(rifle)!) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showRifleDialog(context, rifle),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  String? _rifleSubtitle(Rifle rifle) {
    final parts = [
      if (rifle.caliber != null) rifle.caliber!,
      if (rifle.notes != null) rifle.notes!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити гвинтівку?'),
        content: Text('«${rifle.name}» буде видалено безповоротно.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<EquipmentProvider>().deleteRifle(rifle.id!);
    }
  }
}

// ── Bullets ──────────────────────────────────────────────────────────────────

class _BulletTab extends StatelessWidget {
  const _BulletTab();

  @override
  Widget build(BuildContext context) {
    final ep = context.watch<EquipmentProvider>();
    if (ep.bullets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/inactive/ic_bullet_inactive.svg',
              width: 64,
              height: 64,
              colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
            ),
            const SizedBox(height: 16),
            const Text('Немає набоїв', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Натисніть + щоб додати перший', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: ep.bullets.length,
      itemBuilder: (ctx, i) => _BulletItem(bullet: ep.bullets[i]),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final Bullet bullet;
  const _BulletItem({required this.bullet});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SvgPicture.asset(
        'assets/icons/active/ic_bullet_active.svg',
        width: 24,
        height: 24,
      ),
      title: Text(bullet.name),
      subtitle: bullet.displayName != bullet.name ? Text(bullet.displayName) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showBulletDialog(context, bullet),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити набій?'),
        content: Text('«${bullet.name}» буде видалено безповоротно.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Скасувати')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<EquipmentProvider>().deleteBullet(bullet.id!);
    }
  }
}
