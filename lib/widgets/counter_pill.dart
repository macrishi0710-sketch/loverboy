import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// "Maar: N" counter pill in Caveat, coral background.
class CounterPill extends StatelessWidget {
  const CounterPill({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
      child: Container(
        key: ValueKey(count), // re-animates on every increment
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: context.accent,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: context.accent.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          'Maar: $count',
          style: const TextStyle(
            fontFamily: AppTheme.handwritingFamily,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
