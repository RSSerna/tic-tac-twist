import 'game_status.dart';
import 'move.dart';
import 'player.dart';

/// Shared contract of all game engines.
///
/// Engines are immutable value objects: [applyMove] returns a new engine and
/// never mutates the receiver. This is what makes determinism trivial to test
/// (same move list on a fresh engine always reproduces the same state) and
/// gives Phase 3 search algorithms free copy semantics.
///
/// Engines are pure Dart, time-independent, and fully serialisable via
/// [toJson] plus each engine's `fromJson` factory. [GameStatus] is derived,
/// not stored in JSON.
abstract interface class GameEngine<M extends Move> {
  Player get currentPlayer;

  GameStatus get status;

  /// All legal moves for [currentPlayer]; empty iff the game is over.
  /// Legality is decided here and only here — the UI never decides.
  List<M> legalMoves();

  /// Returns the state after [move]. Throws [IllegalMoveException] if the
  /// move is not legal in this state.
  GameEngine<M> applyMove(M move);

  Map<String, Object?> toJson();
}
