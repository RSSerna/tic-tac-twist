import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../../../theme/typography.dart';

/// A [DropdownButton] wearing the same stadium-shaped `surface` skin as
/// [PillActionButton] — the picker used for one-of-many settings.
///
/// Replaces a column of radio tiles: five turn-timer presets as tiles is a
/// screenful, and as a pill it's one line.
class PillDropdown<T> extends StatelessWidget {
  const PillDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final elevations = context.gameElevations;
    final radius = BorderRadius.circular(24);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      // Capped and expanded rather than sized to its widest option: an
      // untruncated option (Spanish's turn-timer presets) would otherwise
      // set the pill's width and push the row's label off the screen.
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        boxShadow: elevations.resting,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          borderRadius: radius,
          dropdownColor: colors.surface,
          icon: Icon(Icons.keyboard_arrow_down, color: colors.ink),
          style: styles.label,
          // The menu inherits the pill's own text colour rather than
          // Material's default, so a skin change carries into it.
          selectedItemBuilder: (context) => [
            for (final item in items)
              Align(
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle(style: styles.label, child: item.child),
              ),
          ],
        ),
      ),
    );
  }
}
