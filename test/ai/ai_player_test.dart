import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/ai/ai_player.dart';
import 'package:nested_game/ai/difficulty.dart';
import 'package:nested_game/engines/common/game_mode.dart';

void main() {
  test('dispatches to a legal move for every mode', () {
    // Easy only — this is a wiring/dispatch smoke test, not a search
    // correctness test (those live in the per-agent test files), so it
    // stays on the fast tier.
    const player = AiPlayer(Difficulty.easy);
    for (final mode in GameMode.values) {
      final engine = mode.createEngine();
      final move = player.chooseMove(mode, engine, Random(0));
      expect(engine.legalMoves(), contains(move),
          reason: '$mode produced an illegal move');
    }
  });
}
