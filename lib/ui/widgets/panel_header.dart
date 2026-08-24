import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// The header on full-screen panels: a circular badge, a title with a
/// subtitle under it, and a close button.
///
/// Panels use this instead of an `AppBar` — they're dismissed with the X
/// rather than a back arrow, and the badge/title block is taller and heavier
/// than any `AppBar` treatment.
class PanelHeader extends StatelessWidget {
  const PanelHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.closeKey,
    this.trailing,
  });

  /// Optional controls sitting between the title block and the close button —
  /// the Skins screen's source tabs, for instance.
  final Widget? trailing;

  /// Drawn inside the badge. A widget rather than an `IconData` so a panel
  /// can use painted art (`AppMark`) where an icon won't do.
  final Widget icon;

  final String title;
  final String subtitle;

  /// Key for the close button, so tests can dismiss the panel.
  final Key? closeKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final elevations = context.gameElevations;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              boxShadow: elevations.raised,
            ),
            child: Center(child: icon),
          ),
          const SizedBox(width: 16),
          // One Expanded holding the title and any trailing controls, rather
          // than making each of them flexible in the outer Row. It absorbs
          // all the slack, which is what keeps the close button pinned to the
          // right edge no matter how short the title is. Inside it, both
          // parts are Flexible so they squeeze instead of overflowing — a
          // translated subtitle beside a set of pills doesn't fit a phone
          // width at full size.
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: styles.display),
                      Text(subtitle, style: styles.subtitle),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 16),
                  Flexible(child: trailing!),
                ],
              ],
            ),
          ),
          IconButton(
            key: closeKey,
            icon: const Icon(Icons.close),
            iconSize: 40,
            color: colors.neutral,
            tooltip: l10n.close,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
