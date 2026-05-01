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
import 'settings_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ShotLog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('Немає сесій. Натисніть + щоб почати тренування.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (ctx, i) => _SessionTile(
                      session: _sessions[i],
                      rifle: _sessions[i].rifleId != null ? _rifles[_sessions[i].rifleId!] : null,
                      bullet: _sessions[i].bulletId != null ? _bullets[_sessions[i].bulletId!] : null,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SessionDetailScreen(sessionId: _sessions[i].id!),
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
    // Request runtime permissions before opening the session form.
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

    await context.read<SessionProvider>().startSession(session, settings);
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SessionScreen(settings: settings)),
    );

    _load();
  }
}

class _SessionTile extends StatelessWidget {
  final Session session;
  final Rifle? rifle;
  final Bullet? bullet;
  final VoidCallback onTap;

  const _SessionTile({
    required this.session,
    this.rifle,
    this.bullet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(session.createdAt);
    final subtitle = [
      if (rifle != null) rifle!.displayName,
      if (bullet != null) bullet!.displayName,
      if (session.distanceM != null) '${session.distanceM!.toStringAsFixed(0)} м',
    ].join(' · ');

    return ListTile(
      leading: CircleAvatar(
        child: Text('${session.shotCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      title: Text(dateStr),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
