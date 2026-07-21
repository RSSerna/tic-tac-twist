import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../engines/common/game_engine.dart';
import '../engines/common/game_mode.dart';
import '../engines/common/move.dart';
import '../engines/stacking/stacking_move.dart';
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
      // A plain literal, not a `<<` shift: `1 << 32` wrapped to 0 on the web
      // runtime (`nextInt(0)` then throws a RangeError) — observed via a
      // real DartError in Chrome, not caught by `flutter test` since tests
      // always run on the VM, never the web JS runtime. Bit-shift results
      // near the int width aren't reliably portable there, so this avoids
      // `<<` entirely rather than guessing at a shift amount that happens
      // to be safe. 2^31-1 is still ~2.1 billion seed values.
      'seed': Random().nextInt(2147483647),
    };
    // dart:isolate has no web implementation at all — `Isolate.run` throws
    // "Unsupported operation" there unconditionally (confirmed via a real
    // DartError in Chrome), not just under some configuration. There's no
    // background-thread equivalent to fall back to on web without adding
    // Web Worker infrastructure, so this runs on the main thread instead.
    // The `Future.delayed` first just lets the "AI thinking" indicator
    // actually paint before the computation blocks the UI thread — it does
    // NOT prevent the freeze itself. Impossible's ~1.5s MCTS budget will
    // still visibly freeze the tab on web until real Web Worker support is
    // built (a bigger follow-up, not part of this fix).
    final resultJson = kIsWeb
        ? await Future<void>.delayed(Duration.zero).then((_) => _computeInIsolate(request))
        : await Isolate.run(() => _computeInIsolate(request));
    return _decodeMove(mode, resultJson);
  }

  static Map<String, Object?> _computeInIsolate(Map<String, Object?> request) {
    final mode = GameMode.values.byName(request['mode']! as String);
    final difficulty = Difficulty.values.byName(request['difficulty']! as String);
    final seed = request['seed']! as int;
    final engineJson = (request['engine']! as Map).cast<String, Object?>();
    final engine = mode.decodeEngine(engineJson);
    final move = AiPlayer(difficulty).chooseMove(mode, engine, Random(seed));
    return move.toJson();
  }

  static Move _decodeMove(GameMode mode, Map<String, Object?> json) => mode.isStacking
      ? StackingMove.fromJson(json)
      : UltimateMove.fromJson(json);
}
