import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/engines/common/game_engine.dart';
import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/engines/common/game_status.dart';
import 'package:nested_game/engines/common/move.dart';
import 'package:nested_game/engines/common/player.dart';
import 'package:nested_game/engines/ultimate/ultimate_engine.dart';
import 'package:nested_game/engines/ultimate/ultimate_move.dart';
import 'package:nested_game/tutorial/tutorial_script.dart';
import 'package:nested_game/tutorial/tutorial_step.dart';

/// Every scripted move must be legal, in order, against a fresh engine —
/// this is the real engine the tutorial runs on (design doc §7: "do not
/// build a separate mock engine"), so a bug here is a bug a real player
/// would hit mid-lesson.
void main() {
  group('every scripted move is legal in sequence, and nothing ends early', () {
    for (final mode in GameMode.values) {
      test(mode.name, () {
        final script = TutorialScript.forMode(mode);
        GameEngine<Move> engine = mode.createEngine();
        final moveSteps = script.steps
            .where((s) => s is TutorialHumanMove || s is TutorialOpponentMove)
            .toList();

        for (var i = 0; i < moveSteps.length; i++) {
          final step = moveSteps[i];
          final move = switch (step) {
            TutorialHumanMove(:final move) => move,
            TutorialOpponentMove(:final move) => move,
            _ => throw StateError('unreachable'),
          };
          expect(engine.status.isOngoing, isTrue,
              reason: 'game ended before scripted move #$i ($move) played');
          expect(engine.legalMoves(), contains(move),
              reason: 'scripted move #$i ($move) is illegal at this point');
          engine = engine.applyMove(move);
        }
      });
    }
  });

  test('Static tutorial ends in a real win for the human (P1)', () {
    final script = TutorialScript.forMode(GameMode.stackStatic);
    GameEngine<Move> engine = GameMode.stackStatic.createEngine();
    for (final step in script.steps) {
      if (step case TutorialHumanMove(:final move) || TutorialOpponentMove(:final move)) {
        engine = engine.applyMove(move);
      }
    }
    expect(engine.status.outcome, GameOutcome.won);
    expect(engine.status.winner, Player.one);
    expect(engine.status.reason, EndReason.line);
  });

  test('Movable tutorial ends in a real win for the human (P1)', () {
    final script = TutorialScript.forMode(GameMode.stackMovable);
    GameEngine<Move> engine = GameMode.stackMovable.createEngine();
    for (final step in script.steps) {
      if (step case TutorialHumanMove(:final move) || TutorialOpponentMove(:final move)) {
        engine = engine.applyMove(move);
      }
    }
    expect(engine.status.outcome, GameOutcome.won);
    expect(engine.status.winner, Player.one);
    expect(engine.status.reason, EndReason.line);
  });

  test('Ultimate tutorial claims board 4 for the human and demonstrates a free move',
      () {
    final script = TutorialScript.forMode(GameMode.ultimate);
    var engine = UltimateEngine.initial();
    var moveCount = 0;
    // After the very first move, targetBoard is only ever null because the
    // engine normalised a directed send into a free move (its board had
    // already finished) — so seeing null here again is exactly the signal
    // that the free-move beat actually fired.
    var freeMoveAfterFirstPly = false;

    for (final step in script.steps) {
      final UltimateMove? move = switch (step) {
        TutorialHumanMove(:final move) => move as UltimateMove,
        TutorialOpponentMove(:final move) => move as UltimateMove,
        _ => null,
      };
      if (move == null) continue;
      moveCount++;
      if (moveCount > 1 && engine.targetBoard == null) {
        freeMoveAfterFirstPly = true;
      }
      engine = engine.applyMove(move);
    }

    expect(engine.resultOf(4).claimant, Player.one,
        reason: 'the human should have claimed board 4');
    expect(engine.status.isOngoing, isTrue,
        reason: 'tutorial should not force an overall game end');
    expect(freeMoveAfterFirstPly, isTrue,
        reason: 'script should include a genuine free-move beat');
  });
}
