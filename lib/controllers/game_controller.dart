import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/ai_runner.dart';
import '../ai/difficulty.dart';
import 'daily_challenge_controller.dart';
import '../engines/common/game_engine.dart';
import '../engines/common/game_mode.dart';
import '../engines/common/game_status.dart';
import '../engines/common/move.dart';
import '../engines/stacking/stacking_engine.dart';
import '../engines/stacking/stacking_move.dart';
import '../engines/ultimate/ultimate_engine.dart';
import '../engines/ultimate/ultimate_move.dart';
import '../services/achievement_service.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/game_persistence_service.dart';
import '../services/stats/stats_service.dart';
import '../services/tutorial_progress_service.dart';
import '../theme/skin.dart';
import '../tutorial/tutorial_script.dart';
import '../tutorial/tutorial_step.dart';
import 'game_session.dart';
import 'session_opponents.dart';
import 'settings_controller.dart';
import 'skin_controller.dart';
import 'tutorial_state.dart';

/// The AI move computer this controller calls. A [Provider] (not a plain
/// top-level constant) so tests can override it with a fast fake instead of
/// spawning a real isolate (see CLAUDE.md: Riverpod for shared state).
final aiRunnerProvider = Provider<AiMoveComputer>((ref) => AiRunner.chooseMove);

/// Maps a turn timer preset's seconds to the real [Duration] to count down.
/// A seam (not a direct `Duration(seconds: seconds)` call) so tests can
/// swap in a millisecond-scale mapping instead of waiting out real
/// 15s/30s countdowns.
final turnTimerDurationProvider = Provider<Duration Function(int seconds)>(
  (ref) =>
      (seconds) => Duration(seconds: seconds),
);

final gameControllerProvider = NotifierProvider<GameController, GameSession?>(
  GameController.new,
);

/// Turn management and the single gateway for mutating game state.
///
/// Every move — local UI and AI in v1, a network listener added in v2 —
/// goes through [submitMove]. No other path touches the engine (CLAUDE.md
/// rule 3). Legality lives in the engine; this class only asks
/// `legalMoves()`.
class GameController extends Notifier<GameSession?> {
  Timer? _turnTimer;

  @override
  GameSession? build() {
    ref.onDispose(() => _turnTimer?.cancel());
    return null;
  }

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
  void startGame(
    GameMode mode, {
    SessionOpponents opponents = SessionOpponents.human,
  }) {
    final session = GameSession(
      mode: mode,
      engine: mode.createEngine(),
      starterPerson: 1,
      opponents: opponents,
      turnTimerSeconds: _currentTurnTimerSeconds(),
      startedAt: DateTime.now(),
    );
    state = session;
    _persist();
    _recordGameStarted(session);
    _maybeTriggerAiMove();
    _rescheduleTurnTimer();
  }

  /// Ends the game (post-result "exit to menu", or the resume-or-abandon
  /// dialog's "abandon"). No stats effect — a finished game already
  /// recorded its result; a never-started saved game never played.
  void exitGame() {
    _turnTimer?.cancel();
    state = null;
    unawaited(ref.read(gamePersistenceServiceProvider).clearSnapshot());
  }

  /// Leaves an in-progress game. Vs-AI, this is a loss for the human
  /// (product doc §4: "abandoning a game vs AI counts as a loss") —
  /// pass-and-play has no single "you" to charge a loss to, so it has no
  /// stats effect. Already-finished games should go through [exitGame]
  /// instead (there's nothing left to abandon).
  Future<void> abandonGame() async {
    final session = _session;
    if (session.status.isOngoing &&
        !session.isTutorial &&
        session.opponents.personTwoIsAi) {
      await ref
          .read(statsServiceProvider)
          .recordVsAiResult(
            session.mode,
            session.opponents.difficulty!,
            MatchResult.loss,
          );
    }
    exitGame();
  }

  int? _currentTurnTimerSeconds() =>
      ref.read(settingsControllerProvider).value?.turnTimer.seconds;

  // ----------------------------------------------------------- tutorial
  //
  // Design doc §7: a real game, on the real engine, with a scripted
  // opponent and prompts driven by step (move) count. Never persisted —
  // an interrupted tutorial just restarts (see TutorialState).

  /// Starts mode's guided first game. Person 1 is always the human.
  void startTutorial(GameMode mode) {
    state = GameSession(
      mode: mode,
      engine: mode.createEngine(),
      starterPerson: 1,
      tutorial: TutorialState(script: TutorialScript.forMode(mode)),
    );
    _maybeAutoPlayTutorialStep();
  }

  /// Advances past a [TutorialMessage] step — the "Next" control. Board
  /// taps advance [TutorialHumanMove] steps instead, via [submitMove].
  void tutorialNext() {
    final session = _session;
    final tutorial = session.tutorial;
    if (tutorial == null || tutorial.currentStep is! TutorialMessage) return;
    state = session.copy(tutorial: tutorial.advance());
    _maybeAutoPlayTutorialStep();
  }

  /// Ends the tutorial, marking the mode as completed either way — skipping
  /// is still a completed onboarding, not a "try again next launch" (design
  /// doc §7: "skippable, but not silently").
  Future<void> finishTutorial() async {
    final session = _session;
    await ref.read(tutorialProgressServiceProvider).markCompleted(session.mode);
    final analytics = ref.read(analyticsServiceProvider);
    if (session.tutorial?.isComplete ?? false) {
      unawaited(analytics.tutorialCompleted(session.mode));
    } else {
      unawaited(analytics.tutorialSkipped(session.mode));
    }
    state = null;
  }

  void _maybeAutoPlayTutorialStep() {
    final session = state;
    if (session == null) return;
    final tutorial = session.tutorial;
    if (tutorial == null || tutorial.isComplete) return;
    final step = tutorial.currentStep;
    if (step is! TutorialOpponentMove) return;
    Future.delayed(const Duration(milliseconds: 700), () {
      // Stale guard, same pattern as the AI turn: only apply if nothing
      // else changed state while we were waiting.
      if (!identical(state, session)) return;
      submitMove(step.move);
    });
  }

  /// Whether [move] is the tutorial script's next expected move — true
  /// unconditionally outside a tutorial. Gates every staging path so a
  /// tutorial session can only ever play its scripted line.
  bool _isTutorialMoveAllowed(GameSession session, Move move) {
    final tutorial = session.tutorial;
    if (tutorial == null) return true;
    final step = tutorial.currentStep;
    return step is TutorialHumanMove && step.move == move;
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
    final nextSession = GameSession(
      mode: session.mode,
      engine: session.mode.createEngine(),
      starterPerson: nextStarter,
      opponents: session.opponents,
      turnTimerSeconds: _currentTurnTimerSeconds(),
      startedAt: DateTime.now(),
    );
    state = nextSession;
    _persist();
    _recordGameStarted(nextSession);
    _maybeTriggerAiMove();
    _rescheduleTurnTimer();
  }

  // ------------------------------------------------------------- results

  /// Records the outcome once a game just finished — local by seat, vs-AI
  /// from the human's perspective (product doc §4). Never called for
  /// tutorials, which have nothing to do with a player's stats.
  void _recordResult(GameSession session) {
    final status = session.status;
    final service = ref.read(statsServiceProvider);
    unawaited(_recordDailyProgress(session));
    if (session.opponents.personTwoIsAi) {
      const humanPerson = 1; // always true vs-AI (rules doc §5)
      final result = switch (status.outcome) {
        GameOutcome.draw => MatchResult.draw,
        GameOutcome.won =>
          session.personFor(status.winner!) == humanPerson
              ? MatchResult.win
              : MatchResult.loss,
        GameOutcome.ongoing => throw StateError(
          'unreachable: recorded while ongoing',
        ),
      };
      unawaited(
        service.recordVsAiResult(
          session.mode,
          session.opponents.difficulty!,
          result,
        ),
      );
    } else {
      final winnerPerson = status.outcome == GameOutcome.won
          ? session.personFor(status.winner!)
          : null;
      unawaited(
        service.recordLocalResult(session.mode, winnerPerson: winnerPerson),
      );
    }
  }

  /// Feeds the daily challenges behind the shop's claim meter. Fire-and-
  /// forget like stats and achievements — a finished game must never wait on
  /// storage.
  Future<void> _recordDailyProgress(GameSession session) async {
    final status = session.status;
    if (status.outcome == GameOutcome.ongoing) return;

    final vsAi = session.opponents.personTwoIsAi;
    // Vs AI the human is always person 1 (rules doc §5); pass-and-play has no
    // "you", so any decisive result counts as the day's win.
    final humanWon =
        status.outcome == GameOutcome.won &&
        (!vsAi || session.personFor(status.winner!) == 1);
    final difficulty = session.opponents.difficulty;
    final tough =
        vsAi &&
        humanWon &&
        difficulty != null &&
        difficulty.index >= Difficulty.hard.index;

    await ref
        .read(dailyChallengeControllerProvider.notifier)
        .recordGameFinished(
          mode: session.mode,
          won: humanWon,
          beatToughAi: tough,
        );
  }

  // ---------------------------------------------------------- analytics
  //
  // Product doc §5's deliberately small event set. Fire-and-forget, same
  // rationale as stats/achievements — analytics must never slow down a move.

  void _recordGameStarted(GameSession session) {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .gameStarted(
            mode: session.mode,
            opponentType: session.opponents.personTwoIsAi ? 'ai' : 'human',
            difficulty: session.opponents.difficulty,
          ),
    );
  }

  void _recordGameEnded(GameSession session) {
    final status = session.status;
    final result = switch (status.outcome) {
      GameOutcome.won => 'win',
      GameOutcome.draw => 'draw',
      GameOutcome.ongoing => throw StateError(
        'unreachable: recorded while ongoing',
      ),
    };
    final duration = session.startedAt == null
        ? Duration.zero
        : DateTime.now().difference(session.startedAt!);
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .gameEnded(
            mode: session.mode,
            result: result,
            endReason: status.reason!.name,
            moveCount: session.moveCount,
            duration: duration,
            firstPlayer: session.starterPerson,
          ),
    );
  }

  /// Product doc §3.1's example achievement set — unlocking any one of them
  /// unlocks the one premium skin this phase ships (real chests, rarity
  /// tiers, and per-achievement rewards are Phase 9). Only fires for an
  /// actual win (a line or a tiebreak decision) — a timeout forfeit doesn't
  /// count as "beating" anything.
  Future<void> _checkAchievements(Move move, GameSession session) async {
    final status = session.status;
    if (status.outcome != GameOutcome.won) return;
    if (status.reason != EndReason.line &&
        status.reason != EndReason.tiebreak) {
      return;
    }

    final achievements = <Achievement>{};

    if (session.opponents.personTwoIsAi &&
        session.opponents.difficulty == Difficulty.impossible &&
        session.personFor(status.winner!) == 1) {
      achievements.add(switch (session.mode) {
        GameMode.stackStatic => Achievement.beatImpossibleStatic,
        GameMode.stackMovable => Achievement.beatImpossibleMovable,
        GameMode.ultimate => Achievement.beatImpossibleUltimate,
      });
    }
    if (session.mode.isStacking &&
        status.reason == EndReason.line &&
        move is PlaceMove &&
        move.level == 4 &&
        status.winningLine!.contains(move.cell)) {
      achievements.add(Achievement.winWithL4OnFinalMove);
    }
    if (session.mode == GameMode.ultimate &&
        (session.engine as UltimateEngine).claimedCount(status.winner!) >= 6) {
      achievements.add(Achievement.claimBoardMajority);
    }
    if (achievements.isEmpty) return;

    final service = ref.read(achievementServiceProvider);
    var anyNewlyUnlocked = false;
    for (final achievement in achievements) {
      if (await service.unlock(achievement)) anyNewlyUnlocked = true;
    }
    if (anyNewlyUnlocked) {
      await ref
          .read(skinControllerProvider.notifier)
          .unlockSkin(GameSkin.nestingDolls);
    }
  }

  // --------------------------------------------------------- turn timer
  //
  // Design doc §3.6: optional, off by default, controller-level presentation
  // state — the engine never sees a clock (CLAUDE.md rule 5).

  void _rescheduleTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
    final session = state;
    if (session == null) return;
    final seconds = session.turnTimerSeconds;
    if (seconds == null ||
        session.status.isOver ||
        session.isAiTurn ||
        session.isTutorial) {
      if (session.turnDeadline != null) {
        state = session.copy(turnDeadline: null);
      }
      return;
    }
    final duration = ref.read(turnTimerDurationProvider)(seconds);
    // The deadline is presentation state for the live countdown display —
    // stamped once here, not ticked every second, so scheduling doesn't
    // touch persistence or stats on its own.
    final withDeadline = session.copy(
      turnDeadline: DateTime.now().add(duration),
    );
    state = withDeadline;
    _turnTimer = Timer(duration, () => _forfeitOnTimeout(withDeadline));
  }

  void _forfeitOnTimeout(GameSession expected) {
    // Stale-timer guard: if anything else changed state since this timer
    // was scheduled, it's for a turn that no longer exists.
    if (!identical(state, expected)) return;
    final timedOutPlayer = expected.currentPlayer;
    final newSession = expected.copy(
      forfeitStatus: GameStatus.won(timedOutPlayer.opponent, EndReason.timeout),
      turnDeadline: null,
    );
    state = newSession;
    _recordResult(newSession);
    _recordGameEnded(newSession);
    _persist();
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
  /// AI turn if it's now the AI's move. A turn timer, if the game has one,
  /// restarts fresh rather than trying to reconstruct elapsed real time
  /// across the backgrounding gap.
  void resumeSession(GameSession session) {
    // startedAt is never persisted (see GameSession's doc comment) — a
    // fresh value here means duration only ever reflects time actually
    // spent with the app open, same rationale as the turn timer restarting
    // fresh rather than reconstructing elapsed real time.
    state = session.copy(startedAt: DateTime.now());
    _maybeTriggerAiMove();
    _rescheduleTurnTimer();
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

  /// Stages [move] if the engine says it is legal (and, in a tutorial, if
  /// it's also the script's next expected move).
  void stageMove(Move move) {
    final session = _session;
    if (session.isAiTurn) return;
    if (session.engine.legalMoves().contains(move) &&
        _isTutorialMoveAllowed(session, move)) {
      state = session.copy(stagedMove: move);
    }
  }

  /// Commits the staged move. Committed moves are final — no undo.
  void commitStagedMove() {
    final staged = _session.stagedMove;
    if (staged != null) submitMove(staged);
  }

  /// The only path that mutates game state — the real engine, whether the
  /// move came from local UI, the AI, or (design doc §7) a tutorial's
  /// scripted opponent.
  void submitMove(Move move) {
    final session = _session;
    final tutorial = session.tutorial;
    final wasOngoing = session.status.isOngoing;
    final newEngine = session.engine.applyMove(move);
    final newSession = GameSession(
      mode: session.mode,
      engine: newEngine,
      starterPerson: session.starterPerson,
      opponents: session.opponents,
      lastMove: move,
      tutorial: tutorial?.advance(),
      turnTimerSeconds: session.turnTimerSeconds,
      moveCount: session.moveCount + 1,
      startedAt: session.startedAt,
    );
    state = newSession;
    _playMoveSfx(session.mode, move, session.engine, newEngine);
    if (wasOngoing && newSession.status.outcome == GameOutcome.won) {
      _playSfx(SfxSound.gameWin);
    }
    if (tutorial == null) {
      _persist();
      if (wasOngoing && newSession.status.isOver) {
        _recordResult(newSession);
        unawaited(_checkAchievements(move, newSession));
        _recordGameEnded(newSession);
      }
      _maybeTriggerAiMove();
      _rescheduleTurnTimer();
    } else {
      _maybeAutoPlayTutorialStep();
    }
  }

  // ------------------------------------------------------------------ audio
  //
  // Design doc §5: chip placement, cover (weightier), small-board claim,
  // game win, invalid move. Fire-and-forget, gated on the live SFX setting
  // — never blocks or delays a move (same rationale as _playSfx itself).

  void _playSfx(SfxSound sound) {
    final enabled =
        ref.read(settingsControllerProvider).value?.sfxEnabled ?? true;
    if (!enabled) return;
    unawaited(ref.read(audioServiceProvider).playSfx(sound));
  }

  void _playMoveSfx(
    GameMode mode,
    Move move,
    GameEngine<Move> oldEngine,
    GameEngine<Move> newEngine,
  ) {
    if (mode.isStacking) {
      final cell = switch (move) {
        PlaceMove(:final cell) => cell,
        RelocateMove(:final to) => to,
        _ => null,
      };
      if (cell == null) return;
      final covered = (oldEngine as StackingEngine).topChipAt(cell) != null;
      _playSfx(covered ? SfxSound.chipCover : SfxSound.chipPlace);
    } else {
      _playSfx(SfxSound.chipPlace);
      final board = (move as UltimateMove).board;
      final wasClaimed =
          (oldEngine as UltimateEngine).resultOf(board).claimant != null;
      final isClaimed =
          (newEngine as UltimateEngine).resultOf(board).claimant != null;
      if (!wasClaimed && isClaimed) _playSfx(SfxSound.boardClaim);
    }
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
      if (legal.contains(move) && _isTutorialMoveAllowed(session, move)) {
        state = session.copy(stagedMove: move);
        return;
      }
    }
    if (session.selectedCell != null && session.selectedCell != cell) {
      final move = RelocateMove(session.selectedCell!, cell);
      if (legal.contains(move) && _isTutorialMoveAllowed(session, move)) {
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
    // Only beep when a selection was actively rejected — a casual tap with
    // nothing selected is normal browsing, not a failed attempt.
    if (session.selectedLevel != null || session.selectedCell != null) {
      _playSfx(SfxSound.invalidMove);
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
    if (session.engine.legalMoves().contains(move) &&
        _isTutorialMoveAllowed(session, move)) {
      state = session.copy(stagedMove: move);
    } else {
      _playSfx(SfxSound.invalidMove);
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

  // A fast/easy-difficulty search can resolve in a handful of milliseconds,
  // so without a floor the AI's move lands before the human has had any
  // chance to register the "thinking" state — it just looks like the board
  // changed itself. This is a felt-pacing minimum, not a real computation
  // cost, so it's a plain constant rather than a themeable GameAnimations
  // token (skins restyle chip/board visuals, not AI turn-taking pace).
  static const _minAiThinkTime = Duration(milliseconds: 1000);

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
    final stopwatch = Stopwatch()..start();
    final move = await ref.read(aiRunnerProvider)(
      mode: session.mode,
      difficulty: session.opponents.difficulty!,
      engine: session.engine,
    );
    // Skipped under `flutter test` — same rationale and mechanism as
    // audio/ads/purchase's test no-ops (Phase 7/9): a widget test pumping a
    // fixed number of frames shouldn't have to account for a purely
    // cosmetic pacing delay. `kIsWeb` must short-circuit first since
    // `Platform.environment` throws on web at runtime (Phase 10 bug).
    final isTest = !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';
    if (!isTest) {
      final remaining = _minAiThinkTime - stopwatch.elapsed;
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    }
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
    return session.engine
        .legalMoves()
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
