import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/ai/difficulty.dart';
import 'package:nested_game/controllers/game_session.dart';
import 'package:nested_game/controllers/session_opponents.dart';
import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/engines/stacking/stacking_engine.dart';
import 'package:nested_game/engines/stacking/stacking_move.dart';
import 'package:nested_game/engines/ultimate/ultimate_engine.dart';
import 'package:nested_game/engines/ultimate/ultimate_move.dart';

void main() {
  group('GameSession JSON round-trip', () {
    test('pass-and-play stacking session preserves engine state and seating',
        () {
      final engine = (GameMode.stackStatic.createEngine() as StackingEngine)
          .applyMove(const PlaceMove(2, 4));
      final session = GameSession(
        mode: GameMode.stackStatic,
        engine: engine,
        starterPerson: 2,
      );

      final restored =
          GameSession.fromJson(jsonDecode(jsonEncode(session.toJson())));

      expect(restored.mode, GameMode.stackStatic);
      expect(restored.starterPerson, 2);
      expect(restored.opponents.personTwoIsAi, isFalse);
      expect(
        jsonEncode(restored.engine.toJson()),
        jsonEncode(session.engine.toJson()),
      );
    });

    test('vs-AI Ultimate session preserves opponents and difficulty', () {
      final engine = (GameMode.ultimate.createEngine() as UltimateEngine)
          .applyMove(const UltimateMove(4, 0));
      final session = GameSession(
        mode: GameMode.ultimate,
        engine: engine,
        starterPerson: 1,
        opponents: SessionOpponents.vsAi(Difficulty.hard),
      );

      final restored =
          GameSession.fromJson(jsonDecode(jsonEncode(session.toJson())));

      expect(restored.opponents.personTwoIsAi, isTrue);
      expect(restored.opponents.difficulty, Difficulty.hard);
      expect((restored.engine as UltimateEngine).targetBoard, 0);
    });

    test('presentation state is never serialised — resumes with a clean slate',
        () {
      final base = GameSession(
        mode: GameMode.stackStatic,
        engine: GameMode.stackStatic.createEngine(),
        starterPerson: 1,
      );
      final withUiState = base.copy(
        selectedLevel: 2,
        stagedMove: const PlaceMove(2, 4),
        aiThinking: true,
      );

      final restored =
          GameSession.fromJson(jsonDecode(jsonEncode(withUiState.toJson())));

      expect(restored.selectedLevel, isNull);
      expect(restored.selectedCell, isNull);
      expect(restored.stagedMove, isNull);
      expect(restored.aiThinking, isFalse);
    });

    test('rejects malformed snapshots', () {
      expect(
        () => GameSession.fromJson({
          'mode': 'stackStatic',
          'engine': GameMode.stackStatic.createEngine().toJson(),
          'starterPerson': 3, // only 1 or 2 are valid
          'opponents': SessionOpponents.human.toJson(),
        }),
        throwsFormatException,
      );
    });
  });
}
