import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../theme/rarity.dart';

enum ChestRevealPhase { cycling, landed }

/// What the reveal sheet (`ChestRevealSheet`) shows right now: which pill is
/// lit ([displayedTier]) and the actual rolled outcome ([finalTier]) — the
/// same value once [phase] reaches [ChestRevealPhase.landed].
@immutable
class ChestRevealState {
  const ChestRevealState({
    required this.phase,
    required this.displayedTier,
    required this.finalTier,
  });

  final ChestRevealPhase phase;
  final Rarity displayedTier;
  final Rarity finalTier;
}

/// Drives the chest-opening reveal: a brief cycle through every rarity tier
/// (least → most rare, `Rarity.values`' own order) that settles on whichever
/// one the chest actually rolled.
///
/// **Only ever started for a fragment-reward outcome** (`shop_screen.dart`'s
/// `_ClaimBar._claim`) — a whole-cosmetic instant unlock has no rarity of
/// its own in this design (`ChestController._grantOne`'s doc comment), so
/// animating one would misrepresent it.
///
/// Same `Timer`-driven `Notifier` idiom as `MatchEmoteController`: a
/// controller-owned state machine advanced by `Timer`s, rendered reactively
/// by a dumb widget, rather than a raw `AnimationController` (none exist
/// anywhere else in this codebase).
class ChestRevealController extends Notifier<ChestRevealState?> {
  /// How often the highlighted pill advances while cycling.
  static const tick = Duration(milliseconds: 130);

  /// How many ticks the cycle runs before landing — ~1.3s.
  static const _ticks = 10;

  /// How long the sheet stays up after landing before auto-dismissing, if
  /// the player never taps it.
  static const autoDismissAfterLanding = Duration(milliseconds: 1600);

  Timer? _cycleTimer;
  Timer? _autoDismissTimer;
  int _ticksElapsed = 0;

  @override
  ChestRevealState? build() {
    ref.onDispose(_cancelTimers);
    return null; // no reveal in progress
  }

  /// Starts a new cycle landing on [finalTier]. No-ops if one is already
  /// running — the sheet's own dismissal is what clears [state] back to
  /// null, so a second `start` mid-cycle would only happen from a bug
  /// upstream, not a legitimate double-claim (the daily chest allows
  /// exactly one claim).
  void start(Rarity finalTier) {
    if (state != null) return;
    _ticksElapsed = 0;
    state = ChestRevealState(
      phase: ChestRevealPhase.cycling,
      displayedTier: Rarity.values.first,
      finalTier: finalTier,
    );
    _cycleTimer = Timer.periodic(tick, (_) => _advance());
  }

  void _advance() {
    _ticksElapsed++;
    final current = state;
    if (current == null) return; // dismissed mid-cycle
    if (_ticksElapsed >= _ticks) {
      _land(current.finalTier);
      return;
    }
    final next = Rarity
        .values[(Rarity.values.indexOf(current.displayedTier) + 1) %
            Rarity.values.length];
    state = ChestRevealState(
      phase: ChestRevealPhase.cycling,
      displayedTier: next,
      finalTier: current.finalTier,
    );
  }

  void _land(Rarity finalTier) {
    _cycleTimer?.cancel();
    _cycleTimer = null;
    state = ChestRevealState(
      phase: ChestRevealPhase.landed,
      displayedTier: finalTier,
      finalTier: finalTier,
    );
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(autoDismissAfterLanding, dismiss);
  }

  /// Tap-to-skip (design doc §4: "celebrations may run longer but must be
  /// tap-skippable"). While cycling, jumps straight to the landed tier
  /// rather than dismissing outright — the player still sees what they won.
  void skipToLanded() {
    final current = state;
    if (current == null || current.phase == ChestRevealPhase.landed) return;
    _land(current.finalTier);
  }

  /// Closes the sheet. Reduced-motion callers skip straight here without
  /// ever calling [start] — see `_ClaimBar._claim`.
  void dismiss() {
    _cancelTimers();
    state = null;
  }

  void _cancelTimers() {
    _cycleTimer?.cancel();
    _cycleTimer = null;
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
  }
}

final chestRevealControllerProvider =
    NotifierProvider<ChestRevealController, ChestRevealState?>(
      ChestRevealController.new,
    );
