import 'dart:math';

import '../engines/common/game_engine.dart';
import '../engines/common/game_mode.dart';
import '../engines/common/move.dart';
import '../engines/stacking/stacking_engine.dart';
import '../engines/ultimate/ultimate_engine.dart';
import 'difficulty.dart';
import 'stacking/stacking_minimax_agent.dart';
import 'ultimate/ultimate_heuristic_agent.dart';
import 'ultimate/ultimate_mcts_agent.dart';

/// Picks and runs the right concrete agent for a mode + difficulty (rules
/// doc §6): minimax for stacking; a heuristic agent for Ultimate Easy/Medium
/// (full search isn't viable there) and MCTS for Ultimate Hard/Impossible.
///
/// Synchronous and pure Dart. The async/isolate boundary lives one layer up
/// in [AiRunner], so this stays trivially unit-testable on its own.
class AiPlayer {
  const AiPlayer(this.difficulty);

  final Difficulty difficulty;

  Move chooseMove(GameMode mode, GameEngine<Move> engine, Random random) {
    if (mode.isStacking) {
      return StackingMinimaxAgent(difficulty)
          .chooseMove(engine as StackingEngine, random);
    }
    final ultimateEngine = engine as UltimateEngine;
    return switch (difficulty) {
      Difficulty.easy ||
      Difficulty.medium =>
        UltimateHeuristicAgent(difficulty).chooseMove(ultimateEngine, random),
      Difficulty.hard ||
      Difficulty.impossible =>
        UltimateMctsAgent(difficulty).chooseMove(ultimateEngine, random),
    };
  }
}
