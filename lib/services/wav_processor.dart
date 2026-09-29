import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Offline, on-device WAV reader + pitch shifter used by talking mode.
///
/// Pipeline (exactly the "record -> pitch-shift -> playback" flow):
///   1. `record` writes a mono 16-bit PCM wav to a temp file.
///   2. [readWav16] parses the RIFF chunks into Int16 samples.
///   3. [pitchShiftUp] resamples the audio faster and folds the speed-up
///      back to the original duration with a granular (overlap-add)
///      technique - this raises the *perceived pitch* like the classic
///      cartoon-pet voice while keeping timing natural.
///   4. [writeWav16] saves the shifted audio; SoundService plays it.
class WavProcessor {
  static const _frame = 1024; // granular window size
  static const _hop = 512;    // 50% overlap

  /// Parse a mono/stereo 16-bit PCM wav. Returns samples normalised to
  /// mono Float32 (-1..1). Throws FormatException on unsupported files.
  static Future<Float32List> readWav16(String path) async {
    final bytes = await File(path).readAsBytes();
    if (bytes.length < 44) throw const FormatException('wav too small');
    final bd = ByteData.sublistView(bytes);
    String tag(int o) => String.fromCharCodes(bytes.sublist(o, o + 4));
    if (tag(0) != 'RIFF' || tag(8) != 'WAVE') {
      throw const FormatException('not a RIFF/WAVE file');
    }

    int fmtChannels = 1, fmtRate = 44100, sampleCount = 0, dataStart = 0;
    // Walk the chunk list looking for "fmt " and "data".
    int pos = 12;
    while (pos + 8 <= bytes.length) {
      final id = tag(pos);
      final size = bd.getUint32(pos + 4, true);
      if (id == 'fmt ') {
        fmtChannels = bd.getUint16(pos + 10, true);
        fmtRate = bd.getUint32(pos + 12, true);
      } else if (id == 'data') {
        dataStart = pos + 8;
        sampleCount = (size ~/ 2); // 16-bit samples across all channels
        break;
      }
      pos += 8 + size + (size.isOdd ? 1 : 0); // chunks are word-aligned
    }
    if (dataStart == 0 || sampleCount == 0) throw const FormatException('no data chunk');

    final totalFrames = sampleCount ~/ fmtChannels;
    final out = Float32List(totalFrames);
    for (int i = 0; i < totalFrames; i++) {
      double acc = 0;
      for (int c = 0; c < fmtChannels; c++) {
        final idx = (i * fmtChannels + c) * 2;
        if (dataStart + idx + 1 < bytes.length) {
          acc += bd.getInt16(dataStart + idx, true) / 32768.0;
        }
      }
      out[i] = acc / fmtChannels;
    }
    return out;
  }

  /// Raise perceived pitch by [ratio] (e.g. 1.6 = 60% higher, chipmunk style).
  ///
  /// Implementation: play the buffer [ratio]x faster (simple index
  /// interpolation), then rebuild the original timeline in overlapping
  /// grains so duration is preserved. The result sounds like the same
  /// utterance sung higher - exactly what a pet-mimic app needs.
  static Float32List pitchShiftUp(Float32List input, double ratio) {
    if (ratio <= 1.0001 || input.length < _frame * 2) return input;
    final n = input.length;
    final result = Float32List(n);

    // Stage 1: speed up by reading input at `ratio * position`
    // (this raises pitch; output is shorter than the input).
    final spedLen = (n / ratio).floor();
    final sped = Float32List(spedLen);
    for (int i = 0; i < spedLen; i++) {
      final src = i * ratio;
      final i0 = src.floor();
      final frac = src - i0;
      final a = input[i0];
      final b = (i0 + 1 < n) ? input[i0 + 1] : a;
      sped[i] = a + (b - a) * frac;
    }

    // Stage 2: WSOLA-style time-stretch of [sped] back to length n using
    // Hann-windowed overlapping grains -> pitch up, same duration.
    final stretch = n / spedLen; // >= 1
    for (int dst = 0; dst + _frame <= n; dst += _hop) {
      final gStart = (dst / stretch).floor();
      for (int j = 0; j < _frame; j++) {
        final s = gStart + j;
        if (s < 0 || s >= spedLen) continue;
        // Hann window over the grain.
        final w = 0.5 - 0.5 * math.cos(2 * math.pi * j / (_frame - 1));
        result[dst + j] += sped[s] * w;
      }
    }
    // Compensate the 50%-overlap Hann sum (~1.0 average power).
    for (int i = 0; i < n; i++) {
      result[i] *= 0.5;
    }
    // Normalise to avoid clipping after overlap-add summation.
    double peak = 0;
    for (final v in result) {
      if (v.abs() > peak) peak = v.abs();
    }
    if (peak > 0.95) {
      final g = 0.95 / peak;
      for (int i = 0; i < result.length; i++) {
        result[i] *= g;
      }
    }
    return result;
  }

  /// Write mono 16-bit PCM wav (used to hand the shifted audio to audioplayers).
  static Future<void> writeWav16(String path, Float32List samples, int sampleRate) async {
    final byteLen = samples.length * 2;
    final bd = ByteData(44 + byteLen);
    void ascii(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        bd.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    bd.setUint32(4, 36 + byteLen, true);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bd.setUint32(16, 16, true);          // fmt chunk size
    bd.setUint16(20, 1, true);           // PCM
    bd.setUint16(22, 1, true);           // mono
    bd.setUint32(24, sampleRate, true);
    bd.setUint32(28, sampleRate * 2, true); // byte rate
    bd.setUint16(32, 2, true);           // block align
    bd.setUint16(34, 16, true);          // bits per sample
    ascii(36, 'data');
    bd.setUint32(40, byteLen, true);
    for (int i = 0; i < samples.length; i++) {
      final v = (samples[i] * 32767).clamp(-32768, 32767).toInt();
      bd.setInt16(44 + i * 2, v, true);
    }
    await File(path).writeAsBytes(bd.buffer.asUint8List());
  }

  /// Full pipeline: read [srcPath], shift pitch up by [ratio], write [dstPath].
  /// Returns the destination path. Falls back to playing the raw recording
  /// if anything goes wrong (talking mode should never hard-fail).
  static Future<String> processFile(String srcPath, String dstPath, double ratio, int sampleRate) async {
    try {
      final samples = await readWav16(srcPath);
      final shifted = pitchShiftUp(samples, ratio);
      await writeWav16(dstPath, shifted, sampleRate);
      return dstPath;
    } catch (_) {
      return srcPath; // graceful degradation: play un-pitched audio
    }
  }

  /// Convenience wrapper used by TalkController: derives a sibling file name
  /// next to [srcPath] and runs [processFile].
  static Future<String> shiftPath(String srcPath, double ratio, int sampleRate) async {
    final dot = srcPath.lastIndexOf('.');
    final base = dot > 0 ? srcPath.substring(0, dot) : srcPath;
    final dst = '${base}_hi.wav';
    return processFile(srcPath, dst, ratio, sampleRate);
  }

  /// Duration in ms of a mono 16-bit PCM wav written at [sampleRate]
  /// (reads only the file size - cheap and exact for our own writer).
  static int durationMsOf(String path, int sampleRate) {
    try {
      final len = File(path).lengthSync();
      final samples = ((len - 44) / 2).clamp(0, double.infinity).toInt();
      return (samples * 1000 / sampleRate).round().clamp(300, 15000);
    } catch (_) {
      return 2000;
    }
  }
}
