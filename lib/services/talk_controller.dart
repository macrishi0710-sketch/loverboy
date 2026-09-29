import 'dart:async';

import 'package:flutter/foundation.dart';

import 'recorder_service.dart';
import 'wav_processor.dart';

/// Talking-mode state machine: idle -> listening -> processing -> speaking.
enum TalkState { idle, requestingMic, listening, processing, speaking }

/// Drives the "repeat what the user says in a funny high-pitched voice" loop:
///
///   record (on-device PCM wav)  ->  pitch-shift up (granular WSOLA)  ->  play
///
/// Everything happens locally; audio never leaves the phone. The controller
/// also exposes [amplitude] so the UI can show a live mic meter and drive the
/// monkey's mouth-sync animation while the shifted clip plays.
class TalkController extends ChangeNotifier {
  TalkController({required this.onPlayPitched});

  /// Wired to SoundService.playPitchedFile - one place owns all audio output
  /// so the "sound off" setting is respected everywhere.
  final Future<void> Function(String path) onPlayPitched;

  static const double pitchRate = 1.65; // ~+9 semitones: classic cartoon pet voice
  static const int sampleRate = 16000;
  static const Duration maxRecording = Duration(seconds: 8);

  final RecorderService _rec = RecorderService();

  Timer? _maxTimer;      // hard cap so we never record a giant file
  Timer? _levelTimer;    // polls recorder level -> notifies UI at ~12Hz
  Timer? _playDoneTimer; // ends the "speaking" phase when audio should be over

  TalkState _state = TalkState.idle;
  TalkState get state => _state;

  double _amplitude = 0;
  double get amplitude => _amplitude;

  bool get isBusy =>
      _state == TalkState.listening || _state == TalkState.processing || _state == TalkState.speaking;

  /// Mic button tap handler.
  Future<void> toggleRecording() async {
    switch (_state) {
      case TalkState.listening:
        await stopAndProcess();
        break;
      case TalkState.idle:
      case TalkState.requestingMic:
        await startListening();
        break;
      case TalkState.speaking:
        // Interrupt current playback and start a new take.
        await _finishSpeaking();
        await startListening();
        break;
      case TalkState.processing:
        break; // momentary - ignore taps
    }
  }

  Future<void> startListening() async {
    _setState(TalkState.requestingMic);
    try {
      if (!await _rec.hasPermission()) {
        _setState(TalkState.idle);
        return; // caller listens for permissionDeniedTick to show a hint bubble
      }
      await _rec.start(sampleRate: sampleRate);
      _setState(TalkState.listening);

      _levelTimer?.cancel();
      _levelTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        _amplitude = _rec.level;
        notifyListeners();
      });

      _maxTimer?.cancel();
      _maxTimer = Timer(maxRecording, () {
        if (_state == TalkState.listening) stopAndProcess();
      });
    } catch (e) {
      debugPrint('startListening failed: $e');
      await _rec.cancel();
      _setState(TalkState.idle);
    }
  }

  Future<void> stopAndProcess() async {
    if (_state != TalkState.listening) return;
    _maxTimer?.cancel();
    _levelTimer?.cancel();
    _levelTimer = null;

    String? src;
    try {
      src = await _rec.stop();
    } catch (e) {
      debugPrint('recorder stop failed: $e');
    }
    _amplitude = 0;
    if (src == null) {
      _setState(TalkState.idle);
      return; // nothing said -> back to idle quietly
    }

    _setState(TalkState.processing);

    // Pitch-shift fully offline. shiftPath returns the raw recording as a
    // graceful fallback if anything about the file is unexpected.
    final outPath = await WavProcessor.shiftPath(src, pitchRate, sampleRate);

    _setState(TalkState.speaking);
    await onPlayPitched(outPath);

    // End the mouth animation roughly when the audio ends.
    final durMs = WavProcessor.durationMsOf(outPath, sampleRate);
    _playDoneTimer?.cancel();
    _playDoneTimer = Timer(Duration(milliseconds: durMs + 300), _finishSpeaking);
  }

  Future<void> _finishSpeaking() async {
    _playDoneTimer?.cancel();
    _playDoneTimer = null;
    _setState(TalkState.idle);
  }

  /// Cancel everything (called when leaving the screen / app paused).
  Future<void> cancelAll() async {
    _maxTimer?.cancel();
    _playDoneTimer?.cancel();
    _levelTimer?.cancel();
    _levelTimer = null;
    await _rec.cancel();
    _amplitude = 0;
    _setState(TalkState.idle);
  }

  void _setState(TalkState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _maxTimer?.cancel();
    _playDoneTimer?.cancel();
    _levelTimer?.cancel();
    _rec.dispose();
    super.dispose();
  }
}
