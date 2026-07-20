import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_runner.dart';
import '../engines/common/game_mode.dart';
import '../engines/common/game_status.dart';
import '../engines/common/move.dart';
import '../engines/stacking/stacking_engine.dart';
import '../engines/stacking/stacking_move.dart';
import '../engines/ultimate/ultimate_move.dart';
import '../services/game_persistence_service.dart';
import 'game_session.dart';
import 'session_opponents.dart';

/// The AI move computer this controller calls. A [Provider] (not a plain
/// top-level constant) so tests can override it with a fast fake instead of
/// spawning a real isolate (see CLAUDE.md: Riverpod for shared state).
final aiRunnerProvider = Provider<AiMoveComputer>((ref) => AiRunner.chooseMove);

final gameControllerProvider =
    NotifierProvider<GameController, GameSession?>(GameController.new);

/// Turn management and the single gateway for mutating game state.
///
/// Every move — local UI and AI in v1, a network listener added in v2 —
/// goes through [submitMove]. No other path touches the engine (CLAUDE.md
/// rule 3). Legality lives in the engine; this class only asks
/// `legalMoves()`.
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
  /// (rules doc §5) and is always the human when [opponents] is vs-AI;
  /// rematch seating is handled by [rematch].
  void startGame(GameMode mode, {SessionOpponents opponents = SessionOpponents.human}) {
    state = GameSession(
      mode: mode,
      engine: mode.createEngine(),
      starterPerson: 1,
      opponents: opponents,
    );
    _persist();
    _maybeTriggerAiMove();
  }

  void exitGame() {
    state = null;
    unawaited(ref.read(gamePersistenceServiceProvider).clearSnapshot());
  }

  /// New game, same mode and opponents: the loser starts; on a draw the
  /// seats alternate (rules doc §5). This is how the AI can end up moving
  /// first, if the human lost the previous game.
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
      opponents: session.opponents,
    );
    _persist();
    _maybeTriggerAiMove();
  }

  // --------------------------------------------------------- persistence

  /// Saves the current game if it's ongoing, or clears the saved slot if
  /// it just ended — a finished game has nothing left to resume (rules doc
  /// §5: serialise to disk, restore on relaunch with resume-or-abandon).
  void _persist() {
    final session = state;
    final service = ref.read(gamePersistenceServiceProvider);
    if (session == null || session.status.isOver) {
      unawaited(service.clearSnapshot());
    } else {
      unawaited(service.saveSnapshot(session.toJson()));
    }
  }

  /// Loads the saved game, if any, without making it the active session —
  /// callers decide whether to [resumeSession] or [discardSavedGame] (the
  /// resume-or-abandon prompt on relaunch).
  Future<GameSession?> peekSavedGame() async {
    final service = ref.read(gamePersistenceServiceProvider);
    final json = await service.loadSnapshot();
    if (json == null) return null;
    try {
      return GameSession.fromJson(json);
    } on FormatException {
      await service.clearSnapshot();
      return null;
    }
  }

  /// Makes [session] (from [peekSavedGame]) the active game, resuming an
  /// AI turn if it's now the AI's move.
  void resumeSession(GameSession session) {
    state = session;
    _maybeTriggerAiMove();
  }

  Future<void> discardSavedGame() =>
      ref.read(gamePersistenceServiceProvider).clearSnapshot();

  // -------------------------------------------------------------- staging
  //
  // Every staging method below no-ops during the AI's turn: currentPlayer
  // belongs to the AI person, so there is nothing for the human to stage.

  /// Toggles an inventory chip selection (stacking modes).
  void selectInventoryLevel(int level) {
    final session = _session;
    if (session.isAiTurn) return;
    state = session.copy(
      selectedLevel: session.selectedLevel == level ? null : level,
      selectedCell: null,
      stagedMove: null,
    );
  }

  void clearSelection() {
    final session = _session;
    if (session.isAiTurn) return;
    state = session.copy(
      selectedLevel: null,
      selectedCell: null,
      stagedMove: null,
    );
  }

  /// Stages [move] if the engine says it is legal.
  void stageMove(Move move) {
    final session = _session;
    if (session.isAiTurn) return;
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
      opponents: session.opponents,
    );
    _persist();
    _maybeTriggerAiMove();
  }

  // ------------------------------------------------- gesture interpretation

  /// A tap on stacking-board cell, resolved against the current selection.
  /// Free cancellation (design doc §3.2 decision): selecting is never a
  /// commitment; tapping elsewhere clears.
  void onStackingCellTapped(int cell) {
    final session = _session;
    if (session.status.isOver || session.isAiTurn) return;
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
    if (session.status.isOver || session.isAiTurn) return;
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

  // ------------------------------------------------------------------- AI

  /// Kicks off a background AI move if it's now an AI-controlled person's
  /// turn. Safe to call after every state transition — it's a no-op
  /// otherwise.
  void _maybeTriggerAiMove() {
    final session = state;
    if (session == null || session.status.isOver || !session.isAiTurn) return;
    unawaited(_runAiTurn(session));
  }

  Future<void> _runAiTurn(GameSession session) async {
    final legal = session.engine.legalMoves();
    if (legal.length == 1) {
      // Forced move (or a forced pass): no search needed, nothing async —
      // safe to apply immediately.
      submitMove(legal.single);
      return;
    }

    final thinking = session.copy(aiThinking: true);
    state = thinking;
    final move = await ref.read(aiRunnerProvider)(
      mode: session.mode,
      difficulty: session.opponents.difficulty!,
      engine: session.engine,
    );
    // The session may have moved on (exited, restarted) while awaiting —
    // compare against `thinking` (the state we ourselves set), not the
    // original `session`, since setting aiThinking already changed identity.
    // Never apply a stale computation on top of unrelated state.
    if (!identical(state, thinking)) return;
    submitMove(move);
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
