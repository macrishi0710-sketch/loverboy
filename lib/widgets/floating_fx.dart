import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One burst of FX spawned at a tap point: 👋 hand-pop + 3 rising emojis.
class TapBurst {
  TapBurst({required this.origin, required this.tick}) : startedAt = DateTime.now();
  final Offset origin; // local coords inside the pet area
  final int tick;      // unique id from PetController.tapTick
  final DateTime startedAt;
}

/// Renders all active bursts above the monkey. Lives in a Stack; each burst
/// animates with its own controller and removes itself when finished.
class FloatingFx extends StatefulWidget {
  const FloatingFx({super.key, required this.bursts});
  final List<TapBurst> bursts;

  @override
  State<FloatingFx> createState() => _FloatingFxState();
}

class _FloatingFxState extends State<FloatingFx> {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [for (final b in widget.bursts) _Burst(burst: b)],
      ),
    );
  }
}

class _Burst extends StatefulWidget {
  const _Burst({required this.burst});
  final TapBurst burst;
  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..forward();

  static const _emojis = ['💗', '🌷', '💕'];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduced) return const SizedBox.shrink(); // accessibility: skip FX

    final o = widget.burst.origin;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_c.value); // 0..1
        final fade = (1 - _c.value).clamp(0.0, 1.0);
        return Stack(
          children: [
            // 👋 hand pop: quick scale-in then shrink-away.
            Positioned(
              left: o.dx - 26,
              top: o.dy - 26,
              child: Opacity(
                opacity: _c.value < 0.25 ? 1 : fade,
                child: Transform.scale(
                  scale: _c.value < 0.25
                      ? Tween<double>(begin: 0.4, end: 1.35).transform(_c.value / 0.25)
                      : Tween<double>(begin: 1.35, end: 0.8).transform((_c.value - 0.25) / 0.75),
                  child: const Text('👋', style: TextStyle(fontSize: 44)),
                ),
              ),
            ),
            // Three floating emojis rising and fading with slight spread.
            for (int i = 0; i < 3; i++)
              Positioned(
                left: o.dx + (i - 1) * 26 - 14 + 8 * math.sin(t * math.pi + i),
                top: o.dy - 40 - 90 * t - i * 10,
                child: Opacity(
                  opacity: fade,
                  child: Transform.rotate(
                    angle: (i - 1) * 0.25 * t,
                    child: Text(_emojis[i], style: const TextStyle(fontSize: 26)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
