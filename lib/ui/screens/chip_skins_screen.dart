import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/skin_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/purchase_service.dart';
import '../../theme/skin.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/buttons/pill_action_button.dart';
import '../widgets/buttons/segmented_pills.dart';
import '../widgets/chip_view.dart';
import '../widgets/panel_header.dart';
import '../widgets/rarity_legend.dart';

String _skinName(AppLocalizations l10n, GameSkin skin) => switch (skin.id) {
  'turned_wood' => l10n.skinTurnedWoodName,
  'nesting_dolls' => l10n.skinNestingDollsName,
  _ => skin.id,
};

String _skinDesc(AppLocalizations l10n, GameSkin skin) => switch (skin.id) {
  'turned_wood' => l10n.skinTurnedWoodDesc,
  'nesting_dolls' => l10n.skinNestingDollsDesc,
  _ => '',
};

/// The direct-purchase route design doc §2.2 names alongside "earned
/// through play" — null for skins (like the free default) that have no
/// purchase route at all, and always null on web (design doc §9:
/// in_app_purchase has no web implementation, so there's nothing to sell —
/// achievement-unlocking still works there, since it's just local storage).
ProductId? _productFor(GameSkin skin) {
  if (kIsWeb) return null;
  return switch (skin.id) {
    'nesting_dolls' => ProductId.skinNestingDolls,
    _ => null,
  };
}

/// Chip skin picker (roadmap Phase 8): the free default plus one premium set,
/// unlockable either by achievement (design doc §2.6 / product doc §3.1) or
/// direct purchase (product doc §2.2's other cosmetics route).
///
/// Reached from the Custom screen's "Skins" category — chips are one of
/// several things a player will be able to reskin.
class ChipSkinsScreen extends ConsumerStatefulWidget {
  const ChipSkinsScreen({super.key});

  @override
  ConsumerState<ChipSkinsScreen> createState() => _ChipSkinsScreenState();
}

class _ChipSkinsScreenState extends ConsumerState<ChipSkinsScreen> {
  /// Which skin the carousel is centred on. Presentation state — the
  /// *selected* skin lives in `SkinController` and only changes when the
  /// player presses Select.
  int _focused = 0;

  /// Which mark you're dressing. The two are chosen — and sold — separately,
  /// so this decides both what the previews render *and* which mark a Select
  /// applies to. Presentation state: the choice itself lives in
  /// `SkinController`.
  bool _previewFirstPerson = true;

  String _source = 'local';

  late final PageController _pages = PageController(
    viewportFraction: 0.32,
    initialPage: _focused,
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _focus(int index) {
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final skinState = ref.watch(skinControllerProvider).value;

    final skins = GameSkin.values;
    final focusedSkin = skins[_focused.clamp(0, skins.length - 1)];
    final unlocked =
        skinState?.isUnlocked(focusedSkin) ??
        focusedSkin.id == GameSkin.turnedWood.id;
    final selected =
        skinState?.isSelected(
          focusedSkin,
          forFirstPerson: _previewFirstPerson,
        ) ??
        false;

    final sourcePills = SegmentedPills(
      selected: _source,
      onChanged: (value) => setState(() => _source = value),
      segments: [
        PillSegment(
          key: const Key('skins-source-local'),
          label: l10n.skinsSourceLocal,
          value: 'local',
        ),
        // v1 is offline-only (CLAUDE.md): there is no server to fetch skins
        // from, so this is present but inert until v2.
        PillSegment(
          key: const Key('skins-source-online'),
          label: l10n.skinsSourceOnline,
          value: 'online',
          available: false,
        ),
      ],
    );

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // A phone in portrait can't seat the badge, a 44pt title, both
            // source pills and the close button on one line — below this the
            // pills get their own row instead of overflowing.
            final wide = constraints.maxWidth >= 640;
            final short = constraints.maxHeight < 600;

            return Column(
              children: [
                PanelHeader(
                  closeKey: const Key('close-chip-skins'),
                  icon: Icon(Icons.palette, size: 34, color: colors.neutral),
                  title: l10n.skinsTitle,
                  subtitle: l10n.categoryChips,
                ),
                if (!wide)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: sourcePills,
                  ),
                // Source pills, prompt and X/O toggle share one line.
                //
                // A Stack, not a Row: the prompt has to sit at the *screen's*
                // centre so the carousel's focused tile can line up directly
                // under it. In a Row it would centre in whatever the pills and
                // toggle left over, which is off-centre and different in each
                // language.
                //
                // The infinite width is load-bearing: a Stack sizes itself to
                // its largest *non-positioned* child, which here is the narrow
                // prompt — so `left: 0` and `right: 0` would pin the pills and
                // toggle to the prompt's edges, clustering all three in the
                // middle. Filling the width makes those the screen's edges.
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          children: [
                            Text(
                              l10n.skinsSelectPrompt,
                              textAlign: TextAlign.center,
                              style: styles.subtitle,
                            ),
                            // Purely decorative — the first thing to drop when
                            // vertical space is scarce.
                            if (!short)
                              Icon(
                                Icons.keyboard_double_arrow_down,
                                color: colors.ink,
                              ),
                          ],
                        ),
                        // Below this width the three would overlap, so the
                        // pills move to their own line above.
                        if (wide) Positioned(left: 0, child: sourcePills),
                        Positioned(
                          right: 0,
                          child: _PreviewPersonToggle(
                            firstPerson: _previewFirstPerson,
                            onChanged: (value) =>
                                setState(() => _previewFirstPerson = value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _SkinCarousel(
                    controller: _pages,
                    skins: skins,
                    compact: short,
                    previewFirstPerson: _previewFirstPerson,
                    isUnlocked: (skin) =>
                        skinState?.isUnlocked(skin) ??
                        skin.id == GameSkin.turnedWood.id,
                    isSelected: (skin) =>
                        skinState?.isSelected(
                          skin,
                          forFirstPerson: _previewFirstPerson,
                        ) ??
                        false,
                    onFocusChanged: (index) => setState(() => _focused = index),
                    onTapTile: _focus,
                  ),
                ),
                _FocusedSkinActions(
                  skin: focusedSkin,
                  unlocked: unlocked,
                  selected: selected,
                  forFirstPerson: _previewFirstPerson,
                  compact: short,
                ),
                const RarityLegend(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Width reserved for the carousel's forward arrow — and mirrored on the
/// other side, so the focused tile stays centred on the screen rather than on
/// the space the arrow leaves.
const double _arrowSlot = 56;

/// The centre-focused row of skin tiles.
class _SkinCarousel extends StatelessWidget {
  const _SkinCarousel({
    required this.controller,
    required this.skins,
    required this.compact,
    required this.previewFirstPerson,
    required this.isUnlocked,
    required this.isSelected,
    required this.onFocusChanged,
    required this.onTapTile,
  });

  final PageController controller;
  final List<GameSkin> skins;

  /// Slims the progress bar on screens with no height to spare — at full
  /// size it costs 10pt that a 480pt-tall phone doesn't have.
  final bool compact;

  final bool previewFirstPerson;
  final bool Function(GameSkin) isUnlocked;
  final bool Function(GameSkin) isSelected;
  final ValueChanged<int> onFocusChanged;
  final ValueChanged<int> onTapTile;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Mirrors the forward arrow's slot. Without it the PageView is
              // 56pt narrower on the right, so its centred tile sits 28pt
              // left of the prompt it's supposed to line up under.
              const SizedBox(width: _arrowSlot),
              Expanded(
                child: PageView.builder(
                  controller: controller,
                  itemCount: skins.length,
                  onPageChanged: onFocusChanged,
                  padEnds: true,
                  itemBuilder: (context, index) {
                    final skin = skins[index];
                    return AnimatedBuilder(
                      animation: controller,
                      builder: (context, child) {
                        // Distance from centre drives the scale, so the
                        // focused tile grows continuously as you drag rather
                        // than snapping when the page index flips.
                        final page =
                            controller.hasClients &&
                                controller.position.haveDimensions
                            ? controller.page ?? index.toDouble()
                            : index.toDouble();
                        final distance = (page - index).abs().clamp(0.0, 1.0);
                        return Transform.scale(
                          scale: 1 - distance * 0.22,
                          child: child,
                        );
                      },
                      child: _SkinTile(
                        skin: skin,
                        unlocked: isUnlocked(skin),
                        selected: isSelected(skin),
                        previewFirstPerson: previewFirstPerson,
                        onTap: () => onTapTile(index),
                      ),
                    );
                  },
                ),
              ),
              _CarouselArrow(controller: controller, itemCount: skins.length),
            ],
          ),
        ),
        // Narrower and taller than full-bleed: at full width the bar read as
        // a hairline stretched across the screen. Centred on the same axis as
        // the carousel above it.
        Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            compact ? 2 : 8,
            24,
            compact ? 4 : 10,
          ),
          child: FractionallySizedBox(
            widthFactor: 0.45,
            child: _CarouselProgress(
              controller: controller,
              itemCount: skins.length,
              compact: compact,
              track: colors.ink,
              thumb: colors.surface,
            ),
          ),
        ),
      ],
    );
  }
}

class _SkinTile extends StatelessWidget {
  const _SkinTile({
    required this.skin,
    required this.unlocked,
    required this.selected,
    required this.previewFirstPerson,
    required this.onTap,
  });

  final GameSkin skin;
  final bool unlocked;
  final bool selected;
  final bool previewFirstPerson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final elevations = context.gameElevations;

    return Semantics(
      button: true,
      selected: selected,
      label: unlocked
          ? _skinName(l10n, skin)
          : '${_skinName(l10n, skin)}, ${l10n.skinLocked}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              key: Key('skin-card-${skin.id}'),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: elevations.raised,
                border: selected
                    ? Border.all(color: colors.ink, width: 3)
                    : null,
              ),
              padding: const EdgeInsets.all(16),
              child: unlocked
                  ? ChipView(
                      color: previewFirstPerson
                          ? colors.playerA
                          : colors.playerB,
                      ringColor: colors.surface,
                      level: 4,
                      isFirstPerson: previewFirstPerson,
                      appearance: skin.appearance,
                    )
                  // A locked skin shows a lock rather than a dimmed preview:
                  // the art is the thing being sold, so don't give it away.
                  : Center(
                      child: Icon(
                        Icons.lock,
                        size: 40,
                        color: colors.neutral,
                        semanticLabel: l10n.skinLocked,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrolls the carousel forward, shown only while there's more to reach.
class _CarouselArrow extends StatefulWidget {
  const _CarouselArrow({required this.controller, required this.itemCount});

  final PageController controller;
  final int itemCount;

  @override
  State<_CarouselArrow> createState() => _CarouselArrowState();
}

class _CarouselArrowState extends State<_CarouselArrow> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final page =
            widget.controller.hasClients &&
                widget.controller.position.haveDimensions
            ? widget.controller.page ?? 0
            : 0.0;
        final canAdvance = page < widget.itemCount - 1.05;

        return SizedBox(
          width: _arrowSlot,
          child: canAdvance
              ? IconButton(
                  key: const Key('skins-scroll-forward'),
                  icon: const Icon(Icons.chevron_right),
                  iconSize: 44,
                  color: colors.ink,
                  tooltip: l10n.categoryNext,
                  onPressed: () => widget.controller.nextPage(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  ),
                )
              : null,
        );
      },
    );
  }
}

/// The bar under the carousel: a thumb whose position tracks the page.
class _CarouselProgress extends StatelessWidget {
  const _CarouselProgress({
    required this.controller,
    required this.itemCount,
    required this.compact,
    required this.track,
    required this.thumb,
  });

  final PageController controller;
  final int itemCount;
  final bool compact;
  final Color track;
  final Color thumb;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final page = controller.hasClients && controller.position.haveDimensions
            ? controller.page ?? 0
            : 0.0;
        final progress = itemCount <= 1 ? 0.0 : page / (itemCount - 1);

        return LayoutBuilder(
          builder: (context, constraints) {
            final thumbWidth = (constraints.maxWidth / itemCount).clamp(
              40.0,
              constraints.maxWidth,
            );
            return SizedBox(
              height: compact ? 18 : 28,
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      height: compact ? 14 : 24,
                      decoration: BoxDecoration(
                        color: track,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment(progress * 2 - 1, 0),
                    child: Container(
                      width: thumbWidth,
                      height: compact ? 12 : 20,
                      decoration: BoxDecoration(
                        color: thumb,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Name, description and the Select/Buy action for whichever skin is
/// centred. Kept out of the tiles so a tile stays a preview of the art.
class _FocusedSkinActions extends ConsumerWidget {
  const _FocusedSkinActions({
    required this.skin,
    required this.unlocked,
    required this.selected,
    required this.forFirstPerson,
    required this.compact,
  });

  /// Which mark a Select applies to — the X/O toggle above the carousel.
  final bool forFirstPerson;

  final GameSkin skin;
  final bool unlocked;
  final bool selected;

  /// Drops the description on screens too short to spare the two lines.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final styles = context.gameTextStyles;
    final product = _productFor(skin);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Column(
        children: [
          Text(_skinName(l10n, skin), style: styles.cardTitle),
          if (!compact) ...[
            const SizedBox(height: 2),
            Text(
              unlocked ? _skinDesc(l10n, skin) : l10n.skinUnlockHint,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: styles.caption,
            ),
          ],
          const SizedBox(height: 8),
          if (!unlocked)
            product == null
                ? Text(l10n.skinLocked, style: styles.labelMuted)
                : PillActionButton(
                    key: Key('buy-skin-${skin.id}'),
                    label: l10n.skinBuyButton,
                    onPressed: () =>
                        ref.read(purchaseServiceProvider).buy(product),
                  )
          else if (selected)
            Text(l10n.skinSelected, style: styles.label)
          else
            PillActionButton(
              key: Key('select-skin-${skin.id}'),
              label: l10n.skinSelect,
              onPressed: () => ref
                  .read(skinControllerProvider.notifier)
                  .selectSkin(skin, forFirstPerson: forFirstPerson),
            ),
        ],
      ),
    );
  }
}

/// Switches the previews between the two players' renderings.
class _PreviewPersonToggle extends StatelessWidget {
  const _PreviewPersonToggle({
    required this.firstPerson,
    required this.onChanged,
  });

  final bool firstPerson;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final elevations = context.gameElevations;

    Widget half(IconData icon, bool isFirst) {
      final active = isFirst == firstPerson;
      return GestureDetector(
        onTap: () => onChanged(isFirst),
        child: Container(
          width: 44,
          height: 40,
          decoration: BoxDecoration(
            // The active half gets the fill; the palette has no "active"
            // colour, so `neutral` at low alpha stands in for one.
            color: active
                ? colors.neutral.withValues(alpha: 0.35)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 22, color: colors.ink),
        ),
      );
    }

    return Semantics(
      button: true,
      label: firstPerson
          ? l10n.skinPreviewAsPlayer1
          : l10n.skinPreviewAsPlayer2,
      child: ExcludeSemantics(
        child: Container(
          key: const Key('skin-preview-person'),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: elevations.resting,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icons, not the letters "X"/"O" — a hardcoded glyph would be
              // untranslated user-facing text, and these match the shapes
              // the Ultimate board already paints.
              half(Icons.close, true),
              half(Icons.circle_outlined, false),
            ],
          ),
        ),
      ),
    );
  }
}
