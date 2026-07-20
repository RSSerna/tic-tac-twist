import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engines/common/game_status.dart';
import '../engines/common/move.dart';
import '../engines/stacking/stacking_engine.dart';
import '../engines/stacking/stacking_move.dart';
import '../engines/ultimate/ultimate_move.dart';
import 'game_mode.dart';
import 'game_session.dart';

final gameControllerProvider =
    NotifierProvider<GameController, GameSession?>(GameController.new);

/// Turn management and the single gateway for mutating game state.
///
/// Every move — local UI now, AI in Phase 3, network in v2 — goes through
/// [submitMove]. No other path touches the engine (CLAUDE.md rule 3).
/// Legality lives in the engine; this class only asks `legalMoves()`.
class GameController extends Notifier<GameSession?> {
  @override
  GameSession? build() => null;

  GameSession get _session {
    final session = state;
    if (session == null) {
      throw StateError('No active game');
    }
    return session;
  }

  /// Starts a fresh game. Person 1 starts the first game of a session
  /// (rules doc §5); rematch seating is handled by [rematch].
  void startGame(GameMode mode) {
    state = GameSession(
      mode: mode,
      engine: mode.createEngine(),
      starterPerson: 1,
    );
  }

  void exitGame() => state = null;

  /// New game, same mode: the loser starts; on a draw the seats alternate
  /// (rules doc §5).
  void rematch() {
    final session = _session;
    final status = session.status;
    final nextStarter = switch (status.outcome) {
      GameOutcome.won => 3 - session.personFor(status.winner!),
      _ => 3 - session.starterPerson,
    };
    state = GameSession(
      mode: session.mode,
      engine: session.mode.createEngine(),
      starterPerson: nextStarter,
    );
  }

  // -------------------------------------------------------------- staging

  /// Toggles an inventory chip selection (stacking modes).
  void selectInventoryLevel(int level) {
    final session = _session;
    state = session.copy(
      selectedLevel: session.selectedLevel == level ? null : level,
      selectedCell: null,
      stagedMove: null,
    );
  }

  void clearSelection() {
    state = _session.copy(
      selectedLevel: null,
      selectedCell: null,
      stagedMove: null,
    );
  }

  /// Stages [move] if the engine says it is legal.
  void stageMove(Move move) {
    final session = _session;
    if (session.engine.legalMoves().contains(move)) {
      state = session.copy(stagedMove: move);
    }
  }

  /// Commits the staged move. Committed moves are final — no undo.
  void commitStagedMove() {
    final staged = _session.stagedMove;
    if (staged != null) submitMove(staged);
  }

  /// The only path that mutates game state.
  void submitMove(Move move) {
    final session = _session;
    state = GameSession(
      mode: session.mode,
      engine: session.engine.applyMove(move),
      starterPerson: session.starterPerson,
    );
  }

  // ------------------------------------------------- gesture interpretation

  /// A tap on stacking-board cell, resolved against the current selection.
  /// Free cancellation (design doc §3.2 decision): selecting is never a
  /// commitment; tapping elsewhere clears.
  void onStackingCellTapped(int cell) {
    final session = _session;
    if (session.status.isOver) return;
    final staged = session.stagedMove;

    // Second tap on the staged target commits.
    if (staged is PlaceMove && staged.cell == cell ||
        staged is RelocateMove && staged.to == cell) {
      commitStagedMove();
      return;
    }

    final legal = session.engine.legalMoves();
    if (session.selectedLevel != null) {
      final move = PlaceMove(session.selectedLevel!, cell);
      if (legal.contains(move)) {
        state = session.copy(stagedMove: move);
        return;
      }
    }
    if (session.selectedCell != null && session.selectedCell != cell) {
      final move = RelocateMove(session.selectedCell!, cell);
      if (legal.contains(move)) {
        state = session.copy(stagedMove: move);
        return;
      }
    }
    // Tapping a chip with legal destinations selects it for relocation.
    if (legal.whereType<RelocateMove>().any((m) => m.from == cell)) {
      state = session.copy(
        selectedLevel: null,
        selectedCell: cell,
        stagedMove: null,
      );
      return;
    }
    clearSelection();
  }

  /// A tap on an Ultimate cell: stage if legal, commit on the second tap,
  /// clear otherwise.
  void onUltimateCellTapped(int board, int cell) {
    final session = _session;
    if (session.status.isOver) return;
    final move = UltimateMove(board, cell);
    if (session.stagedMove == move) {
      commitStagedMove();
      return;
    }
    if (session.engine.legalMoves().contains(move)) {
      state = session.copy(stagedMove: move);
    } else {
      clearSelection();
    }
  }

  // ------------------------------------------------------------- queries

  /// Cells a staged-or-selected stacking chip may land on (for the always-on
  /// legal-move highlight; leaks nothing — legality is visible-top only).
  Set<int> stackingHighlightTargets() {
    final session = state;
    if (session == null || session.status.isOver) return const {};
    final legal = session.engine.legalMoves();
    if (session.selectedLevel != null) {
      return legal
          .whereType<PlaceMove>()
          .where((m) => m.level == session.selectedLevel)
          .map((m) => m.cell)
          .toSet();
    }
    if (session.selectedCell != null) {
      return legal
          .whereType<RelocateMove>()
          .where((m) => m.from == session.selectedCell)
          .map((m) => m.to)
          .toSet();
    }
    return const {};
  }

  /// Boards the current Ultimate player may play in — the send-rule
  /// indicator, always on; on a free move this is every open board.
  Set<int> ultimatePlayableBoards() {
    final session = state;
    if (session == null || session.status.isOver) return const {};
    return session.engine.legalMoves()
        .whereType<UltimateMove>()
        .map((m) => m.board)
        .toSet();
  }

  /// Whether the current player's only option is to pass.
  bool get mustPass {
    final session = state;
    if (session == null) return false;
    final legal = session.engine.legalMoves();
    return legal.length == 1 && legal.first is PassMove;
  }

  StackingEngine get stackingEngine => _session.engine as StackingEngine;
}
