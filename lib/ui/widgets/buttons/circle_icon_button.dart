import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';

/// A circular `surface` button with a drop shadow — the icon affordance used
/// around the edges of the home screen.
///
/// Deliberately not an [IconButton]: Material's version is transparent and
/// square-ish, and reproducing the filled-circle-with-shadow treatment at
/// every call site is how a design drifts.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.diameter = 48,
  });

  final IconData icon;

  /// Doubles as the accessibility label, so it must be a translated string —
  /// never a literal.
  final String tooltip;

  final VoidCallback? onPressed;

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final elevations = context.gameElevations;

    return Tooltip(
      message: tooltip,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: elevations.raised,
        ),
        // ClipOval inside the shadowed Container, not around it: clipping the
        // outside would clip the shadow away with it.
        child: ClipOval(
          child: Material(
            color: colors.surface,
            child: InkWell(
              onTap: onPressed,
              child: Center(
                child: Icon(icon, size: diameter * 0.5, color: colors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
