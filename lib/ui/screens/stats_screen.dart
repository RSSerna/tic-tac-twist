import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/difficulty.dart';
import '../../engines/common/game_mode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/stats/mode_stats.dart';
import '../../services/stats/stats_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

String _modeName(AppLocalizations l10n, GameMode mode) => switch (mode) {
  GameMode.stackStatic => l10n.modeStackStatic,
  GameMode.stackMovable => l10n.modeStackMovable,
  GameMode.ultimate => l10n.modeUltimate,
};

String _difficultyName(AppLocalizations l10n, Difficulty difficulty) =>
    switch (difficulty) {
      Difficulty.easy => l10n.difficultyEasy,
      Difficulty.medium => l10n.difficultyMedium,
      Difficulty.hard => l10n.difficultyHard,
      Difficulty.impossible => l10n.difficultyImpossible,
    };

/// Per-mode W/L/D (design doc §10; product doc §4). Local is tracked by
/// seat (Player 1 / Player 2), not a "you" perspective that doesn't exist
/// for a shared device; vs-AI is tracked from the human's perspective,
/// split by difficulty so Easy farming doesn't drown out real results.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statsTitle),
        backgroundColor: colors.ground,
        foregroundColor: colors.ink,
      ),
      body: SafeArea(
        child: FutureBuilder<List<ModeStats>>(
          future: Future.wait(
            GameMode.values.map(
              (mode) => ref.read(statsServiceProvider).statsFor(mode),
            ),
          ),
          builder: (context, snapshot) {
            final stats = snapshot.data;
            if (stats == null) return const SizedBox.shrink();
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                for (var i = 0; i < GameMode.values.length; i++) ...[
                  _ModeStatsCard(mode: GameMode.values[i], stats: stats[i]),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ModeStatsCard extends StatelessWidget {
  const _ModeStatsCard({required this.mode, required this.stats});

  final GameMode mode;
  final ModeStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final hasAnyGames =
        stats.local.total > 0 || stats.vsAi.values.any((c) => c.total > 0);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_modeName(l10n, mode), style: styles.screenTitle),
            const SizedBox(height: 12),
            if (!hasAnyGames)
              Text(l10n.statsNoGamesYet, style: styles.bodyMuted)
            else ...[
              if (stats.local.total > 0) ...[
                Text(l10n.statsLocalHeading, style: styles.labelMuted),
                const SizedBox(height: 4),
                Text(
                  '${l10n.statsPlayerWins(1, stats.local.p1Wins)}   '
                  '${l10n.statsPlayerWins(2, stats.local.p2Wins)}   '
                  '${l10n.statsDrawsCount(stats.local.draws)}',
                  style: styles.data,
                ),
                const SizedBox(height: 12),
              ],
              if (stats.vsAi.values.any((c) => c.total > 0)) ...[
                Text(l10n.statsVsAiHeading, style: styles.labelMuted),
                const SizedBox(height: 4),
                for (final difficulty in Difficulty.values)
                  if (stats.vsAi[difficulty]!.total > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${_difficultyName(l10n, difficulty)} — '
                        '${l10n.statsRecord(stats.vsAi[difficulty]!.wins, stats.vsAi[difficulty]!.losses, stats.vsAi[difficulty]!.draws)}',
                        style: styles.data,
                      ),
                    ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
