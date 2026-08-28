import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/age_gate_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/app_assets.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/buttons/pill_action_button.dart';
import '../widgets/buttons/pill_dropdown.dart';

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // A phone in landscape has ~390pt of height, which the full-size
            // mark plus the question, picker and button overrun. Shrinking
            // the mark recovers most of it; the scroll view catches whatever
            // a long translation still spills.
            //
            // The threshold is deliberately generous: the question renders at
            // `screenTitle`, which wraps to two lines on a narrow screen, so
            // the full-size layout needs ~600pt before everything is above
            // the fold. Below that the picker ends up needing a scroll to
            // reach, which on a gate the player must answer is worth avoiding.
            final compact = constraints.maxHeight < 700;
            final markSize = compact ? 96.0 : 180.0;
            final gap = compact ? 16.0 : 24.0;

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: markSize,
                          height: markSize,
                          padding: EdgeInsets.all(compact ? 10 : 16),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            shape: BoxShape.circle,
                            boxShadow: context.gameElevations.raised,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              AppImages.shumiLogo,
                              fit: BoxFit.cover,
                              // Degrades to an icon rather than a broken-image
                              // glyph if the art ever goes missing, same
                              // convention as `ChipView`'s asset skins.
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    Icons.cake_outlined,
                                    size: markSize * 0.31,
                                    color: colors.ink,
                                  ),
                            ),
                          ),
                        ),
                        SizedBox(height: gap),
                        Text(
                          l10n.ageGateQuestion,
                          textAlign: TextAlign.center,
                          // `screenTitle` is 48pt and wraps to two or three
                          // lines on a narrow screen, which is what pushed
                          // the picker below the fold — step down when
                          // height is the scarce thing.
                          style: compact ? styles.banner : styles.screenTitle,
                        ),
                        SizedBox(height: gap),
                        PillDropdown<int>(
                          key: const Key('age-gate-year'),
                          value: _selectedYear,
                          // This picker is the screen's whole question, not a
                          // control tucked at the end of a settings row — so
                          // it gets centred and sized up. `banner` rather
                          // than `screenTitle`: at 48pt the latter no longer
                          // fits a pill.
                          centerLabel: true,
                          style: styles.banner,
                          // No default year: the picker starts unset so
                          // nothing here nudges toward an answer (product
                          // doc §1.1).
                          hint: Text(l10n.ageGateChooseYear),
                          items: [
                            for (final year in years)
                              DropdownMenuItem(
                                value: year,
                                child: Text('$year'),
                              ),
                          ],
                          onChanged: (year) =>
                              setState(() => _selectedYear = year),
                        ),
                        SizedBox(height: gap),
                        PillActionButton(
                          key: const Key('age-gate-continue'),
                          label: l10n.ageGateContinue,
                          onPressed: _selectedYear == null
                              ? null
                              : () => ref
                                    .read(ageGateControllerProvider.notifier)
                                    .answerBirthYear(
                                      _selectedYear!,
                                      currentYear: currentYear,
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
