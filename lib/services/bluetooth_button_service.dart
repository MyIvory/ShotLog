import 'package:flutter/services.dart';

class BluetoothButtonService {
  void Function()? onButtonPressed;
  bool _listening = false;

  bool _handler(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.audioVolumeUp ||
        key == LogicalKeyboardKey.audioVolumeDown ||
        key == LogicalKeyboardKey.cameraFocus ||
        key == LogicalKeyboardKey.camera ||
        key == LogicalKeyboardKey.mediaRecord) {
      onButtonPressed?.call();
      return true;
    }
    return false;
  }

  void start() {
    if (_listening) return;
    _listening = true;
    HardwareKeyboard.instance.addHandler(_handler);
  }

  void stop() {
    if (!_listening) return;
    _listening = false;
    HardwareKeyboard.instance.removeHandler(_handler);
  }
}
