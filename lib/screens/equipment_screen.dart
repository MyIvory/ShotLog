import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rifle.dart';
import '../models/bullet.dart';
import '../providers/equipment_provider.dart';

class EquipmentScreen extends StatelessWidget {
  const EquipmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Спорядження'),
          bottom: const TabBar(tabs: [Tab(text: 'Гвинтівки'), Tab(text: 'Набої')]),
        ),
        body: const TabBarView(children: [_RifleTab(), _BulletTab()]),
      ),
    );
  }
}

// ── Rifles ──────────────────────────────────────────────────────────────────

class _RifleTab extends StatelessWidget {
  const _RifleTab();

  @override
  Widget build(BuildContext context) {
    final ep = context.watch<EquipmentProvider>();
    return Scaffold(
      body: ep.rifles.isEmpty
          ? const Center(child: Text('Немає гвинтівок. Додайте першу.'))
          : ListView.builder(
              itemCount: ep.rifles.length,
              itemBuilder: (ctx, i) => _RifleItem(rifle: ep.rifles[i]),
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showRifleDialog(context),
      ),
    );
  }

  Future<void> _showRifleDialog(BuildContext context, [Rifle? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name);
    final calCtrl = TextEditingController(text: existing?.caliber);
    final notesCtrl = TextEditingController(text: existing?.notes);
    final ep = context.read<EquipmentProvider>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Нова гвинтівка' : 'Редагувати'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Назва *')),
            TextField(controller: calCtrl, decoration: const InputDecoration(labelText: 'Калібр')),
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Нотатки')),
          ],
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
}

class _RifleItem extends StatelessWidget {
  final Rifle rifle;
  const _RifleItem({required this.rifle});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(rifle.name),
      subtitle: rifle.caliber != null ? Text(rifle.caliber!) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _RifleTab()._showRifleDialog(context, rifle),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => context.read<EquipmentProvider>().deleteRifle(rifle.id!),
          ),
        ],
      ),
    );
  }
}

// ── Bullets ──────────────────────────────────────────────────────────────────

class _BulletTab extends StatelessWidget {
  const _BulletTab();

  @override
  Widget build(BuildContext context) {
    final ep = context.watch<EquipmentProvider>();
    return Scaffold(
      body: ep.bullets.isEmpty
          ? const Center(child: Text('Немає набоїв. Додайте перший.'))
          : ListView.builder(
              itemCount: ep.bullets.length,
              itemBuilder: (ctx, i) => _BulletItem(bullet: ep.bullets[i]),
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showBulletDialog(context),
      ),
    );
  }

  Future<void> _showBulletDialog(BuildContext context, [Bullet? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name);
    final calCtrl = TextEditingController(text: existing?.caliber);
    final weightCtrl = TextEditingController(
        text: existing?.weightGr != null ? existing!.weightGr!.toStringAsFixed(1) : '');
    final notesCtrl = TextEditingController(text: existing?.notes);
    final ep = context.read<EquipmentProvider>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Новий набій' : 'Редагувати'),
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
            TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Нотатки')),
          ],
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
}

class _BulletItem extends StatelessWidget {
  final Bullet bullet;
  const _BulletItem({required this.bullet});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(bullet.name),
      subtitle: Text(bullet.displayName != bullet.name ? bullet.displayName : ''),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _BulletTab()._showBulletDialog(context, bullet),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => context.read<EquipmentProvider>().deleteBullet(bullet.id!),
          ),
        ],
      ),
    );
  }
}
