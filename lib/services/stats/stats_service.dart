import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai/difficulty.dart';
import '../../engines/common/game_mode.dart';
import 'mode_stats.dart';
import 'result_counts.dart';

/// Which side of a vs-AI result the human ended up on.
enum MatchResult { win, loss, draw }

/// Local, on-device per-mode W/L/D (product doc §4). No accounts, no sync.
abstract interface class StatsService {
  Future<ModeStats> statsFor(GameMode mode);

  /// [winnerPerson] is 1 or 2; null means a draw.
  Future<void> recordLocalResult(GameMode mode, {required int? winnerPerson});

  Future<void> recordVsAiResult(
    GameMode mode,
    Difficulty difficulty,
    MatchResult result,
  );

  Future<void> resetAll();
}

final statsServiceProvider =
    Provider<StatsService>((ref) => SharedPreferencesStatsService());

class SharedPreferencesStatsService implements StatsService {
  static const _key = 'nested_game.stats.v1';

  Future<Map<GameMode, ModeStats>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      return {for (final mode in GameMode.values) mode: ModeStats.empty};
    }
    final decoded = (jsonDecode(raw) as Map).cast<String, Object?>();
    return {
      for (final mode in GameMode.values)
        mode: decoded[mode.name] is Map
            ? ModeStats.fromJson((decoded[mode.name] as Map).cast<String, Object?>())
            : ModeStats.empty,
    };
  }

  Future<void> _saveAll(Map<GameMode, ModeStats> all) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = {for (final e in all.entries) e.key.name: e.value.toJson()};
    await prefs.setString(_key, jsonEncode(encoded));
  }

  @override
  Future<ModeStats> statsFor(GameMode mode) async => (await _loadAll())[mode]!;

  @override
  Future<void> recordLocalResult(GameMode mode, {required int? winnerPerson}) async {
    final all = await _loadAll();
    final current = all[mode]!;
    final updatedLocal = switch (winnerPerson) {
      1 => current.local.withP1Win(),
      2 => current.local.withP2Win(),
      _ => current.local.withDraw(),
    };
    all[mode] = ModeStats(local: updatedLocal, vsAi: current.vsAi);
    await _saveAll(all);
  }

  @override
  Future<void> recordVsAiResult(
    GameMode mode,
    Difficulty difficulty,
    MatchResult result,
  ) async {
    final all = await _loadAll();
    final current = all[mode]!;
    final currentCounts = current.vsAi[difficulty] ?? const ResultCounts();
    final updatedCounts = switch (result) {
      MatchResult.win => currentCounts.withWin(),
      MatchResult.loss => currentCounts.withLoss(),
      MatchResult.draw => currentCounts.withDraw(),
    };
    all[mode] = ModeStats(
      local: current.local,
      vsAi: {...current.vsAi, difficulty: updatedCounts},
    );
    await _saveAll(all);
  }

  @override
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
