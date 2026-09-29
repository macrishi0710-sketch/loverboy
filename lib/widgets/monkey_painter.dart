import 'package:flutter/material.dart';

import '../animations/monkey_anim.dart';
import '../providers/pet_controller.dart';
import '../theme/app_theme.dart';

/// Miko drawn entirely with Canvas primitives so every layer can animate
/// independently at 60fps (no image decoding, no SVG re-parse per frame).
/// The matching layered vector source is assets/monkey/monkey.svg.
///
/// Draw space: a 400x500 virtual canvas scaled to fit the given size.
class MonkeyPainter extends CustomPainter {
  MonkeyPainter({required this.anim, required this.pet, required this.dark});

  final MonkeyAnim anim;
  final MonkeyFace face;
  final bool dark;

  // Palette (fur slightly lightened in dark mode for contrast).
  Color get fur => dark ? const Color(0xFFC79360) : const Color(0xFFB9854C);
  Color get furDark => dark ? const Color(0xFFB07E48) : const Color(0xFFA8763F);
  Color get tan => dark ? const Color(0xFFF7DFC2) : const Color(0xFFF2D6B3);
  Color get line => dark ? const Color(0xFFEFE0D8) : const Color(0xFF4A2B35);
  Color get blush => const Color(0x99F6A5B8);
  Color get pupil => const Color(0xFF3A2418);

  @override
  void paint(Canvas canvas, Size size) {
    // Scale the 400x500 art into the widget box.
    final s = size.width / 400 < size.height / 500 ? size.width / 400 : size.height / 500;
    canvas.save();
    canvas.translate((size.width - 400 * s) / 2, (size.height - 500 * s) / 2);
    canvas.scale(s);

    // Global offsets from animations.
    final dy = anim.breathY + anim.laughBounce;
    final dx = anim.shakeX;
    final giggleRot = anim.giggleWobble;

    _drawTail(canvas);
    canvas.save();
    canvas.translate(dx, dy);
    canvas.rotate(giggleRot); // whole-body wobble on belly tickles
    _drawBody(canvas);
    _drawArms(canvas);
    _drawFeet(canvas);
    _drawHead(canvas);
    canvas.restore();
    canvas.restore();
  }

  Paint _fill(Color c) => Paint()..color = c..style = PaintingStyle.fill;
  Paint _stroke(Color c, double w) =>
      Paint()..color = c..strokeWidth = w..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;

  // ---------- layers ----------

  void _drawTail(Canvas canvas) {
    canvas.save();
    // Pivot at the hip (262,372), sway angle from idle loop.
    canvas.translate(262, 372);
    canvas.rotate(anim.tailAngle);
    canvas.translate(-262, -372);
    final p = Path()
      ..moveTo(262, 372)
      ..cubicTo(318, 366, 344, 330, 332, 292)
      ..cubicTo(326, 272, 306, 268, 300, 284)
      ..cubicTo(296, 296, 308, 302, 314, 294);
    canvas.drawPath(p, _stroke(furDark, 16));
    canvas.restore();
  }

  void _drawBody(Canvas canvas) {
    canvas.drawOval(Rect.fromCircle(center: const Offset(200, 352), radius: 96), _fill(fur));
    // squash slightly wider than tall
    canvas.drawOval(const Rect.fromLTRB(108, 248, 292, 456), _fill(fur));
    // belly patch (tappable zone matches PetView hit-testing)
    canvas.drawOval(const Rect.fromLTRB(142, 300, 258, 436), _fill(tan));
  }

  void _drawArms(Canvas canvas) {
    // Left arm hangs; during laugh/giggle it flaps a bit via sin offset.
    final flap = anim.laugh.isAnimating || anim.giggle.isAnimating
        ? 0.25 * (anim.laugh.value > 0 || anim.giggle.value > 0 ? 1 : 0)
        : 0.0;
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(200 + side * 80, 320);
      canvas.rotate(side * flap);
      canvas.translate(-(200 + side * 80), -320);
      final path = Path()
        ..moveTo(200 + side * 80, 320)
        ..cubicTo(200 + side * 64, 344, 200 + side * 60, 384, 200 + side * 78, 412)
        ..cubicTo(200 + side * 84, 426, 200 + side * 66, 424, 200 + side * 62, 410)
        ..cubicTo(200 + side * 56, 388, 200 + side * 62, 352, 200 + side * 54, 332)
        ..close();
      canvas.drawPath(path, _fill(furDark));
      canvas.drawCircle(Offset(200 + side * 78, 414), 16, _fill(tan)); // paw
      canvas.restore();
    }
  }

  void _drawFeet(Canvas canvas) {
    canvas.drawOval(const Rect.fromLTRB(122, 436, 182, 468), _fill(furDark));
    canvas.drawOval(const Rect.fromLTRB(218, 436, 278, 468), _fill(furDark));
  }

  void _drawHead(Canvas canvas) {
    canvas.save();
    canvas.translate(200, 182);
    canvas.rotate(anim.petTilt); // lean into pets
    canvas.translate(-200, -182);

    // Ears (inner disc wiggles slightly with tail phase for life).
    for (final side in [-1.0, 1.0]) {
      final cx = 200 + side * 104;
      canvas.drawCircle(Offset(cx, 176), 30, _fill(furDark));
      canvas.drawCircle(Offset(cx - side * 2, 176), 17, _fill(tan));
    }

    // Skull + face patch.
    canvas.drawCircle(const Offset(200, 182), 112, _fill(fur));
    canvas.drawOval(const Rect.fromLTRB(114, 138, 286, 286), _fill(tan));

    _drawBrows(canvas);
    _drawEyes(canvas);
    _drawCheeks(canvas);

    // Nose.
    canvas.drawOval(const Rect.fromLTRB(188, 204, 212, 220), _fill(const Color(0xFF8A5A34)));
    canvas.drawCircle(const Offset(196, 211), 2, _fill(line));
    canvas.drawCircle(const Offset(204, 211), 2, _fill(line));

    _drawMouth(canvas);
    canvas.restore();
  }

  void _drawBrows(Canvas canvas) {
    // Raise brows during "ouch", relax when loved.
    final lift = face == MonkeyFace.ouch ? -8.0 : (face == MonkeyFace.loved ? 2.0 : 0.0);
    final l = Path()
      ..moveTo(136, 150 + lift)
      ..quadraticBezierTo(158, 138 + lift, 182, 148 + lift);
    final r = Path()
      ..moveTo(218, 148 + lift)
      ..quadraticBezierTo(242, 138 + lift, 264, 150 + lift);
    final p = _stroke(const Color(0xFF6B4A2B), 7);
    canvas.drawPath(l, p);
    canvas.drawPath(r, p);
  }

  void _drawEyes(Canvas canvas) {
    // openness: blink curve normally; squeezed shut on ouch; happy arcs when laughing.
    double open = anim.blinkOpen;
    if (face == MonkeyFace.ouch) open = 0;
    if (face == MonkeyFace.laugh || face == MonkeyFace.giggle) open = 0.25;
    if (face == MonkeyFace.loved) open = 0.5;

    for (final cx in [160.0, 240.0]) {
      final center = Offset(cx, 182);
      if (open <= 0.08 && face == MonkeyFace.ouch) {
        // Squeezed-shut ">_<" style curved lines.
        final dir = cx < 200 ? -1.0 : 1.0;
        final p = Path()
          ..moveTo(cx - 12, 176)
          ..quadraticBezierTo(cx, 188, cx + 12, 176)
          ..moveTo(cx - 12, 190)
          ..quadraticBezierTo(cx, 178, cx + 12, 190);
        canvas.drawPath(p, _stroke(line, 5));
        assert(dir != 0);
      } else if (open <= 0.25 && (face == MonkeyFace.laugh || face == MonkeyFace.giggle)) {
        // Happy closed arcs ^_^
        final p = Path()
          ..moveTo(cx - 14, 186)
          ..quadraticBezierTo(cx, 168, cx + 14, 186);
        canvas.drawPath(p, _stroke(line, 5));
      } else if (face == MonkeyFace.loved) {
        // Soft half-closed content eyes.
        canvas.drawCircle(center, 16, _fill(Colors.white));
        canvas.drawCircle(center.translate(0, 4), 9, _fill(pupil));
        canvas.drawCircle(center.translate(3, 1), 3, _fill(Colors.white));
        // Droopy lid
        canvas.drawOval(Rect.fromLTWH(cx - 17, 165, 34, 12), _fill(fur));
      } else {
        // Normal open eye, squashed vertically by blink amount.
        final h = 16.0 * open.clamp(0.08, 1.0);
        canvas.drawOval(Rect.fromLTWH(cx - 16, 182 - h, 32, 2 * h), _fill(Colors.white));
        if (open > 0.35) {
          canvas.drawOval(Rect.fromLTWH(cx - 9 + 3, 184 - 9 * open, 18, 18 * open), _fill(pupil));
          canvas.drawCircle(Offset(cx + 6, 179), 3, _fill(Colors.white));
        }
      }
    }
  }

  void _drawCheeks(Canvas canvas) {
    // Blush stronger when loved / after hits.
    final boost = (face == MonkeyFace.loved || face == MonkeyFace.ouch) ? 1.25 : 1.0;
    for (final cx in [132.0, 268.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, 216), width: 32 * boost, height: 20 * boost),
        _fill(blush),
      );
    }
  }

  void _drawMouth(Canvas canvas) {
    switch (face) {
      case MonkeyFace.ouch:
        // Big open "ow" oval.
        canvas.drawOval(const Rect.fromLTRB(182, 232, 218, 268), _fill(const Color(0xFF7A3040)));
        canvas.drawOval(const Rect.fromLTRB(190, 252, 210, 266), _fill(const Color(0xFFF0788C))); // tongue
        break;
      case MonkeyFace.laugh:
      case MonkeyFace.giggle:
        // Wide open grin.
        final p = Path()
          ..moveTo(168, 234)
          ..quadraticBezierTo(200, 276, 232, 234)
          ..close();
        canvas.drawPath(p, _fill(const Color(0xFF7A3040)));
        break;
      case MonkeyFace.loved:
        // Small gentle smile.
        final p = Path()
          ..moveTo(180, 240)
          ..quadraticBezierTo(200, 256, 220, 240);
        canvas.drawPath(p, _stroke(line, 6));
        break;
      case MonkeyFace.happy:
        // Talking-mode mouth overrides the smile with an animated oval.
        final m = anim.talkMouth;
        if (m > 0.05) {
          final h = 6 + 26 * m;
          canvas.drawOval(
            Rect.fromCenter(center: const Offset(200, 246), width: 34, height: h),
            _fill(const Color(0xFF7A3040)),
          );
        } else if (anim.yawn > 0.05) {
          // Occasional idle yawn.
          final h = 8 + 22 * anim.yawn;
          canvas.drawOval(
            Rect.fromCenter(center: const Offset(200, 248), width: 26, height: h),
            _fill(const Color(0xFF7A3040)),
          );
        } else {
          final p = Path()
            ..moveTo(172, 236)
            ..quadraticBezierTo(200, 262, 228, 236);
          canvas.drawPath(p, _stroke(line, 6));
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant MonkeyPainter old) => true; // driven by vsync anyway
}
