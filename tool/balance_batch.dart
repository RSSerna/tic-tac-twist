// Phase 3 balance testing (rules doc §6.1). Runs AI-vs-AI batches and
// reports on:
//   - first-player advantage in each stacking mode
//   - draw rate and average game length per mode
//   - how often the "most visible chips" / "most claimed boards" tiebreak
//     actually decides a game
//   - whether Impossible ever loses to a weaker tier (a cheap empirical
//     probe for "unbeatable vs. forced draw", not a proof either way)
//
// Pure Dart, no Flutter dependency — run with `dart run tool/balance_batch.dart`.
// Trial counts here are deliberately modest (a first pass, not a
// statistically tight study); see the README printed at the end for how to
// scale this up.

import 'dart:math';

import 'package:nested_game/ai/ai_player.dart';
import 'package:nested_game/ai/difficulty.dart';
import 'package:nested_game/engines/common/game_engine.dart';
import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/engines/common/game_status.dart';
import 'package:nested_game/engines/common/move.dart';
import 'package:nested_game/engines/common/player.dart';

/// Safety net against a pathologically long Movable game slipping past the
/// repetition rule in some untested corner; not expected to ever fire.
const _maxPlies = 300;

class GameOutcome {
  const GameOutcome({required this.winner, required this.reason, required this.plies, required this.aborted});
  final Player? winner;
  final EndReason? reason;
  final int plies;
  final bool aborted;
}

GameOutcome playOneGame(
  GameMode mode,
  Difficulty p1Difficulty,
  Difficulty p2Difficulty,
  Random random,
) {
  GameEngine<Move> engine = mode.createEngine();
  var plies = 0;
  while (engine.status.isOngoing && plies < _maxPlies) {
    final difficulty =
        engine.currentPlayer == Player.one ? p1Difficulty : p2Difficulty;
    final move = AiPlayer(difficulty).chooseMove(mode, engine, random);
    engine = engine.applyMove(move);
    plies++;
  }
  if (engine.status.isOngoing) {
    return GameOutcome(winner: null, reason: null, plies: plies, aborted: true);
  }
  final status = engine.status;
  return GameOutcome(
      winner: status.winner, reason: status.reason, plies: plies, aborted: false);
}

class BatchStats {
  int p1Wins = 0;
  int p2Wins = 0;
  int draws = 0;
  int aborted = 0;
  int totalPlies = 0;
  int lineWins = 0;
  int tiebreakWins = 0;
  int tiebreakDraws = 0;
  int repetitionDraws = 0;

  int get games => p1Wins + p2Wins + draws + aborted;
  double get avgPlies => games == 0 ? 0 : totalPlies / games;
  double get drawRate => games == 0 ? 0 : draws / games;
  double get p1WinRate => games == 0 ? 0 : p1Wins / games;
  double get p2WinRate => games == 0 ? 0 : p2Wins / games;
  double get tiebreakFireRate =>
      games == 0 ? 0 : (tiebreakWins + tiebreakDraws) / games;

  void record(GameOutcome outcome) {
    totalPlies += outcome.plies;
    if (outcome.aborted) {
      aborted++;
      return;
    }
    switch (outcome.winner) {
      case Player.one:
        p1Wins++;
      case Player.two:
        p2Wins++;
      case null:
        draws++;
    }
    switch (outcome.reason) {
      case EndReason.line:
        lineWins++;
      case EndReason.tiebreak:
        if (outcome.winner == null) {
          tiebreakDraws++;
        } else {
          tiebreakWins++;
        }
      case EndReason.repetition:
        repetitionDraws++;
      case null:
        break;
    }
  }
}

BatchStats runBatch(
  GameMode mode,
  Difficulty p1Difficulty,
  Difficulty p2Difficulty,
  int trials,
  Random random,
) {
  final stats = BatchStats();
  for (var i = 0; i < trials; i++) {
    stats.record(playOneGame(mode, p1Difficulty, p2Difficulty, random));
  }
  return stats;
}

String _pct(double v) => '${(v * 100).toStringAsFixed(0)}%';

void _printRow(String label, BatchStats s) {
  final flags = <String>[
    if (s.aborted > 0) '${s.aborted} aborted (hit $_maxPlies-ply cap)',
  ];
  print('  $label: games=${s.games}  '
      'P1=${_pct(s.p1WinRate)} P2=${_pct(s.p2WinRate)} draw=${_pct(s.drawRate)}  '
      'avgPlies=${s.avgPlies.toStringAsFixed(1)}  '
      'tiebreakFired=${_pct(s.tiebreakFireRate)}'
      '${s.repetitionDraws > 0 ? '  repetitionDraws=${s.repetitionDraws}' : ''}'
      '${flags.isNotEmpty ? '  [${flags.join(', ')}]' : ''}');
}

Future<void> main() async {
  final random = Random(42); // fixed seed: a reproducible report

  print('=== Phase 3 balance batch (rules doc §6.1) ===\n');

  print('-- Symmetric-difficulty games (first-player advantage, draw rate, '
      'game length, tiebreak frequency) --');
  for (final mode in [GameMode.stackStatic, GameMode.stackMovable]) {
    print('${mode.name}:');
    for (final difficulty in [Difficulty.easy, Difficulty.medium, Difficulty.hard]) {
      final stats = runBatch(mode, difficulty, difficulty, 12, random);
      _printRow(difficulty.name, stats);
    }
  }
  print('ultimate:');
  for (final difficulty in [Difficulty.easy, Difficulty.medium]) {
    final stats = runBatch(GameMode.ultimate, difficulty, difficulty, 10, random);
    _printRow(difficulty.name, stats);
  }
  {
    final stats = runBatch(GameMode.ultimate, Difficulty.hard, Difficulty.hard, 2, random);
    _printRow('hard', stats);
  }

  print('\n-- Impossible spot-check: does Impossible ever lose to Hard? '
      '(small sample — a probe, not proof) --');
  for (final mode in [GameMode.stackStatic, GameMode.stackMovable]) {
    final asP1 = runBatch(mode, Difficulty.impossible, Difficulty.hard, 2, random);
    final asP2 = runBatch(mode, Difficulty.hard, Difficulty.impossible, 2, random);
    final impossibleLosses = asP1.p2Wins + asP2.p1Wins;
    final impossibleWins = asP1.p1Wins + asP2.p2Wins;
    final draws = asP1.draws + asP2.draws;
    print('  ${mode.name}: Impossible record vs Hard — '
        'W=$impossibleWins D=$draws L=$impossibleLosses '
        '(${asP1.games + asP2.games} games)');
  }
  {
    final asP1 = runBatch(GameMode.ultimate, Difficulty.impossible, Difficulty.hard, 1, random);
    final asP2 = runBatch(GameMode.ultimate, Difficulty.hard, Difficulty.impossible, 1, random);
    final impossibleLosses = asP1.p2Wins + asP2.p1Wins;
    final impossibleWins = asP1.p1Wins + asP2.p2Wins;
    final draws = asP1.draws + asP2.draws;
    print('  ultimate: Impossible record vs Hard — '
        'W=$impossibleWins D=$draws L=$impossibleLosses '
        '(${asP1.games + asP2.games} games)');
  }

  print('\nNote: trial counts here are small (a first pass to catch gross '
      'imbalances cheaply); treat percentages as directional, not precise. '
      'Re-run with higher trial counts (edit the constants above) for a '
      'statistically tighter read before locking in chip inventories.');
}
