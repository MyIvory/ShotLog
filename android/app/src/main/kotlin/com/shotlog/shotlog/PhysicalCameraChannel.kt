package com.shotlog.shotlog

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.util.Range
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PhysicalCameraChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "shotlog/physical_camera"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "getPhysicalBackCameras") getPhysicalBackCameras(result)
        else result.notImplemented()
    }

    @Suppress("UNCHECKED_CAST")
    private fun getPhysicalBackCameras(result: MethodChannel.Result) {
        try {
            val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val output = mutableListOf<Map<String, Any>>()

            for (logicalId in manager.cameraIdList) {
                val logChars = manager.getCameraCharacteristics(logicalId)
                val facing = logChars.get(CameraCharacteristics.LENS_FACING) ?: continue
                if (facing != CameraCharacteristics.LENS_FACING_BACK) continue

                val sensorOrientation = logChars.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90

                // Logical camera zoom range
                val logicalZoomMin: Double
                val logicalZoomMax: Double
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val range = logChars.get(CameraCharacteristics.CONTROL_ZOOM_RATIO_RANGE)
                            as? Range<Float>
                    logicalZoomMin = range?.lower?.toDouble() ?: 1.0
                    logicalZoomMax = range?.upper?.toDouble() ?: 1.0
                } else {
                    val maxDig = logChars.get(CameraCharacteristics.SCALER_AVAILABLE_MAX_DIGITAL_ZOOM)
                        ?.toDouble() ?: 1.0
                    logicalZoomMin = 1.0
                    logicalZoomMax = maxDig
                }

                val physicalIds: List<String> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    logChars.physicalCameraIds.sortedBy { it.toIntOrNull() ?: Int.MAX_VALUE }
                } else {
                    emptyList()
                }

                if (physicalIds.isNotEmpty()) {
                    for (physId in physicalIds) {
                        try {
                            val physChars = manager.getCameraCharacteristics(physId)
                            val focalLengths = physChars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                            val focalLength = focalLengths?.minOrNull()?.toDouble() ?: 0.0

                            val sensorSize = physChars.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
                            val sensorWidth = sensorSize?.width?.toDouble() ?: 0.0
                            val sensorHeight = sensorSize?.height?.toDouble() ?: 0.0

                            output.add(mapOf(
                                "id" to physId,
                                "logicalId" to logicalId,
                                "focalLength" to focalLength,
                                "sensorWidth" to sensorWidth,
                                "sensorHeight" to sensorHeight,
                                "logicalZoomMin" to logicalZoomMin,
                                "logicalZoomMax" to logicalZoomMax,
                                "sensorOrientation" to sensorOrientation,
                                "isPhysical" to true
                            ))
                        } catch (_: Exception) {
                            // Physical camera not queryable — skip
                        }
                    }
                } else {
                    // No physical cameras exposed — return the logical camera itself
                    val focalLengths = logChars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
                    val focalLength = focalLengths?.minOrNull()?.toDouble() ?: 0.0
                    output.add(mapOf(
                        "id" to logicalId,
                        "logicalId" to logicalId,
                        "focalLength" to focalLength,
                        "logicalZoomMin" to logicalZoomMin,
                        "logicalZoomMax" to logicalZoomMax,
                        "sensorOrientation" to sensorOrientation,
                        "isPhysical" to false
                    ))
                }
            }

            result.success(output)
        } catch (e: Exception) {
            result.error("CAMERA_ERROR", e.message, null)
        }
    }
}
