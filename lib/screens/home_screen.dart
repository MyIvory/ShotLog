import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../database/session_repository.dart';
import '../models/session.dart';
import '../providers/equipment_provider.dart';
import '../providers/session_provider.dart';
import '../services/settings_service.dart';
import '../widgets/parallax_bg.dart';
import 'new_session_sheet.dart';
import 'session_screen.dart';
import 'session_detail_screen.dart';

const _kAccent  = Color(0xFFE87722);
const _kText    = Color(0xFFF0EAE5);
const _kHint    = Color(0x61F0EAE5);

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSettingsTap;
  const HomeScreen({super.key, this.onSettingsTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = SessionRepository();
  List<Session> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await _repo.getAll();
    if (!mounted) return;
    await context.read<EquipmentProvider>().loadAll();
    if (mounted) {
      setState(() { _sessions = sessions; _loading = false; });
    }
  }

  String _subtitle() {
    const months = [
      '', 'січень', 'лютий', 'березень', 'квітень', 'травень', 'червень',
      'липень', 'серпень', 'вересень', 'жовтень', 'листопад', 'грудень',
    ];
    final now = DateTime.now();
    final n = _sessions.length;
    final word = n % 10 == 1 && n % 100 != 11
        ? 'сесія'
        : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)
            ? 'сесії'
            : 'сесій';
    return '$n $word · ${months[now.month]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final mq  = MediaQuery.of(context);
    final top = mq.padding.top;
    final bot = mq.padding.bottom;
    final ep  = context.watch<EquipmentProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: const ParallaxBg(asset: 'assets/images/bg_range.png'),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99100C0A), Color(0xF0100C0A)],
                  stops: [0.0, 0.55],
                ),
              ),
            ),
          ),
          // ── List (full screen, scrolls under header) ──
          if (_loading)
            const Center(child: CircularProgressIndicator(color: _kAccent))
          else if (_sessions.isEmpty)
            _EmptyState(onTap: _startNewSession)
          else
            ListView.separated(
              padding: EdgeInsets.fromLTRB(16, top + 76 + 8, 16, bot + 16),
              itemCount: _sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final s = _sessions[i];
                final rifle = s.rifleId != null
                    ? ep.rifles.where((r) => r.id == s.rifleId).firstOrNull
                    : null;
                return _SessionCard(
                  session: s,
                  rifleName: rifle?.name,
                  caliber: rifle?.caliber,
                  onTap: () async {
                    await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionDetailScreen(sessionId: s.id!),
                      ),
                    );
                    _load();
                  },
                );
              },
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('ShotLog',
                                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                                          color: _kText, letterSpacing: -0.5)),
                                  if (!_loading) ...[
                                    const SizedBox(height: 2),
                                    Text(_subtitle(),
                                        style: const TextStyle(fontSize: 12, color: _kHint)),
                                  ],
                                ],
                              ),
                            ),
                            _GlassBtn(
                              onTap: _startNewSession,
                              child: const Icon(Icons.add, color: _kText, size: 20),
                            ),
                            const SizedBox(width: 8),
                            _GlassBtn(
                              onTap: widget.onSettingsTap,
                              child: const Icon(Icons.settings_outlined, color: _kText, size: 18),
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

  Future<void> _startNewSession() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    if (statuses.values.any((s) => !s.isGranted)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Потрібен доступ до камери та мікрофону')),
      );
      return;
    }

    if (!mounted) return;
    await context.read<EquipmentProvider>().loadAll();

    if (!mounted) return;
    final session = await showModalBottomSheet<Session>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const NewSessionSheet(),
    );

    if (session == null || !mounted) return;

    final settings = await SettingsService().load();
    if (!mounted) return;

    try {
      await context.read<SessionProvider>().startSession(session, settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Помилка запуску сесії: $e')),
        );
      }
      return;
    }
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SessionScreen(settings: settings)),
    );
    _load();
  }
}

// ── Session card ──────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final Session session;
  final String? rifleName;
  final String? caliber;
  final VoidCallback onTap;

  const _SessionCard({
    required this.session,
    required this.onTap,
    this.rifleName,
    this.caliber,
  });

  static const _monthsShort = [
    '', 'січ', 'лют', 'бер', 'квіт', 'тра', 'чер',
    'лип', 'сер', 'вер', 'жов', 'лис', 'гру',
  ];

  String _relativeDate(DateTime dt) {
    final now = DateTime.now();
    final today    = DateTime(now.year, now.month, now.day);
    final cardDate = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(cardDate).inDays;
    if (diff == 0) return 'сьогодні';
    if (diff == 1) return 'вчора';
    if (diff < 7)  return '$diff днів тому';
    return '${dt.day} ${_monthsShort[dt.month]}';
  }

  String _timeRange(Session s) {
    final h = s.createdAt.hour.toString().padLeft(2, '0');
    final m = s.createdAt.minute.toString().padLeft(2, '0');
    if (s.endedAt == null) return '$h:$m';
    final eh = s.endedAt!.hour.toString().padLeft(2, '0');
    final em = s.endedAt!.minute.toString().padLeft(2, '0');
    return '$h:$m — $eh:$em';
  }

  String? _duration(Session s) {
    if (s.endedAt == null) return null;
    final mins = s.endedAt!.difference(s.createdAt).inMinutes;
    return '$mins хв';
  }

  @override
  Widget build(BuildContext context) {
    final dt       = session.createdAt;
    final chips    = <(String, bool)>[
      if (rifleName != null) (rifleName!, true),
      if (caliber   != null) (caliber!, true),
      if (_duration(session) != null) (_duration(session)!, false),
    ];

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                // Date block
                Container(
                  width: 42,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xCCB05010),
                    border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${dt.day}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                              color: _kText, height: 1)),
                      const SizedBox(height: 1),
                      Text(_monthsShort[dt.month],
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                              color: Color(0xB3F0EAE5), letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Name + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.name ?? 'Сесія',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                              color: _kText),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${_relativeDate(dt)} · ${_timeRange(session)}',
                          style: const TextStyle(fontSize: 11, color: _kHint)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Shot badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xCCB05010),
                    border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${session.shotCount}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                              color: _kText, height: 1,
                              fontFeatures: [FontFeature.tabularFigures()])),
                      const SizedBox(height: 1),
                      const Text('постр.',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600,
                              color: Color(0xB3F0EAE5), letterSpacing: 0.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right,
                    size: 16, color: Color(0x38F0EAE5)),
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
      ),
    );
  }
}

// ── Chip ──────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool accent;
  const _Chip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent ? const Color(0x0FE87722) : const Color(0x0FFFFFFF),
        border: Border.all(
          color: accent ? const Color(0x33E87722) : const Color(0x17FFFFFF),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w500,
              color: accent ? const Color(0xBFE87722) : const Color(0x73F0EAE5))),
    );
  }
}

// ── Glass button ─────────────────────────────────────────────────────────────

class _GlassBtn extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _GlassBtn({required this.child, this.onTap});

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

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.fiber_smart_record_outlined,
            size: 72, color: Color(0x4DF0EAE5)),
        const SizedBox(height: 18),
        const Text('Жодної сесії',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _kText)),
        const SizedBox(height: 8),
        const Text('Натисніть кнопку нижче, щоб\nрозпочати перше тренування',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _kHint, height: 1.4)),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(
                color: Color(0x73E87722), blurRadius: 20, offset: Offset(0, 4),
              )],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, color: Color(0xFF1A0A00), size: 20),
              SizedBox(width: 6),
              Text('Нова сесія',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: Color(0xFF1A0A00))),
            ]),
          ),
        ),
      ]),
    );
  }
}
