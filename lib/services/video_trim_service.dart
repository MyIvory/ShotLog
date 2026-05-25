import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VideoTrimService {
  static const _channel = MethodChannel('shotlog/video_trim');

  /// Trims [inputPath] starting from [startMs] ms, saves to [outputPath].
  /// Returns output path on success, null if trim failed (caller keeps original).
  Future<String?> trimClip({
    required String inputPath,
    required String outputPath,
    required int startMs,
  }) async {
    if (startMs <= 0) return null;
    try {
      return await _channel.invokeMethod<String>('trimVideo', {
        'input': inputPath,
        'output': outputPath,
        'startMs': startMs,
      });
    } catch (e) {
      debugPrint('[VideoTrimService] trim failed: $e');
      return null;
    }
  }
}
