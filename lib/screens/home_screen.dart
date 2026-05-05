import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../database/session_repository.dart';
import '../database/rifle_repository.dart';
import '../database/bullet_repository.dart';
import '../models/session.dart';
import '../models/rifle.dart';
import '../models/bullet.dart';
import '../providers/equipment_provider.dart';
import '../providers/session_provider.dart';
import '../services/settings_service.dart';
import 'new_session_sheet.dart';
import 'session_screen.dart';
import 'session_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = SessionRepository();
  final _rifleRepo = RifleRepository();
  final _bulletRepo = BulletRepository();
  List<Session> _sessions = [];
  Map<int, Rifle> _rifles = {};
  Map<int, Bullet> _bullets = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await _repo.getAll();
    final rifles = await _rifleRepo.getAll();
    final bullets = await _bulletRepo.getAll();

    if (mounted) {
      setState(() {
        _sessions = sessions;
        _rifles = {for (final r in rifles) r.id!: r};
        _bullets = {for (final b in bullets) b.id!: b};
        _loading = false;
      });
    }
  }

  String _appBarSubtitle() {
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ShotLog'),
            if (!_loading)
              Text(
                _appBarSubtitle(),
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_smart_record_outlined,
                            size: 96,
                            color: cs.outlineVariant),
                        const SizedBox(height: 24),
                        Text('Жодної сесії',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text(
                          'Натисніть кнопку нижче, щоб розпочати перше тренування',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 7, bottom: 88),
                    itemCount: _sessions.length,
                    itemBuilder: (ctx, i) => _SessionCard(
                      session: _sessions[i],
                      rifle: _sessions[i].rifleId != null
                          ? _rifles[_sessions[i].rifleId!]
                          : null,
                      bullet: _sessions[i].bulletId != null
                          ? _bullets[_sessions[i].bulletId!]
                          : null,
                      onTap: () async {
                        await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SessionDetailScreen(sessionId: _sessions[i].id!),
                          ),
                        );
                        _load();
                      },
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Нова сесія'),
        onPressed: _startNewSession,
      ),
    );
  }

  Future<void> _startNewSession() async {
    final statuses =
        await [Permission.camera, Permission.microphone].request();
    if (statuses.values.any((s) => !s.isGranted)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Потрібен доступ до камери та мікрофону')),
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

// ── Session Card ─────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final Session session;
  final Rifle? rifle;
  final Bullet? bullet;
  final VoidCallback onTap;

  const _SessionCard({
    required this.session,
    this.rifle,
    this.bullet,
    required this.onTap,
  });

  static const _monthsShort = [
    '', 'січ', 'лют', 'бер', 'квіт', 'трав', 'черв',
    'лип', 'серп', 'вер', 'жовт', 'лист', 'груд',
  ];

  String _formatCardDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_monthsShort[dt.month]} ${dt.year} · $h:$m';
  }

  bool get _hasChips =>
      rifle != null || bullet != null || session.distanceM != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
      child: Material(
        color: const Color(0xFF261E1A),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF33281F)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.name ?? 'Сесія',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFF0EAE5),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatCardDate(session.createdAt),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF7A6E68),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Badge(count: session.shotCount),
                  ],
                ),
                if (_hasChips) ...[
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (rifle != null) _WarmChip(label: rifle!.name),
                      if (bullet != null) _WarmChip(label: bullet!.name),
                      if (session.distanceM != null)
                        _WarmChip(
                            label:
                                '${session.distanceM!.toStringAsFixed(0)}м'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE87722),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Color(0xFF1A0A00),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WarmChip extends StatelessWidget {
  final String label;
  const _WarmChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF33281F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF4A3528)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFFC89A6A), fontSize: 9),
      ),
    );
  }
}
