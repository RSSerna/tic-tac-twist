import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/ai/difficulty.dart';
import 'package:nested_game/controllers/game_controller.dart';
import 'package:nested_game/controllers/game_session.dart';
import 'package:nested_game/controllers/session_opponents.dart';
import 'package:nested_game/controllers/settings_controller.dart';
import 'package:nested_game/controllers/turn_timer_preset.dart';
import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/engines/common/game_status.dart';
import 'package:nested_game/engines/common/move.dart';
import 'package:nested_game/engines/stacking/stacking_config.dart';
import 'package:nested_game/engines/stacking/stacking_engine.dart';
import 'package:nested_game/engines/stacking/stacking_move.dart';
import 'package:nested_game/services/settings_service.dart';
import 'package:nested_game/services/stats/stats_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the preset via the real service (into the mock SharedPreferences
/// store `setUp` resets), then overrides [turnTimerDurationProvider] so the
/// countdown runs in milliseconds instead of real seconds — a real, short
/// wait is simpler and more reliable here than fighting fake-time
/// infrastructure interacting with the shared_preferences mock plugin.
Future<ProviderContainer> containerWithTurnTimer(TurnTimerPreset preset) async {
  await SharedPreferencesSettingsService().setTurnTimerPreset(preset);
  final container = ProviderContainer(overrides: [
    turnTimerDurationProvider
        .overrideWithValue((seconds) => Duration(milliseconds: seconds * 10)),
  ]);
  await container.read(settingsControllerProvider.future);
  return container;
}

/// Fire-and-forget stats writes (same pattern as persistence elsewhere in
/// GameController) need a beat to actually land before a test can observe
/// them — this flushes pending microtasks/short async chains without
/// depending on fake-time infrastructure.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

Map<String, Object?> chip(int owner, int level) => {'owner': owner, 'level': level};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('stats recording on natural game end', () {
    test('local pass-and-play win is recorded by seat', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame(GameMode.stackStatic);
      // P1 wins the top row.
      for (final (level, cell) in [(1, 0), (1, 3), (1, 1), (1, 4), (1, 2)]) {
        controller.submitMove(PlaceMove(level, cell));
      }
      expect(container.read(gameControllerProvider)!.status.isOver, isTrue);
      await settle();

      final stats = await container.read(statsServiceProvider).statsFor(GameMode.stackStatic);
      expect(stats.local.p1Wins, 1);
      expect(stats.local.p2Wins, 0);
      expect(stats.local.draws, 0);
    });

    test('local pass-and-play draw is recorded', () async {
      // One ply before test/engines/stacking_static_test.dart's verified
      // "exact tie → draw" fixture: P1's last chip (an L3) not yet placed
      // at cell 2 (its removal doesn't expose a line for either side —
      // hand-checked; cell 0's L4 looked like a simpler removal at first,
      // but it's the only thing blocking a P2 win at 0-3-6). resumeSession
      // loads an ALREADY-terminal state as-is without invoking the
      // recording hook, so the transition itself has to happen via
      // submitMove for _recordResult to fire, same as real play.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      final oneMoveEarly = StackingEngine.fromJson({
        'config': StackingConfig.staticMode.toJson(),
        'board': [
          [chip(2, 1), chip(2, 2), chip(1, 4)],
          [chip(1, 1), chip(2, 2)],
          [chip(2, 1), chip(2, 2)], // P1's L3 not placed here yet
          [chip(1, 1), chip(2, 3)],
          <Object?>[],
          [chip(2, 1), chip(1, 3)],
          [chip(1, 2), chip(2, 3)],
          [chip(1, 1), chip(1, 2)],
          [chip(1, 2), chip(2, 4)],
        ],
        'currentPlayer': 1,
      });
      expect(oneMoveEarly.status.isOngoing, isTrue);
      controller.resumeSession(
        GameSession(mode: GameMode.stackStatic, engine: oneMoveEarly, starterPerson: 1),
      );
      controller.submitMove(const PlaceMove(3, 2));
      expect(container.read(gameControllerProvider)!.status,
          const GameStatus.draw(EndReason.tiebreak));
      await settle();

      final stats = await container.read(statsServiceProvider).statsFor(GameMode.stackStatic);
      expect(stats.local.draws, 1);
    });

    test('vs-AI win and loss are recorded from the human\'s perspective', () async {
      // A synchronous fake AI that always plays a specific injected move —
      // lets the test choreograph exact outcomes instead of relying on real
      // search. Same seam vs_ai_flow_test.dart uses.
      Move? nextAiMove;
      final container = ProviderContainer(overrides: [
        aiRunnerProvider.overrideWithValue(({
          required mode,
          required difficulty,
          required engine,
        }) async =>
            nextAiMove ?? engine.legalMoves().first),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);

      // Human (P1) wins: P1 takes the top row, AI (P2) plays elsewhere.
      controller.startGame(GameMode.stackStatic,
          opponents: SessionOpponents.vsAi(Difficulty.easy));
      nextAiMove = const PlaceMove(1, 3);
      controller.submitMove(const PlaceMove(1, 0));
      await settle();
      nextAiMove = const PlaceMove(1, 4);
      controller.submitMove(const PlaceMove(1, 1));
      await settle();
      controller.submitMove(const PlaceMove(1, 2)); // wins
      await settle();
      expect(container.read(gameControllerProvider)!.status.outcome, GameOutcome.won);

      var stats = await container.read(statsServiceProvider).statsFor(GameMode.stackStatic);
      expect(stats.vsAi[Difficulty.easy]!.wins, 1);

      // Human loses: injected near-finished position where the AI's only
      // scripted move completes its own line.
      final losingEngine = StackingEngine.fromJson({
        'config': StackingConfig.staticMode.toJson(),
        'board': [
          [chip(2, 1)],
          [chip(2, 1)],
          <Object?>[],
          <Object?>[],
          <Object?>[],
          <Object?>[],
          <Object?>[],
          <Object?>[],
          <Object?>[],
        ],
        'currentPlayer': 2,
      });
      nextAiMove = const PlaceMove(1, 2); // completes 0,1,2 for the AI
      controller.resumeSession(GameSession(
        mode: GameMode.stackStatic,
        engine: losingEngine,
        starterPerson: 1,
        opponents: SessionOpponents.vsAi(Difficulty.easy),
      ));
      await settle();
      expect(container.read(gameControllerProvider)!.status.outcome, GameOutcome.won);
      stats = await container.read(statsServiceProvider).statsFor(GameMode.stackStatic);
      expect(stats.vsAi[Difficulty.easy]!.losses, 1);
    });
  });

  group('abandon', () {
    test('abandoning an ongoing vs-AI game records a loss and clears state',
        () async {
      final container = ProviderContainer(overrides: [
        aiRunnerProvider.overrideWithValue(({
          required mode,
          required difficulty,
          required engine,
        }) async =>
            engine.legalMoves().first),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame(GameMode.stackStatic,
          opponents: SessionOpponents.vsAi(Difficulty.hard));

      await controller.abandonGame();
      await settle();

      expect(container.read(gameControllerProvider), isNull);
      final stats =
          await container.read(statsServiceProvider).statsFor(GameMode.stackStatic);
      expect(stats.vsAi[Difficulty.hard]!.losses, 1);
    });

    test('abandoning an ongoing local game clears state with no stats effect',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame(GameMode.stackStatic);

      await controller.abandonGame();
      await settle();

      expect(container.read(gameControllerProvider), isNull);
      final stats =
          await container.read(statsServiceProvider).statsFor(GameMode.stackStatic);
      expect(stats.local.total, 0);
    });

    test('abandoning after the game already ended has no stats effect', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame(GameMode.stackStatic);
      for (final (level, cell) in [(1, 0), (1, 3), (1, 1), (1, 4), (1, 2)]) {
        controller.submitMove(PlaceMove(level, cell));
      }
      await settle();
      final statsAfterWin =
          await container.read(statsServiceProvider).statsFor(GameMode.stackStatic);

      await controller.abandonGame();
      await settle();

      final statsAfterAbandon =
          await container.read(statsServiceProvider).statsFor(GameMode.stackStatic);
      expect(statsAfterAbandon.local.p1Wins, statsAfterWin.local.p1Wins);
    });
  });

  group('turn timer', () {
    test('expiry forfeits the game to the other player and records it', () async {
      // seconds15 → 150ms via turnTimerDurationProvider's test override.
      final container = await containerWithTurnTimer(TurnTimerPreset.seconds15);
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame(GameMode.stackStatic); // local: P1 to move first

      await Future<void>.delayed(const Duration(milliseconds: 200));

      final session = container.read(gameControllerProvider)!;
      expect(session.status.reason, EndReason.timeout);
      expect(session.status.outcome, GameOutcome.won);
      // P1 was to move and let the clock run out — P2 wins by forfeit.
      expect(session.personFor(session.status.winner!), 2);

      final stats =
          await container.read(statsServiceProvider).statsFor(GameMode.stackStatic);
      expect(stats.local.p2Wins, 1);
    });

    test('a move before expiry cancels the pending forfeit', () async {
      final container = await containerWithTurnTimer(TurnTimerPreset.seconds15);
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame(GameMode.stackStatic);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      controller.submitMove(const PlaceMove(1, 4));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // 200ms has passed but no single turn ever reached 150ms
      // uninterrupted, so nothing should have forfeited.
      expect(container.read(gameControllerProvider)!.status.isOngoing, isTrue);
      controller.exitGame(); // cancel the still-pending fresh timer
    });

    test('off (the default) never forfeits', () async {
      final container = ProviderContainer(overrides: [
        turnTimerDurationProvider
            .overrideWithValue((seconds) => Duration(milliseconds: seconds * 10)),
      ]);
      addTearDown(container.dispose);
      await container.read(settingsControllerProvider.future);
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame(GameMode.stackStatic);

      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(container.read(gameControllerProvider)!.status.isOngoing, isTrue);
    });
  });
}
