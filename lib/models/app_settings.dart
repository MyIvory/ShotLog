enum TriggerMode { button, bluetooth }

class AppSettings {
  final int countdownSec;
  final int timeoutSec;
  final int postRollSec;
  final int preRollSec;
  // dBFS threshold: 0 is loudest, -160 is silence. Default -20 catches very loud sounds only.
  final double detectionDbfs;
  final TriggerMode triggerMode;
  // Camera ID (Android Camera2 ID string). Empty = use first back camera.
  final String selectedCameraId;
  // Zoom range restriction to keep the selected physical lens active.
  // 0.0 means "use camera controller's native min/max".
  final double cameraZoomMin;
  final double cameraZoomMax;

  const AppSettings({
    this.countdownSec = 3,
    this.timeoutSec = 10,
    this.postRollSec = 3,
    this.preRollSec = 2,
    this.detectionDbfs = -20.0,
    this.triggerMode = TriggerMode.bluetooth,
    this.selectedCameraId = '',
    this.cameraZoomMin = 0.0,
    this.cameraZoomMax = 0.0,
  });

  AppSettings copyWith({
    int? countdownSec,
    int? timeoutSec,
    int? postRollSec,
    int? preRollSec,
    double? detectionDbfs,
    TriggerMode? triggerMode,
    String? selectedCameraId,
    double? cameraZoomMin,
    double? cameraZoomMax,
  }) =>
      AppSettings(
        countdownSec: countdownSec ?? this.countdownSec,
        timeoutSec: timeoutSec ?? this.timeoutSec,
        postRollSec: postRollSec ?? this.postRollSec,
        preRollSec: preRollSec ?? this.preRollSec,
        detectionDbfs: detectionDbfs ?? this.detectionDbfs,
        triggerMode: triggerMode ?? this.triggerMode,
        selectedCameraId: selectedCameraId ?? this.selectedCameraId,
        cameraZoomMin: cameraZoomMin ?? this.cameraZoomMin,
        cameraZoomMax: cameraZoomMax ?? this.cameraZoomMax,
      );
}
