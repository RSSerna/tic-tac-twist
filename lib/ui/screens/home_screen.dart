import 'package:flutter/material.dart';

import '../../engines/common/game_mode.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import 'sub_mode_screen.dart';

/// Home / mode select: the three v1 modes.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              l10n.appTitle,
              textAlign: TextAlign.center,
              style: textTheme.displayMedium?.copyWith(color: colors.ink),
            ),
            Text(
              l10n.homeTagline,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(color: colors.neutral),
            ),
            const SizedBox(height: 32),
            for (final mode in GameMode.values) ...[
              _ModeCard(mode: mode),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.mode});

  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final textTheme = Theme.of(context).textTheme;

    final (name, description) = switch (mode) {
      GameMode.stackStatic => (l10n.modeStackStatic, l10n.modeStackStaticDesc),
      GameMode.stackMovable =>
        (l10n.modeStackMovable, l10n.modeStackMovableDesc),
      GameMode.ultimate => (l10n.modeUltimate, l10n.modeUltimateDesc),
    };

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        key: Key('mode-${mode.name}'),
        borderRadius: BorderRadius.circular(4),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => SubModeScreen(mode: mode)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: textTheme.titleLarge?.copyWith(color: colors.ink)),
              const SizedBox(height: 4),
              Text(description,
                  style:
                      textTheme.bodyMedium?.copyWith(color: colors.neutral)),
            ],
          ),
        ),
      ),
    );
  }
}
