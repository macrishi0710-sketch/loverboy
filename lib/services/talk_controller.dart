import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'wav_processor.dart';

/// Talking-mode state machine: idle -> listening -> processing -> speaking.
enum TalkState { idle, requestingMic, listening, processing, speaking }

/// Owns the microphone recorder + pitch-shift pipeline for talking mode.
///
/// Flow (like the classic pet apps): hold/tap the mic button -> record ->
/// stop -> pitch up on-device -> play through SoundService while the UI
/// drives a mouth-sync animation from [amplitude]/[speakingLevel].
class TalkController extends ChangeNotifier {
  TalkController({required this.onPlayPitched});

  /// Callback wired to SoundService.playPitchedFile - keeps audio output
  /// in one place and lets the settings (sound on/off) apply consistently.
  final Future<void> Function(String path, double rate) onPlayPitched;

  static const double pitchRate = 1.6; // ~+8 semitones: funny high voice

  final AudioRecorder _rec = AudioRecorder();
  Timer? _maxRecTimer;
  Timer? _playDoneTimer;
  String? _lastRecordPath;

  TalkState _state = TalkState.idle;
  TalkState get state => _state;

  double _amplitude = 0; // live mic level (drives ear glow / meter)
  double get amplitude => _amplitude;

  StreamSubscription<Amplitude>? _ampSub;

  bool get isBusy =>
      _state == TalkState.listening || _state == TalkState.processing || _state == TalkState.speaking;

  /// Tap handler: starts recording, or stops + processes if already listening.
  Future<void> toggleRecording() async {
    switch (_state) {
      case TalkState.listening:
        await stopAndProcess();
        break;
      case TalkState.idle:
      case TalkState.requestingMic:
        await startListening();
        break;
      default:
        // Ignore taps while processing/speaking (or restart after speech).
        if (_state == TalkState.speaking) {
          await _finishSpeaking();
          await startListening();
        }
    }
  }

  Future<void> startListening() async {
    _setState(TalkState.requestingMic);
    try {
      if (!await _rec.hasPermission()) {
        _setState(TalkState.idle);
        return; // user denied - UI shows a hint bubble instead
      }
      final dir = await _tempDir();
      final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // small + universally readable
          bitRate: 96000,
          sampleRate: 16000, // 16k keeps processing cheap; fine for a pet voice
          numChannels: 1,
        ),
        path: path,
      );
      _lastRecordPath = path;
      _setState(TalkState.listening);

      // Live amplitude for the recording meter.
      _ampSub?.cancel();
      _ampSub = _rec.onAmplitudeChanged(const Duration(milliseconds: 80)).listen((amp) {
        // dBFS (-2..0 mapped) -> 0..1
        final v = ((amp.current + 40) / 40).clamp(0.0, 1.0);
        _amplitude = v * v; // perceptual-ish curve
        notifyListeners();
      });

      // Auto-stop safety cap (10 s) so we never record huge files.
      _maxRecTimer?.cancel();
      _maxRecTimer = Timer(const Duration(seconds: 10), () {
        if (_state == TalkState.listening) stopAndProcess();
      });
    } catch (e) {
      debugPrint('startListening failed: $e');
      _setState(TalkState.idle);
    }
  }

  Future<void> stopAndProcess() async {
    if (_state != TalkState.listening) return;
    _maxRecTimer?.cancel();
    await _ampSub?.cancel();
    _ampSub = null;
    _amplitude = 0;

    String? src;
    try {
      src = await _rec.stop();
    } catch (_) {
      src = null;
    }
    src ??= _lastRecordPath;
    if (src == null || !await File(src).exists()) {
      _setState(TalkState.idle);
      return;
    }

    _setState(TalkState.processing);

    // The m4a from `record` is not trivially decodable in pure Dart, so we
    // use the pragmatic approach used by many Flutter pets: re-encode via
    // audioplayers round-trip is unavailable offline -> instead we read the
    // file with the wav processor when it IS a wav, otherwise fall back to
    // playback-rate shifting (setPlaybackRate) which still raises the pitch.
    final dir = await _tempDir();
    final shifted = '${dir.path}/shifted_${DateTime.now().millisecondsSinceEpoch}.wav';
    String playPath = src;
    double rate = pitchRate;

    if (src.endsWith('.wav')) {
      playPath = await WavProcessor.processFile(src, shifted, pitchRate, 16000);
      rate = 1.0; // already shifted offline
    }
    // else: play at setPlaybackRate(pitchRate) inside SoundService.

    _setState(TalkState.speaking);
    await onPlayPitched(playPath, playPath.endsWith('.wav') ? 1.0 : pitchRate);

    // Estimate duration so the mouth animation ends roughly with the audio.
    final durMs = await _estimateDurationMs(src);
    _playDoneTimer?.cancel();
    _playDoneTimer = Timer(Duration(milliseconds: (durMs / rate).round() + 350), _finishSpeaking);
  }

  Future<int> _estimateDurationMs(String path) async {
    try {
      final stat = await File(path).stat();
      // AAC @96kbps ≈ 12 KB per second.
      return math.max(600, (stat.size / 12000 * 1000).round());
    } catch (_) {
      return 2000;
    }
  }

  Future<void> _finishSpeaking() async {
    _playDoneTimer?.cancel();
    _setState(TalkState.idle);
  }

  /// Cancel everything (called when leaving the screen).
  Future<void> cancelAll() async {
    _maxRecTimer?.cancel();
    _playDoneTimer?.cancel();
    await _ampSub?.cancel();
    _ampSub = null;
    try {
      if (await _rec.isRecording()) await _rec.stop();
    } catch (_) {}
    _setState(TalkState.idle);
  }

  void _setState(TalkState s) {
    _state = s;
    notifyListeners();
  }

  Future<Directory> _tempDir() async {
    final d = await getTemporaryDirectory();
    return d;
  }

  @override
  void dispose() {
    _maxRecTimer?.cancel();
    _playDoneTimer?.cancel();
    _ampSub?.cancel();
    _rec.dispose();
    super.dispose();
  }
}
