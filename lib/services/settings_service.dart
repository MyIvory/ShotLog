import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const _countdown = 'countdown_sec';
  static const _timeout = 'timeout_sec';
  static const _postRoll = 'post_roll_sec';
  static const _preRoll = 'pre_roll_sec';
  static const _detectionDb = 'detection_dbfs';

  Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      countdownSec: p.getInt(_countdown) ?? 3,
      timeoutSec: p.getInt(_timeout) ?? 10,
      postRollSec: p.getInt(_postRoll) ?? 3,
      preRollSec: p.getInt(_preRoll) ?? 2,
      detectionDbfs: p.getDouble(_detectionDb) ?? -40.0,
    );
  }

  Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_countdown, s.countdownSec);
    await p.setInt(_timeout, s.timeoutSec);
    await p.setInt(_postRoll, s.postRollSec);
    await p.setInt(_preRoll, s.preRollSec);
    await p.setDouble(_detectionDb, s.detectionDbfs);
  }
}
