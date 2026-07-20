import '../common/move.dart';

/// A move in Ultimate: play [cell] (0–8) inside small [board] (0–8), both
/// row-major.
class UltimateMove implements Move {
  const UltimateMove(this.board, this.cell);

  final int board;
  final int cell;

  @override
  Map<String, Object?> toJson() => {'board': board, 'cell': cell};

  factory UltimateMove.fromJson(Map<String, Object?> json) =>
      UltimateMove(json['board'] as int, json['cell'] as int);

  @override
  bool operator ==(Object other) =>
      other is UltimateMove && other.board == board && other.cell == cell;

  @override
  int get hashCode => Object.hash(board, cell);

  @override
  String toString() => 'Ultimate(b$board c$cell)';
}
