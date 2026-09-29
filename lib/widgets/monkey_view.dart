import 'package:flutter/material.dart';

import '../animations/monkey_anim.dart';
import '../providers/pet_controller.dart';
import 'monkey_painter.dart';

/// The interactive monkey.
///
/// Owns nothing but gestures + painting: [anim] is supplied by the screen so
/// all one-shot controllers (shake/giggle/laugh/pet/talk) can be driven from
/// HomeScreen's listeners on PetController / TalkController.
///
/// Hit-testing happens in the 400x500 virtual art canvas (same space as
/// MonkeyPainter):
///   * head circle (center 200,182, r ~118)     -> drag = pet (happy sound)
///   * belly oval (142,300)-(258,436)           -> tap = giggle
///   * anywhere else inside the body silhouette-> tap = HIT (ouch reaction)
///   * long-press anywhere                       -> laugh
class MonkeyView extends StatefulWidget {
  const MonkeyView({
    super.key,
    required this.anim,
    required this.pet,
    required this.onHit,
    required this.onBellyTap,
    required this.onPetHead,
    required this.onLongPress,
  });

  final MonkeyAnim anim;
  final PetController pet;
  final void Function(Offset localPos) onHit;
  final VoidCallback onBellyTap;
  final VoidCallback onPetHead;
  final VoidCallback onLongPress;

  @override
  State<MonkeyView> createState() => _MonkeyViewState();
}

class _MonkeyViewState extends State<MonkeyView> {
  // Virtual canvas constants - must match MonkeyPainter's draw space.
  static const Size _art = Size(400, 500);
  static const Offset _headC = Offset(200, 182);
  static const double _headR = 118;
  static const Rect _belly = Rect.fromLTRB(142, 300, 258, 436);

  DateTime? _lastPet;

  /// Throttled so a fast drag doesn't spam the happy sound.
  void _maybePet() {
    final now = DateTime.now();
    if (_lastPet == null || now.difference(_lastPet!) > const Duration(milliseconds: 700)) {
      _lastPet = now;
      widget.onPetHead();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      // Same fit logic as MonkeyPainter: uniform scale, centered.
      final s = (box.maxWidth / _art.width < box.maxHeight / _art.height)
          ? box.maxWidth / _art.width
          : box.maxHeight / _art.height;
      final offX = (box.maxWidth - _art.width * s) / 2;
      final offY = (box.maxHeight - _art.height * s) / 2;

      /// Convert a local pointer position into art coordinates.
      Offset toArt(Offset p) => Offset((p.dx - offX) / s, (p.dy - offY) / s);

      bool inBody(Offset a) {
        if ((_headC - a).distance <= _headR) return true; // head + ears
        if (a.dx >= 104 && a.dx <= 296 && a.dy >= 244 && a.dy <= 470) return true; // torso/arms
        if (Rect.fromLTWH(118, 430, 168, 44).contains(a)) return true; // feet
        return false;
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) {
          final a = toArt(d.localPosition);
          if (!inBody(a)) return; // taps on the room do nothing
          if (_belly.contains(a)) {
            widget.onBellyTap();
          } else {
            widget.onHit(d.localPosition); // view-local pos -> hand-pop origin
          }
        },
        onLongPress: widget.onLongPress,
        // Pan (any direction) over the head = petting. Using onPan* avoids
        // competing with tap/long-press recognizers for the other zones.
        onPanUpdate: (d) {
          final a = toArt(d.localPosition);
          if ((_headC - a).distance <= _headR + 12) _maybePet();
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([
            widget.anim.master, widget.anim.shake, widget.anim.giggle,
            widget.anim.laugh, widget.anim.pet, widget.anim.talk,
          ]),
          builder: (context, _) => CustomPaint(
            size: Size(box.maxWidth, box.maxHeight),
            painter: MonkeyPainter(
              anim: widget.anim,
              pet: widget.pet,
              dark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
      );
    });
  }
}
