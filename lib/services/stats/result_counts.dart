import 'package:meta/meta.dart';

/// Win/loss/draw counts from a single, well-defined perspective (vs-AI:
/// the human; see [LocalResultCounts] for pass-and-play, which has no
/// single perspective across games).
@immutable
class ResultCounts {
  const ResultCounts({this.wins = 0, this.losses = 0, this.draws = 0});

  final int wins;
  final int losses;
  final int draws;

  int get total => wins + losses + draws;

  ResultCounts withWin() => ResultCounts(wins: wins + 1, losses: losses, draws: draws);
  ResultCounts withLoss() => ResultCounts(wins: wins, losses: losses + 1, draws: draws);
  ResultCounts withDraw() => ResultCounts(wins: wins, losses: losses, draws: draws + 1);

  Map<String, Object?> toJson() => {'w': wins, 'l': losses, 'd': draws};

  factory ResultCounts.fromJson(Map<String, Object?> json) => ResultCounts(
        wins: json['w'] as int? ?? 0,
        losses: json['l'] as int? ?? 0,
        draws: json['d'] as int? ?? 0,
      );
}

/// Pass-and-play has no persistent per-seat identity across games (design
/// decision, Phase 6, 2026-07-20) — tracked by seat (Player 1 / Player 2),
/// not by a "you" perspective that doesn't exist for a shared device.
@immutable
class LocalResultCounts {
  const LocalResultCounts({this.p1Wins = 0, this.p2Wins = 0, this.draws = 0});

  final int p1Wins;
  final int p2Wins;
  final int draws;

  int get total => p1Wins + p2Wins + draws;

  LocalResultCounts withP1Win() =>
      LocalResultCounts(p1Wins: p1Wins + 1, p2Wins: p2Wins, draws: draws);
  LocalResultCounts withP2Win() =>
      LocalResultCounts(p1Wins: p1Wins, p2Wins: p2Wins + 1, draws: draws);
  LocalResultCounts withDraw() =>
      LocalResultCounts(p1Wins: p1Wins, p2Wins: p2Wins, draws: draws + 1);

  Map<String, Object?> toJson() => {'p1': p1Wins, 'p2': p2Wins, 'd': draws};

  factory LocalResultCounts.fromJson(Map<String, Object?> json) => LocalResultCounts(
        p1Wins: json['p1'] as int? ?? 0,
        p2Wins: json['p2'] as int? ?? 0,
        draws: json['d'] as int? ?? 0,
      );
}
