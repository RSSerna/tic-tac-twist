import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/engines/common/game_status.dart';
import 'package:nested_game/engines/common/player.dart';
import 'package:nested_game/engines/stacking/chip.dart';
import 'package:nested_game/engines/stacking/stacking_config.dart';
import 'package:nested_game/engines/stacking/stacking_move.dart';
import 'package:nested_game/engines/ultimate/ultimate_move.dart';

void main() {
  group('Player', () {
    test('opponent flips', () {
      expect(Player.one.opponent, Player.two);
      expect(Player.two.opponent, Player.one);
    });

    test('JSON round-trip', () {
      expect(Player.fromJson(Player.one.toJson()), Player.one);
      expect(Player.fromJson(Player.two.toJson()), Player.two);
      expect(() => Player.fromJson(3), throwsFormatException);
      expect(() => Player.fromJson(null), throwsFormatException);
    });
  });

  group('GameStatus', () {
    test('value equality including winning line', () {
      expect(
        const GameStatus.won(Player.one, EndReason.line, winningLine: [0, 1, 2]),
        const GameStatus.won(Player.one, EndReason.line, winningLine: [0, 1, 2]),
      );
      expect(
        const GameStatus.won(Player.one, EndReason.line, winningLine: [0, 1, 2]),
        isNot(const GameStatus.won(Player.one, EndReason.line,
            winningLine: [0, 4, 8])),
      );
      expect(const GameStatus.ongoing().isOngoing, isTrue);
      expect(const GameStatus.draw(EndReason.tiebreak).isOver, isTrue);
    });
  });

  group('Chip', () {
    test('JSON round-trip and validation', () {
      const chip = Chip(Player.two, 3);
      expect(Chip.fromJson(chip.toJson()), chip);
      expect(() => Chip.fromJson({'owner': 1, 'level': 5}),
          throwsFormatException);
      expect(() => Chip.fromJson({'owner': 1, 'level': 0}),
          throwsFormatException);
    });
  });

  group('StackingConfig', () {
    test('launch presets match the rules doc', () {
      expect(StackingConfig.staticMode.canMovePlacedChips, isFalse);
      expect(StackingConfig.staticMode.inventoryPerPlayer,
          {4: 1, 3: 2, 2: 3, 1: 3});
      expect(StackingConfig.movableMode.canMovePlacedChips, isTrue);
      expect(StackingConfig.movableMode.inventoryPerPlayer,
          {4: 1, 3: 1, 2: 2, 1: 2});
    });

    test('JSON round-trip', () {
      for (final config in [
        StackingConfig.staticMode,
        StackingConfig.movableMode,
      ]) {
        expect(StackingConfig.fromJson(config.toJson()), config);
      }
    });
  });

  group('Move JSON', () {
    test('stacking moves round-trip', () {
      const moves = [PlaceMove(3, 7), RelocateMove(2, 5), PassMove()];
      for (final move in moves) {
        expect(StackingMove.fromJson(move.toJson()), move);
      }
      expect(() => StackingMove.fromJson({'type': 'teleport'}),
          throwsFormatException);
    });

    test('ultimate move round-trips', () {
      const move = UltimateMove(4, 0);
      expect(UltimateMove.fromJson(move.toJson()), move);
    });
  });
}
