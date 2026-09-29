import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Low-level microphone recorder for talking mode.
///
/// Wraps the `record` plugin and adds a small **pure-Dart WAV writer** so we
/// can produce 16-bit PCM files directly (the `record` package's wav encoder
/// is Windows-only). Keeping raw PCM means the pitch-shifter in
/// [WavProcessor] can run fully on-device, offline — no backend, no uploads.
class RecorderService {
  RecorderService();

  final AudioRecorder _rec = AudioRecorder();

  // ---- internal recording state ----
  String? _rawPath;         // destination .wav file
  RandomAccessFile? _raf;   // streaming writes (keeps memory flat)
  int _dataBytes = 0;       // payload size, patched into the header at stop()
  int _rate = 16000;        // sample rate actually requested
  Timer? _flushTimer;       // periodic byte-stream drain
  double _rms = 0;          // smoothed level 0..1 for the UI meter

  bool get isRecording => _raf != null;
  double get level => _rms;

  /// Ask the OS for mic access. Returns false when the user denies.
  Future<bool> hasPermission() async {
    try {
      return await _rec.hasPermission();
    } catch (e) {
      debugPrint('hasPermission failed: $e');
      return false;
    }
  }

  /// Start capturing mono 16-bit PCM at [sampleRate].
  Future<void> start({int sampleRate = 16000}) async {
    await cancel();
    _rate = sampleRate;
    final dir = await getTemporaryDirectory();
    _rawPath = '${dir.path}/miko_rec_${DateTime.now().millisecondsSinceEpoch}.wav';
    final f = File(_rawPath!);
    _raf = await f.open(mode: FileMode.write);
    // Reserve the 44-byte canonical header; sizes are patched in stop().
    await _raf!.writeFrom(_wavHeader(0, sampleRate));
    _dataBytes = 0;
    _rms = 0;

    final stream = await _rec.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits, // raw PCM -> our own wav container
        numChannels: 1,                  // mono halves the data rate
        sampleRate: 16000,               // plenty for a cartoon voice, tiny files
        bitRate: 256000,                 // pcm16 ignores this, kept explicit
      ),
    );

    stream.listen(
      (chunk) {
        _append(chunk);
        _rms = math.max(_rms * 0.82, _computeLevel(chunk)); // fast attack, slow decay
      },
      onError: (Object e) => debugPrint('mic stream error: $e'),
      onDone: () {/* handled by stop()/cancel() */},
      cancelOnError: true,
    );
  }

  void _append(List<int> chunk) {
    final raf = _raf;
    if (raf == null) return;
    // Fire-and-forget writes keep the tap-to-record path latency-free.
    raf.writeFrom(chunk).then((_) => _dataBytes += chunk.length).catchError((_) {});
  }

  static double _computeLevel(List<int> bytes) {
    if (bytes.length < 4) return 0;
    double peak = 0;
    final bd = ByteData.sublistView(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
    final n = (bytes.length ~/ 2).clamp(0, 2000);
    for (int i = 0; i < n; i++) {
      final v = bd.getInt16(i * 2, Endian.little).abs() / 32768.0;
      if (v > peak) peak = v;
    }
    return peak;
  }

  /// Stop capture, seal the WAV header and return the file path (null if nothing was recorded).
  Future<String?> stop() async {
    final raf = _raf;
    final path = _rawPath;
    if (raf == null || path == null) return null;
    _flushTimer?.cancel();
    _flushTimer = null;
    await _rec.stop();
    // Give the last queued writeFrom futures a moment to land.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    try {
      await raf.setPosition(0);
      await raf.writeFrom(_wavHeader(_dataBytes, _rate));
    } finally {
      await raf.flush();
      await raf.close();
    }
    _raf = null;
    _rawPath = null;
    _rms = 0;
    final st = await File(path).stat();
    if (st.length <= 44) return null; // empty take -> treat as "no speech"
    return path;
  }

  /// Abort whatever is happening (screen disposed, permission revoked, ...).
  Future<void> cancel() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    try {
      await _rec.stop();
    } catch (_) {}
    final raf = _raf;
    if (raf != null) {
      try {
        await raf.close();
      } catch (_) {}
    }
    _raf = null;
    _rawPath = null;
    _rms = 0;
  }

  static Uint8List _wavHeader(int dataBytes, int rate) {
    final bd = ByteData(44);
    void ascii(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        bd.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    bd.setUint32(4, 36 + dataBytes, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little); // fmt chunk size
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, 1, Endian.little); // mono
    bd.setUint32(24, rate, Endian.little);
    bd.setUint32(28, rate * 2, Endian.little); // byte rate
    bd.setUint16(32, 2, Endian.little); // block align
    bd.setUint16(34, 16, Endian.little); // bits per sample
    ascii(36, 'data');
    bd.setUint32(40, dataBytes, Endian.little);
    return bd.buffer.asUint8List();
  }

  void dispose() {
    cancel();
    _rec.dispose();
  }
}
