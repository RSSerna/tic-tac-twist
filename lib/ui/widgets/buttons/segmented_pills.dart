import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

/// One choice in a [SegmentedPills] row.
@immutable
class PillSegment {
  const PillSegment({
    required this.label,
    required this.value,
    this.available = true,
    this.key,
  });

  final String label;
  final String value;

  /// A segment that exists in the design but has nothing behind it yet
  /// renders dimmed and refuses taps.
  final bool available;

  final Key? key;
}

/// A row of stadium pills where one is selected — the Skins screen's
/// Local/Online switch.
///
/// Not Material's `SegmentedButton`: that draws a single joined outline with
/// its own fill and check marks, none of which match the loose separate
/// pills the design uses.
class SegmentedPills extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<PillSegment> segments;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final elevations = context.gameElevations;

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final segment in segments)
          Semantics(
            button: true,
            selected: segment.value == selected,
            enabled: segment.available,
            label: segment.available
                ? segment.label
                : '${segment.label}, ${l10n.categoryComingSoon}',
            child: ExcludeSemantics(
              child: Opacity(
                opacity: segment.available ? 1 : 0.45,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: elevations.resting,
                  ),
                  child: Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      key: segment.key,
                      borderRadius: BorderRadius.circular(24),
                      onTap: segment.available
                          ? () => onChanged(segment.value)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Text(
                          segment.label.toUpperCase(),
                          style: styles.label.copyWith(
                            letterSpacing: 1.5,
                            // Weight, not colour, marks the active pill:
                            // a colour swap would need a token that means
                            // "active", and the palette has no such thing.
                            fontWeight: segment.value == selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: segment.value == selected
                                ? colors.ink
                                : colors.neutral,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
