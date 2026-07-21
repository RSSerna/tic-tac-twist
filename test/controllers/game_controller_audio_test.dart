import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/game_controller.dart';
import 'package:nested_game/controllers/game_session.dart';
import 'package:nested_game/controllers/settings_controller.dart';
import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/engines/stacking/stacking_config.dart';
import 'package:nested_game/engines/stacking/stacking_engine.dart';
import 'package:nested_game/engines/stacking/stacking_move.dart';
import 'package:nested_game/engines/ultimate/ultimate_engine.dart';
import 'package:nested_game/engines/ultimate/ultimate_move.dart';
import 'package:nested_game/services/audio_service.dart';
import 'package:nested_game/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Map<String, Object?> chip(int owner, int level) => {'owner': owner, 'level': level};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeAudioService audio;
  late ProviderContainer container;
  late GameController controller;

  ProviderContainer buildContainer() {
    audio = FakeAudioService();
    final c = ProviderContainer(overrides: [
      audioServiceProvider.overrideWithValue(audio),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    container = buildContainer();
    controller = container.read(gameControllerProvider.notifier);
  });

  group('stacking', () {
    test('placing on an empty cell plays chipPlace, not chipCover', () {
      controller.startGame(GameMode.stackStatic);
      controller.submitMove(const PlaceMove(1, 0));

      expect(audio.sfxPlayed, [SfxSound.chipPlace]);
    });

    test('covering an occupied cell plays chipCover', () {
      final engine = StackingEngine.fromJson({
        'config': StackingConfig.staticMode.toJson(),
        'board': [
          [chip(2, 1)], // P2's L1 sits alone at cell 0
          <Object?>[], <Object?>[], <Object?>[], <Object?>[],
          <Object?>[], <Object?>[], <Object?>[], <Object?>[],
        ],
        'currentPlayer': 1,
      });
      controller.resumeSession(
        GameSession(mode: GameMode.stackStatic, engine: engine, starterPerson: 1),
      );
      audio.sfxPlayed.clear(); // resumeSession itself plays nothing; belt and suspenders

      controller.submitMove(const PlaceMove(2, 0)); // P1's L2 covers P2's L1

      expect(audio.sfxPlayed, [SfxSound.chipCover]);
    });

    test('a game-ending move also plays gameWin', () {
      controller.startGame(GameMode.stackStatic);
      // P1 takes the top row: 0, 3, 1, 4, 2 (own moves interleaved with P2's).
      for (final (level, cell) in [(1, 0), (1, 3), (1, 1), (1, 4), (1, 2)]) {
        controller.submitMove(PlaceMove(level, cell));
      }

      expect(container.read(gameControllerProvider)!.status.isOver, isTrue);
      expect(audio.sfxPlayed.where((s) => s == SfxSound.gameWin).length, 1);
    });

    test('an invalid attempt with a selection active plays invalidMove', () {
      controller.startGame(GameMode.stackStatic);
      controller.submitMove(const PlaceMove(4, 0)); // P1's L4 at cell 0 — uncoverable
      controller.submitMove(const PlaceMove(1, 1)); // P2 elsewhere
      audio.sfxPlayed.clear();

      controller.selectInventoryLevel(1);
      controller.onStackingCellTapped(0); // L1 can never cover an L4 — illegal

      expect(audio.sfxPlayed, [SfxSound.invalidMove]);
    });
  });

  group('ultimate', () {
    test('a placement plays chipPlace; completing a small board also plays boardClaim', () {
      // Board 0: P1 already owns cells 0 and 1; targetBoard forces play
      // there, so completing cell 2 both places a chip and claims the board.
      final cells = List<int>.filled(81, 0);
      cells[0] = 1;
      cells[1] = 1;
      final engine = UltimateEngine.fromJson({
        'cells': cells,
        'currentPlayer': 1,
        'targetBoard': 0,
      });
      controller.resumeSession(
        GameSession(mode: GameMode.ultimate, engine: engine, starterPerson: 1),
      );
      audio.sfxPlayed.clear();

      controller.submitMove(const UltimateMove(0, 2));

      expect(audio.sfxPlayed, [SfxSound.chipPlace, SfxSound.boardClaim]);
    });

    test('an invalid tap on a non-legal board plays invalidMove', () {
      controller.startGame(GameMode.ultimate);
      controller.submitMove(const UltimateMove(0, 0)); // sends P2 to board 0
      audio.sfxPlayed.clear();

      controller.onUltimateCellTapped(1, 0); // board 1 isn't the forced target

      expect(audio.sfxPlayed, [SfxSound.invalidMove]);
    });
  });

  group('sfx setting', () {
    test('sfxEnabled=false suppresses every sound', () async {
      await SharedPreferencesSettingsService().setSfxEnabled(false);
      final c = buildContainer();
      await c.read(settingsControllerProvider.future); // resolve before reading it
      final ctrl = c.read(gameControllerProvider.notifier);
      ctrl.startGame(GameMode.stackStatic);
      ctrl.submitMove(const PlaceMove(1, 0));

      expect(audio.sfxPlayed, isEmpty);
    });
  });
}
