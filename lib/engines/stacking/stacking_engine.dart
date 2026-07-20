import 'package:meta/meta.dart';

import '../common/game_engine.dart';
import '../common/game_status.dart';
import '../common/move.dart';
import '../common/player.dart';
import 'chip.dart';
import 'stacking_config.dart';
import 'stacking_move.dart';

/// The stacking engine. Serves Stack-Static and Stack-Movable via
/// [StackingConfig] — one engine, two configs.
///
/// Immutable: [applyMove] returns a new engine. Board is 9 stacks
/// (bottom → top), cells indexed 0–8 row-major.
///
/// Rule interpretations fixed here (see rules doc §1):
/// - Win is checked at the end of every turn. If the mover's move produces
///   lines for BOTH players at once (possible in Movable via a reveal), the
///   mover's line wins — you complete your own win on your own turn.
/// - Threefold repetition of position (board + player to move) is a draw,
///   tracked only in Movable, where positions can recur.
/// - Game end with no line (neither player has any legal action) goes to
///   tiebreak: more topmost-visible chips wins, exact tie is a draw. The
///   rules doc defines this for Static (§2.3); we apply the same rule to
///   Movable's near-impossible no-action states for consistency.
@immutable
class StackingEngine implements GameEngine<StackingMove> {
  StackingEngine._(
    this.config,
    this._board,
    this.currentPlayer,
    this._positionCounts,
  ) : status = _evaluate(config, _board, currentPlayer, _positionCounts);

  /// A fresh game. [Player.one] moves first.
  factory StackingEngine.initial(StackingConfig config) {
    final board = List<List<Chip>>.unmodifiable(
      List.generate(9, (_) => List<Chip>.unmodifiable(const <Chip>[])),
    );
    return StackingEngine._(
      config,
      board,
      Player.one,
      config.canMovePlacedChips
          ? Map.unmodifiable({_positionKey(board, Player.one): 1})
          : const <String, int>{},
    );
  }

  final StackingConfig config;

  /// 9 stacks, bottom → top.
  final List<List<Chip>> _board;

  @override
  final Player currentPlayer;

  @override
  final GameStatus status;

  /// Occurrence count of every position seen so far (Movable only; empty in
  /// Static, where chips only accumulate and positions cannot recur).
  final Map<String, int> _positionCounts;

  // ---------------------------------------------------------------- queries

  /// Topmost chip of [cell], or null if empty. This plus [stackDepthAt] is
  /// all the UI may show — never render buried chips (CLAUDE.md).
  Chip? topChipAt(int cell) {
    final stack = _board[cell];
    return stack.isEmpty ? null : stack.last;
  }

  /// How many chips are stacked on [cell]. Public information — everyone
  /// watched the stack being built.
  int stackDepthAt(int cell) => _board[cell].length;

  /// Full stack of [cell], bottom → top. For serialisation, tests, and AI —
  /// never for rendering.
  List<Chip> stackAt(int cell) => _board[cell];

  /// Chips [player] still holds, keyed by level. Derived: initial inventory
  /// minus chips on the board (placed chips never return to inventory).
  Map<int, int> remainingInventory(Player player) {
    final remaining = Map<int, int>.of(config.inventoryPerPlayer);
    for (final stack in _board) {
      for (final chip in stack) {
        if (chip.owner == player) {
          remaining[chip.level] = (remaining[chip.level] ?? 0) - 1;
        }
      }
    }
    return remaining;
  }

  /// Squares whose topmost chip belongs to [player] — the tiebreak metric.
  int visibleChipCount(Player player) {
    var count = 0;
    for (final stack in _board) {
      if (stack.isNotEmpty && stack.last.owner == player) count++;
    }
    return count;
  }

  // ------------------------------------------------------------ legal moves

  @override
  List<StackingMove> legalMoves() {
    if (status.isOver) return const [];
    final moves = <StackingMove>[
      ..._placements(currentPlayer),
      ..._relocations(currentPlayer),
    ];
    if (moves.isEmpty) return const [PassMove()];
    return moves;
  }

  List<PlaceMove> _placements(Player player) {
    final moves = <PlaceMove>[];
    final remaining = remainingInventory(player);
    for (var level = 1; level <= 4; level++) {
      if ((remaining[level] ?? 0) <= 0) continue;
      for (var cell = 0; cell < 9; cell++) {
        if (_canLand(level, cell)) moves.add(PlaceMove(level, cell));
      }
    }
    return moves;
  }

  List<RelocateMove> _relocations(Player player) {
    if (!config.canMovePlacedChips) return const [];
    final moves = <RelocateMove>[];
    for (var from = 0; from < 9; from++) {
      final stack = _board[from];
      // Only the topmost chip of a stack is movable, and only by its owner.
      if (stack.isEmpty || stack.last.owner != player) continue;
      final level = stack.last.level;
      for (var to = 0; to < 9; to++) {
        if (to == from) continue;
        if (_canLand(level, to)) {
          moves.add(RelocateMove(from, to));
        }
      }
    }
    return moves;
  }

  /// Whether a chip of [level] may land on [cell]: empty, or topmost chip
  /// strictly smaller (rules doc §1). Legality depends only on visible
  /// chips. L4 uncoverability is emergent — no level exceeds 4.
  bool _canLand(int level, int cell) {
    final stack = _board[cell];
    if (stack.isEmpty) return true;
    return stack.last.level < level;
  }

  // -------------------------------------------------------------- apply

  @override
  StackingEngine applyMove(StackingMove move) {
    if (status.isOver) {
      throw IllegalMoveException(move, 'Game is over: $status');
    }
    if (!legalMoves().contains(move)) {
      throw IllegalMoveException(move, 'Not a legal move for $currentPlayer');
    }

    final board = [for (final stack in _board) List<Chip>.of(stack)];
    switch (move) {
      case PlaceMove(:final level, :final cell):
        board[cell].add(Chip(currentPlayer, level));
      case RelocateMove(:final from, :final to):
        final chip = board[from].removeLast();
        board[to].add(chip);
      case PassMove():
        break;
    }
    final frozen = List<List<Chip>>.unmodifiable(
      board.map(List<Chip>.unmodifiable),
    );

    final next = currentPlayer.opponent;
    var counts = _positionCounts;
    if (config.canMovePlacedChips) {
      final key = _positionKey(frozen, next);
      counts = Map.unmodifiable(
        {...counts, key: (counts[key] ?? 0) + 1},
      );
    }
    return StackingEngine._(config, frozen, next, counts);
  }

  // ---------------------------------------------------------- status

  static const _lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
    [0, 4, 8], [2, 4, 6], // diagonals
  ];

  static GameStatus _evaluate(
    StackingConfig config,
    List<List<Chip>> board,
    Player currentPlayer,
    Map<String, int> positionCounts,
  ) {
    // The mover is whoever produced this position. Their line wins ties
    // where one move completes lines for both players.
    final mover = currentPlayer.opponent;
    final moverLine = _findLine(board, mover);
    if (moverLine != null) {
      return GameStatus.won(mover, EndReason.line, winningLine: moverLine);
    }
    final revealedLine = _findLine(board, currentPlayer);
    if (revealedLine != null) {
      return GameStatus.won(currentPlayer, EndReason.line,
          winningLine: revealedLine);
    }

    if (config.canMovePlacedChips &&
        positionCounts.values.any((c) => c >= 3)) {
      return const GameStatus.draw(EndReason.repetition);
    }

    // Game ends when NEITHER player has any legal action (§2.2). If only the
    // current player is stuck, they pass instead (legalMoves → [PassMove]).
    if (!_hasAnyAction(config, board, currentPlayer) &&
        !_hasAnyAction(config, board, mover)) {
      final moverCount = _countVisible(board, mover);
      final otherCount = _countVisible(board, currentPlayer);
      if (moverCount > otherCount) {
        return GameStatus.won(mover, EndReason.tiebreak);
      }
      if (otherCount > moverCount) {
        return GameStatus.won(currentPlayer, EndReason.tiebreak);
      }
      return const GameStatus.draw(EndReason.tiebreak);
    }

    return const GameStatus.ongoing();
  }

  static List<int>? _findLine(List<List<Chip>> board, Player player) {
    for (final line in _lines) {
      if (line.every((cell) {
        final stack = board[cell];
        return stack.isNotEmpty && stack.last.owner == player;
      })) {
        return line;
      }
    }
    return null;
  }

  static int _countVisible(List<List<Chip>> board, Player player) {
    var count = 0;
    for (final stack in board) {
      if (stack.isNotEmpty && stack.last.owner == player) count++;
    }
    return count;
  }

  static bool _hasAnyAction(
    StackingConfig config,
    List<List<Chip>> board,
    Player player,
  ) {
    bool canLand(int level, int cell) {
      final stack = board[cell];
      return stack.isEmpty || stack.last.level < level;
    }

    final remaining = Map<int, int>.of(config.inventoryPerPlayer);
    for (final stack in board) {
      for (final chip in stack) {
        if (chip.owner == player) {
          remaining[chip.level] = (remaining[chip.level] ?? 0) - 1;
        }
      }
    }
    for (var level = 1; level <= 4; level++) {
      if ((remaining[level] ?? 0) <= 0) continue;
      for (var cell = 0; cell < 9; cell++) {
        if (canLand(level, cell)) return true;
      }
    }
    if (config.canMovePlacedChips) {
      for (var from = 0; from < 9; from++) {
        final stack = board[from];
        if (stack.isEmpty || stack.last.owner != player) continue;
        for (var to = 0; to < 9; to++) {
          if (to != from && canLand(stack.last.level, to)) return true;
        }
      }
    }
    return false;
  }

  /// Canonical position identity for the repetition rule: board contents
  /// plus player to move. Inventories are derivable from the board, so they
  /// are not part of the key.
  static String _positionKey(List<List<Chip>> board, Player toMove) {
    final cells = board
        .map((s) => s.map((c) => '${c.owner.toJson()}${c.level}').join('.'))
        .join('|');
    return '$cells#${toMove.toJson()}';
  }

  // ------------------------------------------------------------- JSON

  @override
  Map<String, Object?> toJson() => {
        'config': config.toJson(),
        'board': [
          for (final stack in _board) [for (final chip in stack) chip.toJson()],
        ],
        'currentPlayer': currentPlayer.toJson(),
        if (config.canMovePlacedChips) 'positionCounts': _positionCounts,
      };

  factory StackingEngine.fromJson(Map<String, Object?> json) {
    final config =
        StackingConfig.fromJson((json['config'] as Map).cast<String, Object?>());
    final rawBoard = json['board'];
    if (rawBoard is! List || rawBoard.length != 9) {
      throw const FormatException('Board must have 9 cells');
    }
    final board = List<List<Chip>>.unmodifiable(rawBoard.map((rawStack) {
      final stack = (rawStack as List)
          .map((c) => Chip.fromJson((c as Map).cast<String, Object?>()))
          .toList();
      for (var i = 1; i < stack.length; i++) {
        if (stack[i].level <= stack[i - 1].level) {
          throw const FormatException(
              'Stacks must be strictly ascending bottom → top');
        }
      }
      return List<Chip>.unmodifiable(stack);
    }));
    final currentPlayer = Player.fromJson(json['currentPlayer']);

    // Chips on the board may not exceed either player's initial inventory.
    for (final player in Player.values) {
      final placed = <int, int>{};
      for (final stack in board) {
        for (final chip in stack) {
          if (chip.owner == player) {
            placed[chip.level] = (placed[chip.level] ?? 0) + 1;
          }
        }
      }
      for (final e in placed.entries) {
        if (e.value > (config.inventoryPerPlayer[e.key] ?? 0)) {
          throw FormatException(
              'More L${e.key} chips on board than ${player.name}\'s inventory');
        }
      }
    }

    Map<String, int> counts;
    if (!config.canMovePlacedChips) {
      counts = const {};
    } else {
      final raw = json['positionCounts'];
      counts = raw == null
          ? Map.unmodifiable({_positionKey(board, currentPlayer): 1})
          : Map.unmodifiable((raw as Map).cast<String, int>());
    }
    return StackingEngine._(config, board, currentPlayer, counts);
  }
}
