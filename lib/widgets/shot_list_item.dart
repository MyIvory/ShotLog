import 'dart:io';
import 'package:flutter/material.dart';
import '../models/shot.dart';

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
    final tile = Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
      child: Material(
        color: const Color(0xFF261E1A),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF33281F)),
            ),
            child: Row(
              children: [
                _Thumbnail(path: shot.thumbnailPath),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Постріл #${shot.shotNumber} · ${_formatTime(shot.detectedAt)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFD0C4BC),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(),
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF7A6E68),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF4A3528), size: 18),
              ],
            ),
          ),
        ),
      ),
    );

    if (onDelete == null) return tile;

    return Dismissible(
      key: ValueKey(shot.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 7),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Видалити постріл?'),
                content: const Text('Відео буде видалено безповоротно.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Скасувати')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Видалити')),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => onDelete!(),
      child: tile,
    );
  }

  String _subtitle() {
    final parts = <String>[];
    if (shot.triggerDbfs != null) {
      parts.add('${shot.triggerDbfs!.toStringAsFixed(1)} dBFS');
    }
    if (preRollMs > 0) {
      parts.add('${(preRollMs / 1000).toStringAsFixed(2)}с pre-roll');
    }
    return parts.join(' · ');
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _Thumbnail extends StatelessWidget {
  final String? path;
  const _Thumbnail({this.path});

  @override
  Widget build(BuildContext context) {
    if (path != null) {
      final file = File(path!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(file,
              width: 48, height: 32, fit: BoxFit.cover),
        );
      }
    }
    // Placeholder with amber play triangle
    return Container(
      width: 48,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1806),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Icon(Icons.play_arrow,
            color: Color(0xFFE87722), size: 18),
      ),
    );
  }
}
