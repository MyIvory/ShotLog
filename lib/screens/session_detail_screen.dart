import 'package:flutter/material.dart';
import '../database/session_repository.dart';
import '../database/shot_repository.dart';
import '../database/rifle_repository.dart';
import '../database/bullet_repository.dart';
import '../models/session.dart';
import '../models/shot.dart';
import '../models/rifle.dart';
import '../models/bullet.dart';
import '../services/settings_service.dart';
import '../widgets/shot_list_item.dart';
import '../widgets/video_player_overlay.dart';

class SessionDetailScreen extends StatefulWidget {
  final int sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  Session? _session;
  List<Shot> _shots = [];
  Rifle? _rifle;
  Bullet? _bullet;
  int _preRollSec = 2;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessionFuture = SessionRepository().getById(widget.sessionId);
    final shotsFuture = ShotRepository().getBySession(widget.sessionId);
    final settingsFuture = SettingsService().load();

    final results = await Future.wait([sessionFuture, shotsFuture, settingsFuture]);
    final session = results[0] as Session?;
    final shots = results[1] as List<Shot>;
    final settings = results[2] as dynamic;

    Rifle? rifle;
    Bullet? bullet;
    if (session?.rifleId != null) {
      final all = await RifleRepository().getAll();
      rifle = all.where((r) => r.id == session!.rifleId).firstOrNull;
    }
    if (session?.bulletId != null) {
      final all = await BulletRepository().getAll();
      bullet = all.where((b) => b.id == session!.bulletId).firstOrNull;
    }

    if (mounted) {
      setState(() {
        _session = session;
        _shots = shots;
        _rifle = rifle;
        _bullet = bullet;
        _preRollSec = settings.preRollSec as int;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_session != null ? _formatDate(_session!.createdAt) : 'Сесія'),
      ),
      body: Column(
        children: [
          _MetaCard(session: _session, rifle: _rifle, bullet: _bullet),
          Expanded(
            child: _shots.isEmpty
                ? const Center(child: Text('Немає пострілів у цій сесії'))
                : ListView.builder(
                    itemCount: _shots.length,
                    itemBuilder: (ctx, i) => ShotListItem(
                      shot: _shots[i],
                      onTap: () => _openPlayer(_shots[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _openPlayer(Shot shot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VideoPlayerOverlay(shot: shot, preRollSec: _preRollSec),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _MetaCard extends StatelessWidget {
  final Session? session;
  final Rifle? rifle;
  final Bullet? bullet;

  const _MetaCard({this.session, this.rifle, this.bullet});

  @override
  Widget build(BuildContext context) {
    if (session == null) return const SizedBox.shrink();
    final rows = <(String, String?)>[
      ('Гвинтівка', rifle?.displayName),
      ('Набій', bullet?.displayName),
      ('Дистанція', session!.distanceM != null ? '${session!.distanceM!.toStringAsFixed(0)} м' : null),
      ('Погода', session!.weather),
      ('Нотатки', session!.notes),
    ].where((e) => e.$2 != null).toList();

    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows
              .map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(e.$1, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ),
                        Expanded(child: Text(e.$2!, style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
