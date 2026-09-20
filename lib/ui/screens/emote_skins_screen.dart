import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/emote_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/emote.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/emote_view.dart';
import '../widgets/panel_header.dart';
import '../widgets/app_glyph.dart';
import '../../theme/app_assets.dart';

/// Gutter either side of the loadout row, and the gap between its slots.
///
/// Shared with the calculation that sizes the slots — if the two disagree,
/// four slots stop fitting the width and the row starts scrolling, which is
/// exactly what the sizing exists to prevent.
const double _loadoutPadding = 24;
const double _loadoutGap = 16;

String emoteName(AppLocalizations l10n, Emote emote) => switch (emote) {
  Emote.thumbsUp => l10n.emoteNameThumbsUp,
  Emote.clap => l10n.emoteNameClap,
  Emote.laugh => l10n.emoteNameLaugh,
  Emote.cry => l10n.emoteNameCry,
  Emote.surprised => l10n.emoteNameSurprised,
  Emote.thinking => l10n.emoteNameThinking,
  Emote.fire => l10n.emoteNameFire,
  Emote.heart => l10n.emoteNameHeart,
  Emote.party => l10n.emoteNameParty,
  Emote.star => l10n.emoteNameStar,
};

/// Emote loadout picker: the four slots a player takes into a match, above
/// the catalogue they're chosen from.
///
/// Reached from the Custom screen's "Emote" category. Sending emotes needs
/// an opponent to send them *to*, which is v2 — equipping them is local, so
/// it works today and the match-side wiring lands with multiplayer.
class EmoteSkinsScreen extends ConsumerWidget {
  const EmoteSkinsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final state = ref.watch(emoteControllerProvider).value;
    final controller = ref.read(emoteControllerProvider.notifier);

    final loadout = state?.loadout ?? const <Emote>[];

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Header, the heading block, a row of 160pt slots and the
            // catalogue need ~560pt together. Below that both rows shrink
            // rather than the catalogue being pushed off the bottom — it's
            // the half of the screen the player actually picks from.
            final compact = constraints.maxHeight < 620;
            final tileSize = compact ? 64.0 : 110.0;

            // Height sets the ambition; width sets the ceiling. All four
            // slots must be on screen at once — a loadout you have to scroll
            // to see isn't a loadout — so on a phone the slots shrink to
            // whatever four-across actually fits.
            final widthPerSlot =
                (constraints.maxWidth -
                    _loadoutPadding * 2 -
                    _loadoutGap * (Emote.loadoutSize - 1)) /
                Emote.loadoutSize;
            final slotSize = [
              compact ? 88.0 : 160.0,
              widthPerSlot,
            ].reduce((a, b) => a < b ? a : b).clamp(48.0, 160.0);

            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PanelHeader(
                  closeKey: const Key('close-emotes'),
                  icon: AppGlyph(
                    AppIcons.emoji,
                    size: 34,
                    color: colors.neutral,
                  ),
                  title: l10n.emotesTitle,
                  subtitle: l10n.emotesSubtitle(Emote.loadoutSize),
                ),
                // Heading and slots share one centred column, so the label
                // sits over the slots it names rather than off at the left
                // margin.
                Column(
                  children: [
                    Text(l10n.emotesLoadoutHeading, style: styles.subtitle),
                    AppGlyph(AppIcons.doubleChevronDown, size: 22, color: colors.ink),
                    const SizedBox(height: 8),
                    _LoadoutRow(
                      loadout: loadout,
                      slotSize: slotSize,
                      onRemove: controller.removeAt,
                    ),
                  ],
                ),
                // const Spacer(),
                _EmoteCatalogue(
                  tileSize: tileSize,
                  isUnlocked: (emote) => state?.isUnlocked(emote) ?? emote.free,
                  isEquipped: (emote) => loadout.contains(emote),
                  onTap: controller.toggle,
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The four equipped slots. Tapping a filled one empties it.
class _LoadoutRow extends StatelessWidget {
  const _LoadoutRow({
    required this.loadout,
    required this.slotSize,
    required this.onRemove,
  });

  final List<Emote> loadout;
  final double slotSize;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _loadoutPadding),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: _loadoutGap,
          children: [
            for (var slot = 0; slot < Emote.loadoutSize; slot++)
              _EmoteSlot(
                key: Key('emote-slot-$slot'),
                size: slotSize,
                emote: slot < loadout.length ? loadout[slot] : null,
                emptyLabel: l10n.emotesEmptySlot,
                onTap: slot < loadout.length ? () => onRemove(slot) : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _EmoteSlot extends StatelessWidget {
  const _EmoteSlot({
    super.key,
    required this.size,
    required this.emote,
    required this.emptyLabel,
    required this.onTap,
  });

  final double size;
  final Emote? emote;
  final String emptyLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final elevations = context.gameElevations;
    final radius = BorderRadius.circular(size * 0.18);
    final filled = emote != null;

    return Semantics(
      button: true,
      label: filled ? emoteName(l10n, emote!) : emptyLabel,
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
              onTap: onTap,
              child: filled
                  ? Padding(
                      padding: EdgeInsets.all(size * 0.18),
                      child: EmoteView(emote: emote!),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// The scrolling catalogue every emote is picked from.
class _EmoteCatalogue extends StatefulWidget {
  const _EmoteCatalogue({
    required this.tileSize,
    required this.isUnlocked,
    required this.isEquipped,
    required this.onTap,
  });

  final double tileSize;
  final bool Function(Emote) isUnlocked;
  final bool Function(Emote) isEquipped;
  final ValueChanged<Emote> onTap;

  @override
  State<_EmoteCatalogue> createState() => _EmoteCatalogueState();
}

class _EmoteCatalogueState extends State<_EmoteCatalogue> {
  final _controller = ScrollController();

  /// Matches the category row: a couple of pixels left to scroll isn't worth
  /// offering an arrow for.
  static const _endSlack = 8.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canScrollForward =>
      _controller.hasClients &&
      _controller.position.pixels <
          _controller.position.maxScrollExtent - _endSlack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;

    const gutter = 24.0;
    const chevronSlot = 48.0;

    return SizedBox(
      height: widget.tileSize + 16,
      child: Row(
        children: [
          // Mirrors the chevron's slot so the catalogue centres against the
          // screen, not against the space the chevron leaves.
          const SizedBox(width: chevronSlot),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) {
                setState(() {});
                return false;
              },
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  setState(() {});
                  return false;
                },
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: gutter),
                    child: ConstrainedBox(
                      // Filling the viewport lets the Row centre its tiles
                      // while they fit, and simply scroll once there are more
                      // emotes than fit. A ListView can't do the first half —
                      // it always packs from the leading edge.
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth - gutter * 2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 12,
                        children: [
                          for (final emote in Emote.values)
                            _CatalogueTile(
                              key: Key('emote-${emote.id}'),
                              emote: emote,
                              size: widget.tileSize,
                              unlocked: widget.isUnlocked(emote),
                              equipped: widget.isEquipped(emote),
                              onTap: () => widget.onTap(emote),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: chevronSlot,
            child: _canScrollForward
                ? IconButton(
                    key: const Key('emote-scroll-forward'),
                    icon: const AppGlyph(AppIcons.chevronRight, size: 20),
                    iconSize: 40,
                    color: colors.ink,
                    tooltip: l10n.categoryNext,
                    onPressed: () => _controller.animateTo(
                      (_controller.position.pixels +
                              _controller.position.viewportDimension * 0.8)
                          .clamp(0, _controller.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _CatalogueTile extends StatelessWidget {
  const _CatalogueTile({
    super.key,
    required this.emote,
    required this.size,
    required this.unlocked,
    required this.equipped,
    required this.onTap,
  });

  final Emote emote;
  final double size;
  final bool unlocked;
  final bool equipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final elevations = context.gameElevations;
    final radius = BorderRadius.circular(size * 0.22);

    return Semantics(
      button: true,
      enabled: unlocked,
      selected: equipped,
      label: [
        emoteName(l10n, emote),
        if (!unlocked) l10n.skinLocked else if (equipped) l10n.emoteEquipped,
      ].join(', '),
      child: ExcludeSemantics(
        child: Opacity(
          opacity: unlocked ? 1 : 0.45,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: elevations.resting,
              // Equipped emotes stay in the catalogue rather than vanishing
              // from it — the outline is what says "this one's already in".
              border: equipped ? Border.all(color: colors.ink, width: 3) : null,
            ),
            child: Material(
              color: colors.surface,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: unlocked ? onTap : null,
                child: Padding(
                  padding: EdgeInsets.all(size * 0.18),
                  child: unlocked
                      ? EmoteView(emote: emote)
                      : AppGlyph(
                          AppIcons.locked,
                          size: size * 0.4,
                          color: colors.neutral,
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
