import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/engines/common/game_status.dart';
import 'package:nested_game/engines/common/move.dart';
import 'package:nested_game/engines/common/player.dart';
import 'package:nested_game/engines/ultimate/ultimate_engine.dart';
import 'package:nested_game/engines/ultimate/ultimate_move.dart';

/// Small-board cell templates (0 empty / 1 / 2).
const winP1 = [1, 1, 1, 2, 2, 0, 0, 0, 0];
const winP2 = [2, 2, 2, 1, 1, 0, 0, 0, 0];
const drawnBoard = [1, 1, 2, 2, 2, 1, 1, 1, 2]; // full, no line

Map<String, Object?> stateJson({
  required Map<int, List<int>> boards,
  required int currentPlayer,
  int? targetBoard,
}) {
  final cells = List<int>.filled(81, 0);
  boards.forEach((board, layout) {
    for (var i = 0; i < 9; i++) {
      cells[board * 9 + i] = layout[i];
    }
  });
  return {
    'cells': cells,
    'currentPlayer': currentPlayer,
    'targetBoard': targetBoard,
  };
}

UltimateEngine play(UltimateEngine engine, List<UltimateMove> moves) =>
    moves.fold(engine, (e, m) => e.applyMove(m));

/// Scripted opening: P1 claims board 0 on the 0–4–8 diagonal at move 13,
/// then move 15 sends P2 to the claimed board → free move.
const scriptedGame = [
  UltimateMove(0, 0), // P1 → sends to board 0
  UltimateMove(0, 1), // P2 → board 1
  UltimateMove(1, 0), // P1 → board 0
  UltimateMove(0, 3), // P2 → board 3
  UltimateMove(3, 0), // P1 → board 0
  UltimateMove(0, 5), // P2 → board 5
  UltimateMove(5, 4), // P1 → board 4
  UltimateMove(4, 0), // P2 → board 0
  UltimateMove(0, 4), // P1 → board 4
  UltimateMove(4, 1), // P2 → board 1
  UltimateMove(1, 8), // P1 → board 8
  UltimateMove(8, 0), // P2 → board 0
  UltimateMove(0, 8), // P1 claims board 0 (0,4,8) → board 8
  UltimateMove(8, 2), // P2 → board 2
  UltimateMove(2, 0), // P1 → board 0 is claimed → free move
];

void main() {
  group('Ultimate — send rule', () {
    test('first move: anywhere (81 legal moves)', () {
      final engine = UltimateEngine.initial();
      expect(engine.currentPlayer, Player.one);
      expect(engine.targetBoard, isNull);
      expect(engine.legalMoves(), hasLength(81));
    });

    test('the cell you play dictates the opponent\'s board', () {
      // Doc example: P1 plays top-left cell of the centre board.
      final engine =
          UltimateEngine.initial().applyMove(const UltimateMove(4, 0));
      expect(engine.currentPlayer, Player.two);
      expect(engine.targetBoard, 0);
      final moves = engine.legalMoves();
      expect(moves, hasLength(9));
      expect(moves.every((m) => m.board == 0), isTrue);
    });

    test('playing outside the target board is illegal', () {
      final engine =
          UltimateEngine.initial().applyMove(const UltimateMove(4, 0));
      expect(() => engine.applyMove(const UltimateMove(1, 0)),
          throwsA(isA<IllegalMoveException>()));
    });

    test('occupied cells are illegal', () {
      final engine = play(UltimateEngine.initial(), [
        const UltimateMove(0, 0),
        const UltimateMove(0, 1),
      ]);
      // P1 sent to board 1; and cell (0,0) is occupied anyway.
      expect(() => engine.applyMove(const UltimateMove(0, 0)),
          throwsA(isA<IllegalMoveException>()));
    });
  });

  group('Ultimate — claiming and free move', () {
    test('winning a small board claims and closes it', () {
      final engine = play(UltimateEngine.initial(), scriptedGame.sublist(0, 13));
      expect(engine.resultOf(0), BoardResult.wonByOne);
      expect(engine.claimedCount(Player.one), 1);
      expect(engine.status, const GameStatus.ongoing());
      // Board 0 still has empty cells, but is out of play forever.
      expect(engine.legalMoves().any((m) => m.board == 0), isFalse);
      expect(() => engine.applyMove(const UltimateMove(0, 2)),
          throwsA(isA<IllegalMoveException>()));
    });

    test('sent to a claimed board → free move in any open board', () {
      final engine = play(UltimateEngine.initial(), scriptedGame);
      expect(engine.targetBoard, isNull);
      final moves = engine.legalMoves();
      expect(moves.any((m) => m.board == 0), isFalse);
      // Free move spans multiple boards and only empty cells.
      expect(moves.map((m) => m.board).toSet().length, greaterThan(1));
      expect(moves, isNot(contains(const UltimateMove(8, 0))));
    });

    test('sent to a drawn board → free move; drawn board is out of play', () {
      final engine = UltimateEngine.fromJson(stateJson(
        boards: {4: drawnBoard},
        currentPlayer: 1,
        targetBoard: 4,
      ));
      expect(engine.resultOf(4), BoardResult.drawn);
      expect(engine.targetBoard, isNull);
      final moves = engine.legalMoves();
      expect(moves, hasLength(72)); // 8 open boards × 9 cells
      expect(moves.any((m) => m.board == 4), isFalse);
    });
  });

  group('Ultimate — big-board outcome', () {
    test('three claimed boards in a row wins outright', () {
      final engine = UltimateEngine.fromJson(stateJson(
        boards: {
          0: winP1,
          1: winP1,
          2: [1, 1, 0, 2, 2, 0, 0, 0, 0], // P1 completes row 0 with cell 2
        },
        currentPlayer: 1,
        targetBoard: 2,
      ));
      expect(engine.status, const GameStatus.ongoing());
      final won = engine.applyMove(const UltimateMove(2, 2));
      expect(won.resultOf(2), BoardResult.wonByOne);
      expect(
        won.status,
        const GameStatus.won(Player.one, EndReason.line,
            winningLine: [0, 1, 2]),
      );
      expect(won.legalMoves(), isEmpty);
      expect(() => won.applyMove(const UltimateMove(3, 0)),
          throwsA(isA<IllegalMoveException>()));
    });

    test('drawn boards are neutral: they break big-board lines', () {
      // Boards 0 and 8 claimed by P1, board 4 drawn: no 0-4-8 win.
      final engine = UltimateEngine.fromJson(stateJson(
        boards: {0: winP1, 8: winP1, 4: drawnBoard},
        currentPlayer: 2,
        targetBoard: null,
      ));
      expect(engine.status, const GameStatus.ongoing());
    });

    test('all boards finished, no big line → most claimed boards wins', () {
      // P1 claims {0,2,3,4,7}, P2 {1,5,6,8} — no big-board line either way.
      final engine = UltimateEngine.fromJson(stateJson(
        boards: {
          0: winP1, 1: winP2, 2: winP1,
          3: winP1, 4: winP1, 5: winP2,
          6: winP2, 7: winP1, 8: winP2,
        },
        currentPlayer: 1,
        targetBoard: null,
      ));
      expect(engine.claimedCount(Player.one), 5);
      expect(engine.claimedCount(Player.two), 4);
      expect(engine.status,
          const GameStatus.won(Player.one, EndReason.tiebreak));
      expect(engine.status.winningLine, isNull);
    });

    test('all boards finished, equal claims → draw', () {
      // Same layout, but the centre board is drawn: 4 v 4.
      final engine = UltimateEngine.fromJson(stateJson(
        boards: {
          0: winP1, 1: winP2, 2: winP1,
          3: winP1, 4: drawnBoard, 5: winP2,
          6: winP2, 7: winP1, 8: winP2,
        },
        currentPlayer: 1,
        targetBoard: null,
      ));
      expect(engine.claimedCount(Player.one), 4);
      expect(engine.claimedCount(Player.two), 4);
      expect(engine.status, const GameStatus.draw(EndReason.tiebreak));
      expect(engine.legalMoves(), isEmpty);
    });
  });

  group('Ultimate — serialisation and determinism', () {
    test('determinism: same move list reproduces the same state', () {
      final a = play(UltimateEngine.initial(), scriptedGame);
      final b = play(UltimateEngine.initial(), scriptedGame);
      expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
    });

    test('JSON round-trip preserves state, target, and legal moves', () {
      final engine = play(UltimateEngine.initial(), scriptedGame.sublist(0, 7));
      final restored =
          UltimateEngine.fromJson(jsonDecode(jsonEncode(engine.toJson())));
      expect(jsonEncode(restored.toJson()), jsonEncode(engine.toJson()));
      expect(restored.targetBoard, engine.targetBoard);
      expect(restored.legalMoves(), unorderedEquals(engine.legalMoves()));

      // Resuming a restored game reaches the same result as never pausing.
      final resumed = play(restored, scriptedGame.sublist(7));
      final unpaused = play(UltimateEngine.initial(), scriptedGame);
      expect(jsonEncode(resumed.toJson()), jsonEncode(unpaused.toJson()));
    });

    test('fromJson rejects malformed states', () {
      expect(
        () => UltimateEngine.fromJson({
          'cells': List<int>.filled(80, 0),
          'currentPlayer': 1,
          'targetBoard': null,
        }),
        throwsFormatException,
      );
      expect(
        () => UltimateEngine.fromJson(stateJson(
          boards: {
            0: [3, 0, 0, 0, 0, 0, 0, 0, 0],
          },
          currentPlayer: 1,
        )),
        throwsFormatException,
      );
      // A small board with lines for both players is unreachable.
      expect(
        () => UltimateEngine.fromJson(stateJson(
          boards: {
            0: [1, 1, 1, 2, 2, 2, 0, 0, 0],
          },
          currentPlayer: 1,
        )),
        throwsFormatException,
      );
      expect(
        () => UltimateEngine.fromJson(stateJson(
          boards: const {},
          currentPlayer: 1,
          targetBoard: 11,
        )),
        throwsFormatException,
      );
    });
  });
}
