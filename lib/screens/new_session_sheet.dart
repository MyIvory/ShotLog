import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bullet.dart';
import '../models/rifle.dart';
import '../models/session.dart';
import '../providers/equipment_provider.dart';
import '../services/weather_service.dart';
import '../widgets/parallax_bg.dart';

const _kText        = Color(0xFFF0EAE5);
const _kHint        = Color(0x61F0EAE5);
const _kAccent      = Color(0xFFE87722);
const _kGlassBg     = Color(0x26FFFFFF);
const _kGlassBorder = Color(0x28FFFFFF);

// ── Entry point ────────────────────────────────────────────────────────────────

Future<Session?> showNewSessionScreen(BuildContext context) =>
    Navigator.push<Session>(
      context,
      MaterialPageRoute(builder: (_) => const NewSessionScreen()),
    );

// ── Screen ────────────────────────────────────────────────────────────────────

class NewSessionScreen extends StatefulWidget {
  const NewSessionScreen({super.key});

  @override
  State<NewSessionScreen> createState() => _NewSessionScreenState();
}

class _NewSessionScreenState extends State<NewSessionScreen> {
  Rifle?  _rifle;
  Bullet? _bullet;
  bool _fetchingWeather = false;
  bool _nameError       = false;

  final _nameCtrl    = TextEditingController();
  final _distCtrl    = TextEditingController();
  final _weatherCtrl = TextEditingController();
  final _notesCtrl   = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _distCtrl.dispose();
    _weatherCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    Navigator.of(context).pop(Session(
      name:      _nameCtrl.text.trim(),
      createdAt: DateTime.now(),
      rifleId:   _rifle?.id,
      bulletId:  _bullet?.id,
      distanceM: double.tryParse(_distCtrl.text.trim()),
      weather:   _weatherCtrl.text.trim().isEmpty ? null : _weatherCtrl.text.trim(),
      notes:     _notesCtrl.text.trim().isEmpty   ? null : _notesCtrl.text.trim(),
    ));
  }

  Future<void> _fetchWeather() async {
    setState(() => _fetchingWeather = true);
    try {
      final w = await WeatherService().fetchWeatherString();
      if (mounted) setState(() => _weatherCtrl.text = w);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не вдалося отримати погоду: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingWeather = false);
    }
  }

  Future<void> _pickRifle() async {
    final ep     = context.read<EquipmentProvider>();
    final result = await _showGlassPicker<Rifle>(
      context:       context,
      title:         'Гвинтівка',
      items:         ep.rifles,
      selected:      _rifle,
      displayString: (r) => r.displayName,
      isEqual:       (a, b) => a.id != null && a.id == b.id,
    );
    if (result != null && mounted) setState(() => _rifle = result);
  }

  Future<void> _pickBullet() async {
    final ep     = context.read<EquipmentProvider>();
    final result = await _showGlassPicker<Bullet>(
      context:       context,
      title:         'Набій',
      items:         ep.bullets,
      selected:      _bullet,
      displayString: (b) => b.displayName,
      isEqual:       (a, b) => a.id != null && a.id == b.id,
    );
    if (result != null && mounted) setState(() => _bullet = result);
  }

  Future<void> _addRifle() async {
    final rifle = await showModalBottomSheet<Rifle>(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder:            (_) => const _AddRifleSheet(),
    );
    if (rifle != null && mounted) setState(() => _rifle = rifle);
  }

  Future<void> _addBullet() async {
    final bullet = await showModalBottomSheet<Bullet>(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder:            (_) => const _AddBulletSheet(),
    );
    if (bullet != null && mounted) setState(() => _bullet = bullet);
  }

  @override
  Widget build(BuildContext context) {
    final mq  = MediaQuery.of(context);
    final top = mq.padding.top;
    final bot = mq.padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Background ──────────────────────────────────────────────────────
          const Positioned.fill(
            child: ParallaxBg(asset: 'assets/images/bg_range.png'),
          ),
          Positioned.fill(child: Container(color: const Color(0xB8100C0A))),
          Positioned.fill(
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE60C0A08)],
                  stops: [0.25, 1.0],
                ),
              ),
            ),
          ),

          // ── Form content ────────────────────────────────────────────────────
          Positioned.fill(
            child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, top + 76 + 8, 16, 24 + bot),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Назва
                _GlassCard(children: [
                  _GlassTextField(
                    ctrl:      _nameCtrl,
                    label:     'Назва сесії',
                    hint:      'напр. Тренування на 100м',
                    required:  true,
                    errorText: _nameError ? 'Обов\'язкове поле' : null,
                    onChanged: (_) {
                      if (_nameError) setState(() => _nameError = false);
                    },
                  ),
                ]),
                const SizedBox(height: 10),

                // Спорядження
                _GlassCard(children: [
                  _SelectorRow(
                    label: 'Гвинтівка',
                    value: _rifle?.displayName,
                    onTap: _pickRifle,
                    onAdd: _addRifle,
                  ),
                  _kCardDivider,
                  _SelectorRow(
                    label: 'Набій',
                    value: _bullet?.displayName,
                    onTap: _pickBullet,
                    onAdd: _addBullet,
                  ),
                ]),
                const SizedBox(height: 10),

                // Умови
                _GlassCard(children: [
                  _GlassTextField(
                    ctrl:         _distCtrl,
                    label:        'Дистанція',
                    suffix:       'м',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  _kCardDivider,
                  Row(children: [
                    Expanded(
                      child: _GlassTextField(
                        ctrl:  _weatherCtrl,
                        label: 'Погода / умови',
                        hint:  'напр. вітер 3 м/с, +12°C',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _WeatherBtn(loading: _fetchingWeather, onTap: _fetchWeather),
                    ),
                  ]),
                ]),
                const SizedBox(height: 10),

                // Нотатки
                _GlassCard(children: [
                  _GlassTextField(ctrl: _notesCtrl, label: 'Нотатки', maxLines: 3),
                ]),
              ],
            ),
          )),

          // ── Glass header ────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.transparent,
                  child: Column(children: [
                    SizedBox(height: top),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Нова сесія',
                                    style: TextStyle(
                                        fontSize: 26, fontWeight: FontWeight.w700,
                                        color: _kText, letterSpacing: -0.5)),
                                SizedBox(height: 2),
                                Text('Заповни деталі тренування',
                                    style: TextStyle(fontSize: 12, color: _kHint)),
                              ],
                            ),
                          ),
                          _HeaderBtn(
                            icon:  Icons.west,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 8),
                          _HeaderBtn(
                            icon:  Icons.play_arrow,
                            onTap: _submit,
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glass Card ────────────────────────────────────────────────────────────────

const _kCardDivider = Divider(
  height: 1, thickness: 0.5,
  color: Color(0x20FFFFFF),
  indent: 16, endIndent: 16,
);

class _GlassCard extends StatelessWidget {
  final List<Widget> children;
  const _GlassCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color:        _kGlassBg,
          border:       Border.all(color: _kGlassBorder, width: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
}

// ── Glass Text Field ──────────────────────────────────────────────────────────

class _GlassTextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String  label;
  final String? hint;
  final String? errorText;
  final String? suffix;
  final int     maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool required;

  const _GlassTextField({
    required this.ctrl,
    required this.label,
    this.hint,
    this.errorText,
    this.suffix,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller:   ctrl,
          maxLines:     maxLines,
          keyboardType: keyboardType,
          onChanged:    onChanged,
          style:        const TextStyle(color: _kText, fontSize: 15),
          cursorColor:  _kAccent,
          decoration: InputDecoration(
            labelText:   required ? '$label *' : label,
            labelStyle:  const TextStyle(color: _kHint, fontSize: 13),
            hintText:    hint,
            hintStyle:   const TextStyle(color: _kHint, fontSize: 14),
            errorText:   errorText,
            errorStyle:  const TextStyle(color: Color(0xFFFF6050), fontSize: 11),
            suffixText:  suffix,
            suffixStyle: const TextStyle(color: _kHint, fontSize: 14),
            border:      InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      );
}

// ── Selector Row (rifle / bullet) ─────────────────────────────────────────────

class _SelectorRow extends StatelessWidget {
  final String  label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const _SelectorRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(color: _kHint, fontSize: 12, height: 1)),
                  const SizedBox(height: 3),
                  Text(
                    value ?? 'Не вибрано',
                    style: TextStyle(
                      color:    value != null ? _kText : _kHint,
                      fontSize: 15,
                      height:   1,
                    ),
                  ),
                ],
              ),
            ),
            // Add button — consumes tap before the parent GestureDetector
            GestureDetector(
              onTap:    onAdd,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width:  32, height: 32,
                decoration: BoxDecoration(
                  color:        const Color(0x1AFFFFFF),
                  border:       Border.all(color: const Color(0x1EFFFFFF), width: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(child: Icon(Icons.add, color: _kText, size: 16)),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

// ── Weather button ────────────────────────────────────────────────────────────

class _WeatherBtn extends StatelessWidget {
  final bool         loading;
  final VoidCallback onTap;

  const _WeatherBtn({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color:        const Color(0x1AFFFFFF),
            border:       Border.all(color: const Color(0x1EFFFFFF), width: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: _kText),
                  )
                : const Icon(Icons.cloud_download_outlined, color: _kText, size: 16),
          ),
        ),
      );
}

// ── Header button ─────────────────────────────────────────────────────────────

class _HeaderBtn extends StatelessWidget {
  final IconData      icon;
  final VoidCallback? onTap;

  const _HeaderBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color:        const Color(0x1AFFFFFF),
            border:       Border.all(color: const Color(0x1EFFFFFF), width: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Icon(icon, color: _kText, size: 20)),
        ),
      );
}

// ── Add Equipment Sheets ──────────────────────────────────────────────────────

class _AddRifleSheet extends StatefulWidget {
  const _AddRifleSheet();

  @override
  State<_AddRifleSheet> createState() => _AddRifleSheetState();
}

class _AddRifleSheetState extends State<_AddRifleSheet> {
  final _nameCtrl = TextEditingController();
  final _calCtrl  = TextEditingController();
  bool _nameError = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    final ep    = context.read<EquipmentProvider>();
    final rifle = await ep.addRifle(Rifle(
      name:    _nameCtrl.text.trim(),
      caliber: _calCtrl.text.trim().isEmpty ? null : _calCtrl.text.trim(),
    ));
    if (mounted) Navigator.of(context).pop(rifle);
  }

  @override
  Widget build(BuildContext context) {
    final bot = MediaQuery.paddingOf(context).bottom
        + MediaQuery.viewInsetsOf(context).bottom;
    return _EquipSheet(
      title:     'Нова гвинтівка',
      onSubmit:  _submit,
      botInset:  bot,
      children: [
        _GlassTextField(
          ctrl:      _nameCtrl,
          label:     'Назва',
          required:  true,
          errorText: _nameError ? 'Обов\'язкове поле' : null,
          onChanged: (_) { if (_nameError) setState(() => _nameError = false); },
        ),
        _kCardDivider,
        _GlassTextField(ctrl: _calCtrl, label: 'Калібр'),
      ],
    );
  }
}

class _AddBulletSheet extends StatefulWidget {
  const _AddBulletSheet();

  @override
  State<_AddBulletSheet> createState() => _AddBulletSheetState();
}

class _AddBulletSheetState extends State<_AddBulletSheet> {
  final _nameCtrl     = TextEditingController();
  final _calCtrl      = TextEditingController();
  final _weightCtrl   = TextEditingController();
  final _velocityCtrl = TextEditingController();
  bool _nameError = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _weightCtrl.dispose();
    _velocityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    final ep     = context.read<EquipmentProvider>();
    final bullet = await ep.addBullet(Bullet(
      name:       _nameCtrl.text.trim(),
      caliber:    _calCtrl.text.trim().isEmpty ? null : _calCtrl.text.trim(),
      weightGr:   double.tryParse(_weightCtrl.text.trim()),
      velocityMs: double.tryParse(_velocityCtrl.text.trim()),
    ));
    if (mounted) Navigator.of(context).pop(bullet);
  }

  @override
  Widget build(BuildContext context) {
    final bot = MediaQuery.paddingOf(context).bottom
        + MediaQuery.viewInsetsOf(context).bottom;
    return _EquipSheet(
      title:    'Новий набій',
      onSubmit: _submit,
      botInset: bot,
      children: [
        _GlassTextField(
          ctrl:      _nameCtrl,
          label:     'Назва',
          required:  true,
          errorText: _nameError ? 'Обов\'язкове поле' : null,
          onChanged: (_) { if (_nameError) setState(() => _nameError = false); },
        ),
        _kCardDivider,
        _GlassTextField(ctrl: _calCtrl, label: 'Калібр'),
        _kCardDivider,
        _GlassTextField(
          ctrl:         _weightCtrl,
          label:        'Вага',
          suffix:       'gr',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        _kCardDivider,
        _GlassTextField(
          ctrl:         _velocityCtrl,
          label:        'Швидкість',
          suffix:       'м/с',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }
}

// Shared shell for add-equipment sheets
class _EquipSheet extends StatelessWidget {
  final String       title;
  final VoidCallback onSubmit;
  final double       botInset;
  final List<Widget> children;

  const _EquipSheet({
    required this.title,
    required this.onSubmit,
    required this.botInset,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color:  Color(0x2AFFFFFF),
            border: Border(top: BorderSide(color: _kGlassBorder, width: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 32, height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0x40FFFFFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600,
                              color: _kText)),
                    ),
                    _HeaderBtn(
                      icon:  Icons.west,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    _HeaderBtn(
                      icon:  Icons.check,
                      onTap: onSubmit,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.5, color: Color(0x20FFFFFF)),
              // Fields
              ...children,
              SizedBox(height: 16 + botInset),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Glass Picker Sheet ────────────────────────────────────────────────────────

Future<T?> _showGlassPicker<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required T? selected,
  required String Function(T) displayString,
  required bool Function(T, T) isEqual,
}) =>
    showModalBottomSheet<T>(
      context:         context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _GlassPickerSheet<T>(
        title:         title,
        items:         items,
        selected:      selected,
        displayString: displayString,
        isEqual:       isEqual,
      ),
    );

class _GlassPickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final T? selected;
  final String Function(T) displayString;
  final bool Function(T, T) isEqual;

  const _GlassPickerSheet({
    required this.title,
    required this.items,
    required this.selected,
    required this.displayString,
    required this.isEqual,
  });

  bool _isSelected(T item) =>
      selected != null && isEqual(item, selected as T);

  @override
  Widget build(BuildContext context) {
    final bot = MediaQuery.paddingOf(context).bottom;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0x2AFFFFFF),
            border: Border(top: BorderSide(color: _kGlassBorder, width: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 32, height: 3,
                  decoration: BoxDecoration(
                    color:        const Color(0x40FFFFFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600, color: _kText)),
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Text(
                    'Список порожній.\nДодайте спорядження у розділі Налаштування.',
                    style: const TextStyle(color: _kHint, fontSize: 14, height: 1.5),
                  ),
                )
              else
                ...items.map((item) => _PickerItem(
                      label:    displayString(item),
                      selected: _isSelected(item),
                      onTap:    () => Navigator.of(context).pop(item),
                    )),
              SizedBox(height: 16 + bot),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerItem extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  const _PickerItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      color:      selected ? _kAccent : _kText,
                      fontSize:   15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    )),
              ),
              if (selected)
                const Icon(Icons.check, color: _kAccent, size: 18),
            ],
          ),
        ),
      );
}
