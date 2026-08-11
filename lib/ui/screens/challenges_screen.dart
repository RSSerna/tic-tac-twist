import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/achievement_service.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

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
            Icon(
              completed ? Icons.check_circle : Icons.lock_outline,
              color: completed ? colors.playerA : colors.neutral,
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
