class AppSettings {
  final int countdownSec;
  final int timeoutSec;
  final int postRollSec;
  final int preRollSec;
  // dBFS threshold: 0 is loudest, -160 is silence. Default -20 catches very loud sounds only.
  final double detectionDbfs;

  const AppSettings({
    this.countdownSec = 3,
    this.timeoutSec = 10,
    this.postRollSec = 3,
    this.preRollSec = 2,
    this.detectionDbfs = -20.0,
  });

  AppSettings copyWith({
    int? countdownSec,
    int? timeoutSec,
    int? postRollSec,
    int? preRollSec,
    double? detectionDbfs,
  }) =>
      AppSettings(
        countdownSec: countdownSec ?? this.countdownSec,
        timeoutSec: timeoutSec ?? this.timeoutSec,
        postRollSec: postRollSec ?? this.postRollSec,
        preRollSec: preRollSec ?? this.preRollSec,
        detectionDbfs: detectionDbfs ?? this.detectionDbfs,
      );
}
