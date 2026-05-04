import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../database/session_repository.dart';
import '../database/shot_repository.dart';
import '../database/rifle_repository.dart';
import '../database/bullet_repository.dart';
import '../models/session.dart';
import '../models/shot.dart';
import '../models/rifle.dart';
import '../models/bullet.dart';
import '../providers/session_provider.dart';
import '../services/settings_service.dart';
import '../widgets/shot_list_item.dart';
import '../widgets/video_player_overlay.dart';
import 'session_screen.dart';

class SessionDetailScreen extends StatefulWidget {
  final int sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _sessionRepo = SessionRepository();
  final _shotRepo = ShotRepository();

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
    final sessionFuture = _sessionRepo.getById(widget.sessionId);
    final shotsFuture = _shotRepo.getBySession(widget.sessionId);
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

  Future<void> _deleteShot(Shot shot) async {
    await _shotRepo.delete(shot.id!);
    try { await File(shot.clipPath).delete(); } catch (_) {}
    if (shot.thumbnailPath != null) {
      try { await File(shot.thumbnailPath!).delete(); } catch (_) {}
    }
    final updated = _session!.copyWith(shotCount: _session!.shotCount - 1);
    await _sessionRepo.update(updated);
    setState(() {
      _shots.removeWhere((s) => s.id == shot.id);
      _session = updated;
    });
  }

  Future<void> _deleteSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Видалити сесію?'),
        content: const Text('Всі відео та дані сесії будуть видалені безповоротно.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Скасувати')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Видалити'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    for (final shot in _shots) {
      try { await File(shot.clipPath).delete(); } catch (_) {}
      if (shot.thumbnailPath != null) {
        try { await File(shot.thumbnailPath!).delete(); } catch (_) {}
      }
    }
    await _shotRepo.deleteBySession(widget.sessionId);
    await _sessionRepo.delete(widget.sessionId);

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _continueSession() async {
    if (_session == null) return;
    final settings = await SettingsService().load();
    if (!mounted) return;
    await context.read<SessionProvider>().continueSession(_session!, settings);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SessionScreen(settings: settings)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_session?.name ?? _formatDate(_session!.createdAt)),
      ),
      body: Column(
        children: [
          _MetaSection(
            session: _session,
            rifle: _rifle,
            bullet: _bullet,
            shots: _shots,
          ),
          Expanded(
            child: _shots.isEmpty
                ? const Center(child: Text('Немає пострілів у цій сесії'))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 6, bottom: 8),
                    itemCount: _shots.length,
                    itemBuilder: (ctx, i) => ShotListItem(
                      shot: _shots[i],
                      preRollMs: _shots[i].shotOffsetMs,
                      onTap: () => _openPlayer(_shots[i]),
                      onDelete: () => _deleteShot(_shots[i]),
                    ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Видалити',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red)),
                      onPressed: _deleteSession,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Продовжити'),
                      onPressed: _continueSession,
                    ),
                  ),
                ],
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
        builder: (_) =>
            VideoPlayerOverlay(shot: shot, preRollSec: _preRollSec),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}'
        '.${dt.month.toString().padLeft(2, '0')}'
        '.${dt.year}';
  }
}

// ── Meta section (chips + stats) ─────────────────────────────────────────────

class _MetaSection extends StatelessWidget {
  final Session? session;
  final Rifle? rifle;
  final Bullet? bullet;
  final List<Shot> shots;

  const _MetaSection({this.session, this.rifle, this.bullet, required this.shots});

  @override
  Widget build(BuildContext context) {
    if (session == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final withDbfs = shots.where((s) => s.triggerDbfs != null).toList();
    final avgDbfs = withDbfs.isNotEmpty
        ? withDbfs.map((s) => s.triggerDbfs!).reduce((a, b) => a + b) /
            withDbfs.length
        : null;

    final duration = session!.endedAt != null
        ? _formatDuration(
            session!.endedAt!.difference(session!.createdAt))
        : '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chips row
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (rifle != null) _WarmChip(label: rifle!.displayName),
              if (bullet != null) _WarmChip(label: bullet!.displayName),
              if (session!.distanceM != null)
                _WarmChip(
                    label:
                        '${session!.distanceM!.toStringAsFixed(0)}м'),
              _WarmChip(label: _formatDateShort(session!.createdAt)),
            ],
          ),
        ),
        // Stats row
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Row(
            children: [
              Expanded(
                  child: _StatCard(
                      value: '${session!.shotCount}',
                      label: 'Постр.')),
              const SizedBox(width: 6),
              Expanded(
                  child: _StatCard(
                      value: avgDbfs != null
                          ? avgDbfs.toStringAsFixed(1)
                          : '--',
                      label: 'Сер. dBFS')),
              const SizedBox(width: 6),
              Expanded(
                  child: _StatCard(value: duration, label: 'Тривал.')),
            ],
          ),
        ),
        if (session!.notes != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Text(
              session!.notes!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _formatDateShort(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}'
        '.${dt.month.toString().padLeft(2, '0')}'
        '.${(dt.year % 100).toString().padLeft(2, '0')}';
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF261E1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF33281F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE87722),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(fontSize: 8, color: Color(0xFF7A6E68)),
          ),
        ],
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF4A3528)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Color(0xFFC89A6A), fontSize: 9),
      ),
    );
  }
}
