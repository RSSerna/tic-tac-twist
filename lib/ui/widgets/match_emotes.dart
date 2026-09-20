import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/emote_controller.dart';
import '../../controllers/game_controller.dart';
import '../../controllers/match_emote_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/emote.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../screens/emote_skins_screen.dart' show emoteName;
import 'emote_view.dart';
import '../../theme/app_assets.dart';
import 'app_glyph.dart';
import '../root_size.dart';

/// One bubble per seat, above the board: where an emote from that player
/// appears.
///
/// **Both bubbles are always drawn, empty or not.** The empty one is the
/// point — it's the reserved place a received emote will land once there's a
/// network to receive one (`05-V2-DEFERRED.md` §4.2). In pass-and-play the
/// other player is sitting right there, so this already works end to end;
/// vs the AI, that seat simply never fills.
class MatchEmoteBubbles extends ConsumerWidget {
  const MatchEmoteBubbles({super.key, this.compact = false});

  /// Shrinks the bubbles for screens too short to spare the full height.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(matchEmoteControllerProvider);
    final colors = context.gameColors;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 2 : 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final person in [1, 2]) ...[
            if (person == 2) SizedBox(width: compact ? 12 : 24),
            _SeatBubble(
              key: Key('emote-bubble-$person'),
              person: person,
              emote: shown.forPerson(person),
              color: person == 1 ? colors.playerA : colors.playerB,
              compact: compact,
            ),
          ],
        ],
      ),
    );
  }
}

class _SeatBubble extends StatelessWidget {
  const _SeatBubble({
    super.key,
    required this.person,
    required this.emote,
    required this.color,
    required this.compact,
  });

  final int person;
  final Emote? emote;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final l10n = AppLocalizations.of(context);
    final size = compact ? 34.0 : 44.0;
    final filled = emote != null;

    return Semantics(
      // An empty bubble says so rather than going unannounced — it's a
      // reserved place, not a decoration.
      label: filled
          ? l10n.matchEmoteFromPlayer(person, emoteName(l10n, emote!))
          : l10n.matchEmoteEmptySeat(person),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(
              l10n.playerShort(person),
              style: styles.labelMuted.copyWith(color: color),
            ),
          ),
          const SizedBox(width: 6),
          AnimatedContainer(
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : context.gameAnimations.placement,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: filled ? colors.surface : Colors.transparent,
              shape: BoxShape.circle,
              // Dashed isn't available on a BoxDecoration, so an empty seat
              // reads as a place by being a faint outline against a filled,
              // shadowed one.
              border: Border.all(
                color: filled ? color : colors.neutral,
                width: filled ? 2 : 1,
              ),
              boxShadow: filled ? context.gameElevations.resting : null,
            ),
            child: filled
                ? Padding(
                    padding: EdgeInsets.all(compact ? 5 : 7),
                    child: ExcludeSemantics(
                      child: EmoteView(emote: emote!, color: colors.ink),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// The send tray: a toggle that opens the player's four equipped emotes.
///
/// Closed by default and it costs one button, because the game screen's
/// vertical budget in portrait is already spoken for by the banner, board,
/// inventory and staging bar.
///
/// **The open tray is an overlay, not a sibling**: it floats over whatever is
/// behind it and takes no layout space at all, so opening it never nudges the
/// board, inventory or staging bar. It anchors *below* the button whenever
/// there's room; in portrait the staging bar is the last thing on screen and
/// leaves ~10pt under it, so there it flips above. Either way nothing moves.
///
/// The tray belongs to **whoever is to move**, matching the inventory and
/// staging bar beside it. Sending is not a move and never touches the
/// engine, so it stays available while the AI is thinking.
class MatchEmoteTray extends ConsumerStatefulWidget {
  const MatchEmoteTray({
    super.key,
    required this.person,
    required this.barKey,
  });

  /// The seat sending — the person to move.
  final int person;

  /// Gap between the button and the tray.
  static const gap = 8.0;

  /// The bar this button sits in. Used only when the tray has to open
  /// upwards: it clears the whole bar rather than the button, because the
  /// bar wraps onto a second run once Confirm appears and a tray anchored to
  /// the button alone would sit on top of it.
  final GlobalKey barKey;

  @override
  ConsumerState<MatchEmoteTray> createState() => _MatchEmoteTrayState();
}

class _MatchEmoteTrayState extends ConsumerState<MatchEmoteTray> {
  final _portal = OverlayPortalController();
  final _toggleKey = GlobalKey();

  bool _open = false;

  /// Enough room for the tray plus its gap and a margin. An estimate is fine:
  /// it only decides *which side* to anchor on — the anchoring itself is
  /// measured, so being a few points out never misplaces the tray.
  static const _spaceNeededBelow = 88.0;


  void _setOpen(bool open) {
    setState(() => _open = open);
    open ? _portal.show() : _portal.hide();
  }

  @override
  Widget build(BuildContext context) {
    // Any change to the game closes the tray. Two reasons, both real:
    // a turn change would otherwise let the next tap send as a seat the
    // player didn't mean; and the tray's position is worked out once, when
    // it opens, so leaving it up while the staging bar underneath it grows a
    // second run (Confirm appearing) strands it on top of Confirm — which
    // then can't be pressed. It's a transient popup either way.
    ref.listen(gameControllerProvider, (previous, next) {
      if (_open && !identical(previous, next)) _setOpen(false);
    });

    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildTray,
      child: _ToggleButton(
        key: _toggleKey,
        open: _open,
        onPressed: () => _setOpen(!_open),
      ),
    );
  }

  Widget _buildTray(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final loadout =
        ref.watch(emoteControllerProvider).value?.loadout ?? const [];
    final onCooldown = ref.watch(matchEmoteControllerProvider).onCooldown;

    // Nothing equipped: the tray would open onto an empty row, so it says
    // where to fix that instead of pretending to be a control.
    final empty = loadout.isEmpty;

    final tray = Container(
      key: const Key('emote-tray'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: context.gameElevations.raised,
      ),
      child: empty
          ? Text(
              l10n.matchEmoteNoneEquipped,
              key: const Key('emote-tray-empty'),
              style: styles.caption,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final emote in loadout)
                  _SendButton(
                    key: Key('send-emote-${emote.id}'),
                    emote: emote,
                    enabled: !onCooldown,
                    onSend: () {
                      ref
                          .read(matchEmoteControllerProvider.notifier)
                          .send(emote, person: widget.person);
                      _setOpen(false);
                    },
                  ),
              ],
            ),
    );

    final button =
        _toggleKey.currentContext?.findRenderObject() as RenderBox?;
    final bar = widget.barKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null || !button.hasSize) return const SizedBox.shrink();

    // Below the button wherever it fits. In portrait the staging bar is the
    // last thing on screen and leaves ~10pt under it, so there the tray
    // flips above rather than opening off the bottom edge.
    final anchor = button.localToGlobal(Offset.zero) & button.size;
    final screen = rootViewSize(_toggleKey.currentContext!);
    final below =
        (screen?.height ?? double.infinity) - anchor.bottom >=
        _spaceNeededBelow;

    // Going up, clear the whole bar, not just the button: the bar wraps onto
    // a second run once Confirm appears, and a tray that clears only the
    // button lands on top of Confirm — which then can't be pressed.
    final clearAbove = bar != null && bar.hasSize
        ? bar.localToGlobal(Offset.zero).dy
        : anchor.top;

    // The overlay's coordinate space is the root's, so the anchor's global
    // numbers are already in the right frame. A layout delegate rather than
    // a Positioned: it is handed the tray's measured size, which is what
    // lets the tray sit centred *on the button* and still clamp itself onto
    // the screen — the tray is far wider than the button, and wider again in
    // Spanish, so a button near an edge would otherwise hang off it.
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _TrayLayout(
          anchor: anchor,
          clearAbove: clearAbove,
          below: below,
        ),
        child: tray,
      ),
    );
  }
}

/// Places the open tray under (or over) the emote button.
///
/// Exists to get at [getPositionForChild]'s `childSize`: the tray's width
/// isn't known until it's laid out, and both centring it on the button and
/// keeping it on screen need that number.
class _TrayLayout extends SingleChildLayoutDelegate {
  const _TrayLayout({
    required this.anchor,
    required this.clearAbove,
    required this.below,
  });

  /// The emote button, in the overlay's (= the root's) coordinates.
  final Rect anchor;

  /// The y the tray must stay above when it opens upwards — the top of the
  /// whole staging bar, not just of the button.
  final double clearAbove;

  final bool below;

  /// Kept clear of the screen edges when a tray has to be pushed sideways.
  static const _margin = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Centred on the button, then slid back onto the screen if that would
    // hang it off an edge. `clamp` needs a non-empty range, hence the max:
    // a tray wider than the screen pins to the left margin instead.
    final centred = anchor.center.dx - childSize.width / 2;
    final rightLimit = math.max(
      _margin,
      size.width - childSize.width - _margin,
    );
    final dy = below
        ? anchor.bottom + MatchEmoteTray.gap
        : clearAbove - MatchEmoteTray.gap - childSize.height;
    return Offset(centred.clamp(_margin, rightLimit), math.max(0, dy));
  }

  @override
  bool shouldRelayout(_TrayLayout old) =>
      old.anchor != anchor ||
      old.clearAbove != clearAbove ||
      old.below != below;
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    super.key,
    required this.open,
    required this.onPressed,
  });

  final bool open;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      expanded: open,
      label: l10n.matchEmoteTrayToggle,
      child: Tooltip(
        message: l10n.matchEmoteTrayToggle,
        child: Material(
          color: open ? colors.ink : colors.surface,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('emote-tray-toggle'),
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              // The same glyph either way: the button's filled-`ink`
              // background already says the tray is open, and swapping to a
              // chevron lost the one icon that says what the button is for.
              child: AppGlyph(
                AppIcons.emoji,
                size: 24,
                color: open ? colors.surface : colors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    super.key,
    required this.emote,
    required this.enabled,
    required this.onSend,
  });

  final Emote emote;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      enabled: enabled,
      label: l10n.matchEmoteSend(emoteName(l10n, emote)),
      child: Opacity(
        // The shared locked/unavailable idiom (design system §11), reused
        // for a control that's merely resting.
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onSend : null,
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: SizedBox(
                width: 26,
                height: 26,
                child: ExcludeSemantics(
                  child: EmoteView(emote: emote, color: colors.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
