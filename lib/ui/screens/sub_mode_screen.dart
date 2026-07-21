import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../engines/common/game_mode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import 'difficulty_screen.dart';
import 'game_screen.dart';

/// Opponent picker for one mode: local pass-and-play, or vs AI (which then
/// asks for a difficulty).
class SubModeScreen extends ConsumerWidget {
  const SubModeScreen({super.key, required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;

    final modeName = switch (mode) {
      GameMode.stackStatic => l10n.modeStackStatic,
      GameMode.stackMovable => l10n.modeStackMovable,
      GameMode.ultimate => l10n.modeUltimate,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(modeName),
        backgroundColor: colors.ground,
        foregroundColor: colors.ink,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _OptionCard(
              key: const Key('play-local'),
              title: l10n.playLocal,
              description: l10n.playLocalDesc,
              onTap: () {
                ref.read(gameControllerProvider.notifier).startGame(mode);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const GameScreen()),
                );
              },
            ),
            const SizedBox(height: 12),
            _OptionCard(
              key: const Key('play-vs-ai'),
              title: l10n.playVsAi,
              description: l10n.playVsAiDesc,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DifficultyScreen(mode: mode),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
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
    final textTheme = Theme.of(context).textTheme;

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
              Text(title, style: textTheme.titleLarge?.copyWith(color: colors.ink)),
              const SizedBox(height: 4),
              Text(description,
                  style: textTheme.bodyMedium?.copyWith(color: colors.neutral)),
            ],
          ),
        ),
      ),
    );
  }
}
