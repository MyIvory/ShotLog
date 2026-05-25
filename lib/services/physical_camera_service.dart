import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

class PhysicalCameraInfo {
  final String id;
  final String logicalId;
  final double focalLength;
  final double sensorWidth;
  final double sensorHeight;
  final int sensorOrientation;
  final bool isPhysical;
  // Estimated zoom range in logical-camera coordinate space.
  // null = couldn't determine (use controller min/max).
  final double? zoomMin;
  final double? zoomMax;

  const PhysicalCameraInfo({
    required this.id,
    required this.logicalId,
    required this.focalLength,
    required this.sensorWidth,
    required this.sensorHeight,
    required this.sensorOrientation,
    required this.isPhysical,
    this.zoomMin,
    this.zoomMax,
  });

  String get focalLabel => '${focalLength.toStringAsFixed(1)} mm';

  // 35 mm equivalent focal length (more accurate for cross-sensor zoom estimation).
  double get equiv35mm {
    if (focalLength <= 0 || sensorWidth <= 0 || sensorHeight <= 0) return focalLength;
    final diagonal = sqrt(sensorWidth * sensorWidth + sensorHeight * sensorHeight);
    return focalLength * 43.27 / diagonal;
  }
}

class PhysicalCameraService {
  static const _channel = MethodChannel('shotlog/physical_camera');

  Future<List<PhysicalCameraInfo>> getBackCameras() async {
    try {
      final raw = await _channel.invokeListMethod<Map>('getPhysicalBackCameras') ?? [];
      if (raw.isEmpty) return _fallback();

      // Group by logicalId
      final Map<String, List<Map>> byLogical = {};
      for (final cam in raw) {
        final lid = cam['logicalId'] as String;
        byLogical.putIfAbsent(lid, () => []).add(cam);
      }

      final result = <PhysicalCameraInfo>[];

      for (final entry in byLogical.entries) {
        final cameras = entry.value;
        final logicalZoomMin = (cameras.first['logicalZoomMin'] as num).toDouble();
        final logicalZoomMax = (cameras.first['logicalZoomMax'] as num).toDouble();

        if (cameras.length == 1) {
          final cam = cameras.first;
          result.add(_fromMap(cam, logicalZoomMin, logicalZoomMax));
        } else {
          // Sort by focal length (ultrawide first).
          final sorted = cameras.toList()
            ..sort((a, b) => (a['focalLength'] as num).compareTo(b['focalLength'] as num));

          // Build temporary PhysicalCameraInfo objects to access equiv35mm.
          final infos = sorted.map((c) => _fromMap(c, null, null)).toList();

          // Use 35 mm equivalents when available; fall back to raw focal lengths.
          final equivs = infos.map((c) => c.equiv35mm > 0 ? c.equiv35mm : c.focalLength).toList();

          // Reference equiv = ultrawide_equiv / logicalZoomMin.
          // This anchors: equivs.first / refEquiv = logicalZoomMin ✓
          final refEquiv = (logicalZoomMin > 0 && equivs.first > 0)
              ? equivs.first / logicalZoomMin
              : equivs[equivs.length ~/ 2];

          for (var i = 0; i < infos.length; i++) {
            final e = equivs[i];

            final minBound = i == 0
                ? logicalZoomMin
                : sqrt(equivs[i - 1] * e) / refEquiv;
            final maxBound = i == infos.length - 1
                ? logicalZoomMax
                : sqrt(e * equivs[i + 1]) / refEquiv;

            result.add(PhysicalCameraInfo(
              id: infos[i].id,
              logicalId: infos[i].logicalId,
              focalLength: infos[i].focalLength,
              sensorWidth: infos[i].sensorWidth,
              sensorHeight: infos[i].sensorHeight,
              sensorOrientation: infos[i].sensorOrientation,
              isPhysical: infos[i].isPhysical,
              zoomMin: minBound.clamp(logicalZoomMin, logicalZoomMax),
              zoomMax: maxBound.clamp(logicalZoomMin, logicalZoomMax),
            ));
          }
        }
      }

      // Remove standalone logical cameras whose ID is already a physical camera
      // (Samsung exposes the same hardware in both getCameraIdList and getPhysicalCameraIds).
      final physicalIds = result.where((c) => c.isPhysical).map((c) => c.id).toSet();
      return result
          .where((c) => c.isPhysical || !physicalIds.contains(c.id))
          .toList();
    } catch (_) {
      return _fallback();
    }
  }

  static PhysicalCameraInfo _fromMap(Map cam, double? zoomMin, double? zoomMax) {
    return PhysicalCameraInfo(
      id: cam['id'] as String,
      logicalId: cam['logicalId'] as String,
      focalLength: (cam['focalLength'] as num).toDouble(),
      sensorWidth: (cam['sensorWidth'] as num? ?? 0).toDouble(),
      sensorHeight: (cam['sensorHeight'] as num? ?? 0).toDouble(),
      sensorOrientation: (cam['sensorOrientation'] as num).toInt(),
      isPhysical: cam['isPhysical'] as bool,
      zoomMin: zoomMin,
      zoomMax: zoomMax,
    );
  }

  Future<List<PhysicalCameraInfo>> _fallback() async {
    try {
      final cameras = await availableCameras();
      return cameras
          .where((c) => c.lensDirection == CameraLensDirection.back)
          .map((c) => PhysicalCameraInfo(
                id: c.name,
                logicalId: c.name,
                focalLength: 0,
                sensorWidth: 0,
                sensorHeight: 0,
                sensorOrientation: c.sensorOrientation,
                isPhysical: false,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
