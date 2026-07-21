import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/difficulty.dart';
import '../engines/common/game_mode.dart';

/// The exact, deliberately small event set from product doc §5 — answers a
/// handful of open balance questions (first-player advantage, draw rates,
/// whether Impossible is actually unbeatable, tutorial completion) without
/// per-move tracking or any identifier: "No user IDs. No advertising ID. No
/// per-move tracking. Aggregate only."
abstract interface class AnalyticsService {
  Future<void> gameStarted({
    required GameMode mode,
    required String opponentType,
    Difficulty? difficulty,
  });

  Future<void> gameEnded({
    required GameMode mode,
    required String result,
    required String endReason,
    required int moveCount,
    required Duration duration,
    required int firstPlayer,
  });

  Future<void> tutorialCompleted(GameMode mode);
  Future<void> tutorialSkipped(GameMode mode);

  /// Not called yet — the full chest system (product doc §3) is deferred
  /// past this phase, per the doc's own explicit trim order. Defined now so
  /// the event set is complete and ready the moment a chest source exists.
  Future<void> chestOpened(String source);

  Future<void> adWatched(String placement);
}

/// Active by default (see class doc comment on [FirebaseAnalyticsService])
/// until a Firebase project is configured and this is overridden.
final analyticsServiceProvider =
    Provider<AnalyticsService>((ref) => const NoOpAnalyticsService());

class NoOpAnalyticsService implements AnalyticsService {
  const NoOpAnalyticsService();

  @override
  Future<void> gameStarted({
    required GameMode mode,
    required String opponentType,
    Difficulty? difficulty,
  }) async {}

  @override
  Future<void> gameEnded({
    required GameMode mode,
    required String result,
    required String endReason,
    required int moveCount,
    required Duration duration,
    required int firstPlayer,
  }) async {}

  @override
  Future<void> tutorialCompleted(GameMode mode) async {}

  @override
  Future<void> tutorialSkipped(GameMode mode) async {}

  @override
  Future<void> chestOpened(String source) async {}

  @override
  Future<void> adWatched(String placement) async {}
}
