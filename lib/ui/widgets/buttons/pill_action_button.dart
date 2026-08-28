import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

/// A small stadium-shaped action button — the compact sibling of
/// `MenuPillButton`, for controls that sit at the end of a settings row.
class PillActionButton extends StatelessWidget {
  const PillActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final elevations = context.gameElevations;
    final radius = BorderRadius.circular(24);
    final enabled = onPressed != null;

    return Opacity(
      // A null `onPressed` already stops the tap, but without this the pill
      // still looks pressable — the same 0.45 the locked category tiles and
      // source pills use.
      opacity: enabled ? 1 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: elevations.resting,
        ),
        child: Material(
          color: colors.surface,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(label, style: styles.label),
            ),
          ),
        ),
      ),
    );
  }
}
