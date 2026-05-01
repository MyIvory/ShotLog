import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioDetectionService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSub;
  bool _debouncing = false;
  bool _active = false;
  String? _tempPath;

  void Function()? onShotDetected;

  // Broadcasts current dBFS level; subscribers: UI visualizer.
  final _ampController = StreamController<double>.broadcast();
  Stream<double> get amplitudeStream => _ampController.stream;
  double _lastDbfs = -80.0;
  double get lastDbfs => _lastDbfs;

  double _thresholdDbfs = -20.0;

  void updateThreshold(double v) => _thresholdDbfs = v;

  Future<void> start(double thresholdDbfs) async {
    if (_active) return;
    _active = true;
    _debouncing = false;
    _thresholdDbfs = thresholdDbfs;

    // File-based recording is more reliable for onAmplitudeChanged on Android.
    final dir = await getTemporaryDirectory();
    _tempPath = '${dir.path}/shotlog_monitor_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        numChannels: 1,
        sampleRate: 44100,
      ),
      path: _tempPath!,
    );

    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 50))
        .listen((amp) {
      _lastDbfs = amp.current;
      if (!_ampController.isClosed) _ampController.add(amp.current);

      if (amp.current >= _thresholdDbfs && !_debouncing) {
        _debouncing = true;
        onShotDetected?.call();
        Future.delayed(const Duration(seconds: 2), () => _debouncing = false);
      }
    });
  }

  Future<void> stop() async {
    _active = false;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    _lastDbfs = -80.0;
    if (_tempPath != null) {
      try { await File(_tempPath!).delete(); } catch (_) {}
      _tempPath = null;
    }
    _debouncing = false;
  }

  void dispose() {
    _amplitudeSub?.cancel();
    _ampController.close();
    _recorder.dispose();
  }
}
