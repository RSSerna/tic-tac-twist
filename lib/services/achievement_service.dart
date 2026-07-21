import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Product doc §3.1's example achievement set ("beat Impossible in each
/// mode, win with an L4 chip on the final move, claim all 9 boards in
/// Ultimate"). The full chest system (rarity, odds, caps) is Phase 9 —
/// this phase only tracks completion and uses it to unlock the one premium
/// skin (see `GameController._checkAchievements`).
///
/// [claimBoardMajority] is a deliberate departure from the doc's literal
/// "claim all 9 boards": the engine ends the game the moment any 3-in-a-row
/// of boards completes, and owning 8 of 9 boards always already contains a
/// complete line (removing any single cell from a 3×3 grid still leaves at
/// least one full row, column, or diagonal among the rest) — so "claimed
/// all 9, game still ongoing" can never actually occur. Six is the highest
/// threshold that's still reachable in a real game (see the achievement
/// tests for a constructed example) while staying a meaningfully dominant
/// win.
enum Achievement {
  beatImpossibleStatic,
  beatImpossibleMovable,
  beatImpossibleUltimate,
  winWithL4OnFinalMove,
  claimBoardMajority,
}

abstract interface class AchievementService {
  Future<Set<Achievement>> unlocked();

  /// Returns true iff [achievement] was newly unlocked (false if it was
  /// already completed).
  Future<bool> unlock(Achievement achievement);
}

final achievementServiceProvider =
    Provider<AchievementService>((ref) => SharedPreferencesAchievementService());

class SharedPreferencesAchievementService implements AchievementService {
  static const _key = 'nested_game.achievements.unlocked';

  @override
  Future<Set<Achievement>> unlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final names = (prefs.getStringList(_key) ?? const []).toSet();
    return Achievement.values.where((a) => names.contains(a.name)).toSet();
  }

  @override
  Future<bool> unlock(Achievement achievement) async {
    final prefs = await SharedPreferences.getInstance();
    final names = (prefs.getStringList(_key) ?? const []).toSet();
    if (names.contains(achievement.name)) return false;
    await prefs.setStringList(_key, [...names, achievement.name]);
    return true;
  }
}
