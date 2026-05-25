import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const _countdown = 'countdown_sec';
  static const _timeout = 'timeout_sec';
  static const _postRoll = 'post_roll_sec';
  static const _preRoll = 'pre_roll_sec';
  static const _detectionDb = 'detection_dbfs';
  static const _triggerMode = 'trigger_mode';
  static const _cameraId = 'selected_camera_id';
  static const _cameraZoomMin = 'camera_zoom_min';
  static const _cameraZoomMax = 'camera_zoom_max';

  Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      countdownSec: p.getInt(_countdown) ?? 3,
      timeoutSec: (p.getInt(_timeout) ?? 10).clamp(10, 60),
      postRollSec: p.getInt(_postRoll) ?? 3,
      preRollSec: p.getInt(_preRoll) ?? 2,
      detectionDbfs: p.getDouble(_detectionDb) ?? -40.0,
      triggerMode: TriggerMode.values[p.getInt(_triggerMode) ?? TriggerMode.bluetooth.index],
      selectedCameraId: p.getString(_cameraId) ?? '',
      cameraZoomMin: p.getDouble(_cameraZoomMin) ?? 0.0,
      cameraZoomMax: p.getDouble(_cameraZoomMax) ?? 0.0,
    );
  }

  Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_countdown, s.countdownSec);
    await p.setInt(_timeout, s.timeoutSec);
    await p.setInt(_postRoll, s.postRollSec);
    await p.setInt(_preRoll, s.preRollSec);
    await p.setDouble(_detectionDb, s.detectionDbfs);
    await p.setInt(_triggerMode, s.triggerMode.index);
    await p.setString(_cameraId, s.selectedCameraId);
    await p.setDouble(_cameraZoomMin, s.cameraZoomMin);
    await p.setDouble(_cameraZoomMax, s.cameraZoomMax);
  }

  Future<void> saveCameraZoomRange(String cameraId, double min, double max) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('camera_zoom_min_$cameraId', min);
    await p.setDouble('camera_zoom_max_$cameraId', max);
  }

  Future<(double, double)?> loadCameraZoomRange(String cameraId) async {
    final p = await SharedPreferences.getInstance();
    final min = p.getDouble('camera_zoom_min_$cameraId');
    final max = p.getDouble('camera_zoom_max_$cameraId');
    if (min == null || max == null) return null;
    return (min, max);
  }
}
