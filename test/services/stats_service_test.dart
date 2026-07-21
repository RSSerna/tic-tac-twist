import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/ai/difficulty.dart';
import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/services/stats/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts at all-zero for every mode', () async {
    final service = SharedPreferencesStatsService();
    for (final mode in GameMode.values) {
      final stats = await service.statsFor(mode);
      expect(stats.local.total, 0);
      for (final difficulty in Difficulty.values) {
        expect(stats.vsAi[difficulty]!.total, 0);
      }
    }
  });

  test('records local results by seat, independently per mode', () async {
    final service = SharedPreferencesStatsService();
    await service.recordLocalResult(GameMode.stackStatic, winnerPerson: 1);
    await service.recordLocalResult(GameMode.stackStatic, winnerPerson: 1);
    await service.recordLocalResult(GameMode.stackStatic, winnerPerson: 2);
    await service.recordLocalResult(GameMode.stackStatic, winnerPerson: null);

    final staticStats = await service.statsFor(GameMode.stackStatic);
    expect(staticStats.local.p1Wins, 2);
    expect(staticStats.local.p2Wins, 1);
    expect(staticStats.local.draws, 1);

    final ultimateStats = await service.statsFor(GameMode.ultimate);
    expect(ultimateStats.local.total, 0, reason: 'modes must not bleed into each other');
  });

  test('records vs-AI results split by difficulty', () async {
    final service = SharedPreferencesStatsService();
    await service.recordVsAiResult(
        GameMode.ultimate, Difficulty.easy, MatchResult.win);
    await service.recordVsAiResult(
        GameMode.ultimate, Difficulty.easy, MatchResult.win);
    await service.recordVsAiResult(
        GameMode.ultimate, Difficulty.impossible, MatchResult.loss);
    await service.recordVsAiResult(
        GameMode.ultimate, Difficulty.impossible, MatchResult.draw);

    final stats = await service.statsFor(GameMode.ultimate);
    expect(stats.vsAi[Difficulty.easy]!.wins, 2);
    expect(stats.vsAi[Difficulty.easy]!.losses, 0);
    expect(stats.vsAi[Difficulty.impossible]!.losses, 1);
    expect(stats.vsAi[Difficulty.impossible]!.draws, 1);
    expect(stats.vsAi[Difficulty.medium]!.total, 0,
        reason: 'difficulties must not bleed into each other');
  });

  test('persists across service instances (real disk-backed behaviour)', () async {
    await SharedPreferencesStatsService()
        .recordLocalResult(GameMode.stackMovable, winnerPerson: 2);
    final reloaded = await SharedPreferencesStatsService()
        .statsFor(GameMode.stackMovable);
    expect(reloaded.local.p2Wins, 1);
  });

  test('resetAll clears every mode back to zero', () async {
    final service = SharedPreferencesStatsService();
    await service.recordLocalResult(GameMode.stackStatic, winnerPerson: 1);
    await service.recordVsAiResult(
        GameMode.ultimate, Difficulty.hard, MatchResult.win);

    await service.resetAll();

    for (final mode in GameMode.values) {
      final stats = await service.statsFor(mode);
      expect(stats.local.total, 0);
      expect(stats.vsAi.values.every((c) => c.total == 0), isTrue);
    }
  });
}
