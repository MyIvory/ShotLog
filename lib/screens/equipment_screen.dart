import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../models/rifle.dart';
import '../models/bullet.dart';
import '../providers/equipment_provider.dart';
import '../widgets/parallax_bg.dart';

const _kAccent   = Color(0xFFE87722);
const _kText     = Color(0xFFF0EAE5);
const _kHint     = Color(0x73F0EAE5);
const _kBgRifle  = Color(0x80B05010);
const _kBgBullet = Color(0x803C7850);

// ── Entry point ───────────────────────────────────────────────────────────────

void showEquipmentSheet(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EquipmentScreen()),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final mq  = MediaQuery.of(context);
    final top = mq.padding.top;
    final bot = mq.padding.bottom;
    final topPad = top + 124.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background
          const Positioned.fill(
            child: ParallaxBg(
              asset: 'assets/images/bg_rifle.webp',
              baseAlignment: Alignment(0.2, -1.0),
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
          // ── Lists ──
          Positioned.fill(
            child: IndexedStack(
              index: _tab,
              children: [
                _RifleTab(topPad: topPad, bottomPad: bot + 16),
                _BulletTab(topPad: topPad, bottomPad: bot + 16),
              ],
            ),
          ),
          // ── Transparent blur header ──
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
                                  Text('Спорядження',
                                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                                          color: _kText, letterSpacing: -0.5)),
                                  SizedBox(height: 2),
                                  Text('Твій стрілецький інвентар',
                                      style: TextStyle(fontSize: 12, color: Color(0x61F0EAE5))),
                                ],
                              ),
                            ),
                            _EqBtn(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(Icons.west, color: _kText, size: 18),
                            ),
                            const SizedBox(width: 8),
                            _EqBtn(
                              onTap: () => _tab == 0
                                  ? _showRifleSheet(context)
                                  : _showBulletSheet(context),
                              child: const Icon(Icons.add, color: _kText, size: 20),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(children: [
                          Expanded(child: _TabBtn(
                            label: 'Гвинтівки',
                            svgActive:   'assets/icons/active/ic_rifle_active.svg',
                            svgInactive: 'assets/icons/inactive/ic_rifle_inactive.svg',
                            active: _tab == 0,
                            onTap: () => setState(() => _tab = 0),
                          )),
                          const SizedBox(width: 6),
                          Expanded(child: _TabBtn(
                            label: 'Набої',
                            svgActive:   'assets/icons/active/ic_bullet_active.svg',
                            svgInactive: 'assets/icons/inactive/ic_bullet_inactive.svg',
                            active: _tab == 1,
                            onTap: () => setState(() => _tab = 1),
                          )),
                        ]),
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

// ── Header button (glass square) ──────────────────────────────────────────────

class _EqBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _EqBtn({required this.onTap, required this.child});

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

// ── Tab button ────────────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final String svgActive;
  final String svgInactive;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({
    required this.label, required this.svgActive, required this.svgInactive,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? const Color(0x26E87722) : const Color(0x0DFFFFFF),
          border: Border.all(
            color: active ? const Color(0x66E87722) : const Color(0x14FFFFFF),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              active ? svgActive : svgInactive,
              width: 18, height: 18,
              colorFilter: ColorFilter.mode(
                active ? _kAccent : _kHint, BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: active ? _kAccent : _kHint)),
          ],
        ),
      ),
    );
  }
}

// ── Rifles ────────────────────────────────────────────────────────────────────

class _RifleTab extends StatelessWidget {
  final double topPad;
  final double bottomPad;
  const _RifleTab({required this.topPad, required this.bottomPad});

  @override
  Widget build(BuildContext context) {
    final rifles = context.watch<EquipmentProvider>().rifles;
    if (rifles.isEmpty) {
      return _EmptyState(
        svg: 'assets/icons/inactive/ic_rifle_inactive.svg',
        label: 'Немає гвинтівок',
        hint: 'Натисніть + щоб додати першу',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, bottomPad + 16),
      itemCount: rifles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _RifleCard(rifle: rifles[i]),
    );
  }
}

class _RifleCard extends StatelessWidget {
  final Rifle rifle;
  const _RifleCard({required this.rifle});

  @override
  Widget build(BuildContext context) {
    final chips = [
      if (rifle.caliber != null) (rifle.caliber!, true),
      if (rifle.notes != null) (rifle.notes!, false),
    ];
    return _EqCard(
      badgeColor: _kBgRifle,
      svg: 'assets/icons/active/ic_rifle_active.svg',
      name: rifle.name,
      subtitle: rifle.caliber,
      chips: chips,
      onEdit: () => _showRifleSheet(context, rifle),
      onDelete: () => _showDeleteSheet(
          context, rifle.name,
          () => context.read<EquipmentProvider>().deleteRifle(rifle.id!)),
    );
  }
}

// ── Bullets ───────────────────────────────────────────────────────────────────

class _BulletTab extends StatelessWidget {
  final double topPad;
  final double bottomPad;
  const _BulletTab({required this.topPad, required this.bottomPad});

  @override
  Widget build(BuildContext context) {
    final bullets = context.watch<EquipmentProvider>().bullets;
    if (bullets.isEmpty) {
      return _EmptyState(
        svg: 'assets/icons/inactive/ic_bullet_inactive.svg',
        label: 'Немає набоїв',
        hint: 'Натисніть + щоб додати перший',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, bottomPad + 16),
      itemCount: bullets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _BulletCard(bullet: bullets[i]),
    );
  }
}

class _BulletCard extends StatelessWidget {
  final Bullet bullet;
  const _BulletCard({required this.bullet});

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (bullet.caliber != null) bullet.caliber!,
      if (bullet.weightGr != null) '${bullet.weightGr!.toStringAsFixed(0)} gr',
      if (bullet.velocityMs != null) '${bullet.velocityMs!.toStringAsFixed(0)} м/с',
    ].join(' · ');

    final chips = [
      if (bullet.caliber != null) (bullet.caliber!, true),
      if (bullet.weightGr != null) ('${bullet.weightGr!.toStringAsFixed(0)} gr', false),
      if (bullet.velocityMs != null) ('${bullet.velocityMs!.toStringAsFixed(0)} м/с', false),
    ];

    return _EqCard(
      badgeColor: _kBgBullet,
      svg: 'assets/icons/active/ic_bullet_active.svg',
      name: bullet.name,
      subtitle: sub.isNotEmpty ? sub : null,
      chips: chips,
      onEdit: () => _showBulletSheet(context, bullet),
      onDelete: () => _showDeleteSheet(
          context, bullet.name,
          () => context.read<EquipmentProvider>().deleteBullet(bullet.id!)),
    );
  }
}

// ── Shared card ───────────────────────────────────────────────────────────────

class _EqCard extends StatelessWidget {
  final Color badgeColor;
  final String svg;
  final String name;
  final String? subtitle;
  final List<(String, bool)> chips;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _EqCard({
    required this.badgeColor, required this.svg,
    required this.name, required this.subtitle,
    required this.chips, required this.onEdit, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        border: Border.all(color: const Color(0x28FFFFFF), width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, 13, 14, chips.isEmpty ? 13 : 10),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: SvgPicture.asset(
                  svg, width: 22, height: 22,
                  colorFilter: const ColorFilter.mode(_kText, BlendMode.srcIn),
                )),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                          color: _kText)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(fontSize: 12, color: Color(0x6BF0EAE5))),
                  ],
                ],
              )),
              _ActionBtn(icon: Icons.edit_outlined, onTap: onEdit),
              const SizedBox(width: 2),
              _ActionBtn(icon: Icons.delete_outline, isDelete: true, onTap: onDelete),
            ]),
          ),
          if (chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Wrap(
                spacing: 5, runSpacing: 5,
                children: [
                  for (final (label, accent) in chips)
                    _Chip(label: label, accent: accent),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String svg;
  final String label;
  final String hint;
  const _EmptyState({required this.svg, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SvgPicture.asset(svg, width: 48, height: 48,
              colorFilter: const ColorFilter.mode(Color(0x4DF0EAE5), BlendMode.srcIn)),
          const SizedBox(height: 12),
          Text(label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _kText)),
          const SizedBox(height: 5),
          Text(hint, style: const TextStyle(fontSize: 13, color: Color(0x73F0EAE5))),
        ]),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDelete;
  const _ActionBtn({required this.icon, required this.onTap, this.isDelete = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF),
          border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18,
            color: isDelete ? const Color(0xFFFF7070) : const Color(0x80F0EAE5)),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool accent;
  const _Chip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent ? const Color(0x1AE87722) : const Color(0x0FFFFFFF),
        border: Border.all(
          color: accent ? const Color(0x40E87722) : const Color(0x17FFFFFF),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: accent ? const Color(0xD9E87722) : const Color(0x80F0EAE5))),
    );
  }
}

// ── Sheet helpers ─────────────────────────────────────────────────────────────

BoxDecoration _sheetDecoration() => const BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1610), Color(0xFF130E0C)],
  ),
  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  border: Border(
    top:   BorderSide(color: Color(0x1AFFFFFF), width: 0.5),
    left:  BorderSide(color: Color(0x1AFFFFFF), width: 0.5),
    right: BorderSide(color: Color(0x1AFFFFFF), width: 0.5),
  ),
);

Widget _handle() => Container(
  width: 36, height: 4,
  margin: const EdgeInsets.only(top: 12),
  decoration: BoxDecoration(
    color: const Color(0x2EFFFFFF),
    borderRadius: BorderRadius.circular(2),
  ),
);

Widget _sheetHeader(String title, String subtitle) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
            color: _kText, letterSpacing: -0.2)),
    const SizedBox(height: 3),
    Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0x61F0EAE5))),
  ]),
);

// ── Rifle sheet ───────────────────────────────────────────────────────────────

Future<void> _showRifleSheet(BuildContext context, [Rifle? existing]) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RifleSheet(
        ep: context.read<EquipmentProvider>(), existing: existing),
  );
}

class _RifleSheet extends StatefulWidget {
  final EquipmentProvider ep;
  final Rifle? existing;
  const _RifleSheet({required this.ep, this.existing});

  @override
  State<_RifleSheet> createState() => _RifleSheetState();
}

class _RifleSheetState extends State<_RifleSheet> {
  late final TextEditingController _name  = TextEditingController(text: widget.existing?.name);
  late final TextEditingController _cal   = TextEditingController(text: widget.existing?.caliber);
  late final TextEditingController _notes = TextEditingController(text: widget.existing?.notes);

  @override
  void dispose() {
    _name.dispose(); _cal.dispose(); _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: _sheetDecoration(),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _handle(),
          _sheetHeader(
            widget.existing == null ? 'Нова гвинтівка' : 'Редагувати гвинтівку',
            'Заповніть дані спорядження',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(children: [
              _GlassField(label: 'Назва', isRequired: true,
                  controller: _name, hint: 'напр. CZ Shadow 2'),
              const SizedBox(height: 9),
              _GlassField(label: 'Калібр',
                  controller: _cal, hint: 'напр. 9×19 мм'),
              const SizedBox(height: 9),
              _GlassField(label: 'Нотатки',
                  controller: _notes, hint: 'опціонально'),
            ]),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16,
                MediaQuery.of(context).padding.bottom + 16),
            child: _Footer(
              onCancel: () => Navigator.pop(context),
              onSave: () async {
                if (_name.text.trim().isEmpty) return;
                final r = Rifle(
                  id: widget.existing?.id,
                  name: _name.text.trim(),
                  caliber: _cal.text.trim().isEmpty ? null : _cal.text.trim(),
                  notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                );
                if (widget.existing == null) {
                  await widget.ep.addRifle(r);
                } else {
                  await widget.ep.updateRifle(r);
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Bullet sheet ──────────────────────────────────────────────────────────────

Future<void> _showBulletSheet(BuildContext context, [Bullet? existing]) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BulletSheet(
        ep: context.read<EquipmentProvider>(), existing: existing),
  );
}

class _BulletSheet extends StatefulWidget {
  final EquipmentProvider ep;
  final Bullet? existing;
  const _BulletSheet({required this.ep, this.existing});

  @override
  State<_BulletSheet> createState() => _BulletSheetState();
}

class _BulletSheetState extends State<_BulletSheet> {
  late final TextEditingController _name   = TextEditingController(text: widget.existing?.name);
  late final TextEditingController _cal    = TextEditingController(text: widget.existing?.caliber);
  late final TextEditingController _weight = TextEditingController(
      text: widget.existing?.weightGr?.toStringAsFixed(1) ?? '');
  late final TextEditingController _vel    = TextEditingController(
      text: widget.existing?.velocityMs?.toStringAsFixed(0) ?? '');
  late final TextEditingController _notes  = TextEditingController(text: widget.existing?.notes);

  @override
  void dispose() {
    _name.dispose(); _cal.dispose(); _weight.dispose();
    _vel.dispose(); _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: _sheetDecoration(),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _handle(),
          _sheetHeader(
            widget.existing == null ? 'Новий набій' : 'Редагувати набій',
            'Балістичні характеристики',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(children: [
              _GlassField(label: 'Назва', isRequired: true,
                  controller: _name, hint: 'напр. Hornady ELD-M 208gr'),
              const SizedBox(height: 9),
              _GlassField(label: 'Калібр',
                  controller: _cal, hint: 'напр. .300 Win Mag'),
              const SizedBox(height: 9),
              Row(children: [
                Expanded(child: _GlassField(
                    label: 'Вага, gr', controller: _weight, hint: '208',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                const SizedBox(width: 8),
                Expanded(child: _GlassField(
                    label: 'Швидкість, м/с', controller: _vel, hint: '820',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true))),
              ]),
              const SizedBox(height: 9),
              _GlassField(label: 'Нотатки',
                  controller: _notes, hint: 'опціонально'),
            ]),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16,
                MediaQuery.of(context).padding.bottom + 16),
            child: _Footer(
              onCancel: () => Navigator.pop(context),
              onSave: () async {
                if (_name.text.trim().isEmpty) return;
                final b = Bullet(
                  id: widget.existing?.id,
                  name: _name.text.trim(),
                  caliber: _cal.text.trim().isEmpty ? null : _cal.text.trim(),
                  weightGr: double.tryParse(_weight.text.trim()),
                  velocityMs: double.tryParse(_vel.text.trim()),
                  notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                );
                if (widget.existing == null) {
                  await widget.ep.addBullet(b);
                } else {
                  await widget.ep.updateBullet(b);
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Delete sheet ──────────────────────────────────────────────────────────────

Future<void> _showDeleteSheet(
    BuildContext context, String name, VoidCallback onConfirm) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DeleteSheet(name: name, onConfirm: onConfirm),
  );
}

class _DeleteSheet extends StatelessWidget {
  final String name;
  final VoidCallback onConfirm;
  const _DeleteSheet({required this.name, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _sheetDecoration(),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _handle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(children: [
            const Icon(Icons.delete_outline, size: 40, color: Color(0xFFFF7070)),
            const SizedBox(height: 8),
            const Text('Видалити?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _kText)),
            const SizedBox(height: 6),
            Text('«$name» буде видалено безповоротно.\nПов\'язані сесії залишаться.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0x6BF0EAE5), height: 1.4)),
          ]),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16,
              MediaQuery.of(context).padding.bottom + 16),
          child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0x12FFFFFF),
                  border: Border.all(color: const Color(0x1EFFFFFF), width: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('Скасувати',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                        color: Color(0xA6F0EAE5)))),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                onConfirm();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xD9DC3C3C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('Видалити',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: Colors.white))),
              ),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ── Glass input field ─────────────────────────────────────────────────────────

class _GlassField extends StatelessWidget {
  final String label;
  final bool isRequired;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  const _GlassField({
    required this.label, required this.controller, required this.hint,
    this.isRequired = false, this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                letterSpacing: 0.5, color: Color(0x59F0EAE5))),
        if (isRequired)
          const Text(' *',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: _kAccent)),
      ]),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: _kText),
        cursorColor: _kAccent,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: Color(0x33F0EAE5)),
          filled: true,
          fillColor: const Color(0x0FFFFFFF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0x1FFFFFFF), width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0x1FFFFFFF), width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0x80E87722), width: 0.5),
          ),
        ),
      ),
    ]);
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onSave;
  const _Footer({required this.onCancel, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: GestureDetector(
        onTap: onCancel,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0x12FFFFFF),
            border: Border.all(color: const Color(0x1EFFFFFF), width: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(child: Text('Скасувати',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                  color: Color(0xA6F0EAE5)))),
        ),
      )),
      const SizedBox(width: 8),
      Expanded(flex: 2, child: GestureDetector(
        onTap: onSave,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: _kAccent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(
              color: Color(0x4DE87722), blurRadius: 12, offset: Offset(0, 2),
            )],
          ),
          child: const Center(child: Text('Зберегти',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: Color(0xFF1A0A00)))),
        ),
      )),
    ]);
  }
}
