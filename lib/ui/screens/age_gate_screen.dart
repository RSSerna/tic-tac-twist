import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/age_gate_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';

/// The neutral age screen (product doc §1.1): shown once, before anything
/// else, gates ad initialisation. "Neutral" means a plain question with no
/// framing that nudges toward an older answer — a single year picker and
/// one "Continue" button, no shortcut or default that favours "adult".
class AgeGateScreen extends ConsumerStatefulWidget {
  const AgeGateScreen({super.key});

  @override
  ConsumerState<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends ConsumerState<AgeGateScreen> {
  int? _selectedYear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final textTheme = Theme.of(context).textTheme;
    final currentYear = DateTime.now().year;
    final years = [for (var y = currentYear; y >= currentYear - 100; y--) y];

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.ageGateQuestion,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(color: colors.ink),
                ),
                const SizedBox(height: 24),
                DropdownButton<int>(
                  key: const Key('age-gate-year'),
                  value: _selectedYear,
                  hint: Text(l10n.ageGateChooseYear),
                  items: [
                    for (final year in years)
                      DropdownMenuItem(value: year, child: Text('$year')),
                  ],
                  onChanged: (year) => setState(() => _selectedYear = year),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('age-gate-continue'),
                  onPressed: _selectedYear == null
                      ? null
                      : () => ref
                          .read(ageGateControllerProvider.notifier)
                          .answerBirthYear(_selectedYear!, currentYear: currentYear),
                  child: Text(l10n.ageGateContinue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
