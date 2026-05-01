import 'package:flutter/material.dart';
import '../providers/session_provider.dart';

class SessionStateOverlay extends StatelessWidget {
  final SessionState state;
  final int countdownRemaining;
  final int shotCount;

  const SessionStateOverlay({
    super.key,
    required this.state,
    required this.countdownRemaining,
    required this.shotCount,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StateChip(state: state, countdown: countdownRemaining),
          _ShotCounter(count: shotCount),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final SessionState state;
  final int countdown;

  const _StateChip({required this.state, required this.countdown});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      SessionState.ready => ('ГОТОВО', Colors.green),
      SessionState.countdown => ('ВІДЛІК: $countdown', Colors.orange),
      SessionState.recordingArmed => ('● ЗАПИС', Colors.red),
      SessionState.recordingPost => ('● ЗАВЕРШЕННЯ', Colors.red),
      SessionState.processing => ('ЗБЕРЕЖЕННЯ...', Colors.blue),
      _ => ('—', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

class _ShotCounter extends StatelessWidget {
  final int count;
  const _ShotCounter({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Пострілів: $count',
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}
