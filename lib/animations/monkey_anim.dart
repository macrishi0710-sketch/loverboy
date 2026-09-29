import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared, cheap-to-use animation values for the monkey.
///
/// The pet screen owns ONE master [AnimationController] ticking at ~60fps and
/// derives all idle motion from it (breathing, blinking, tail sway, yawns),
/// plus one-shot controllers for hit-shake / giggle / laugh / talking mouth.
class MonkeyAnim {
  MonkeyAnim({required TickerProvider vsync, required bool reducedMotion})
      : _reduced = reducedMotion {
    master = AnimationController(
      vsync: vsync,
      duration: const Duration(seconds: 4), // one full idle cycle
    )..repeat();

    shake = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 450));
    giggle = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 900));
    laugh = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 1600));
    pet = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 1200));
    talk = AnimationController(vsync: vsync, duration: const Duration(milliseconds: 700));
  }

  final bool _reduced;
  late final AnimationController master; // idle loop
  late final AnimationController shake;  // one-shot hit reaction (~0.45s)
  late final AnimationController giggle; // belly tap wiggle
  late final AnimationController laugh;  // long-press laugh bounce
  late final AnimationController pet;    // head-pet tilt
  late final AnimationController talk;   // mouth sync while speaking

  /// Idle-cycle position 0..1.
  double get t => master.value;

  /// Vertical breathing offset in px (frozen when reduced-motion is on).
  double get breathY => _reduced ? 0 : -3.0 * math.sin(t * 2 * math.pi);

  /// Tail sway angle (radians).
  double get tailAngle => _reduced ? 0 : 0.18 * math.sin(t * 2 * math.pi);

  /// Blink curve: 1 = fully open, 0 = shut. One blink per idle cycle with a
  /// quick secondary flutter so it feels alive.
  double get blinkOpen {
    if (_reduced) return 1;
    final a = _blinkAt(t, 0.55, 0.05);
    final b = _blinkAt(t, 0.61, 0.035);
    return math.min(a, b);
  }

  double _blinkAt(double tt, double center, double halfWidth) {
    final dt = (tt - center).abs();
    if (dt >= halfWidth) return 1;
    // Triangle close->open inside the window.
    return dt / halfWidth;
  }

  /// Occasional yawn near the end of the idle cycle (0..1 intensity).
  double get yawn {
    if (_reduced) return 0;
    const c = 0.88, w = 0.09;
    final dt = (t - c).abs();
    if (dt > w) return 0;
    return 1 - dt / w;
  }

  /// Hit shake: fast decaying horizontal wiggle while [shake] runs.
  double get shakeX {
    if (_reduced || !shake.isAnimating) return 0;
    final v = shake.value; // 0..1
    return 10 * (1 - v) * math.sin(v * 2 * math.pi * 4);
  }

  /// Giggle: small side-to-side squash driven by [giggle].
  double get giggleWobble {
    if (!giggle.isAnimating) return 0;
    final v = giggle.value;
    return math.sin(v * math.pi * 6) * 0.06 * (1 - v);
  }

  /// Laugh: vertical bounce driven by [laugh].
  double get laughBounce {
    if (!laugh.isAnimating) return 0;
    final v = laugh.value;
    return -14 * math.abs(math.sin(v * math.pi * 4)) * (1 - v);
  }

  /// Mouth openness for talking mode (0..1) driven by [talk].
  double get talkMouth {
    if (!talk.isAnimating) return 0;
    if (_reduced) return 0.5; // static half-open instead of flapping
    return 0.5 + 0.5 * math.sin(talk.value * 2 * math.pi * 3);
  }

  /// Head tilt while being petted (radians, lean into the hand).
  double get petTilt {
    if (!pet.isAnimating) return 0;
    final v = pet.value;
    final env = v < 0.3 ? v / 0.3 : (v > 0.7 ? (1 - v) / 0.3 : 1.0);
    return -0.12 * env;
  }

  void playShake() => shake.forward(from: 0);
  void playGiggle() => giggle.forward(from: 0);
  void playLaugh() => laugh.forward(from: 0);
  void playPet() => pet.forward(from: 0);

  void startTalking() {
    if (_reduced) {
      talk.value = 0.5;
    } else {
      talk.repeat();
    }
  }

  void stopTalking() {
    talk.stop();
    talk.value = 0;
  }

  void dispose() {
    master.dispose();
    shake.dispose();
    giggle.dispose();
    laugh.dispose();
    pet.dispose();
    talk.dispose();
  }
}
