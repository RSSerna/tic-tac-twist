import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';
import '../locked_preview.dart';

/// A square `surface` tile with a caption above its glyph — one entry in the
/// Custom screen's category row.
///
/// An [available] tile of `false` renders dimmed with a lock and refuses
/// taps: the category exists in the design but has nothing behind it yet, and
/// a tile that opens an empty screen is worse than one that says so.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.available = true,
    this.size = 150,
  });

  final String label;

  /// The tile's glyph. A widget, not an `IconData`, so painted art works too.
  final Widget icon;

  final VoidCallback onPressed;
  final bool available;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final elevations = context.gameElevations;
    final radius = BorderRadius.circular(20);

    return Semantics(
      button: true,
      enabled: available,
      label: available ? label : '$label, ${l10n.categoryComingSoon}',
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: elevations.raised,
          ),
          child: Material(
            color: colors.surface,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: available ? onPressed : null,
              child: Opacity(
                opacity: available ? 1 : 0.45,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        // Uppercased here rather than in the ARB so the
                        // translation stays a normal sentence-case string —
                        // design system §2.2 allows caps only on labels this
                        // small.
                        label.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: styles.caption.copyWith(
                          color: colors.ink,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          // An unavailable category keeps its own icon, badged
                          // as locked, so it reads "coming" rather than "empty".
                          child: LockedPreview(
                            locked: !available,
                            badgeSize: 32,
                            child: icon,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
