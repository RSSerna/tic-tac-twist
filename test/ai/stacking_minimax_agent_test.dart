import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/ai/difficulty.dart';
import 'package:nested_game/ai/stacking/stacking_minimax_agent.dart';
import 'package:nested_game/engines/common/player.dart';
import 'package:nested_game/engines/stacking/stacking_config.dart';
import 'package:nested_game/engines/stacking/stacking_engine.dart';
import 'package:nested_game/engines/stacking/stacking_move.dart';

Map<String, Object?> chip(int owner, int level) =>
    {'owner': owner, 'level': level};

Map<String, Object?> stateJson(
  StackingConfig config,
  List<List<Map<String, Object?>>> board,
  int currentPlayer,
) =>
    {'config': config.toJson(), 'board': board, 'currentPlayer': currentPlayer};

void main() {
  // Hard/Impossible have zero injected randomness (rules doc §6), so their
  // tactical choices are deterministic and safe to assert on exactly.
  const agent = StackingMinimaxAgent(Difficulty.hard);

  test('takes an immediate winning placement', () {
    // P1 tops at 0 and 1; cell 2 is open — placing anything there wins,
    // regardless of level (win check ignores level).
    final engine = StackingEngine.fromJson(stateJson(
      StackingConfig.staticMode,
      [
        [chip(1, 1)],
        [chip(1, 1)],
        [],
        [chip(2, 2)],
        [],
        [],
        [],
        [],
        [],
      ],
      1,
    ));
    final move = agent.chooseMove(engine, Random(0));
    expect(move, isA<PlaceMove>());
    expect((move as PlaceMove).cell, 2);
  });

  test('blocks the opponent\'s immediate winning line', () {
    // P2 to move; P1 threatens 0,1,2. Occupying cell 2 and covering either
    // of P1's chips at 0/1 are both valid blocks — assert the black-box
    // property (the threat is gone) rather than one specific cell.
    final engine = StackingEngine.fromJson(stateJson(
      StackingConfig.staticMode,
      [
        [chip(1, 1)],
        [chip(1, 1)],
        [],
        [chip(2, 2)],
        [],
        [],
        [],
        [],
        [],
      ],
      2,
    ));
    final move = agent.chooseMove(engine, Random(0));
    final after = engine.applyMove(move as PlaceMove);
    final stillThreatened = after.topChipAt(0)?.owner == Player.one &&
        after.topChipAt(1)?.owner == Player.one &&
        after.topChipAt(2)?.owner == Player.one;
    expect(stillThreatened, isFalse,
        reason: 'AI left P1\'s winning line 0,1,2 intact');
    expect(after.status.isOngoing, isTrue);
  });

  test('a forced pass is returned without searching', () {
    // P1 holds only chips too small to land anywhere; P2 still has moves,
    // so the game continues rather than ending.
    final engine = StackingEngine.fromJson(stateJson(
      StackingConfig.staticMode,
      [
        [chip(1, 4)],
        [chip(1, 3)],
        [chip(2, 4)],
        [chip(2, 2)],
        [chip(1, 2), chip(2, 3)],
        [chip(1, 3)],
        [chip(1, 2)],
        [chip(1, 2)],
        [chip(2, 2)],
      ],
      1,
    ));
    expect(engine.legalMoves(), const [PassMove()]);
    expect(agent.chooseMove(engine, Random(0)), const PassMove());
  });

  test('always returns a legal move, every tier, both stacking configs', () {
    // Deep tiers carry a real time budget, so this only plays a couple of
    // plies per tier to keep the suite fast rather than exhaustive.
    const pliesPerTier = {
      Difficulty.easy: 2,
      Difficulty.medium: 2,
      Difficulty.hard: 1,
      Difficulty.impossible: 1,
    };
    for (final difficulty in Difficulty.values) {
      for (final config in [StackingConfig.staticMode, StackingConfig.movableMode]) {
        final tierAgent = StackingMinimaxAgent(difficulty);
        var engine = StackingEngine.initial(config);
        final plies = pliesPerTier[difficulty]!;
        for (var ply = 0; ply < plies && engine.status.isOngoing; ply++) {
          final legal = engine.legalMoves();
          final move = tierAgent.chooseMove(engine, Random(ply));
          expect(legal, contains(move),
              reason: '$difficulty/$config produced an illegal move');
          engine = engine.applyMove(move);
        }
      }
    }
  });
}
