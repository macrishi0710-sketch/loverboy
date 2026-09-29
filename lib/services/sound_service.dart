import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

/// Central place for all sound + haptic effects.
///
/// - Every FX player is pre-created once (fast, no allocation on tap).
/// - If a setting is off the call becomes a no-op.
/// - Haptics degrade gracefully when unsupported by the device.
class SoundService {
  SoundService();

  bool soundsEnabled = true;
  bool vibrationEnabled = true;

  // One player per short FX so rapid taps never cut each other off.
  final AudioPlayer _ouch = AudioPlayer(playerId: 'ouch');
  final AudioPlayer _boing = AudioPlayer(playerId: 'boing');
  final AudioPlayer _giggle = AudioPlayer(playerId: 'giggle');
  final AudioPlayer _happy = AudioPlayer(playerId: 'happy');
  final AudioPlayer _laugh = AudioPlayer(playerId: 'laugh');

  // Dedicated player for talking-mode playback (pitch-shifted recordings).
  final AudioPlayer _voice = AudioPlayer(playerId: 'voice');

  /// Short cartoon "ouch/boing" for a hit.
  Future<void> playOuch() => _play(_ouch, 'sounds/ouch.mp3');
  Future<void> playBoing() => _play(_boing, 'sounds/boing.mp3');
  Future<void> playGiggle() => _play(_giggle, 'sounds/giggle.mp3');
  Future<void> playHappy() => _play(_happy, 'sounds/happy.mp3');
  Future<void> playLaugh() => _play(_laugh, 'sounds/laugh.mp3');

  /// Play a recorded wav file. The file was already pitch-shifted on-device
  /// by [WavProcessor], so it plays at normal rate; `sound off` still applies.
  Future<void> playPitchedFile(String path) async {
    if (!soundsEnabled) return;
    try {
      await _voice.stop();
      await _voice.setReleaseMode(ReleaseMode.stop);
      await _voice.play(DeviceFileSource(path));
    } catch (e) {
      debugPrint('playPitchedFile failed: $e');
    }
  }

  Future<void> _play(AudioPlayer p, String asset) async {
    if (!soundsEnabled) return;
    try {
      await p.stop();
      // Low latency mode where supported keeps taps feeling instant.
      await p.setPlaySpeed(1.0);
      await p.play(AssetSource(asset));
    } catch (_) {
      // Never crash the UI because of audio issues (e.g. emulator quirks).
    }
  }

  /// Light haptic tick used on hits. Uses Android-only strong/medium calls
  /// through HapticsPlus and falls back to standard patterns.
  Future<void> lightImpact() async {
    if (!vibrationEnabled) return;
    try {
      final ok = await Haptics.canVibrate();
      if (ok) {
        // Try the extra-light pattern first (feels like a soft "tap").
        final v = await Haptics.vibrate(HapticsType.light);
        if (!v) await Haptics.vibrate(HapticsType.selection);
      }
    } on PlatformException {
      // Some devices throw when haptics are disabled at OS level - ignore.
    } catch (_) {}
  }

  Future<void> dispose() async {
    for (final p in [_ouch, _boing, _giggle, _happy, _laugh, _voice]) {
      try {
        await p.dispose();
      } catch (_) {}
    }
  }
}
