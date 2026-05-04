import 'package:flutter/services.dart';

class BluetoothButtonService {
  static const _channel = MethodChannel('com.shotlog/bt_button');

  void Function()? onButtonPressed;
  bool _listening = false;

  void start() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onButtonPressed') {
        onButtonPressed?.call();
      }
    });
  }

  void stop() {
    if (!_listening) return;
    _listening = false;
    _channel.setMethodCallHandler(null);
  }
}
