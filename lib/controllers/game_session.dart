import 'package:meta/meta.dart';

import '../engines/common/game_engine.dart';
import '../engines/common/game_status.dart';
import '../engines/common/move.dart';
import '../engines/common/player.dart';
import 'game_mode.dart';

/// One game in progress, plus its presentation state (selection, staging).
///
/// Selection and staging never touch the engine or its serialisation —
/// they live here, in the controller layer.
///
/// People vs engine players: engines always give the first move to
/// [Player.one]; who *sits* in that seat changes between games (loser starts
/// the rematch). [starterPerson] records which person (1 or 2) is
/// [Player.one] in this game, and person identity is what colours and
/// labels follow.
@immutable
class GameSession {
  const GameSession({
    required this.mode,
    required this.engine,
    required this.starterPerson,
    this.selectedLevel,
    this.selectedCell,
    this.stagedMove,
  });

  final GameMode mode;
  final GameEngine<Move> engine;

  /// Which person (1 or 2) moves first in this game (= engine [Player.one]).
  final int starterPerson;

  /// Stacking: inventory chip level picked, awaiting a target cell.
  final int? selectedLevel;

  /// Movable: origin cell of a chip picked for relocation.
  final int? selectedCell;

  /// Fully specified move awaiting confirmation (no-undo rule: confirm
  /// before commit, never take back after).
  final Move? stagedMove;

  Player get currentPlayer => engine.currentPlayer;
  GameStatus get status => engine.status;

  int personFor(Player player) =>
      player == Player.one ? starterPerson : 3 - starterPerson;

  int get currentPerson => personFor(currentPlayer);

  static const _unset = Object();

  GameSession copy({
    GameEngine<Move>? engine,
    Object? selectedLevel = _unset,
    Object? selectedCell = _unset,
    Object? stagedMove = _unset,
  }) =>
      GameSession(
        mode: mode,
        engine: engine ?? this.engine,
        starterPerson: starterPerson,
        selectedLevel: identical(selectedLevel, _unset)
            ? this.selectedLevel
            : selectedLevel as int?,
        selectedCell: identical(selectedCell, _unset)
            ? this.selectedCell
            : selectedCell as int?,
        stagedMove:
            identical(stagedMove, _unset) ? this.stagedMove : stagedMove as Move?,
      );
}
