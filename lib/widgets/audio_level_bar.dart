import 'package:flutter/material.dart';

class AudioLevelBar extends StatelessWidget {
  final double dbfs; // current amplitude dBFS (negative, 0 = loudest)
  final double thresholdDbfs;

  const AudioLevelBar({super.key, required this.dbfs, required this.thresholdDbfs});

  @override
  Widget build(BuildContext context) {
    // Map dBFS range [-80, 0] to [0, 1]
    final level = ((dbfs + 80) / 80).clamp(0.0, 1.0);
    final thresholdPos = ((thresholdDbfs + 80) / 80).clamp(0.0, 1.0);
    final isLoud = dbfs >= thresholdDbfs;

    return SizedBox(
      height: 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            children: [
              Container(color: Colors.grey[800]),
              AnimatedContainer(
                duration: const Duration(milliseconds: 40),
                width: width * level,
                color: isLoud ? Colors.redAccent : Colors.greenAccent,
              ),
              Positioned(
                left: width * thresholdPos - 1,
                child: Container(width: 2, height: 4, color: Colors.orange),
              ),
            ],
          );
        },
      ),
    );
  }
}
