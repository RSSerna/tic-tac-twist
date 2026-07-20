import '../common/move.dart';

/// Moves in the stacking engine. Cells are indexed 0–8, row-major.
sealed class StackingMove implements Move {
  const StackingMove();

  static StackingMove fromJson(Map<String, Object?> json) =>
      switch (json['type']) {
        'place' => PlaceMove(json['level'] as int, json['cell'] as int),
        'relocate' => RelocateMove(json['from'] as int, json['to'] as int),
        'pass' => const PassMove(),
        _ => throw FormatException('Unknown stacking move: ${json['type']}'),
      };
}

/// Place a chip of [level] from the current player's inventory onto [cell].
class PlaceMove extends StackingMove {
  const PlaceMove(this.level, this.cell);

  final int level;
  final int cell;

  @override
  Map<String, Object?> toJson() =>
      {'type': 'place', 'level': level, 'cell': cell};

  @override
  bool operator ==(Object other) =>
      other is PlaceMove && other.level == level && other.cell == cell;

  @override
  int get hashCode => Object.hash('place', level, cell);

  @override
  String toString() => 'Place(L$level → $cell)';
}

/// Move the current player's topmost-visible chip from [from] to [to].
/// Movable mode only.
class RelocateMove extends StackingMove {
  const RelocateMove(this.from, this.to);

  final int from;
  final int to;

  @override
  Map<String, Object?> toJson() => {'type': 'relocate', 'from': from, 'to': to};

  @override
  bool operator ==(Object other) =>
      other is RelocateMove && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash('relocate', from, to);

  @override
  String toString() => 'Relocate($from → $to)';
}

/// Forced pass: the only legal move when the current player has no placement
/// or relocation but the opponent still has one (rules doc §2.2).
class PassMove extends StackingMove {
  const PassMove();

  @override
  Map<String, Object?> toJson() => {'type': 'pass'};

  @override
  bool operator ==(Object other) => other is PassMove;

  @override
  int get hashCode => 'pass'.hashCode;

  @override
  String toString() => 'Pass';
}
