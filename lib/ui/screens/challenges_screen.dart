import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/daily_challenge_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/achievement_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/app_glyph.dart';
import '../../theme/app_assets.dart';

/// Lists the achievements from `03-PRODUCT.md` §3.1 and whether each is done.
///
/// Read-only: unlocking happens in `GameController._checkAchievements` at the
/// end of a game, never here. Completing any one of these unlocks the premium
/// skin (Phase 8 decision), which is why this screen doesn't hand out rewards
/// of its own.
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  static String _label(
    AppLocalizations l10n,
    Achievement achievement,
  ) => switch (achievement) {
    Achievement.beatImpossibleStatic => l10n.challengeBeatImpossibleStatic,
    Achievement.beatImpossibleMovable => l10n.challengeBeatImpossibleMovable,
    Achievement.beatImpossibleUltimate => l10n.challengeBeatImpossibleUltimate,
    Achievement.winWithL4OnFinalMove => l10n.challengeWinWithL4OnFinalMove,
    Achievement.claimBoardMajority => l10n.challengeClaimBoardMajority,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(
        title: Text(l10n.challengesTitle),
        backgroundColor: colors.ground,
        foregroundColor: colors.ink,
      ),
      body: SafeArea(
        child: FutureBuilder<Set<Achievement>>(
          future: ref.read(achievementServiceProvider).unlocked(),
          builder: (context, snapshot) {
            // Nothing unlocked is the correct reading while loading: this is
            // a local key lookup that resolves in a frame or two, and a
            // spinner would flash more than it would inform.
            final unlocked = snapshot.data ?? const <Achievement>{};

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const _DailySection(),
                const SizedBox(height: 24),
                Text(
                  l10n.challengesProgress(
                    unlocked.length,
                    Achievement.values.length,
                  ),
                  style: styles.data,
                ),
                const SizedBox(height: 16),
                for (final achievement in Achievement.values) ...[
                  _ChallengeCard(
                    key: Key('challenge-${achievement.name}'),
                    label: _label(l10n, achievement),
                    completed: unlocked.contains(achievement),
                  ),
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

/// Today's challenges, which fill the Shop's claim meter.
///
/// Separate from the achievements below: achievements are permanent and
/// unlock the premium skin; these reset every day and feed the reward.
class _DailySection extends ConsumerWidget {
  const _DailySection();

  static String _label(AppLocalizations l10n, DailyChallenge challenge) =>
      switch (challenge) {
        DailyChallenge.playTwoGames => l10n.dailyPlayTwoGames,
        DailyChallenge.winOneGame => l10n.dailyWinOneGame,
        DailyChallenge.playEachMode => l10n.dailyPlayEachMode,
        DailyChallenge.beatToughAi => l10n.dailyBeatToughAi,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final progress =
        ref.watch(dailyChallengeControllerProvider).value ??
        DailyProgress.empty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.dailyChallengesHeading, style: styles.screenTitle),
        const SizedBox(height: 4),
        Text(
          l10n.dailyChallengesProgress(
            progress.completedCount,
            DailyChallenge.values.length,
          ),
          style: styles.data,
        ),
        if (progress.claimed)
          Text(l10n.dailyChallengeClaimed, style: styles.labelMuted)
        else if (progress.isFull)
          Text(l10n.dailyChallengeReady, style: styles.label),
        const SizedBox(height: 12),
        for (final challenge in DailyChallenge.values) ...[
          _DailyRow(
            key: Key('daily-${challenge.name}'),
            label: _label(l10n, challenge),
            count: progress.countFor(challenge),
            target: challenge.target,
            done: progress.isComplete(challenge),
          ),
          const SizedBox(height: 8),
        ],
        Divider(color: colors.neutral.withValues(alpha: 0.3), height: 24),
      ],
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({
    super.key,
    required this.label,
    required this.count,
    required this.target,
    required this.done,
  });

  final String label;
  final int count;
  final int target;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final elevations = context.gameElevations;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: elevations.resting,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // There's no drawn "not yet" glyph, so an unfinished goal is the
          // same check dimmed — the app's unavailable idiom (design system
          // §11). The counter beside it says the state exactly anyway.
          Opacity(
            opacity: done ? 1 : 0.45,
            child: AppGlyph(
              AppIcons.check,
              color: done ? colors.ink : colors.neutral,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: done ? styles.cardTitle : styles.body),
          ),
          const SizedBox(width: 8),
          // Tabular figures so the counter doesn't jitter as it ticks
          // (design system 2.2).
          Text('$count/$target', style: styles.data),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    super.key,
    required this.label,
    required this.completed,
  });

  final String label;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            AppGlyph(
              completed ? AppIcons.check : AppIcons.locked,
              // `ink`, not `playerA`: indigo means "Player 1" everywhere else
              // in the app, and a completed achievement has nothing to do
              // with a player (design system §2.1).
              color: completed ? colors.ink : colors.neutral,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: completed ? styles.cardTitle : styles.bodyMuted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    completed ? l10n.challengeCompleted : l10n.challengeLocked,
                    style: styles.labelMuted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
