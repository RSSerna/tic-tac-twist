import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';

/// Placeholder home screen. Becomes mode select in Phase 2.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.appTitle,
              style: textTheme.displayMedium?.copyWith(color: colors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.homeTagline,
              style: textTheme.titleMedium?.copyWith(color: colors.neutral),
            ),
          ],
        ),
      ),
    );
  }
}
