import 'package:firebase_analytics/firebase_analytics.dart';

import '../ai/difficulty.dart';
import '../engines/common/game_mode.dart';
import 'analytics_service.dart';

/// Firebase Analytics backend for [AnalyticsService]. Shares whichever
/// Firebase project [CrashlyticsCrashReportingService] ends up configured
/// with (see `crash_reporting_crashlytics.dart`) — same `Firebase.initializeApp()`
/// call, no separate setup needed here beyond that.
///
/// Not the active default yet (see `analytics_service.dart`). Override
/// `analyticsServiceProvider` with `FirebaseAnalyticsService()` once Firebase
/// is configured.
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> gameStarted({
    required GameMode mode,
    required String opponentType,
    Difficulty? difficulty,
  }) =>
      _analytics.logEvent(name: 'game_started', parameters: {
        'mode': mode.name,
        'opponent_type': opponentType,
        if (difficulty != null) 'difficulty': difficulty.name,
      });

  @override
  Future<void> gameEnded({
    required GameMode mode,
    required String result,
    required String endReason,
    required int moveCount,
    required Duration duration,
    required int firstPlayer,
  }) =>
      _analytics.logEvent(name: 'game_ended', parameters: {
        'mode': mode.name,
        'result': result,
        'end_reason': endReason,
        'move_count': moveCount,
        'duration_seconds': duration.inSeconds,
        'first_player': firstPlayer,
      });

  @override
  Future<void> tutorialCompleted(GameMode mode) =>
      _analytics.logEvent(name: 'tutorial_completed', parameters: {'mode': mode.name});

  @override
  Future<void> tutorialSkipped(GameMode mode) =>
      _analytics.logEvent(name: 'tutorial_skipped', parameters: {'mode': mode.name});

  @override
  Future<void> chestOpened(String source) =>
      _analytics.logEvent(name: 'chest_opened', parameters: {'source': source});

  @override
  Future<void> adWatched(String placement) =>
      _analytics.logEvent(name: 'ad_watched', parameters: {'placement': placement});
}
