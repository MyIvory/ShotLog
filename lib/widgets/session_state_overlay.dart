import 'package:flutter/material.dart';
import '../providers/session_provider.dart';

class SessionStateOverlay extends StatelessWidget {
  final SessionState state;
  final int countdownRemaining;
  final int shotCount;
  final double? lastTriggerDbfs;

  const SessionStateOverlay({
    super.key,
    required this.state,
    required this.countdownRemaining,
    required this.shotCount,
    this.lastTriggerDbfs,
  });

  static const double _chipWidth = 76.0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: _chipWidth, child: _StateChip(state: state, countdown: countdownRemaining)),
          SizedBox(width: _chipWidth, child: _ShotCounter(count: shotCount)),
        ],
      ),
    );
  }
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StateChip extends StatefulWidget {
  final SessionState state;
  final int countdown;
  const _StateChip({required this.state, required this.countdown});

  @override
  State<_StateChip> createState() => _StateChipState();
}

class _StateChipState extends State<_StateChip>
    with TickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    _updatePulse();
  }

  @override
  void didUpdateWidget(_StateChip old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _updatePulse();
  }

  void _updatePulse() {
    _pulse?.dispose();
    _pulse = null;
    if (widget.state == SessionState.recordingArmed) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _chipConfig(widget.state, widget.countdown);
    final isRec = widget.state == SessionState.recordingArmed;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(widget.state == SessionState.countdown
            ? '${widget.state}${widget.countdown}'
            : widget.state),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: cfg.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cfg.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isRec && _pulse != null) ...[
              AnimatedBuilder(
                animation: _pulse!,
                builder: (_, __) {
                  final value = _pulse?.value ?? 0.0;
                  return Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                        const Color(0xFFFF3B3B),
                        const Color(0xFF8B1A1A),
                        value,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                cfg.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cfg.textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipCfg {
  final Color bg, border, textColor;
  final String label;
  const _ChipCfg({required this.bg, required this.border,
      required this.textColor, required this.label});
}

_ChipCfg _chipConfig(SessionState state, int countdown) {
  return switch (state) {
    SessionState.ready => _ChipCfg(
        bg: const Color(0xCC1E1E1E),
        border: const Color(0xFF4A4038),
        textColor: const Color(0xFF9A9080),
        label: 'ГОТОВО'),
    SessionState.countdown => _ChipCfg(
        bg: const Color(0xDA502800),
        border: const Color(0xFFE87722),
        textColor: const Color(0xFFF0C060),
        label: 'ВІДЛІК: $countdown'),
    SessionState.recordingArmed => _ChipCfg(
        bg: const Color(0xDA500808),
        border: const Color(0xFF8B1A1A),
        textColor: const Color(0xFFFF6B6B),
        label: 'ЗАПИС'),
    SessionState.recordingPost => _ChipCfg(
        bg: const Color(0xDA3C1400),
        border: const Color(0xFFBF360C),
        textColor: const Color(0xFFFF9060),
        label: 'ЗАВЕРШЕННЯ'),
    SessionState.processing => _ChipCfg(
        bg: const Color(0xDA05101E),
        border: const Color(0xFF1565C0),
        textColor: const Color(0xFF90CAF9),
        label: 'ЗБЕРЕЖЕННЯ...'),
    _ => _ChipCfg(
        bg: const Color(0xCC1E1E1E),
        border: const Color(0xFF4A4038),
        textColor: const Color(0xFF9A9080),
        label: '—'),
  };
}

// ── Shot counter ──────────────────────────────────────────────────────────────

class _ShotCounter extends StatelessWidget {
  final int count;
  const _ShotCounter({required this.count});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey(count),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        constraints: const BoxConstraints(minWidth: 56),
        decoration: BoxDecoration(
          color: const Color(0x99000000),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE87722), width: 1),
        ),
        child: Text(
          '$count',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFE87722),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
