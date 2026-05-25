import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class VideoRecordingService {
  CameraController? _controller;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  Future<void> initialize({String cameraId = ''}) async {
    await dispose();
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No cameras available');

    CameraDescription cam;
    if (cameraId.isNotEmpty) {
      final found = cameras.where((c) => c.name == cameraId).firstOrNull;
      if (found != null) {
        cam = found;
      } else {
        // Physical camera ID not in availableCameras — try to open directly.
        // Sensor orientation defaults to 90 (standard for back cameras on Android).
        cam = CameraDescription(
          name: cameraId,
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        );
      }
    } else {
      cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
    }

    _controller = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await _controller!.initialize();
      debugPrint('[VideoRecordingService] opened camera "${cam.name}" successfully');
    } catch (e) {
      // Direct physical camera opening failed — fall back to first back camera.
      debugPrint('[VideoRecordingService] failed to open camera "${cam.name}": $e — falling back');
      await _controller?.dispose();
      final fallback = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      debugPrint('[VideoRecordingService] fallback to camera "${fallback.name}"');
      _controller = CameraController(
        fallback,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
    }
    await _lockFocus();
  }

  // Lock AF to prevent the camera HAL from switching physical lenses
  // during auto-focus attempts (relevant when near zoom boundaries).
  Future<void> _lockFocus() async {
    try {
      await _controller!.setFocusMode(FocusMode.locked);
      debugPrint('[VideoRecordingService] focus locked');
    } catch (e) {
      debugPrint('[VideoRecordingService] could not lock focus: $e');
    }
  }

  Future<void> startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isRecordingVideo) return;
    await _controller!.startVideoRecording();
  }

  /// Returns the saved clip path, or null if [delete] is true.
  Future<String?> stopRecording({required bool delete}) async {
    if (_controller == null || !_controller!.value.isRecordingVideo) return null;

    final xFile = await _controller!.stopVideoRecording();
    if (delete) {
      try {
        await File(xFile.path).delete();
      } catch (_) {}
      return null;
    }

    final dir = await getApplicationDocumentsDirectory();
    final shotsDir = Directory('${dir.path}/shots');
    await shotsDir.create(recursive: true);
    final destPath = '${shotsDir.path}/${DateTime.now().millisecondsSinceEpoch}.mp4';
    await File(xFile.path).rename(destPath);
    return destPath;
  }

  Future<void> setZoom(double zoom) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    await _controller!.setZoomLevel(zoom);
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
