import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// 卡农主旋律音符频率（D大调，前8个音）
const List<double> _canonFreqs = [
  587.33, // D5
  554.37, // C#5
  493.88, // B4
  440.00, // A4
  392.00, // G4
  369.99, // F#4
  392.00, // G4
  440.00, // A4
];

class TonePlayer {
  static final TonePlayer _instance = TonePlayer._();
  factory TonePlayer() => _instance;
  TonePlayer._();

  int _melodyIndex = 0; // 旋律进度，永不重置
  String? _cacheDir;

  /// 播放卡农下一个音符
  Future<void> playNextNote() async {
    final freq = _canonFreqs[_melodyIndex % _canonFreqs.length];
    _melodyIndex++;
    await _playTone(freq, 0.35);
  }

  /// 重置连击（不影响旋律进度）
  void resetCombo() {}

  Future<void> _playTone(double freq, double durationSec) async {
    try {
      if (_cacheDir == null) {
        final dir = await getTemporaryDirectory();
        _cacheDir = dir.path;
      }
      final file = File('$_cacheDir/canon_tone.wav');
      final bytes = _generateWav(freq, durationSec);
      await file.writeAsBytes(bytes, flush: true);

      final player = AudioPlayer();
      await player.play(DeviceFileSource(file.path));
      // 播放完释放
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      print('[TonePlayer] 播放失败: $e');
    }
  }

  Uint8List _generateWav(double freq, double durationSec) {
    const int sampleRate = 22050;
    final int numSamples = (sampleRate * durationSec).round();
    final int dataSize = numSamples * 2;
    final int fileSize = 36 + dataSize;
    final ByteData buf = ByteData(44 + dataSize);

    // RIFF header
    buf.setUint8(0, 0x52); buf.setUint8(1, 0x49);
    buf.setUint8(2, 0x46); buf.setUint8(3, 0x46);
    buf.setUint32(4, fileSize, Endian.little);
    buf.setUint8(8, 0x57); buf.setUint8(9, 0x41);
    buf.setUint8(10, 0x56); buf.setUint8(11, 0x45);

    // fmt subchunk
    buf.setUint8(12, 0x66); buf.setUint8(13, 0x6D);
    buf.setUint8(14, 0x74); buf.setUint8(15, 0x20);
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little);
    buf.setUint16(22, 1, Endian.little);
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, sampleRate * 2, Endian.little);
    buf.setUint16(32, 2, Endian.little);
    buf.setUint16(34, 16, Endian.little);

    // data subchunk
    buf.setUint8(36, 0x64); buf.setUint8(37, 0x61);
    buf.setUint8(38, 0x74); buf.setUint8(39, 0x61);
    buf.setUint32(40, dataSize, Endian.little);

    // 柔和音色：三角波 + 泛音 + 慢起慢释
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // ADSR: 慢起 30ms → 衰减 100ms → 持续 → 慢释 80ms
      double env;
      if (t < 0.03) {
        env = t / 0.03;
      } else if (t < 0.13) {
        env = 1.0 - 0.35 * (t - 0.03) / 0.1;
      } else if (t < durationSec - 0.08) {
        env = 0.65;
      } else {
        env = 0.65 * (durationSec - t) / 0.08;
      }
      // 三角波基音（比正弦波柔和）+ 微弱泛音
      final phase = 2 * pi * freq * t;
      final triangle = asin(sin(phase)) * (2 / pi); // 三角波近似
      final soft_harm = 0.15 * sin(phase * 2);
      final sample = ((triangle + soft_harm) * 12000 * env).round();
      buf.setInt16(44 + i * 2, sample.clamp(-32768, 32767), Endian.little);
    }

    return buf.buffer.asUint8List();
  }

  void dispose() {}
}
