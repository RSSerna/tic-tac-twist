import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../theme/emote.dart';
import 'game_controller.dart';

/// What each seat is currently showing, and whether the tray is briefly
/// closed for business after a send.
@immutable
class MatchEmoteState {
  const MatchEmoteState({this.shown = const {}, this.onCooldown = false});

  /// Person (1 or 2) → the emote their bubble is displaying right now.
  /// A seat with no entry shows an empty bubble.
  final Map<int, Emote> shown;

  /// True for [MatchEmoteController.cooldown] after a send. Anti-spam, and
  /// the rule that will matter most the day there's a real opponent on the
  /// other end of it.
  final bool onCooldown;

  Emote? forPerson(int person) => shown[person];
}

/// Emotes sent during a match.
///
/// **Purely presentation state** (CLAUDE.md architecture rule 6): it never
/// reaches the engine or its serialisation, and sending one is not a move.
/// That's also why this is the layer a v2 network listener would push a
/// received emote into — exactly as the local tray does — without any engine
/// involvement.
///
/// Local-only today. In pass-and-play the opponent is sitting right there, so
/// a sent emote genuinely arrives; vs the AI it simply has no one to answer
/// it, and that seat's bubble stays empty (see `05-V2-DEFERRED.md` §4.2).
class MatchEmoteController extends Notifier<MatchEmoteState> {
  /// How long a sent emote stays on screen. Long enough to be read across
  /// the table in pass-and-play, short enough not to sit over the board.
  static const displayFor = Duration(seconds: 3);

  /// How long the tray is unavailable after a send.
  static const cooldown = Duration(seconds: 2);

  final Map<int, Timer> _clearTimers = {};
  Timer? _cooldownTimer;

  @override
  MatchEmoteState build() {
    // A new game starts with clean bubbles: `startedAt` changes only when a
    // session actually begins (including a rematch), not on every move.
    ref.listen(gameControllerProvider, (previous, next) {
      if (previous?.startedAt != next?.startedAt) _reset();
    });
    ref.onDispose(_cancelTimers);
    return const MatchEmoteState();
  }

  /// Shows [emote] in [person]'s bubble and starts the cooldown. No-ops
  /// while on cooldown — the tray reflects that, but this is the actual gate
  /// (same reasoning as `SkinController.selectSkin`).
  void send(Emote emote, {required int person}) {
    if (state.onCooldown) return;

    _clearTimers.remove(person)?.cancel();
    state = MatchEmoteState(
      shown: {...state.shown, person: emote},
      onCooldown: true,
    );

    _clearTimers[person] = Timer(displayFor, () {
      _clearTimers.remove(person);
      state = MatchEmoteState(
        shown: {...state.shown}..remove(person),
        onCooldown: state.onCooldown,
      );
    });

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(cooldown, () {
      _cooldownTimer = null;
      state = MatchEmoteState(shown: state.shown);
    });
  }

  void _reset() {
    _cancelTimers();
    state = const MatchEmoteState();
  }

  void _cancelTimers() {
    for (final timer in _clearTimers.values) {
      timer.cancel();
    }
    _clearTimers.clear();
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
  }
}

final matchEmoteControllerProvider =
    NotifierProvider<MatchEmoteController, MatchEmoteState>(
      MatchEmoteController.new,
    );
