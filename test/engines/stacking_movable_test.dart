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
  List<List<Map<String, Object?>>> board,
  int currentPlayer,
) =>
    {
      'config': StackingConfig.movableMode.toJson(),
      'board': board,
      'currentPlayer': currentPlayer,
    };

StackingEngine play(StackingEngine engine, List<StackingMove> moves) =>
    moves.fold(engine, (e, m) => e.applyMove(m));

StackingEngine initial() => StackingEngine.initial(StackingConfig.movableMode);

void main() {
  group('Movable — turn options', () {
    test('initial state: placements only, nothing on board to move', () {
      final engine = initial();
      expect(engine.legalMoves(), hasLength(36));
      expect(engine.legalMoves().whereType<RelocateMove>(), isEmpty);
    });

    test('a visible own chip may relocate to empty or smaller-topped squares',
        () {
      final engine = play(initial(), [
        const PlaceMove(2, 4), // P1
        const PlaceMove(1, 0), // P2
      ]);
      final relocations = engine.legalMoves().whereType<RelocateMove>();
      // P1's L2 at 4 can go to every other square: 7 empties + covering
      // P2's L1 at 0. Opponent chips cannot be relocated.
      expect(relocations, hasLength(8));
      expect(relocations.every((m) => m.from == 4), isTrue);
      expect(relocations, contains(const RelocateMove(4, 0)));
      expect(() => engine.applyMove(const RelocateMove(0, 5)),
          throwsA(isA<IllegalMoveException>()));
    });

    test('origin and destination must differ; equal level cannot land', () {
      final engine = play(initial(), [
        const PlaceMove(2, 4), // P1
        const PlaceMove(2, 0), // P2
      ]);
      expect(engine.legalMoves(), isNot(contains(const RelocateMove(4, 4))));
      // P1's L2 cannot land on P2's L2.
      expect(engine.legalMoves(), isNot(contains(const RelocateMove(4, 0))));
    });

    test('moving reveals what was underneath', () {
      final engine = play(initial(), [
        const PlaceMove(1, 4), // P1
        const PlaceMove(1, 0), // P2
        const PlaceMove(2, 0), // P1 covers P2's L1
        const PlaceMove(2, 8), // P2
        const RelocateMove(0, 5), // P1 moves the L2 away
      ]);
      expect(engine.topChipAt(0), const Chip(Player.two, 1));
      expect(engine.stackDepthAt(0), 1);
      expect(engine.topChipAt(5), const Chip(Player.one, 2));
    });

    test('buried chips cannot be extracted', () {
      final engine = play(initial(), [
        const PlaceMove(1, 4), // P1
        const PlaceMove(2, 4), // P2 covers P1's L1
      ]);
      // P1's L1 is buried under P2's L2 — no relocation from 4 is P1's.
      expect(engine.legalMoves().whereType<RelocateMove>(), isEmpty);
      expect(() => engine.applyMove(const RelocateMove(4, 0)),
          throwsA(isA<IllegalMoveException>()));
    });

    test('empty inventory forces relocation; L4 is movable by its owner', () {
      // P1 has all 6 chips placed: L4@0, L1@1, L1@3, L2@5, L2@7 visible,
      // L3 buried under P2's L4 at cell 4. No line among P1 tops.
      final engine = StackingEngine.fromJson(stateJson(
        [
          [chip(1, 4)],
          [chip(1, 1)],
          [],
          [chip(1, 1)],
          [chip(1, 3), chip(2, 4)],
          [chip(1, 2)],
          [],
          [chip(1, 2)],
          [],
        ],
        1,
      ));
      expect(engine.status, const GameStatus.ongoing());
      final moves = engine.legalMoves();
      expect(moves.whereType<PlaceMove>(), isEmpty);
      expect(moves.whereType<PassMove>(), isEmpty);
      // Buried L3 (cell 4) is not movable — the top there is P2's.
      expect(moves.whereType<RelocateMove>().any((m) => m.from == 4), isFalse);
      // The L4 may relocate anywhere except onto P2's L4.
      expect(moves, contains(const RelocateMove(0, 2)));
      expect(moves, isNot(contains(const RelocateMove(0, 4))));
    });
  });

  group('Movable — win detection with reveals', () {
    test('a move that reveals an opponent line loses on the spot', () {
      // P2 tops at 3 and 4; P2's L1 at 5 buried under P1's L2.
      final engine = StackingEngine.fromJson(stateJson(
        [
          [chip(1, 1)],
          [],
          [],
          [chip(2, 1)],
          [chip(2, 2)],
          [chip(2, 1), chip(1, 2)],
          [],
          [],
          [],
        ],
        1,
      ));
      final after = engine.applyMove(const RelocateMove(5, 8));
      expect(
        after.status,
        const GameStatus.won(Player.two, EndReason.line,
            winningLine: [3, 4, 5]),
      );
      expect(after.legalMoves(), isEmpty);
    });

    test('mover precedence: completing your line while revealing theirs wins',
        () {
      // P1 tops at 0 and 1; moving the L2 from 5 to 2 completes P1's row 0
      // AND reveals P2's row 1 — the mover's line wins.
      final engine = StackingEngine.fromJson(stateJson(
        [
          [chip(1, 1)],
          [chip(1, 1)],
          [],
          [chip(2, 1)],
          [chip(2, 2)],
          [chip(2, 1), chip(1, 2)],
          [],
          [],
          [],
        ],
        1,
      ));
      final after = engine.applyMove(const RelocateMove(5, 2));
      expect(
        after.status,
        const GameStatus.won(Player.one, EndReason.line,
            winningLine: [0, 1, 2]),
      );
    });

    test('a line broken before your turn ends never counted', () {
      // Covering the middle of what would be an opponent line prevents it.
      final engine = play(initial(), [
        const PlaceMove(1, 3), // P1
        const PlaceMove(1, 0), // P2
        const PlaceMove(1, 4), // P1 — threat 3,4,5 next
        const PlaceMove(2, 4), // P2 covers the middle
      ]);
      expect(engine.status, const GameStatus.ongoing());
      expect(engine.topChipAt(4), const Chip(Player.two, 2));
    });
  });

  group('Movable — threefold repetition (chosen stall rule)', () {
    // Two placements, then a 4-move shuffle cycle. The position after the
    // second placement recurs after every full cycle; its third occurrence
    // ends the game.
    const placements = [
      PlaceMove(4, 0), // P1's L4 at 0
      PlaceMove(4, 8), // P2's L4 at 8
    ];
    const cycle = [
      RelocateMove(0, 1),
      RelocateMove(8, 7),
      RelocateMove(1, 0),
      RelocateMove(7, 8),
    ];

    test('third occurrence of a position is an immediate draw', () {
      var engine = play(initial(), placements); // occurrence 1
      engine = play(engine, cycle); // occurrence 2
      expect(engine.status, const GameStatus.ongoing());
      engine = play(engine, cycle.sublist(0, 3));
      expect(engine.status, const GameStatus.ongoing());
      engine = engine.applyMove(cycle[3]); // occurrence 3
      expect(engine.status, const GameStatus.draw(EndReason.repetition));
      expect(engine.legalMoves(), isEmpty);
    });

    test('repetition counts survive JSON round-trips', () {
      var engine = play(initial(), [...placements, ...cycle]);
      engine =
          StackingEngine.fromJson(jsonDecode(jsonEncode(engine.toJson())));
      expect(engine.status, const GameStatus.ongoing());
      engine = play(engine, cycle);
      expect(engine.status, const GameStatus.draw(EndReason.repetition));
    });

    test('movable JSON carries positionCounts', () {
      expect(initial().toJson().containsKey('positionCounts'), isTrue);
    });
  });

  group('Movable — serialisation and determinism', () {
    test('determinism: same move list reproduces the same state', () {
      const moves = [
        PlaceMove(2, 4),
        PlaceMove(1, 0),
        RelocateMove(4, 0),
        PlaceMove(3, 4),
        RelocateMove(0, 2),
      ];
      final a = play(initial(), moves);
      final b = play(initial(), moves);
      expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
    });

    test('JSON round-trip preserves state, status, and legal moves', () {
      final engine = play(initial(), [
        const PlaceMove(2, 4),
        const PlaceMove(1, 0),
        const RelocateMove(4, 0),
      ]);
      final restored =
          StackingEngine.fromJson(jsonDecode(jsonEncode(engine.toJson())));
      expect(jsonEncode(restored.toJson()), jsonEncode(engine.toJson()));
      expect(restored.legalMoves(), unorderedEquals(engine.legalMoves()));
      expect(restored.currentPlayer, engine.currentPlayer);
    });
  });
}
