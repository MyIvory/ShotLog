import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
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
import '../widgets/parallax_bg.dart';
import '../widgets/shot_list_item.dart';
import '../widgets/video_player_overlay.dart';
import 'session_screen.dart';

const _kText   = Color(0xFFF0EAE5);
const _kHint   = Color(0x61F0EAE5);
const _kAccent = Color(0xFFE87722);

class SessionDetailScreen extends StatefulWidget {
  final int sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _sessionRepo = SessionRepository();
  final _shotRepo    = ShotRepository();

  Session? _session;
  List<Shot> _shots = [];
  Rifle?   _rifle;
  Bullet?  _bullet;
  int _preRollSec = 2;
  bool _loading   = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _sessionRepo.getById(widget.sessionId),
      _shotRepo.getBySession(widget.sessionId),
      SettingsService().load(),
    ]);
    final session  = results[0] as Session?;
    final shots    = results[1] as List<Shot>;
    final settings = results[2] as dynamic;

    Rifle?  rifle;
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
        _session    = session;
        _shots      = shots;
        _rifle      = rifle;
        _bullet     = bullet;
        _preRollSec = settings.preRollSec as int;
        _loading    = false;
      });
      _generateMissingThumbnails(shots);
    }
  }

  Future<void> _generateMissingThumbnails(List<Shot> shots) async {
    for (final shot in shots) {
      if (!File(shot.clipPath).existsSync()) continue;
      String? thumbPath = shot.thumbnailPath;
      int? durationMs  = shot.durationMs;

      try {
        if (thumbPath == null) {
          thumbPath = await VideoThumbnail.thumbnailFile(
            video: shot.clipPath,
            thumbnailPath: shot.clipPath.replaceAll('.mp4', '_thumb.jpg'),
            imageFormat: ImageFormat.JPEG,
            timeMs: shot.shotOffsetMs,
            quality: 75,
          );
          if (thumbPath != null && shot.id != null) {
            await _shotRepo.updateThumbnail(shot.id!, thumbPath);
          }
        }

        if (durationMs == null && shot.id != null) {
          final ctrl = VideoPlayerController.file(File(shot.clipPath));
          await ctrl.initialize();
          durationMs = ctrl.value.duration.inMilliseconds;
          await ctrl.dispose();
          await _shotRepo.updateDuration(shot.id!, durationMs);
        }
      } catch (_) {}

      if (mounted && (thumbPath != shot.thumbnailPath || durationMs != shot.durationMs)) {
        setState(() {
          final idx = _shots.indexWhere((s) => s.id == shot.id);
          if (idx != -1) {
            _shots[idx] = _shots[idx].copyWith(
              thumbnailPath: thumbPath,
              durationMs: durationMs,
            );
          }
        });
      }
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
    final confirm = await _showGlassConfirm(
      context: context,
      title: 'Видалити сесію?',
      body: 'Всі відео та дані сесії будуть видалені безповоротно.',
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
    try {
      await context.read<SessionProvider>().continueSession(_session!, settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Помилка запуску сесії: $e')),
        );
      }
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SessionScreen(settings: settings)),
    );
    _load();
  }

  void _showInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      isScrollControlled: true,
      builder: (_) => _InfoSheet(
        session: _session,
        rifle: _rifle,
        bullet: _bullet,
        shots: _shots,
        onDelete: () {
          Navigator.of(context).pop(); // закрити модалку
          _deleteSession();
        },
      ),
    );
  }

  void _openPlayer(Shot shot) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => VideoPlayerOverlay(shot: shot, preRollSec: _preRollSec),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mq  = MediaQuery.of(context);
    final top = mq.padding.top;
    final bot = mq.padding.bottom;

    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF100C0A),
        body: const Center(child: CircularProgressIndicator(color: _kAccent)),
      );
    }

    final session  = _session;
    final title    = session?.name ?? _formatDate(session!.createdAt);
    final subtitle = _buildSubtitle(session);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Background (same as HomeScreen) ─────────────────────────
          const Positioned.fill(
            child: ParallaxBg(asset: 'assets/images/bg_range.png'),
          ),
          Positioned.fill(
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99100C0A), Color(0xF0100C0A)],
                  stops: [0.0, 0.55],
                ),
              ),
            ),
          ),

          // ── Shot list ────────────────────────────────────────────────
          _shots.isEmpty
              ? Center(
                  child: Text('Немає пострілів у цій сесії',
                      style: const TextStyle(color: _kHint, fontSize: 15)),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, top + 76 + 8, 16, bot + 16),
                  itemCount: _shots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => ShotListItem(
                    shot: _shots[i],
                    preRollMs: _shots[i].shotOffsetMs,
                    onTap: () => _openPlayer(_shots[i]),
                    onDelete: () => _deleteShot(_shots[i]),
                  ),
                ),

          // ── Glass header ─────────────────────────────────────────────
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
                                  Text(title,
                                      style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          color: _kText,
                                          letterSpacing: -0.5),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text(subtitle,
                                      style: const TextStyle(
                                          fontSize: 12, color: _kHint)),
                                ],
                              ),
                            ),
                            _SessBtn(
                              onTap: () => Navigator.of(context).pop(),
                              child: const Icon(Icons.west,
                                  color: _kText, size: 18),
                            ),
                            const SizedBox(width: 8),
                            _SessBtn(
                              onTap: _showInfo,
                              child: const Icon(Icons.info_outline,
                                  color: _kText, size: 18),
                            ),
                            const SizedBox(width: 8),
                            _SessBtn(
                              onTap: _continueSession,
                              child: const Icon(Icons.play_arrow,
                                  color: _kText, size: 18),
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

  String _buildSubtitle(Session? session) {
    if (session == null) return '';
    final dt = session.createdAt;
    const months = ['', 'січ', 'лют', 'бер', 'квіт', 'тра', 'чер',
        'лип', 'сер', 'вер', 'жов', 'лис', 'гру'];
    final date = '${dt.day} ${months[dt.month]} ${dt.year}';
    final n    = session.shotCount;
    final word = n % 10 == 1 && n % 100 != 11
        ? 'постріл'
        : n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)
            ? 'постріли'
            : 'пострілів';
    return '$date · $n $word';
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}'
      '.${dt.month.toString().padLeft(2, '0')}'
      '.${dt.year}';
}

// ── Glass confirm dialog ──────────────────────────────────────────────────────

Future<bool?> _showGlassConfirm({
  required BuildContext context,
  required String title,
  required String body,
  String confirmLabel = 'Видалити',
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                decoration: BoxDecoration(
                  color: const Color(0x26FFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0x28FFFFFF), width: 0.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _kText)),
                    const SizedBox(height: 8),
                    Text(body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13,
                            color: _kHint,
                            height: 1.4)),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, false),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0x1AFFFFFF),
                              border: Border.all(
                                  color: const Color(0x1EFFFFFF),
                                  width: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text('Скасувати',
                                  style: TextStyle(
                                      fontSize: 14, color: _kText)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, true),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0x33FF4040),
                              border: Border.all(
                                  color: const Color(0x55FF4040),
                                  width: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(confirmLabel,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFFF6B6B))),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ── Info modal ────────────────────────────────────────────────────────────────

class _InfoSheet extends StatelessWidget {
  final Session? session;
  final Rifle?   rifle;
  final Bullet?  bullet;
  final List<Shot> shots;
  final VoidCallback? onDelete;

  const _InfoSheet({
    this.session, this.rifle, this.bullet,
    required this.shots, this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bot = MediaQuery.of(context).padding.bottom;
    if (session == null) return const SizedBox.shrink();

    final withDbfs = shots.where((s) => s.triggerDbfs != null).toList();
    final avgDbfs  = withDbfs.isNotEmpty
        ? withDbfs.map((s) => s.triggerDbfs!).reduce((a, b) => a + b) /
            withDbfs.length
        : null;
    final duration = session!.durationSec != null
        ? _fmtDuration(Duration(seconds: session!.durationSec!))
        : null;

    final chips = <String>[
      if (rifle  != null) rifle!.displayName,
      if (bullet != null) bullet!.displayName,
      if (session!.distanceM != null)
        '${session!.distanceM!.toStringAsFixed(0)} м',
      if (avgDbfs != null) '${avgDbfs.toStringAsFixed(1)} dBFS',
      if (duration != null) duration,
      if (session!.weather != null && session!.weather!.isNotEmpty)
        ...session!.weather!.split(' · ').map((s) => s.trim()),
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, bot + 20),
          decoration: const BoxDecoration(
            color: Color(0x1AFFFFFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top:   BorderSide(color: Color(0x1EFFFFFF), width: 0.5),
              left:  BorderSide(color: Color(0x1EFFFFFF), width: 0.5),
              right: BorderSide(color: Color(0x1EFFFFFF), width: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Деталі сесії',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                      color: _kText)),
              const SizedBox(height: 12),
              if (chips.isNotEmpty)
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: chips.map(_InfoChip.new).toList(),
                ),
              if (session!.notes != null && session!.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x0FFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0x15FFFFFF), width: 0.5),
                  ),
                  child: Text(session!.notes!,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0x99F0EAE5),
                          height: 1.4)),
                ),
              ],
              if (onDelete != null) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0x44FF4040),
                      border: Border.all(
                          color: const Color(0x88FF4040), width: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline,
                            size: 16, color: Color(0xFFFF6B6B)),
                        SizedBox(width: 6),
                        Text('Видалити сесію',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFFF6B6B))),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip(this.label);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x28FFFFFF), width: 0.5),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xCCF0EAE5))),
        ),
      ),
    );
  }
}

// ── Glass button ──────────────────────────────────────────────────────────────

class _SessBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _SessBtn({required this.onTap, required this.child});

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
