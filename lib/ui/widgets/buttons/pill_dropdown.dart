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
    this.hint,
    this.centerLabel = false,
    this.style,
    this.maxWidth = 260,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  /// Shown in place of a selection while [value] is null — for a picker that
  /// starts genuinely unset, rather than defaulting to its first option.
  final Widget? hint;

  /// Centres the selection in the pill rather than aligning it left.
  ///
  /// Off by default: in a settings row the pill sits at the end of a
  /// label-left/control-right line, and a centred value there reads as
  /// drifting. On a picker that stands alone, centred is right.
  final bool centerLabel;

  /// Overrides the label size. Defaults to the standard label style; a
  /// picker that *is* the screen's main control wants something larger.
  final TextStyle? style;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final elevations = context.gameElevations;
    final radius = BorderRadius.circular(24);
    final labelStyle = style ?? styles.label;

    // The chevron sits at the trailing edge and eats width the label can't
    // use, so centring within what's left would sit the text off-centre in
    // the pill. Padding the leading edge by the same amount puts it back.
    final iconSize = (labelStyle.fontSize ?? 14) + 10;

    Widget align(Widget child) => Padding(
      padding: EdgeInsets.only(left: centerLabel ? iconSize : 0),
      child: Align(
        alignment: centerLabel ? Alignment.center : Alignment.centerLeft,
        child: DefaultTextStyle(style: labelStyle, child: child),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      // Capped and expanded rather than sized to its widest option: an
      // untruncated option (Spanish's turn-timer presets) would otherwise
      // set the pill's width and push the row's label off the screen.
      constraints: BoxConstraints(maxWidth: maxWidth),
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
          hint: hint == null ? null : align(hint!),
          isExpanded: true,
          borderRadius: radius,
          dropdownColor: colors.surface,
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: iconSize,
            color: colors.ink,
          ),
          style: labelStyle,
          // The menu inherits the pill's own text colour rather than
          // Material's default, so a skin change carries into it.
          selectedItemBuilder: (context) => [
            for (final item in items) align(item.child),
          ],
        ),
      ),
    );
  }
}
