import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/game_mode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import 'game_screen.dart';

/// Opponent picker for one mode. Local pass-and-play only in v1 Phase 2;
/// the AI entry arrives with Phase 3.
class SubModeScreen extends ConsumerWidget {
  const SubModeScreen({super.key, required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final textTheme = Theme.of(context).textTheme;

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
            Material(
              color: colors.surface,
              borderRadius: BorderRadius.circular(4),
              child: InkWell(
                key: const Key('play-local'),
                borderRadius: BorderRadius.circular(4),
                onTap: () {
                  ref.read(gameControllerProvider.notifier).startGame(mode);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const GameScreen()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.playLocal,
                          style: textTheme.titleLarge
                              ?.copyWith(color: colors.ink)),
                      const SizedBox(height: 4),
                      Text(l10n.playLocalDesc,
                          style: textTheme.bodyMedium
                              ?.copyWith(color: colors.neutral)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
