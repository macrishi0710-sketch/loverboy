import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../animations/monkey_anim.dart';
import '../providers/pet_controller.dart';
import '../services/talk_controller.dart';
import '../widgets/counter_pill.dart';
import '../widgets/floating_fx.dart';
import '../widgets/mic_button.dart';
import '../widgets/monkey_view.dart';
import '../widgets/room_background.dart';
import '../widgets/speech_bubble.dart';
import 'settings_screen.dart';

/// The one and only play screen: cozy room + Miko + bubble + FX + controls.
///
/// Layout uses a Stack sized to the safe area, so it works from small phones
/// (360x640 logical) up to large tablets without clipping.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final MonkeyAnim _anim;
  final List<TapBurst> _bursts = [];

  PetController get _pet => context.read<PetController>();
  TalkController get _talk => context.read<TalkController>();

  @override
  void initState() {
    super.initState();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _anim = MonkeyAnim(vsync: this, reducedMotion: reduced);
    // React to controller events by driving the animation one-shots.
    context.read<PetController>().addListener(_onPetEvent);
    context.read<TalkController>().addListener(_onTalkEvent);
  }

  int _lastTapTick = 0, _lastGiggle = 0, _lastPet = 0, _lastLaugh = 0;

  void _onPetEvent() {
    final p = _pet;
    if (p.tapTick != _lastTapTick) {
      _lastTapTick = p.tapTick;
      _anim.playShake();
      _spawnBurst(p.lastTapPosition, p.tapTick);
    }
    if (p.giggleTick != _lastGiggle) {
      _lastGiggle = p.giggleTick;
      _anim.playGiggle();
    }
    if (p.petTick != _lastPet) {
      _lastPet = p.petTick;
      _anim.playPet();
    }
    if (p.laughTick != _lastLaugh) {
      _lastLaugh = p.laughTick;
      _anim.playLaugh();
    }
  }

  TalkState _lastTalkState = TalkState.idle;

  void _onTalkEvent() {
    // Permission was requested but the recorder refused -> tell the pet so it
    // shows the hint bubble (Talking Tom-style graceful degradation).
    if (_lastTalkState == TalkState.requestingMic && _talk.state == TalkState.idle) {
      _pet.reportMicDenied();
    }
    _lastTalkState = _talk.state;

    switch (_talk.state) {
      case TalkState.speaking:
        _pet.setTalking(true);
        _anim.startTalking();
        break;
      case TalkState.idle:
        if (_pet.isTalking) {
          _pet.setTalking(false);
          _anim.stopTalking();
        }
        break;
      default:
        break;
    }
  }

  /// Add a floating FX burst; auto-remove after its animation completes.
  void _spawnBurst(Offset origin, int tick) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduced) return; // accessibility: skip particle FX entirely
    final burst = TapBurst(origin: origin, tick: tick);
    setState(() => _bursts.add(burst));
    Future.delayed(const Duration(milliseconds: 950), () {
      if (mounted) setState(() => _bursts.removeWhere((b) => b.tick == tick));
    });
  }

  @override
  void dispose() {
    _pet.removeListener(_onPetEvent);
    _talk.removeListener(_onTalkEvent);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pet = context.watch<PetController>();
    final mq = MediaQuery.of(context);
    // Keep the monkey big on small phones: cap the art height to ~52% of the
    // available space so the bubble + controls always fit.
    final petH = (mq.size.height * 0.52).clamp(240.0, 460.0);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: RoomBackground()),

          // ---- top bar: counter pill + settings ----
          Positioned(
            left: 16, right: 16, top: mq.padding.top + 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Consumer<PetController>(
                  builder: (_, p, __) => CounterPill(count: p.hits),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  icon: Icon(Icons.settings_rounded, color: Theme.of(context).colorScheme.onSurface),
                ),
              ],
            ),
          ),

          // ---- speech bubble above the monkey ----
          Positioned(
            left: 0, right: 0,
            top: mq.padding.top + 66,
            child: Column(
              children: [
                SpeechBubble(line: pet.bubbleLine),
                if (pet.bubbleLine != null) const BubbleTail(),
              ],
            ),
          ),

          // ---- the monkey (centered, slightly low like a floor pet) ----
          Align(
            alignment: const Alignment(0, 0.32),
            child: SizedBox(
              height: petH,
              width: mq.size.width * 0.9,
              child: MonkeyView(
                anim: _anim,
                pet: pet,
                onHit: (pos) => _pet.registerHit(pos),
                onBellyTap: _pet.tapBelly,
                onPetHead: _pet.petHead,
                onLongPress: _pet.longPressLaugh,
              ),
            ),
          ),

          // ---- floating hand-pop + emojis over everything ----
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: mq.padding.top + 66),
              child: FloatingFx(bursts: _bursts),
            ),
          ),

          // ---- bottom controls: mic + hint + footer ----
          Positioned(
            left: 0, right: 0, bottom: mq.padding.bottom + 10,
            child: Column(
              children: [
                const MicButtonWithHint(),
                const SizedBox(height: 8),
                Text(
                  pet.footerText,
                  style: TextStyle(
                    fontFamily: 'Caveat',
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mic button + contextual caption ("Tap & speak" / "Sun rahi hoon..." etc.)
/// plus the permission-denied hint.
class MicButtonWithHint extends StatelessWidget {
  const MicButtonWithHint();

  @override
  Widget build(BuildContext context) {
    final talk = context.watch<TalkController>();
    final pet = context.watch<PetController>();

    String caption;
    switch (talk.state) {
      case TalkState.listening:
        caption = 'Bol raha hoon... ya stop dabao 🎤';
        break;
      case TalkState.processing:
        caption = 'Awaz badal rahi hoon 😜';
        break;
      case TalkState.speaking:
        caption = 'Sun! Meri awaaz kaisi lagi? 💗';
        break;
      default:
        caption = 'Mic dabao aur bolo - main dohraunga';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MicButton(controller: talk),
        const SizedBox(height: 6),
        Text(
          caption,
          style: TextStyle(
            fontFamily: 'Caveat',
            fontSize: 19,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        // One-shot hint when the OS denied the microphone.
        if (pet.permissionDeniedTick > 0 && talk.state == TalkState.idle)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '(mic band hai - settings mein on karo)',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
