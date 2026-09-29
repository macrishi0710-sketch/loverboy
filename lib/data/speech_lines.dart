import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Loads all speech lines from `assets/speech_lines.json`.
///
/// Everything is in ONE editable JSON file so lines can be changed
/// without touching Dart code. Falls back to a hard-coded copy of the
/// brief's lines if the asset is missing/corrupt (defensive, offline-safe).
class SpeechLines {
  SpeechLines._(this.lines, this.idleLines, this.milestones);

  /// Random reaction lines shown after a hit.
  final List<String> lines;

  /// Lines the monkey says by itself while idle.
  final List<String> idleLines;

  /// Milestone count -> line (overrides the random line at that count).
  final Map<int, String> milestones;

  static const _fallbackLines = <String>[
    "Ouch jaanu!",
    "Sorry baby!",
    "Ji maalkin!",
    "Aah! Aur maaro meri jaan 🥺",
    "Galti meri thi, sab meri galti!",
    "Ouch! Par gusse mein cute lag rahi ho",
    "Haan ji, jo hukum maalkin!",
    "Maaf kar do na baby 🥺",
    "Tumhara maara bhi pyaara lagta hai",
    "Dard hai par pyaar zyada hai 💗",
    "Bas bas jaanu... nahi, aur maaro 😌",
    "Aapke haath mein dard na ho jaye?",
    "Main to aapka hi hoon maalkin",
    "Oye hoye, meri jaan ka gussa!",
  ];

  static const _fallbackIdle = <String>[
    "Kya kar rahi ho, jaanu? 🌷",
    "Thoda nap loon? 😴",
    "Mujhe kela pasand hai, tumhe?",
  ];

  static const _fallbackMilestones = <int, String>{
    10: "Dus ho gaye! Maaf kiya na? 🥺",
    25: "Maalkin ka gussa shaant hua? 🌷",
    50: "Ab to I love you bol do na 😭💗",
  };


  /// Placeholder instance used before the JSON asset finishes loading.
  /// Uses the built-in fallback lines so the app is never silent.
  static SpeechLines empty() =>
      SpeechLines._(_fallbackLines, _fallbackIdle, _fallbackMilestones);

  /// Read + parse the JSON asset once at startup.
  static Future<SpeechLines> load() async {
    try {
      final raw = await rootBundle.loadString('assets/speech_lines.json');
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final lines = (j['lines'] as List).cast<String>();
      final idle = (j['idleLines'] as List? ?? []).cast<String>();
      final ms = <int, String>{};
      (j['milestones'] as Map? ?? {}).forEach((k, v) => ms[int.parse(k.toString())] = v.toString());
      if (lines.isEmpty) return SpeechLines._(_fallbackLines, _fallbackIdle, _fallbackMilestones);
      return SpeechLines._(lines, idle.isEmpty ? _fallbackIdle : idle, ms.isEmpty ? _fallbackMilestones : ms);
    } catch (_) {
      // Asset missing or malformed - use the built-in copy.
      return SpeechLines._(_fallbackLines, _fallbackIdle, _fallbackMilestones);
    }
  }
}
