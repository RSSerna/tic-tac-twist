import 'package:meta/meta.dart';

import '../../ai/difficulty.dart';
import 'result_counts.dart';

/// One mode's full stats: pass-and-play by seat, plus vs-AI split by
/// difficulty tier (product doc §4 — "otherwise the numbers are
/// meaningless once someone farms Easy").
@immutable
class ModeStats {
  const ModeStats({required this.local, required this.vsAi});

  final LocalResultCounts local;
  final Map<Difficulty, ResultCounts> vsAi;

  static const empty = ModeStats(
    local: LocalResultCounts(),
    vsAi: {
      Difficulty.easy: ResultCounts(),
      Difficulty.medium: ResultCounts(),
      Difficulty.hard: ResultCounts(),
      Difficulty.impossible: ResultCounts(),
    },
  );

  Map<String, Object?> toJson() => {
        'local': local.toJson(),
        'vsAi': {for (final e in vsAi.entries) e.key.name: e.value.toJson()},
      };

  factory ModeStats.fromJson(Map<String, Object?> json) {
    final localJson = json['local'];
    final vsAiJson = json['vsAi'];
    return ModeStats(
      local: localJson is Map
          ? LocalResultCounts.fromJson(localJson.cast<String, Object?>())
          : const LocalResultCounts(),
      vsAi: {
        for (final difficulty in Difficulty.values)
          difficulty: (vsAiJson is Map && vsAiJson[difficulty.name] is Map)
              ? ResultCounts.fromJson(
                  (vsAiJson[difficulty.name] as Map).cast<String, Object?>())
              : const ResultCounts(),
      },
    );
  }
}
