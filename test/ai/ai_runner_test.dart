import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/ai/ai_runner.dart';
import 'package:nested_game/ai/difficulty.dart';
import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/engines/stacking/stacking_move.dart';
import 'package:nested_game/engines/ultimate/ultimate_move.dart';

void main() {
  // Exercises the real Isolate.run round trip (engine → JSON → isolate →
  // move JSON → back), not just the in-process agent logic — the point is
  // to catch any actual isolate-serialisation problem empirically rather
  // than only reasoning about it.
  group('AiRunner (real isolate)', () {
    test('stacking: returns a legal, correctly-typed move', () async {
      const mode = GameMode.stackStatic;
      final engine = mode.createEngine();
      final move = await AiRunner.chooseMove(
        mode: mode,
        difficulty: Difficulty.easy,
        engine: engine,
      );
      expect(move, isA<StackingMove>());
      expect(engine.legalMoves(), contains(move));
    });

    test('ultimate: returns a legal, correctly-typed move', () async {
      const mode = GameMode.ultimate;
      final engine = mode.createEngine();
      final move = await AiRunner.chooseMove(
        mode: mode,
        difficulty: Difficulty.easy,
        engine: engine,
      );
      expect(move, isA<UltimateMove>());
      expect(engine.legalMoves(), contains(move));
    });
  });
}
