import 'package:meta/meta.dart';

import 'player.dart';

enum GameOutcome { ongoing, won, draw }

/// Why a finished game ended.
enum EndReason {
  /// Three in a row — a topmost-visible line (stacking) or a big-board line
  /// of claimed boards (Ultimate).
  line,

  /// No line when play was exhausted; decided by majority count (visible
  /// chips in stacking, claimed boards in Ultimate). A draw with this reason
  /// means the count was exactly tied.
  tiebreak,

  /// Stack-Movable only: the same position occurred three times.
  repetition,
}

/// Terminal-or-not state of a game. Derivable from engine state, so it is
/// not serialised — engines recompute it on deserialisation.
@immutable
class GameStatus {
  const GameStatus.ongoing()
      : outcome = GameOutcome.ongoing,
        winner = null,
        reason = null,
        winningLine = null;

  const GameStatus.won(Player this.winner, this.reason, {this.winningLine})
      : outcome = GameOutcome.won;

  const GameStatus.draw(this.reason)
      : outcome = GameOutcome.draw,
        winner = null,
        winningLine = null;

  final GameOutcome outcome;
  final Player? winner;
  final EndReason? reason;

  /// Indexes of the winning line when [reason] is [EndReason.line]:
  /// cell indexes 0–8 for stacking, big-board indexes 0–8 for Ultimate.
  final List<int>? winningLine;

  bool get isOngoing => outcome == GameOutcome.ongoing;
  bool get isOver => !isOngoing;

  @override
  bool operator ==(Object other) =>
      other is GameStatus &&
      other.outcome == outcome &&
      other.winner == winner &&
      other.reason == reason &&
      _lineEquals(other.winningLine, winningLine);

  @override
  int get hashCode =>
      Object.hash(outcome, winner, reason, Object.hashAll(winningLine ?? []));

  static bool _lineEquals(List<int>? a, List<int>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'GameStatus($outcome, winner: $winner, reason: $reason, line: $winningLine)';
}
