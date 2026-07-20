import 'package:meta/meta.dart';

import '../common/game_engine.dart';
import '../common/game_status.dart';
import '../common/move.dart';
import '../common/player.dart';
import 'ultimate_move.dart';

/// Outcome of one small board.
enum BoardResult { open, wonByOne, wonByTwo, drawn }

extension BoardResultX on BoardResult {
  bool get isFinished => this != BoardResult.open;

  Player? get claimant => switch (this) {
        BoardResult.wonByOne => Player.one,
        BoardResult.wonByTwo => Player.two,
        _ => null,
      };
}

/// The Ultimate engine (rules doc §4).
///
/// Immutable: [applyMove] returns a new engine. The 81 cells are stored
/// board-major (`board * 9 + cell`). Small-board results are derived from
/// cells; [targetBoard] is the one piece of state not derivable from the
/// grid (it encodes the last move), so it is serialised alongside cells.
/// `null` target means a free move — first move of the game, or the player
/// was sent to a finished board (rule 5).
@immutable
class UltimateEngine implements GameEngine<UltimateMove> {
  const UltimateEngine._(
    this._cells,
    this.currentPlayer,
    this.targetBoard,
    this._results,
    this.status,
  );

  factory UltimateEngine._derive(
    List<Player?> cells,
    Player currentPlayer,
    int? targetBoard,
  ) {
    final results = List<BoardResult>.unmodifiable(
      List.generate(9, (b) => _deriveResult(cells, b)),
    );
    // Normalise: a target pointing at a finished board is a free move.
    final target = (targetBoard != null && results[targetBoard].isFinished)
        ? null
        : targetBoard;
    return UltimateEngine._(
        cells, currentPlayer, target, results, _evaluate(results, currentPlayer));
  }

  /// A fresh game. [Player.one] moves first and may play anywhere (rule 2).
  factory UltimateEngine.initial() =>
      UltimateEngine._derive(List<Player?>.unmodifiable(List.filled(81, null)),
          Player.one, null);

  /// 81 cells, board-major; null = empty.
  final List<Player?> _cells;

  @override
  final Player currentPlayer;

  /// Small board the current player must play in; null = free move.
  final int? targetBoard;

  final List<BoardResult> _results;

  @override
  final GameStatus status;

  // ---------------------------------------------------------------- queries

  Player? ownerOf(int board, int cell) => _cells[board * 9 + cell];

  BoardResult resultOf(int board) => _results[board];

  int claimedCount(Player player) =>
      _results.where((r) => r.claimant == player).length;

  // ------------------------------------------------------------ legal moves

  @override
  List<UltimateMove> legalMoves() {
    if (status.isOver) return const [];
    final boards = targetBoard != null
        ? [targetBoard!]
        : [
            for (var b = 0; b < 9; b++)
              if (!_results[b].isFinished) b,
          ];
    return [
      for (final board in boards)
        for (var cell = 0; cell < 9; cell++)
          if (_cells[board * 9 + cell] == null) UltimateMove(board, cell),
    ];
  }

  // ---------------------------------------------------------------- apply

  @override
  UltimateEngine applyMove(UltimateMove move) {
    if (status.isOver) {
      throw IllegalMoveException(move, 'Game is over: $status');
    }
    if (move.board < 0 || move.board > 8 || move.cell < 0 || move.cell > 8) {
      throw IllegalMoveException(move, 'Out of range');
    }
    if (_results[move.board].isFinished) {
      throw IllegalMoveException(move, 'Board ${move.board} is finished');
    }
    if (targetBoard != null && move.board != targetBoard) {
      throw IllegalMoveException(move, 'Must play in board $targetBoard');
    }
    if (_cells[move.board * 9 + move.cell] != null) {
      throw IllegalMoveException(move, 'Cell is occupied');
    }

    final cells = List<Player?>.of(_cells);
    cells[move.board * 9 + move.cell] = currentPlayer;
    // The cell position just played dictates the opponent's board (rule 3);
    // the factory normalises it to a free move if that board is finished.
    return UltimateEngine._derive(
      List<Player?>.unmodifiable(cells),
      currentPlayer.opponent,
      move.cell,
    );
  }

  // ---------------------------------------------------------------- status

  static const _lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];

  static BoardResult _deriveResult(List<Player?> cells, int board) {
    final base = board * 9;
    bool hasLine(Player p) => _lines
        .any((line) => line.every((i) => cells[base + i] == p));

    final oneWins = hasLine(Player.one);
    final twoWins = hasLine(Player.two);
    if (oneWins && twoWins) {
      throw const FormatException('Small board has lines for both players');
    }
    if (oneWins) return BoardResult.wonByOne;
    if (twoWins) return BoardResult.wonByTwo;
    final full = List.generate(9, (i) => cells[base + i]).every((c) => c != null);
    // Drawn boards are neutral and out of play (rule 8).
    return full ? BoardResult.drawn : BoardResult.open;
  }

  static GameStatus _evaluate(List<BoardResult> results, Player currentPlayer) {
    // Mover precedence, mirroring the stacking engine; in legitimate play
    // only the player who just moved can have completed a big-board line.
    for (final player in [currentPlayer.opponent, currentPlayer]) {
      for (final line in _lines) {
        if (line.every((b) => results[b].claimant == player)) {
          return GameStatus.won(player, EndReason.line, winningLine: line);
        }
      }
    }
    if (results.every((r) => r.isFinished)) {
      final one = results.where((r) => r.claimant == Player.one).length;
      final two = results.where((r) => r.claimant == Player.two).length;
      if (one > two) return const GameStatus.won(Player.one, EndReason.tiebreak);
      if (two > one) return const GameStatus.won(Player.two, EndReason.tiebreak);
      return const GameStatus.draw(EndReason.tiebreak);
    }
    return const GameStatus.ongoing();
  }

  // ------------------------------------------------------------------ JSON

  @override
  Map<String, Object?> toJson() => {
        'cells': [for (final c in _cells) c?.toJson() ?? 0],
        'currentPlayer': currentPlayer.toJson(),
        'targetBoard': targetBoard,
      };

  factory UltimateEngine.fromJson(Map<String, Object?> json) {
    final rawCells = json['cells'];
    if (rawCells is! List || rawCells.length != 81) {
      throw const FormatException('cells must have 81 entries');
    }
    final cells = List<Player?>.unmodifiable(rawCells.map((c) => switch (c) {
          0 => null,
          1 => Player.one,
          2 => Player.two,
          _ => throw FormatException('Invalid cell: $c'),
        }));
    final target = json['targetBoard'];
    if (target != null && (target is! int || target < 0 || target > 8)) {
      throw FormatException('Invalid targetBoard: $target');
    }
    return UltimateEngine._derive(
        cells, Player.fromJson(json['currentPlayer']), target as int?);
  }
}
