import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/age_gate_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_assets.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

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
    final styles = context.gameTextStyles;
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
                Container(
                  width: 180,
                  height: 180,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                    boxShadow: context.gameElevations.raised,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      AppImages.shumiLogo,
                      fit: BoxFit.cover,
                      // Degrades to an icon rather than a broken-image glyph
                      // if the art ever goes missing, same convention as
                      // `ChipView`'s asset skins.
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.cake_outlined,
                        size: 56,
                        color: colors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.ageGateQuestion,
                  textAlign: TextAlign.center,
                  style: styles.screenTitle,
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
                            .answerBirthYear(
                              _selectedYear!,
                              currentYear: currentYear,
                            ),
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
