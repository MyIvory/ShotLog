import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../models/shot.dart';
import '../models/app_settings.dart';
import '../database/session_repository.dart';
import '../database/shot_repository.dart';
import '../services/audio_detection_service.dart';
import '../services/video_recording_service.dart';
import '../services/sound_feedback_service.dart';
import '../services/bluetooth_button_service.dart';
import '../services/settings_service.dart';

enum SessionState { idle, ready, countdown, recordingArmed, recordingPost, processing }

class SessionProvider extends ChangeNotifier {
  final _sessionRepo = SessionRepository();
  final _shotRepo = ShotRepository();
  final _audio = AudioDetectionService();
  final _video = VideoRecordingService();
  final _sound = SoundFeedbackService();
  final _bt = BluetoothButtonService();

  SessionState _state = SessionState.idle;
  Session? _activeSession;
  final List<Shot> _shots = [];
  int _countdownRemaining = 0;
  AppSettings _settings = const AppSettings();

  Timer? _countdownTimer;
  Timer? _timeoutTimer;
  Timer? _warningTimer;
  Timer? _warningBeepTimer;
  Timer? _postRollTimer;
  DateTime? _recordingStartTime;

  SessionState get state => _state;
  Session? get activeSession => _activeSession;
  List<Shot> get shots => List.unmodifiable(_shots);
  int get countdownRemaining => _countdownRemaining;
  bool get hasCameraPreview => _video.isInitialized;
  double get detectionThreshold => _settings.detectionDbfs;

  /// Live amplitude stream from microphone (active only during recordingArmed).
  Stream<double> get amplitudeStream => _audio.amplitudeStream;

  Future<void> setZoom(double zoom) => _video.setZoom(zoom);

  Future<void> updateDetectionThreshold(double v) async {
    _settings = _settings.copyWith(detectionDbfs: v);
    _audio.updateThreshold(v);
    await SettingsService().save(_settings);
    notifyListeners();
  }

  /// Expose camera controller for CameraPreview widget.
  dynamic get cameraController => _video.controller;

  Future<void> startSession(Session session, AppSettings settings) async {
    _settings = settings;
    _shots.clear();

    await _video.initialize();

    final sessionWithThreshold = session.copyWith(detectionDbfs: settings.detectionDbfs);
    final id = await _sessionRepo.insert(sessionWithThreshold);
    _activeSession = sessionWithThreshold.copyWith(id: id);

    if (settings.triggerMode == TriggerMode.bluetooth) {
      _bt.onButtonPressed = _onButtonPressed;
      _bt.start();
    }

    _setState(SessionState.ready);
  }

  /// Continues an existing session (shots are appended to it).
  Future<void> continueSession(Session session, AppSettings settings) async {
    _settings = settings;
    _shots.clear();

    // Load existing shots so new shot numbers continue correctly.
    final existing = await _shotRepo.getBySession(session.id!);
    _shots.addAll(existing);

    await _video.initialize();
    _activeSession = session;

    if (settings.triggerMode == TriggerMode.bluetooth) {
      _bt.onButtonPressed = _onButtonPressed;
      _bt.start();
    }

    _setState(SessionState.ready);
  }

  /// Public entry point — use for BT button emulation in UI.
  void triggerButton() => _onButtonPressed();

  void _onButtonPressed() {
    if (_state == SessionState.ready) _startCountdown();
  }

  void _startCountdown() {
    _setState(SessionState.countdown);
    _countdownRemaining = _settings.countdownSec;
    _sound.playCountdownBeep();
    notifyListeners();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _countdownRemaining--;
      if (_countdownRemaining <= 0) {
        t.cancel();
        _sound.playStartRecording();
        _startRecording().catchError((e) {
          debugPrint('Recording start error: $e');
          _setState(SessionState.ready);
        });
      } else {
        _sound.playCountdownBeep();
        notifyListeners();
      }
    });
  }

  Future<void> _startRecording() async {
    _setState(SessionState.recordingArmed);
    _recordingStartTime = DateTime.now();

    try {
      await _video.startRecording();
      // Wait for the start beep (0.55s) to finish before opening the mic,
      // otherwise audioplayers and record fight for audio focus.
      await Future.delayed(const Duration(milliseconds: 650));
      _audio.onShotDetected = _onShotDetected;
      await _audio.start(_settings.detectionDbfs);
      _timeoutTimer = Timer(Duration(seconds: _settings.timeoutSec), _onTimeout);
      _scheduleWarningBeeps();
    } catch (e) {
      debugPrint('_startRecording failed: $e');
      await _audio.stop().catchError((_) async {});
      await _video.stopRecording(delete: true).catchError((_) async => null);
      _setState(SessionState.ready);
    }
  }

  void _scheduleWarningBeeps() {
    const warningSec = 5;
    final delay = _settings.timeoutSec - warningSec;
    if (delay <= 0) return;
    _warningTimer = Timer(Duration(seconds: delay), () {
      _warningBeepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_state != SessionState.recordingArmed) {
          t.cancel();
          return;
        }
        _sound.playTimeoutWarning();
      });
    });
  }

  void _cancelWarningBeeps() {
    _warningTimer?.cancel();
    _warningTimer = null;
    _warningBeepTimer?.cancel();
    _warningBeepTimer = null;
  }

  void _onShotDetected() {
    if (_state != SessionState.recordingArmed) return;
    final offsetMs = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
    final triggerDbfs = _audio.lastDbfs;
    _timeoutTimer?.cancel();
    _cancelWarningBeeps();
    _setState(SessionState.recordingPost);
    _audio.stop().catchError((e) {
      debugPrint('audio.stop error: $e');
    });

    _postRollTimer = Timer(
      Duration(seconds: _settings.postRollSec),
      () => _finishRecording(offsetMs, triggerDbfs).catchError((e) {
        debugPrint('_finishRecording error: $e');
        _setState(SessionState.ready);
      }),
    );
  }

  Future<void> _onTimeout() async {
    if (_state != SessionState.recordingArmed) return;
    _cancelWarningBeeps();
    await _audio.stop();
    await _video.stopRecording(delete: true);
    await _sound.playCancel();
    _setState(SessionState.ready);
  }

  Future<void> _finishRecording(int shotOffsetMs, double triggerDbfs) async {
    _setState(SessionState.processing);
    try {
      final clipPath = await _video.stopRecording(delete: false);

      if (clipPath != null && _activeSession?.id != null) {
        final shot = Shot(
          sessionId: _activeSession!.id!,
          shotNumber: _shots.length + 1,
          detectedAt: _recordingStartTime!.add(Duration(milliseconds: shotOffsetMs)),
          clipPath: clipPath,
          shotOffsetMs: shotOffsetMs,
          triggerDbfs: triggerDbfs,
        );
        final id = await _shotRepo.insert(shot);
        _shots.add(shot.copyWith(id: id));

        final updated = _activeSession!.copyWith(shotCount: _shots.length);
        await _sessionRepo.update(updated);
        _activeSession = updated;
      }

      await _sound.playReady();
    } catch (e) {
      debugPrint('_finishRecording inner error: $e');
    } finally {
      _setState(SessionState.ready);
    }
  }

  Future<void> endSession() async {
    _countdownTimer?.cancel();
    _timeoutTimer?.cancel();
    _cancelWarningBeeps();
    _postRollTimer?.cancel();

    if (_state == SessionState.recordingArmed || _state == SessionState.recordingPost) {
      await _audio.stop();
      await _video.stopRecording(delete: true);
    }

    if (_activeSession != null) {
      final ended = _activeSession!.copyWith(endedAt: DateTime.now());
      await _sessionRepo.update(ended);
    }

    _bt.stop();
    await _video.dispose();
    _activeSession = null;
    _shots.clear();
    _setState(SessionState.idle);
  }

  void _setState(SessionState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _timeoutTimer?.cancel();
    _cancelWarningBeeps();
    _postRollTimer?.cancel();
    _audio.dispose();
    _video.dispose();
    _sound.dispose();
    _bt.stop();
    super.dispose();
  }
}
