import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Speech bubble with a tail pointing down at the monkey. Uses Caveat.
/// Fades+pops in when [line] is non-null, disappears otherwise.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.line});
  final String? line;

  @override
  Widget build(BuildContext context) {
    final visible = line != null && line!.isNotEmpty;
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      scale: visible ? 1 : 0.6,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: visible ? 1 : 0,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(context.isDark ? 0.4 : 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            line ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.handwritingFamily,
              fontWeight: FontWeight.w600,
              fontSize: 24,
              height: 1.15,
              color: context.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bubble tail drawn under the text so it reads as coming from the monkey.
class BubbleTail extends StatelessWidget {
  const BubbleTail({super.key});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 14),
      painter: _TailPainter(color: context.cardBg),
    );
  }
}

class _TailPainter extends CustomPainter {
  _TailPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) => old.color != color;
}
