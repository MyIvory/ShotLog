package com.shotlog.shotlog

import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channel = "com.shotlog/bt_button"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PhysicalCameraChannel.CHANNEL)
            .setMethodCallHandler(PhysicalCameraChannel(applicationContext))
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VideoTrimChannel.CHANNEL)
            .setMethodCallHandler(VideoTrimChannel())
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN) {
            when (event.keyCode) {
                // Volume keys — most common BT shutter buttons
                KeyEvent.KEYCODE_VOLUME_UP,
                KeyEvent.KEYCODE_VOLUME_DOWN,
                // Camera hardware keys
                KeyEvent.KEYCODE_CAMERA,
                KeyEvent.KEYCODE_FOCUS,
                // Headset / media buttons used by some BT remotes
                KeyEvent.KEYCODE_HEADSETHOOK,
                KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE -> {
                    methodChannel?.invokeMethod("onButtonPressed", null)
                    return true  // consume — prevents volume change
                }
            }
        }
        return super.dispatchKeyEvent(event)
    }
}
