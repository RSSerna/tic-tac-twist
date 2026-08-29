import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/difficulty.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/session_opponents.dart';
import '../../engines/common/game_mode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'game_screen.dart';

/// Difficulty picker for a vs-AI game, shown after choosing "Vs AI" for a
/// mode (rules doc §6: four tiers — Easy/Medium/Hard/Impossible).
class DifficultyScreen extends ConsumerWidget {
  const DifficultyScreen({super.key, required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;

    final tiers = [
      (Difficulty.easy, l10n.difficultyEasy, l10n.difficultyEasyDesc),
      (Difficulty.medium, l10n.difficultyMedium, l10n.difficultyMediumDesc),
      (Difficulty.hard, l10n.difficultyHard, l10n.difficultyHardDesc),
      (
        Difficulty.impossible,
        l10n.difficultyImpossible,
        l10n.difficultyImpossibleDesc,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chooseDifficulty),
        backgroundColor: colors.ground,
        foregroundColor: colors.ink,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            for (final (difficulty, title, description) in tiers) ...[
              _DifficultyCard(
                key: Key('difficulty-${difficulty.name}'),
                title: title,
                description: description,
                onTap: () {
                  ref
                      .read(gameControllerProvider.notifier)
                      .startGame(
                        mode,
                        opponents: SessionOpponents.vsAi(difficulty),
                      );
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const GameScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({
    super.key,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final styles = context.gameTextStyles;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: styles.screenTitle),
              const SizedBox(height: 4),
              Text(description, style: styles.bodyMuted),
            ],
          ),
        ),
      ),
    );
  }
}
