import 'dart:io';
import 'package:flutter/material.dart';
import '../models/shot.dart';

class ShotListItem extends StatelessWidget {
  final Shot shot;
  final VoidCallback onTap;

  const ShotListItem({super.key, required this.shot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: _Thumbnail(path: shot.thumbnailPath),
        title: Text('Постріл #${shot.shotNumber}'),
        subtitle: Text(_formatTime(shot.detectedAt)),
        trailing: const Icon(Icons.play_circle_outline, size: 32),
        onTap: onTap,
      ),
    );
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
          child: Image.file(file, width: 56, height: 56, fit: BoxFit.cover),
        );
      }
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.videocam, color: Colors.grey),
    );
  }
}
