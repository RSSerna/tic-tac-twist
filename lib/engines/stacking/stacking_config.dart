import 'package:meta/meta.dart';

/// Configuration separating the two stacking modes. One engine, two configs
/// (CLAUDE.md rule 7); inventories are data, not constants, because they
/// will change during Phase 3 balance testing.
@immutable
class StackingConfig {
  const StackingConfig({
    required this.canMovePlacedChips,
    required this.inventoryPerPlayer,
  });

  /// False = Stack-Static, true = Stack-Movable.
  final bool canMovePlacedChips;

  /// Chips each player starts with, keyed by level 1–4.
  final Map<int, int> inventoryPerPlayer;

  /// Stack-Static launch inventory (rules doc §2.1). The pyramid shape and
  /// the single L4 are load-bearing — do not "simplify".
  static const staticMode = StackingConfig(
    canMovePlacedChips: false,
    inventoryPerPlayer: {4: 1, 3: 2, 2: 3, 1: 3},
  );

  /// Stack-Movable launch inventory (rules doc §3.1).
  static const movableMode = StackingConfig(
    canMovePlacedChips: true,
    inventoryPerPlayer: {4: 1, 3: 1, 2: 2, 1: 2},
  );

  Map<String, Object?> toJson() => {
        'canMovePlacedChips': canMovePlacedChips,
        'inventoryPerPlayer': {
          for (final e in inventoryPerPlayer.entries) '${e.key}': e.value,
        },
      };

  factory StackingConfig.fromJson(Map<String, Object?> json) {
    final canMove = json['canMovePlacedChips'];
    final inventory = json['inventoryPerPlayer'];
    if (canMove is! bool || inventory is! Map) {
      throw const FormatException('Invalid stacking config');
    }
    final parsed = <int, int>{};
    for (final entry in inventory.entries) {
      final level = int.tryParse(entry.key as String);
      final count = entry.value;
      if (level == null || level < 1 || level > 4 || count is! int || count < 0) {
        throw FormatException('Invalid inventory entry: ${entry.key}');
      }
      parsed[level] = count;
    }
    return StackingConfig(
      canMovePlacedChips: canMove,
      inventoryPerPlayer: Map.unmodifiable(parsed),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is StackingConfig &&
      other.canMovePlacedChips == canMovePlacedChips &&
      other.inventoryPerPlayer.length == inventoryPerPlayer.length &&
      other.inventoryPerPlayer.entries
          .every((e) => inventoryPerPlayer[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
        canMovePlacedChips,
        Object.hashAllUnordered(
          inventoryPerPlayer.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );
}
