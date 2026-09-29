import 'package:flutter/material.dart';

import '../services/talk_controller.dart';
import '../theme/app_theme.dart';

/// The big coral mic button that drives talking mode.
/// Visual states: idle (mic), listening (stop + pulsing ring driven by the
/// live mic amplitude), processing (spinner), speaking (sound wave).
class MicButton extends StatelessWidget {
  const MicButton({super.key, required this.controller});

  final TalkController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final listening = state == TalkState.listening;
        final busy = state == TalkState.processing || state == TalkState.speaking;

        IconData icon;
        switch (state) {
          case TalkState.listening:
            icon = Icons.stop_rounded;
            break;
          case TalkState.processing:
            icon = Icons.autorenew_rounded;
            break;
          case TalkState.speaking:
            icon = Icons.graphic_eq_rounded;
            break;
          default:
            icon = Icons.mic_rounded;
        }

        // Pulse ring grows with live mic amplitude while listening.
        final glow = listening ? 6 + 18 * controller.amplitude : 0.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [context.accent, context.accent.withOpacity(0.85)],
            ),
            boxShadow: [
              BoxShadow(
                color: context.accent.withOpacity(0.5),
                blurRadius: glow,
                spreadRadius: listening ? glow / 3 : 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: busy ? null : () => controller.toggleRecording(),
              child: Center(
                child: state == TalkState.processing
                    ? const SizedBox(
                        width: 28, height: 28,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Icon(icon, color: Colors.white, size: 34),
              ),
            ),
          ),
        );
      },
    );
  }
}
