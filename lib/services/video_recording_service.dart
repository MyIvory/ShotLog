import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

class VideoRecordingService {
  CameraController? _controller;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  Future<void> initialize() async {
    await dispose();
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No cameras available');

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
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

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
