import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engines/common/game_mode.dart';
import '../services/daily_challenge_service.dart';

/// Today's daily-challenge progress, and the claim that empties the meter.
///
/// Reads the clock through [now] so tests can cross midnight without waiting
/// for it — the service itself is time-agnostic, taking "today" as an
/// argument (engines stay time-independent; this is a controller concern,
/// same rule as turn timers).
class DailyChallengeController extends AsyncNotifier<DailyProgress> {
  DateTime now() => DateTime.now();

  @override
  Future<DailyProgress> build() =>
      ref.read(dailyChallengeServiceProvider).progress(now());

  Future<void> _refresh() async {
    // Recording is fire-and-forget from the game controller, so this can
    // land after the provider container is gone (a finished game, then the
    // app or a test tearing down). Reading a disposed Ref throws, and the
    // write itself has already happened — there's just nothing left to tell.
    if (!ref.mounted) return;
    final progress = await ref
        .read(dailyChallengeServiceProvider)
        .progress(now());
    if (!ref.mounted) return;
    state = AsyncData(progress);
  }

  /// Called once per finished game. [won] is from the finishing player's
  /// perspective in vs-AI; in pass-and-play someone always wins, which is
  /// still a win for whoever is holding the phone.
  Future<void> recordGameFinished({
    required GameMode mode,
    required bool won,
    required bool beatToughAi,
  }) async {
    // Captured before any await: the container may be disposed by the time
    // these resolve, and the writes should still complete.
    final service = ref.read(dailyChallengeServiceProvider);
    final today = now();
    await service.record(DailyChallenge.playTwoGames, today);
    await service.recordModePlayed(mode, today);
    if (won) await service.record(DailyChallenge.winOneGame, today);
    if (beatToughAi) await service.record(DailyChallenge.beatToughAi, today);
    await _refresh();
  }

  /// Takes today's reward. Returns false if there was nothing to take, so a
  /// caller never grants on a double tap or an unfinished set.
  Future<bool> claim() async {
    final claimed = await ref
        .read(dailyChallengeServiceProvider)
        .claim(now());
    if (claimed) await _refresh();
    return claimed;
  }
}

final dailyChallengeControllerProvider =
    AsyncNotifierProvider<DailyChallengeController, DailyProgress>(
      DailyChallengeController.new,
    );
