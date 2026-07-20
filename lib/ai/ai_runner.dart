import 'dart:isolate';
import 'dart:math';

import '../engines/common/game_engine.dart';
import '../engines/common/game_mode.dart';
import '../engines/common/move.dart';
import '../engines/stacking/stacking_engine.dart';
import '../engines/stacking/stacking_move.dart';
import '../engines/ultimate/ultimate_engine.dart';
import '../engines/ultimate/ultimate_move.dart';
import 'ai_player.dart';
import 'difficulty.dart';

/// Signature the controller depends on. Lets tests substitute a fast fake
/// instead of spawning a real isolate.
typedef AiMoveComputer = Future<Move> Function({
  required GameMode mode,
  required Difficulty difficulty,
  required GameEngine<Move> engine,
});

/// Computes an AI move on a background isolate so a slow search (MCTS on
/// Impossible budgets ~1.5s) never blocks the UI thread or delays queued
/// input/animation (CLAUDE.md: never block input on animation).
///
/// The engine crosses the isolate boundary as JSON rather than as an object,
/// so sendability never depends on unspecified isolate-messaging behaviour
/// for custom classes — only plain maps, lists, and primitives, which are
/// unconditionally guaranteed sendable.
abstract final class AiRunner {
  static Future<Move> chooseMove({
    required GameMode mode,
    required Difficulty difficulty,
    required GameEngine<Move> engine,
  }) async {
    final request = <String, Object?>{
      'mode': mode.name,
      'difficulty': difficulty.name,
      'engine': engine.toJson(),
      'seed': Random().nextInt(1 << 32),
    };
    final resultJson = await Isolate.run(() => _computeInIsolate(request));
    return _decodeMove(mode, resultJson);
  }

  static Map<String, Object?> _computeInIsolate(Map<String, Object?> request) {
    final mode = GameMode.values.byName(request['mode']! as String);
    final difficulty = Difficulty.values.byName(request['difficulty']! as String);
    final seed = request['seed']! as int;
    final engineJson = (request['engine']! as Map).cast<String, Object?>();
    final engine = _decodeEngine(mode, engineJson);
    final move = AiPlayer(difficulty).chooseMove(mode, engine, Random(seed));
    return move.toJson();
  }

  static GameEngine<Move> _decodeEngine(GameMode mode, Map<String, Object?> json) =>
      mode.isStacking ? StackingEngine.fromJson(json) : UltimateEngine.fromJson(json);

  static Move _decodeMove(GameMode mode, Map<String, Object?> json) => mode.isStacking
      ? StackingMove.fromJson(json)
      : UltimateMove.fromJson(json);
}
