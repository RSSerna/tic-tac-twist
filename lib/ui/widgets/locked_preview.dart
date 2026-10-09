import 'package:flutter/material.dart';

import '../../theme/app_assets.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'app_glyph.dart';

/// Which corner badge a [LockedPreview] wears.
enum PreviewBadge { locked, owned }

/// A cosmetic's real art with a small badge in the corner, instead of a lock
/// standing in for it.
///
/// Players need to see what they'd earn or buy; the badge — not hiding the art
/// — is what says "not yours yet". [child] is any widget, so chips, emotes,
/// celebrations and (later) board skins all go through the same wrapper.
///
/// [locked] false with [ownedBadge] false renders [child] untouched.
class LockedPreview extends StatelessWidget {
  const LockedPreview({
    super.key,
    required this.child,
    required this.locked,
    this.ownedBadge = false,
    this.badgeSize = 28,
  });

  final Widget child;
  final bool locked;

  /// Shows a check badge when not [locked] — for a shop card the player owns.
  final bool ownedBadge;

  /// Diameter of the badge circle.
  final double badgeSize;

  /// Pale enough that the art still reads, dim enough to say "not yours".
  static const double lockedOpacity = 0.7;

  @override
  Widget build(BuildContext context) {
    final badge = locked
        ? PreviewBadge.locked
        : ownedBadge
        ? PreviewBadge.owned
        : null;
    if (badge == null) return child;

    final colors = context.gameColors;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Opacity(opacity: locked ? lockedOpacity : 1, child: child),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            key: Key(
              badge == PreviewBadge.locked
                  ? 'preview-badge-locked'
                  : 'preview-badge-owned',
            ),
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              color: colors.ink,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AppGlyph(
              badge == PreviewBadge.locked ? AppIcons.locked : AppIcons.check,
              size: badgeSize * 0.6,
              color: colors.surface,
            ),
          ),
        ),
      ],
    );
  }
}

/// A large look at a cosmetic the player can't equip yet: the art, its name and
/// where it stands. Nothing here equips or buys anything.
Future<void> showCosmeticPreview(
  BuildContext context, {
  required Widget art,
  required String title,
  required String status,
  bool locked = true,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final colors = context.gameColors;
      final styles = context.gameTextStyles;
      return Dialog(
        key: const Key('cosmetic-preview'),
        backgroundColor: colors.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: LockedPreview(locked: locked, badgeSize: 44, child: art),
              ),
              const SizedBox(height: 16),
              Text(title, style: styles.cardTitle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(status, style: styles.labelMuted, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    },
  );
}
