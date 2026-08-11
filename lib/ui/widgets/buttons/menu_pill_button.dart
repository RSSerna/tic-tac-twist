import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

/// The large stadium-shaped `surface` button that makes up the home menu.
///
/// Sized by [height] rather than by its label so a row of them stays even
/// regardless of how long a translated mode name runs (Spanish runs longer —
/// design system §8).
class MenuPillButton extends StatelessWidget {
  const MenuPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 88,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final elevations = context.gameElevations;
    final radius = BorderRadius.circular(height / 2.6);

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: elevations.raised,
      ),
      child: Material(
        color: colors.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: styles.mainMenuButton,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
