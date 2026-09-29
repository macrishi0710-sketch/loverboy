import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The cozy room behind Miko: wall, window with soft light, floor rug,
/// a shelf and a plant - all vector, theme-aware, cheap to paint.
class RoomBackground extends StatelessWidget {
  const RoomBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RoomPainter(
        wall: context.roomWall,
        floor: context.roomFloor,
        accent: context.accent,
        dark: context.isDark,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _RoomPainter extends CustomPainter {
  _RoomPainter({required this.wall, required this.floor, required this.accent, required this.dark});
  final Color wall, floor, accent;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Wall + floor split at ~62% height (behind the monkey's feet).
    final splitY = h * 0.68;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, splitY), Paint()..color = wall);
    canvas.drawRect(Rect.fromLTWH(0, splitY, w, h - splitY), Paint()..color = floor);

    // Soft round rug under the monkey.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, splitY + 40), width: w * 0.8, height: 90),
      Paint()..color = accent.withOpacity(dark ? 0.16 : 0.18),
    );

    // Window (top-left) with warm light glow.
    final win = Rect.fromLTWH(w * 0.08, h * 0.10, w * 0.30, h * 0.22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(win, const Radius.circular(14)),
      Paint()..color = dark ? const Color(0xFF4A3550) : const Color(0xFFFFE3C7),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(win, const Radius.circular(14)),
      Paint()
        ..color = (dark ? const Color(0xFF6B4A6E) : const Color(0xFFF7C89B))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    // Window cross bars.
    final bar = Paint()
      ..color = dark ? const Color(0xFF6B4A6E) : const Color(0xFFF7C89B)
      ..strokeWidth = 4;
    canvas.drawLine(Offset(win.left + win.width / 2, win.top), Offset(win.left + win.width / 2, win.bottom), bar);
    canvas.drawLine(Offset(win.left, win.top + win.height / 2), Offset(win.right, win.top + win.height / 2), bar);

    // Shelf (top-right) with two books + a tiny plant.
    final shelfY = h * 0.16;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.62, shelfY, w * 0.30, 10),
        const Radius.circular(4),
      ),
      Paint()..color = dark ? const Color(0xFF5A3A48) : const Color(0xFFE0B08A),
    );
    canvas.drawRect(Rect.fromLTWH(w * 0.66, shelfY - 34, 12, 34), Paint()..color = accent);
    canvas.drawRect(Rect.fromLTWH(w * 0.66 + 15, shelfY - 28, 12, 28),
        Paint()..color = dark ? const Color(0xFFF6C4CF) : const Color(0xFFF6C4CF));
    // Plant pot.
    canvas.drawCircle(Offset(w * 0.85, shelfY - 16), 12, Paint()..color = const Color(0xFF7FB069));
    canvas.drawRect(Rect.fromLTWH(w * 0.85 - 10, shelfY - 12, 20, 12),
        Paint()..color = dark ? const Color(0xFFB06A5A) : const Color(0xFFD98A6A));

    // Hanging heart garland dots near top for warmth.
    final dot = Paint()..color = accent.withOpacity(0.5);
    for (int i = 0; i < 5; i++) {
      final x = w * (0.42 + i * 0.05);
      final y = h * 0.05 + (i % 2 == 0 ? 0 : 8);
      canvas.drawCircle(Offset(x, y), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _RoomPainter old) =>
      old.wall != wall || old.floor != floor || old.accent != accent || old.dark != dark;
}
