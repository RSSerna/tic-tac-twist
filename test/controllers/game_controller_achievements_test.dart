import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/ai/difficulty.dart';
import 'package:nested_game/controllers/game_controller.dart';
import 'package:nested_game/controllers/game_session.dart';
import 'package:nested_game/controllers/session_opponents.dart';
import 'package:nested_game/controllers/skin_controller.dart';
import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/engines/common/game_status.dart';
import 'package:nested_game/engines/stacking/stacking_config.dart';
import 'package:nested_game/engines/stacking/stacking_engine.dart';
import 'package:nested_game/engines/stacking/stacking_move.dart';
import 'package:nested_game/engines/ultimate/ultimate_engine.dart';
import 'package:nested_game/engines/ultimate/ultimate_move.dart';
import 'package:nested_game/services/achievement_service.dart';
import 'package:nested_game/theme/skin.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fire-and-forget achievement/skin-unlock writes (same pattern as stats
/// elsewhere in GameController) need a beat to land before a test can
/// observe them.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

Map<String, Object?> chip(int owner, int level) => {'owner': owner, 'level': level};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('beat Impossible', () {
    test('winning vs Impossible unlocks that mode\'s achievement and the premium skin',
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
          opponents: SessionOpponents.vsAi(Difficulty.impossible));
      // P1 takes the top row; the fake AI always plays the first legal move
      // (the lowest empty cell), so it never contests it in time.
      for (final cell in [6, 7, 8]) {
        controller.submitMove(PlaceMove(1, cell));
        await settle();
      }
      expect(container.read(gameControllerProvider)!.status.outcome, GameOutcome.won);

      final unlocked = await container.read(achievementServiceProvider).unlocked();
      expect(unlocked, contains(Achievement.beatImpossibleStatic));
      expect(unlocked, isNot(contains(Achievement.beatImpossibleMovable)));

      final skins = await container.read(skinControllerProvider.future);
      expect(skins.isUnlocked(GameSkin.nestingDolls), isTrue);
    });

    test('losing to Impossible unlocks nothing', () async {
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

      // A near-finished position where the AI's only scripted (first-legal)
      // move completes its own line — the human loses.
      final losingEngine = StackingEngine.fromJson({
        'config': StackingConfig.staticMode.toJson(),
        'board': [
          [chip(2, 1)],
          [chip(2, 1)],
          <Object?>[], <Object?>[], <Object?>[], <Object?>[], <Object?>[], <Object?>[], <Object?>[],
        ],
        'currentPlayer': 2,
      });
      controller.resumeSession(GameSession(
        mode: GameMode.stackStatic,
        engine: losingEngine,
        starterPerson: 1,
        opponents: SessionOpponents.vsAi(Difficulty.impossible),
      ));
      await settle();
      expect(container.read(gameControllerProvider)!.status.outcome, GameOutcome.won);

      final unlocked = await container.read(achievementServiceProvider).unlocked();
      expect(unlocked, isEmpty);
      final skins = await container.read(skinControllerProvider.future);
      expect(skins.isUnlocked(GameSkin.nestingDolls), isFalse);
    });

    test('a timeout forfeit win does not count as beating Impossible', () async {
      final container = ProviderContainer(overrides: [
        turnTimerDurationProvider
            .overrideWithValue((seconds) => const Duration(milliseconds: 20)),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);

      // P1 (human) is about to time out against Impossible; P2 (AI) wins by
      // forfeit rather than by actually completing a line.
      final engine = StackingEngine.fromJson({
        'config': StackingConfig.staticMode.toJson(),
        'board': List.generate(9, (_) => <Object?>[]),
        'currentPlayer': 1,
      });
      final session = GameSession(
        mode: GameMode.stackStatic,
        engine: engine,
        starterPerson: 1, // person 1 (human) is Player.one — currently to move
        opponents: SessionOpponents.vsAi(Difficulty.impossible),
        turnTimerSeconds: 15,
      );
      controller.resumeSession(session);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final finished = container.read(gameControllerProvider)!;
      expect(finished.status.reason, EndReason.timeout);

      final unlocked = await container.read(achievementServiceProvider).unlocked();
      expect(unlocked, isEmpty);
    });
  });

  group('win with an L4 chip on the final move', () {
    test('placing the winning L4 unlocks the achievement and the premium skin',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);

      // P1 already owns cells 1 and 2; the final move places an L4 at cell
      // 0, completing the top row with the placed chip itself.
      final engine = StackingEngine.fromJson({
        'config': StackingConfig.staticMode.toJson(),
        'board': [
          <Object?>[],
          [chip(1, 1)],
          [chip(1, 1)],
          <Object?>[], <Object?>[], <Object?>[], <Object?>[], <Object?>[], <Object?>[],
        ],
        'currentPlayer': 1,
      });
      controller.resumeSession(
        GameSession(mode: GameMode.stackStatic, engine: engine, starterPerson: 1),
      );
      controller.submitMove(const PlaceMove(4, 0));
      await settle();

      expect(container.read(gameControllerProvider)!.status.outcome, GameOutcome.won);
      final unlocked = await container.read(achievementServiceProvider).unlocked();
      expect(unlocked, contains(Achievement.winWithL4OnFinalMove));

      final skins = await container.read(skinControllerProvider.future);
      expect(skins.isUnlocked(GameSkin.nestingDolls), isTrue);
    });

    test('winning with a smaller chip on the final move unlocks nothing', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);
      controller.startGame(GameMode.stackStatic);
      for (final cell in [0, 3, 1, 4, 2]) {
        controller.submitMove(PlaceMove(1, cell));
      }
      await settle();

      expect(container.read(gameControllerProvider)!.status.outcome, GameOutcome.won);
      final unlocked = await container.read(achievementServiceProvider).unlocked();
      expect(unlocked, isEmpty);
    });
  });

  group('claim a majority of Ultimate boards', () {
    test('winning while owning 6 of 9 boards unlocks the achievement and the premium skin',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);

      // P1 already fully owns boards 0, 1, 3, 5, 7 (top row of each small
      // board) — deliberately not a big-board line by itself (checked: no
      // row/column/diagonal of {0,1,3,5,7} is complete). Board 2 is two
      // cells in; the final move completes it, giving P1 boards
      // {0,1,2,3,5,7} — 6 total, and *now* the big-board top row [0,1,2]
      // completes for the first time.
      final cells = List<int>.filled(81, 0);
      for (final board in [0, 1, 3, 5, 7]) {
        cells[board * 9 + 0] = 1;
        cells[board * 9 + 1] = 1;
        cells[board * 9 + 2] = 1;
      }
      cells[2 * 9 + 0] = 1;
      cells[2 * 9 + 1] = 1;
      final engine = UltimateEngine.fromJson({
        'cells': cells,
        'currentPlayer': 1,
        'targetBoard': 2,
      });
      controller.resumeSession(
        GameSession(mode: GameMode.ultimate, engine: engine, starterPerson: 1),
      );
      expect(container.read(gameControllerProvider)!.status.isOngoing, isTrue);

      controller.submitMove(const UltimateMove(2, 2));
      await settle();

      expect(container.read(gameControllerProvider)!.status.outcome, GameOutcome.won);
      final unlocked = await container.read(achievementServiceProvider).unlocked();
      expect(unlocked, contains(Achievement.claimBoardMajority));

      final skins = await container.read(skinControllerProvider.future);
      expect(skins.isUnlocked(GameSkin.nestingDolls), isTrue);
    });

    test('winning without claiming every board unlocks nothing', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(gameControllerProvider.notifier);

      // P1 already fully owns boards 0 and 1; board 2 is two cells in. The
      // final move completes board 2 (and the big-board top row) — a
      // normal 3-board win, well under the majority threshold.
      final cells = List<int>.filled(81, 0);
      for (final board in [0, 1]) {
        cells[board * 9 + 0] = 1;
        cells[board * 9 + 1] = 1;
        cells[board * 9 + 2] = 1;
      }
      cells[2 * 9 + 0] = 1;
      cells[2 * 9 + 1] = 1;
      final engine = UltimateEngine.fromJson({
        'cells': cells,
        'currentPlayer': 1,
        'targetBoard': 2,
      });
      controller.resumeSession(
        GameSession(mode: GameMode.ultimate, engine: engine, starterPerson: 1),
      );
      controller.submitMove(const UltimateMove(2, 2));
      await settle();

      expect(container.read(gameControllerProvider)!.status.outcome, GameOutcome.won);
      final unlocked = await container.read(achievementServiceProvider).unlocked();
      expect(unlocked, isEmpty);
    });
  });
}
