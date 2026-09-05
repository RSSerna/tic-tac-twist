import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/services/daily_challenge_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferencesDailyChallengeService service;
  final monday = DateTime(2026, 8, 31, 20);
  final tuesday = DateTime(2026, 9, 1, 9);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = SharedPreferencesDailyChallengeService();
  });

  Future<void> finishTheDay(DateTime day) async {
    await service.record(DailyChallenge.playTwoGames, day, amount: 2);
    await service.record(DailyChallenge.winOneGame, day);
    await service.record(DailyChallenge.beatToughAi, day);
    for (final mode in GameMode.values) {
      await service.recordModePlayed(mode, day);
    }
  }

  test('progress accumulates and caps at each challenge target', () async {
    await service.record(DailyChallenge.playTwoGames, monday, amount: 5);
    final progress = await service.progress(monday);

    expect(progress.countFor(DailyChallenge.playTwoGames), 2);
    expect(progress.isComplete(DailyChallenge.playTwoGames), isTrue);
  });

  test('replaying one mode does not count as playing three', () async {
    for (var i = 0; i < 4; i++) {
      await service.recordModePlayed(GameMode.ultimate, monday);
    }
    final progress = await service.progress(monday);

    expect(progress.countFor(DailyChallenge.playEachMode), 1);
    expect(progress.isComplete(DailyChallenge.playEachMode), isFalse);

    await service.recordModePlayed(GameMode.stackStatic, monday);
    await service.recordModePlayed(GameMode.stackMovable, monday);
    expect(
      (await service.progress(monday)).isComplete(DailyChallenge.playEachMode),
      isTrue,
    );
  });

  test(
    'the reward can only be claimed once, and only when the set is done',
    () async {
      // Not finished: nothing to claim.
      await service.record(DailyChallenge.winOneGame, monday);
      expect(await service.claim(monday), isFalse);

      await finishTheDay(monday);
      final full = await service.progress(monday);
      expect(full.isFull, isTrue);
      expect(full.canClaim, isTrue);

      expect(await service.claim(monday), isTrue);
      // A second tap must not grant twice.
      expect(await service.claim(monday), isFalse);
      expect((await service.progress(monday)).canClaim, isFalse);
    },
  );

  test('a new day starts empty and claimable again', () async {
    await finishTheDay(monday);
    await service.claim(monday);

    final today = await service.progress(tuesday);
    expect(today.completedCount, 0);
    expect(today.claimed, isFalse);
    expect(today.fraction, 0);

    // Yesterday's progress doesn't carry over — there's no streak to lose,
    // and no way to arrive with the day already finished.
    await finishTheDay(tuesday);
    expect(await service.claim(tuesday), isTrue);
  });

  test('the meter fraction tracks completed challenges', () async {
    expect((await service.progress(monday)).fraction, 0);

    await service.record(DailyChallenge.winOneGame, monday);
    expect(
      (await service.progress(monday)).fraction,
      1 / DailyChallenge.values.length,
    );

    await finishTheDay(monday);
    expect((await service.progress(monday)).fraction, 1);
  });
}
