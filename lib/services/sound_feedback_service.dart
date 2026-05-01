import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class SoundFeedbackService {
  final AudioPlayer _player = AudioPlayer();

  late final Uint8List _beepBytes;
  late final Uint8List _readyBytes;
  late final Uint8List _cancelBytes;

  SoundFeedbackService() {
    _beepBytes = _buildWav(880.0, 0.12);
    _readyBytes = _buildWav(660.0, 0.35);
    _cancelBytes = _buildWav(220.0, 0.45);
  }

  Future<void> playCountdownBeep() => _play(_beepBytes);
  Future<void> playReady() => _play(_readyBytes);
  Future<void> playCancel() => _play(_cancelBytes);

  Future<void> _play(Uint8List bytes) async {
    await _player.stop();
    await _player.play(BytesSource(bytes));
  }

  /// Generates a mono 16-bit PCM WAV with fade-in/out envelope.
  Uint8List _buildWav(double frequency, double durationSec) {
    const sampleRate = 22050;
    final numSamples = (sampleRate * durationSec).round();
    final dataSize = numSamples * 2;
    final buf = ByteData(44 + dataSize);
    int o = 0;

    void writeStr(String s) {
      for (final c in s.codeUnits) {
        buf.setUint8(o++, c);
      }
    }

    void u32(int v) {
      buf.setUint32(o, v, Endian.little);
      o += 4;
    }

    void u16(int v) {
      buf.setUint16(o, v, Endian.little);
      o += 2;
    }

    writeStr('RIFF');
    u32(36 + dataSize);
    writeStr('WAVE');
    writeStr('fmt ');
    u32(16);
    u16(1); // PCM
    u16(1); // mono
    u32(sampleRate);
    u32(sampleRate * 2);
    u16(2);
    u16(16);
    writeStr('data');
    u32(dataSize);

    final fadeSamples = (sampleRate * 0.01).round();
    for (int i = 0; i < numSamples; i++) {
      double env = 1.0;
      if (i < fadeSamples) env = i / fadeSamples;
      if (i > numSamples - fadeSamples) env = (numSamples - i) / fadeSamples;
      final sample = (env * 0.7 * 32767 * sin(2 * pi * frequency * i / sampleRate))
          .round()
          .clamp(-32768, 32767);
      buf.setInt16(o, sample, Endian.little);
      o += 2;
    }

    return buf.buffer.asUint8List();
  }

  void dispose() => _player.dispose();
}
