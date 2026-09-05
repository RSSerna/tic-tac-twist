import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engines/common/game_mode.dart';

/// A day's worth of small goals. Completing them fills the shop's claim
/// meter (product doc §3.3's chest progress, built here as something a
/// player can actually finish in one sitting).
///
/// Deliberately modest and non-coercive: the product doc's audience is mixed
/// and possibly child-directed, so these reward playing normally rather than
/// grinding — no streaks to lose, no timers, no "come back in 4 hours".
enum DailyChallenge {
  /// Just show up and play.
  playTwoGames(target: 2),

  /// Win one, any mode, any opponent.
  winOneGame(target: 1),

  /// Play all three modes in a day — the one that nudges toward breadth,
  /// since the app's whole pitch is three variants.
  playEachMode(target: 3),

  /// Beat the AI at Hard or above.
  beatToughAi(target: 1);

  const DailyChallenge({required this.target});

  /// How many increments complete it.
  final int target;
}

/// Today's progress, as counts per challenge.
class DailyProgress {
  const DailyProgress({required this.counts, required this.claimed});

  final Map<DailyChallenge, int> counts;

  /// Whether the reward for a full meter has already been taken today.
  final bool claimed;

  static const empty = DailyProgress(counts: {}, claimed: false);

  int countFor(DailyChallenge challenge) => counts[challenge] ?? 0;

  bool isComplete(DailyChallenge challenge) =>
      countFor(challenge) >= challenge.target;

  int get completedCount =>
      DailyChallenge.values.where(isComplete).length;

  /// 0…1 across the whole day's set — what the shop's meter draws.
  double get fraction => completedCount / DailyChallenge.values.length;

  bool get isFull => completedCount == DailyChallenge.values.length;

  /// Claimable exactly once per day, and only once the set is finished.
  bool get canClaim => isFull && !claimed;
}

abstract interface class DailyChallengeService {
  /// Progress for [today], or a fresh empty day if the stored progress is
  /// from a previous one.
  Future<DailyProgress> progress(DateTime today);

  /// Adds [amount] to [challenge], capped at its target. Rolls the day over
  /// first if the stored progress is stale.
  Future<void> record(
    DailyChallenge challenge,
    DateTime today, {
    int amount = 1,
  });

  /// Records that a game in [mode] was played — the modes seen today are
  /// tracked as a set, since `playEachMode` counts distinct modes.
  Future<void> recordModePlayed(GameMode mode, DateTime today);

  /// Marks today's reward taken. Returns false if it already was, or if the
  /// set isn't finished — the caller must not grant anything on false.
  Future<bool> claim(DateTime today);
}

final dailyChallengeServiceProvider = Provider<DailyChallengeService>(
  (ref) => SharedPreferencesDailyChallengeService(),
);

class SharedPreferencesDailyChallengeService
    implements DailyChallengeService {
  static const _key = 'nested_game.daily.progress';

  /// The stored day, as `yyyy-mm-dd` in *local* time.
  ///
  /// Local, not UTC: "today" has to mean the player's today, or the set
  /// would reset mid-evening for some of them.
  static String dayKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  Future<Map<String, dynamic>> _readRaw(DateTime today) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == null) return {'day': dayKey(today)};
    final decoded = jsonDecode(stored) as Map<String, dynamic>;
    // A stale day is simply a new day: nothing carries over, so there's no
    // streak to break and no way to "lose" progress by not playing.
    if (decoded['day'] != dayKey(today)) return {'day': dayKey(today)};
    return decoded;
  }

  Future<void> _write(Map<String, dynamic> raw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(raw));
  }

  @override
  Future<DailyProgress> progress(DateTime today) async {
    final raw = await _readRaw(today);
    final counts = <DailyChallenge, int>{};
    for (final challenge in DailyChallenge.values) {
      final value = raw[challenge.name];
      if (value is int) counts[challenge] = value;
    }
    return DailyProgress(
      counts: counts,
      claimed: raw['claimed'] == true,
    );
  }

  @override
  Future<void> record(
    DailyChallenge challenge,
    DateTime today, {
    int amount = 1,
  }) async {
    final raw = await _readRaw(today);
    final current = raw[challenge.name] is int ? raw[challenge.name] as int : 0;
    raw[challenge.name] = (current + amount).clamp(0, challenge.target);
    await _write(raw);
  }

  @override
  Future<void> recordModePlayed(GameMode mode, DateTime today) async {
    final raw = await _readRaw(today);
    final seen = (raw['modes'] as List?)?.cast<String>().toSet() ?? <String>{};
    seen.add(mode.name);
    raw['modes'] = seen.toList();
    // Derived rather than incremented: replaying one mode all day must not
    // count three times.
    raw[DailyChallenge.playEachMode.name] = seen.length.clamp(
      0,
      DailyChallenge.playEachMode.target,
    );
    await _write(raw);
  }

  @override
  Future<bool> claim(DateTime today) async {
    final raw = await _readRaw(today);
    final progress = await this.progress(today);
    if (!progress.canClaim) return false;
    raw['claimed'] = true;
    await _write(raw);
    return true;
  }
}
