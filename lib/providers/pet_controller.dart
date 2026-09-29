import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/speech_lines.dart';
import '../services/sound_service.dart';

/// The single source of truth for the whole app:
/// hit counter, current bubble line, monkey face state, settings.
class PetController extends ChangeNotifier {
  PetController({required this.sound, required this.lines});

  final SoundService sound;
  SpeechLines lines; // swapped in once the JSON asset loads

  // ---------- persisted keys ----------
  static const _kHits = 'hit_count';
  static const _kSound = 'sound_on';
  static const _kVibe = 'vibration_on';
  static const _kFooter = 'footer_text';
  static const _defaultFooter = 'Sirf Yashi ke liye 💗';

  // ---------- state ----------
  int get hits => _hits;
  int _hits = 0;

  String? _bubbleLine;        // null -> no bubble visible
  String? get bubbleLine => _bubbleLine;

  /// Face the monkey is currently making.
  MonkeyFace get face => _face;
  MonkeyFace _face = MonkeyFace.happy;

  /// Set while talking-mode audio plays so the mouth can animate open/closed.
  bool get isTalking => _isTalking;
  bool _isTalking = false;

  /// Incremented on every belly tap - the widget layer reacts with a wiggle.
  int giggleTick = 0;
  /// Incremented on every head-pet drag - triggers the happy tilt.
  int petTick = 0;
  /// Incremented on long-press - triggers full laugh.
  int laughTick = 0;
  /// Incremented when the mic permission is denied - the screen shows a hint.
  int permissionDeniedTick = 0;

  void notifyMicDenied() {
    permissionDeniedTick++;
    showBubble('Mic ki permission chahiye 🎤 Settings mein jaakar de do');
    notifyListeners();
  }

  Timer? _bubbleTimer;
  Timer? _faceTimer;
  Timer? _idleTimer;

  String footerText = _defaultFooter;
  bool get soundsOn => sound.soundsEnabled;
  bool get vibrationOn => sound.vibrationEnabled;

  int _lastRandomIndex = -1; // prevents the same random line twice in a row

  /// Replace the placeholder lines with the parsed JSON asset (called from main).
  void setLines(SpeechLines l) {
    lines = l;
    notifyListeners();
  }

  // ---------- boot ----------
  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    _hits = sp.getInt(_kHits) ?? 0;
    sound.soundsEnabled = sp.getBool(_kSound) ?? true;
    sound.vibrationEnabled = sp.getBool(_kVibe) ?? true;
    footerText = sp.getString(_kFooter) ?? _defaultFooter;
    notifyListeners();
    _scheduleIdleChatter();
  }

  // ---------- hit (tap/hit anywhere on the monkey body) ----------
  void registerHit(Offset at) {
    _hits++;
    SharedPreferences.getInstance().then((sp) => sp.setInt(_kHits, _hits));

    // "ow" face + shake for ~0.45s, then back to happy.
    _faceTimer?.cancel();
    _setFace(MonkeyFace.ouch);
    _faceTimer = Timer(const Duration(milliseconds: 450), () => _setFace(MonkeyFace.happy));

    // Milestone line overrides the random line at exact counts.
    final milestone = lines.milestones[_hits];
    showBubble(milestone ?? _nextRandomLine());

    sound.playOuch();
    sound.lightImpact();
    // `at` is used by the view layer for the hand-pop + emoji origin.
    lastTapPosition = at;
    tapTick++;
    notifyListeners();
  }

  Offset lastTapPosition = Offset.zero;
  int tapTick = 0; // bump -> FloatingFx widget spawns a new burst

  String _nextRandomLine() {
    if (lines.lines.length == 1) return lines.lines.first;
    int i;
    do {
      i = math.Random().nextInt(lines.lines.length);
    } while (i == _lastRandomIndex);
    _lastRandomIndex = i;
    return lines.lines[i];
  }

  // ---------- extra interactions ----------
  void tapBelly() {
    giggleTick++;
    sound.playGiggle();
    _setFace(MonkeyFace.giggle, hold: const Duration(milliseconds: 900));
    notifyListeners();
  }

  DateTime? _lastPetAt;
  void petHead() {
    // Throttle: a fast drag fires many pan updates - only react every 700 ms.
    final now = DateTime.now();
    if (_lastPetAt != null && now.difference(_lastPetAt!) < const Duration(milliseconds: 700)) {
      return;
    }
    _lastPetAt = now;
    petTick++;
    sound.playHappy();
    _setFace(MonkeyFace.loved, hold: const Duration(milliseconds: 1200));
    notifyListeners();
  }

  void longPressLaugh() {
    laughTick++;
    sound.playLaugh();
    _setFace(MonkeyFace.laugh, hold: const Duration(milliseconds: 1600));
    notifyListeners();
  }

  // ---------- talking mode hooks ----------
  void setTalking(bool v) {
    if (_isTalking == v) return;
    _isTalking = v;
    notifyListeners();
  }

  void micDenied() {
    showBubble("Mic ki permission de do na 🎤");
  }

  // ---------- bubble ----------
  void showBubble(String text) {
    _bubbleTimer?.cancel();
    _bubbleLine = text;
    notifyListeners();
    _bubbleTimer = Timer(const Duration(milliseconds: 1700), () {
      _bubbleLine = null;
      notifyListeners();
    });
  }

  void _setFace(MonkeyFace f, {Duration? hold}) {
    _face = f;
    notifyListeners();
    if (hold != null) {
      _faceTimer?.cancel();
      _faceTimer = Timer(hold, () {
        _face = MonkeyFace.happy;
        notifyListeners();
      });
    }
  }

  // ---------- idle chatter ----------
  void _scheduleIdleChatter() {
    _idleTimer?.cancel();
    final delay = 8 + math.Random().nextDouble() * 10; // 8..18 s
    _idleTimer = Timer(Duration(seconds: delay.round()), () {
      if (_bubbleLine == null && _face == MonkeyFace.happy && !_isTalking) {
        // Random idle line, also never repeated twice in a row.
        final idx = math.Random().nextInt(lines.idleLines.length);
        showBubble(lines.idleLines[idx]);
      }
      _scheduleIdleChatter();
    });
  }

  // ---------- settings ----------
  Future<void> setSounds(bool v) async {
    sound.soundsEnabled = v;
    (await SharedPreferences.getInstance()).setBool(_kSound, v);
    notifyListeners();
  }

  Future<void> setVibration(bool v) async {
    sound.vibrationEnabled = v;
    (await SharedPreferences.getInstance()).setBool(_kVibe, v);
    notifyListeners();
  }

  Future<void> setFooter(String text) async {
    footerText = text.trim().isEmpty ? _defaultFooter : text.trim();
    (await SharedPreferences.getInstance()).setString(_kFooter, footerText);
    notifyListeners();
  }

  /// Called by the UI when the OS denied microphone access.
  void reportMicDenied() => notifyMicDenied();

  Future<void> resetCounter() async {
    _hits = 0;
    (await SharedPreferences.getInstance()).setInt(_kHits, 0);
    showBubble('Nayi shuruaat! 😌');
    notifyListeners();
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _faceTimer?.cancel();
    _idleTimer?.cancel();
    super.dispose();
  }
}

/// Facial expressions the vector renderer knows how to draw.
enum MonkeyFace { happy, ouch, giggle, loved, laugh }
