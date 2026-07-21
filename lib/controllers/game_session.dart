import 'package:meta/meta.dart';

import '../engines/common/game_engine.dart';
import '../engines/common/game_mode.dart';
import '../engines/common/game_status.dart';
import '../engines/common/move.dart';
import '../engines/common/player.dart';
import 'session_opponents.dart';
import 'tutorial_state.dart';

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
    this.opponents = SessionOpponents.human,
    this.selectedLevel,
    this.selectedCell,
    this.stagedMove,
    this.aiThinking = false,
    this.tutorial,
    this.forfeitStatus,
    this.turnTimerSeconds,
    this.turnDeadline,
    this.moveCount = 0,
    this.startedAt,
  });

  final GameMode mode;
  final GameEngine<Move> engine;

  /// Which person (1 or 2) moves first in this game (= engine [Player.one]).
  final int starterPerson;

  /// Which persons are AI-controlled; fixed identity, independent of
  /// [starterPerson].
  final SessionOpponents opponents;

  /// Stacking: inventory chip level picked, awaiting a target cell.
  final int? selectedLevel;

  /// Movable: origin cell of a chip picked for relocation.
  final int? selectedCell;

  /// Fully specified move awaiting confirmation (no-undo rule: confirm
  /// before commit, never take back after).
  final Move? stagedMove;

  /// An AI move computation is in flight. Presentation state only; used to
  /// show a "thinking" indicator and to keep the human from staging moves
  /// on the AI's turn.
  final bool aiThinking;

  /// Non-null iff this is a tutorial session (design doc §7): the human's
  /// moves are restricted to the script's next expected move, and the
  /// "opponent" auto-plays rather than being AI or a second human. Never
  /// persisted — an interrupted tutorial just restarts (see
  /// [TutorialState]'s doc comment).
  final TutorialState? tutorial;

  /// A controller-level forfeit (design doc §3.6: the local turn timer
  /// expiring). Overrides the engine's own status when set — the engine
  /// itself never produces this; it has no clock (CLAUDE.md rule 5). Not
  /// persisted: a forfeited game is over, so [GameController._persist]
  /// already has nothing left to save.
  final GameStatus? forfeitStatus;

  /// Local turn timer, in seconds; null means off (design doc §3.6).
  /// Fixed for the life of a game, read from settings when the game starts.
  final int? turnTimerSeconds;

  /// Wall-clock deadline for the current turn, set by the controller
  /// whenever it (re)schedules the timer. Presentation state for the live
  /// countdown display only (CLAUDE.md rule 6: engines never see a clock,
  /// and this isn't even engine-adjacent) — never persisted, since a
  /// resumed game restarts its timer fresh rather than reconstructing
  /// elapsed real time across the backgrounding gap.
  final DateTime? turnDeadline;

  /// Total moves played so far (analytics only — product doc §5's
  /// `game_ended` event wants average game length per mode). Persisted so a
  /// resumed game keeps an accurate count.
  final int moveCount;

  /// Wall-clock time this game started, for the `game_ended` event's
  /// duration field. Not persisted — like [turnDeadline], a resumed game
  /// gets a fresh value rather than reconstructing elapsed real time across
  /// the backgrounding gap, so duration only ever reflects time actually
  /// spent with the app open.
  final DateTime? startedAt;

  Player get currentPlayer => engine.currentPlayer;
  GameStatus get status => forfeitStatus ?? engine.status;

  int personFor(Player player) =>
      player == Player.one ? starterPerson : 3 - starterPerson;

  int get currentPerson => personFor(currentPlayer);

  bool get isAiTurn => opponents.isAiPerson(currentPerson);

  bool get isTutorial => tutorial != null;

  static const _unset = Object();

  GameSession copy({
    GameEngine<Move>? engine,
    Object? selectedLevel = _unset,
    Object? selectedCell = _unset,
    Object? stagedMove = _unset,
    bool? aiThinking,
    Object? tutorial = _unset,
    Object? forfeitStatus = _unset,
    Object? turnDeadline = _unset,
    Object? startedAt = _unset,
  }) =>
      GameSession(
        mode: mode,
        engine: engine ?? this.engine,
        starterPerson: starterPerson,
        opponents: opponents,
        selectedLevel: identical(selectedLevel, _unset)
            ? this.selectedLevel
            : selectedLevel as int?,
        selectedCell: identical(selectedCell, _unset)
            ? this.selectedCell
            : selectedCell as int?,
        tutorial: identical(tutorial, _unset)
            ? this.tutorial
            : tutorial as TutorialState?,
        stagedMove:
            identical(stagedMove, _unset) ? this.stagedMove : stagedMove as Move?,
        aiThinking: aiThinking ?? this.aiThinking,
        forfeitStatus: identical(forfeitStatus, _unset)
            ? this.forfeitStatus
            : forfeitStatus as GameStatus?,
        turnTimerSeconds: turnTimerSeconds,
        turnDeadline: identical(turnDeadline, _unset)
            ? this.turnDeadline
            : turnDeadline as DateTime?,
        moveCount: moveCount,
        startedAt: identical(startedAt, _unset) ? this.startedAt : startedAt as DateTime?,
      );

  /// Persisted for interruption handling (rules doc §5): mode, engine
  /// state, and seating only. Selection/staging/aiThinking are presentation
  /// state (CLAUDE.md rule 6) and are never serialised — a resumed game
  /// always comes back with a clean slate for those.
  Map<String, Object?> toJson() => {
        'mode': mode.name,
        'engine': engine.toJson(),
        'starterPerson': starterPerson,
        'opponents': opponents.toJson(),
        'turnTimerSeconds': turnTimerSeconds,
        'moveCount': moveCount,
      };

  factory GameSession.fromJson(Map<String, Object?> json) {
    final mode = GameMode.values.byName(json['mode']! as String);
    final engineJson = (json['engine']! as Map).cast<String, Object?>();
    final starterPerson = json['starterPerson'];
    if (starterPerson is! int || (starterPerson != 1 && starterPerson != 2)) {
      throw const FormatException('Invalid starterPerson');
    }
    return GameSession(
      mode: mode,
      engine: mode.decodeEngine(engineJson),
      starterPerson: starterPerson,
      opponents: SessionOpponents.fromJson(
          (json['opponents']! as Map).cast<String, Object?>()),
      turnTimerSeconds: json['turnTimerSeconds'] as int?,
      moveCount: json['moveCount'] as int? ?? 0,
    );
  }
}
