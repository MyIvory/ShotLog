import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/shot.dart';

const _kText   = Color(0xFFF0EAE5);
const _kHint   = Color(0x61F0EAE5);
const _kAccent = Color(0xFFE87722);

class ShotListItem extends StatelessWidget {
  final Shot shot;
  final int preRollMs;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ShotListItem({
    super.key,
    required this.shot,
    this.preRollMs = 0,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tile = GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x26FFFFFF),
          border: Border.all(color: const Color(0x28FFFFFF), width: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // ── Thumbnail ──────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(13)),
              child: _Thumbnail(path: shot.thumbnailPath),
            ),
            const SizedBox(width: 12),
            // ── Chips ──────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    _ShotChip(
                      label: '#${shot.shotNumber}',
                      accent: true,
                    ),
                    _ShotChip(label: _fmtTime(shot.detectedAt)),
                    if (shot.durationMs != null)
                      _ShotChip(label: _fmtDuration(shot.durationMs!)),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right,
                  size: 16, color: Color(0x38F0EAE5)),
            ),
          ],
        ),
      ),
    );

    if (onDelete == null) return tile;

    return Dismissible(
      key: ValueKey(shot.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async =>
          await _showGlassConfirm(
            context: context,
            title: 'Видалити постріл?',
            body: 'Відео буде видалено безповоротно.',
          ) ??
          false,
      onDismissed: (_) => onDelete!(),
      child: tile,
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _fmtDuration(int ms) {
    final total = ms ~/ 1000;
    final m = (total ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Chip ──────────────────────────────────────────────────────────────────────

class _ShotChip extends StatelessWidget {
  final String label;
  final bool accent;
  const _ShotChip({required this.label, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent
            ? const Color(0xCCB05010)
            : const Color(0x0FFFFFFF),
        border: Border.all(
          color: accent
              ? const Color(0x33FFFFFF)
              : const Color(0x1AFFFFFF),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: accent ? FontWeight.w700 : FontWeight.w500,
          color: accent
              ? const Color(0xFFF0EAE5)
              : const Color(0x99F0EAE5),
        ),
      ),
    );
  }
}

// ── Glass confirm dialog ──────────────────────────────────────────────────────

Future<bool?> _showGlassConfirm({
  required BuildContext context,
  required String title,
  required String body,
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
                            fontSize: 13, color: _kHint, height: 1.4)),
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
                                  color: const Color(0x1EFFFFFF), width: 0.5),
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
                                  color: const Color(0x55FF4040), width: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text('Видалити',
                                  style: TextStyle(
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

// ── Thumbnail ─────────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  final String? path;
  const _Thumbnail({this.path});

  @override
  Widget build(BuildContext context) {
    if (path != null) {
      final file = File(path!);
      if (file.existsSync()) {
        return Image.file(file, width: 96, height: 64, fit: BoxFit.cover);
      }
    }
    return Container(
      width: 96,
      height: 64,
      color: const Color(0x33000000),
      child: const Center(
        child: Icon(Icons.play_circle_outline, color: _kAccent, size: 28),
      ),
    );
  }
}
