import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/engines/common/game_status.dart';
import 'package:nested_game/engines/common/move.dart';
import 'package:nested_game/engines/common/player.dart';
import 'package:nested_game/engines/stacking/chip.dart';
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
    {
      'config': config.toJson(),
      'board': board,
      'currentPlayer': currentPlayer,
    };

StackingEngine play(StackingEngine engine, List<StackingMove> moves) =>
    moves.fold(engine, (e, m) => e.applyMove(m));

void main() {
  group('Static — basics', () {
    test('initial state: 36 placements, no relocations, ongoing', () {
      final engine = StackingEngine.initial(StackingConfig.staticMode);
      expect(engine.currentPlayer, Player.one);
      expect(engine.status, const GameStatus.ongoing());
      final moves = engine.legalMoves();
      expect(moves, hasLength(36)); // 4 levels × 9 cells
      expect(moves.whereType<RelocateMove>(), isEmpty);
      expect(moves.whereType<PassMove>(), isEmpty);
    });

    test('placement lands on the board and decrements inventory', () {
      final engine = StackingEngine.initial(StackingConfig.staticMode)
          .applyMove(const PlaceMove(2, 4));
      expect(engine.topChipAt(4), const Chip(Player.one, 2));
      expect(engine.stackDepthAt(4), 1);
      expect(engine.remainingInventory(Player.one)[2], 2);
      expect(engine.currentPlayer, Player.two);
    });

    test('covering requires strictly smaller — own or opponent chip', () {
      final engine = play(StackingEngine.initial(StackingConfig.staticMode), [
        const PlaceMove(1, 4), // P1
        const PlaceMove(1, 0), // P2
      ]);
      // P1 covers own L1 and opponent's L1 alike.
      expect(engine.legalMoves(), contains(const PlaceMove(2, 4)));
      expect(engine.legalMoves(), contains(const PlaceMove(2, 0)));
      // Equal level cannot cover.
      expect(engine.legalMoves(), isNot(contains(const PlaceMove(1, 4))));
      expect(() => engine.applyMove(const PlaceMove(1, 0)),
          throwsA(isA<IllegalMoveException>()));

      final covered = engine.applyMove(const PlaceMove(2, 0));
      expect(covered.topChipAt(0), const Chip(Player.one, 2));
      expect(covered.stackDepthAt(0), 2);
    });

    test('L4 can never be covered', () {
      final afterL4 = StackingEngine.initial(StackingConfig.staticMode)
          .applyMove(const PlaceMove(4, 0)); // P1's L4
      // Neither P2 now, nor P1 next turn, may target cell 0.
      Iterable<PlaceMove> targetingCellZero(StackingEngine e) =>
          e.legalMoves().whereType<PlaceMove>().where((m) => m.cell == 0);
      expect(targetingCellZero(afterL4), isEmpty);
      final nextTurn = afterL4.applyMove(const PlaceMove(1, 8)); // P2 elsewhere
      expect(targetingCellZero(nextTurn), isEmpty);
      expect(() => nextTurn.applyMove(const PlaceMove(4, 0)),
          throwsA(isA<IllegalMoveException>()));
    });

    test('placed chips never move: no RelocateMove is ever legal', () {
      final engine = play(StackingEngine.initial(StackingConfig.staticMode), [
        const PlaceMove(3, 0),
        const PlaceMove(2, 1),
      ]);
      expect(engine.legalMoves().whereType<RelocateMove>(), isEmpty);
      expect(() => engine.applyMove(const RelocateMove(0, 5)),
          throwsA(isA<IllegalMoveException>()));
    });

    test('static JSON has no positionCounts', () {
      final engine = StackingEngine.initial(StackingConfig.staticMode);
      expect(engine.toJson().containsKey('positionCounts'), isFalse);
    });
  });

  group('Static — win detection', () {
    test('topmost-visible line wins; chip level is irrelevant', () {
      final engine = play(StackingEngine.initial(StackingConfig.staticMode), [
        const PlaceMove(1, 0), // P1
        const PlaceMove(1, 3), // P2
        const PlaceMove(2, 1), // P1
        const PlaceMove(1, 4), // P2
        const PlaceMove(3, 2), // P1 — L1, L2, L3 mixed levels
      ]);
      expect(
        engine.status,
        const GameStatus.won(Player.one, EndReason.line,
            winningLine: [0, 1, 2]),
      );
      expect(engine.legalMoves(), isEmpty);
      expect(() => engine.applyMove(const PlaceMove(1, 8)),
          throwsA(isA<IllegalMoveException>()));
    });

    test('covering an opponent chip can complete your line', () {
      final engine = play(StackingEngine.initial(StackingConfig.staticMode), [
        const PlaceMove(1, 0), // P1
        const PlaceMove(1, 3), // P2
        const PlaceMove(1, 5), // P1
        const PlaceMove(1, 4), // P2
        const PlaceMove(1, 8), // P1 (0, 5, 8 — no line)
        const PlaceMove(2, 5), // P2 covers P1's L1 → row 3,4,5
      ]);
      expect(
        engine.status,
        const GameStatus.won(Player.two, EndReason.line,
            winningLine: [3, 4, 5]),
      );
    });
  });

  group('Static — pass rule and endgame (rules doc §2.2–2.3)', () {
    // Board full; P1 holds only L1s (which cover nothing) → P1 must pass.
    // P2 still holds an L3 that can cover L2 tops → game is NOT over.
    final passState = stateJson(
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
    );

    test('a stuck player passes; the opponent plays on', () {
      final engine = StackingEngine.fromJson(passState);
      expect(engine.status, const GameStatus.ongoing());
      expect(engine.legalMoves(), const [PassMove()]);

      final afterPass = engine.applyMove(const PassMove());
      expect(afterPass.currentPlayer, Player.two);
      for (var cell = 0; cell < 9; cell++) {
        expect(afterPass.stackDepthAt(cell), engine.stackDepthAt(cell));
      }
      // P2's only remaining playable chip is the L3, onto L2 tops.
      expect(
        afterPass.legalMoves(),
        unorderedEquals(const [
          PlaceMove(3, 3),
          PlaceMove(3, 6),
          PlaceMove(3, 7),
          PlaceMove(3, 8),
        ]),
      );
    });

    test('pass is illegal while placements exist', () {
      final engine = StackingEngine.initial(StackingConfig.staticMode);
      expect(() => engine.applyMove(const PassMove()),
          throwsA(isA<IllegalMoveException>()));
    });

    test('both players stuck, no line → more visible chips wins', () {
      // All 18 chips placed, tops [1,1,2,2,2,1,1,1,2] — no line, P1 5 v P2 4.
      final engine = StackingEngine.fromJson(stateJson(
        StackingConfig.staticMode,
        [
          [chip(2, 3), chip(1, 4)],
          [chip(2, 1), chip(1, 2)],
          [chip(1, 1), chip(2, 2)],
          [chip(2, 1)],
          [chip(1, 1), chip(1, 2), chip(2, 4)],
          [chip(2, 1), chip(1, 2)],
          [chip(2, 2), chip(1, 3)],
          [chip(2, 2), chip(1, 3)],
          [chip(1, 1), chip(2, 3)],
        ],
        1,
      ));
      expect(engine.visibleChipCount(Player.one), 5);
      expect(engine.visibleChipCount(Player.two), 4);
      expect(engine.status, const GameStatus.won(Player.one, EndReason.tiebreak));
      expect(engine.legalMoves(), isEmpty);
    });

    test('both players stuck, exact tie → draw', () {
      // Inventories exhausted, one square left empty, tops split 4/4.
      final engine = StackingEngine.fromJson(stateJson(
        StackingConfig.staticMode,
        [
          [chip(2, 1), chip(2, 2), chip(1, 4)],
          [chip(1, 1), chip(2, 2)],
          [chip(2, 1), chip(2, 2), chip(1, 3)],
          [chip(1, 1), chip(2, 3)],
          [],
          [chip(2, 1), chip(1, 3)],
          [chip(1, 2), chip(2, 3)],
          [chip(1, 1), chip(1, 2)],
          [chip(1, 2), chip(2, 4)],
        ],
        2,
      ));
      expect(engine.visibleChipCount(Player.one), 4);
      expect(engine.visibleChipCount(Player.two), 4);
      expect(engine.status, const GameStatus.draw(EndReason.tiebreak));
    });
  });

  group('Static — information and serialisation', () {
    test('legality depends only on visible chips', () {
      // Same tops, different buried chips → identical legal moves.
      final visibleA = StackingEngine.fromJson(stateJson(
        StackingConfig.staticMode,
        [
          [chip(1, 1), chip(1, 3)],
          [], [], [], [], [], [], [], [],
        ],
        2,
      ));
      final visibleB = StackingEngine.fromJson(stateJson(
        StackingConfig.staticMode,
        [
          [chip(2, 2), chip(1, 3)],
          [], [], [], [], [], [], [], [],
        ],
        2,
      ));
      expect(visibleA.legalMoves(), unorderedEquals(visibleB.legalMoves()));
    });

    test('determinism: same move list reproduces the same state', () {
      const moves = [
        PlaceMove(1, 4),
        PlaceMove(2, 4),
        PlaceMove(3, 4),
        PlaceMove(1, 0),
        PlaceMove(2, 0),
        PlaceMove(4, 8),
      ];
      final a = play(StackingEngine.initial(StackingConfig.staticMode), moves);
      final b = play(StackingEngine.initial(StackingConfig.staticMode), moves);
      expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
    });

    test('JSON round-trip preserves state, status, and legal moves', () {
      final engine = play(StackingEngine.initial(StackingConfig.staticMode), [
        const PlaceMove(1, 4),
        const PlaceMove(2, 4),
        const PlaceMove(3, 0),
      ]);
      final restored =
          StackingEngine.fromJson(jsonDecode(jsonEncode(engine.toJson())));
      expect(jsonEncode(restored.toJson()), jsonEncode(engine.toJson()));
      expect(restored.status, engine.status);
      expect(restored.currentPlayer, engine.currentPlayer);
      expect(restored.legalMoves(), unorderedEquals(engine.legalMoves()));
    });

    test('fromJson rejects inconsistent states', () {
      // Non-ascending stack.
      expect(
        () => StackingEngine.fromJson(stateJson(
          StackingConfig.staticMode,
          [
            [chip(1, 3), chip(1, 2)],
            [], [], [], [], [], [], [], [],
          ],
          1,
        )),
        throwsFormatException,
      );
      // More L4s than the inventory allows.
      expect(
        () => StackingEngine.fromJson(stateJson(
          StackingConfig.staticMode,
          [
            [chip(1, 4)],
            [chip(1, 4)],
            [], [], [], [], [], [], [],
          ],
          1,
        )),
        throwsFormatException,
      );
    });
  });
}
