/// A move in some engine. Concrete move types are engine-specific; all are
/// value objects (== by content) and serialise to JSON so games can be
/// persisted and replayed.
abstract interface class Move {
  Map<String, Object?> toJson();
}

/// Thrown by `applyMove` when a move is not in `legalMoves()` for the
/// current state.
class IllegalMoveException implements Exception {
  IllegalMoveException(this.move, this.reason);

  final Move move;
  final String reason;

  @override
  String toString() => 'IllegalMoveException($move): $reason';
}
