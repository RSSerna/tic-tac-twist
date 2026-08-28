import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../widgets/app_mark.dart';
import '../widgets/buttons/category_tile.dart';
import '../widgets/panel_header.dart';
import 'chip_skins_screen.dart';

/// The cosmetic categories a player can customise.
///
/// Only [chips] has content today ([ChipSkinsScreen], roadmap Phase 8). The
/// rest are declared here because the screen is built around the category
/// row — they render locked until each has a system behind it, rather than
/// being hidden and then needing the layout redesigned when they land.
enum CustomizationCategory {
  board(available: false),
  chips(available: true),
  emote(available: false),
  flexing(available: false);

  const CustomizationCategory({required this.available});

  final bool available;
}

/// Customisation root: pick a category, then a cosmetic within it.
class SkinsScreen extends StatelessWidget {
  const SkinsScreen({super.key});

  static String _label(AppLocalizations l10n, CustomizationCategory category) =>
      switch (category) {
        CustomizationCategory.board => l10n.categoryBoard,
        CustomizationCategory.chips => l10n.categoryChips,
        CustomizationCategory.emote => l10n.categoryEmote,
        CustomizationCategory.flexing => l10n.categoryFlexing,
      };

  /// [size] is derived from the tile, so the glyph keeps its proportions
  /// when a short screen shrinks the tiles rather than spilling out of one.
  static Widget _icon(
    BuildContext context,
    CustomizationCategory category,
    double size,
  ) {
    final colors = context.gameColors;
    return switch (category) {
      CustomizationCategory.board => AppMark(size: size),
      // `ink`, not `neutral`: these are the tile's subject, not a disabled
      // or secondary state, and they carry the same weight as `AppMark`
      // beside them (which paints in `ink` too).
      CustomizationCategory.chips => Icon(
        Icons.palette,
        size: size,
        color: colors.ink,
      ),
      CustomizationCategory.emote => Icon(
        Icons.emoji_emotions,
        size: size,
        color: colors.ink,
      ),
      CustomizationCategory.flexing => Icon(
        Icons.accessibility_new,
        size: size,
        color: colors.ink,
      ),
    };
  }

  void _open(BuildContext context, CustomizationCategory category) {
    switch (category) {
      case CustomizationCategory.chips:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ChipSkinsScreen()),
        );
      case CustomizationCategory.board:
      case CustomizationCategory.emote:
      case CustomizationCategory.flexing:
        // Unreachable: CategoryTile refuses taps when unavailable. Left
        // explicit so adding a system means filling this in, not hunting for
        // where navigation was supposed to go.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PanelHeader(
              closeKey: const Key('close-custom'),
              icon: const AppMark(size: 34),
              title: l10n.customTitle,
              subtitle: l10n.customSubtitle,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: _CategoryRow(
                    categories: CustomizationCategory.values,
                    label: _label,
                    icon: _icon,
                    onOpen: _open,
                    // Sized here so a short screen shrinks the tiles squarely
                    // instead of the parent squashing a fixed 180 into a
                    // rectangle — which is what happened at 320x480 in
                    // Spanish, where the wrapped subtitle eats the height.
                    tileSize: (constraints.maxHeight - 24).clamp(72.0, 180.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The horizontally scrolling row of category tiles, with a chevron that
/// appears only when there's more row to reach.
class _CategoryRow extends StatefulWidget {
  const _CategoryRow({
    required this.categories,
    required this.label,
    required this.icon,
    required this.onOpen,
    required this.tileSize,
  });

  final List<CustomizationCategory> categories;
  final String Function(AppLocalizations, CustomizationCategory) label;
  final Widget Function(BuildContext, CustomizationCategory, double) icon;
  final void Function(BuildContext, CustomizationCategory) onOpen;
  final double tileSize;

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A few pixels of remaining extent aren't a tile the player can't see —
  /// offering an arrow that scrolls by 2px reads as a broken control.
  static const _endSlack = 8.0;

  bool get _canScrollForward =>
      _controller.hasClients &&
      _controller.position.pixels <
          _controller.position.maxScrollExtent - _endSlack;

  void _scrollForward() {
    final viewport = _controller.position.viewportDimension;
    _controller.animateTo(
      (_controller.position.pixels + viewport * 0.8).clamp(
        0,
        _controller.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;

    const gutter = 32.0;
    const chevronSlot = 56.0;

    return Row(
      children: [
        // Mirrors the chevron's slot on the left so the tiles centre against
        // the screen rather than against the space the chevron leaves.
        const SizedBox(width: chevronSlot),
        Expanded(
          // Rebuilds the chevron whenever the row's extent or offset changes,
          // so it can't linger after the last tile is already in view.
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
                    // Filling the viewport lets the Row centre its tiles when
                    // they fit; when they don't, the Row is wider than this
                    // minimum and simply scrolls. A ListView can't do the
                    // first half — it always packs from the leading edge.
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth - gutter * 2,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final category in widget.categories) ...[
                          CategoryTile(
                            key: Key('category-${category.name}'),
                            label: widget.label(l10n, category),
                            icon: widget.icon(
                              context,
                              category,
                              widget.tileSize * 0.36,
                            ),
                            available: category.available,
                            // Set here rather than left to the widget's
                            // default: how large these read is a decision
                            // about this screen, not about the tile.
                            size: widget.tileSize,
                            onPressed: () => widget.onOpen(context, category),
                          ),
                          if (category != widget.categories.last)
                            const SizedBox(width: 20),
                        ],
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
                  key: const Key('category-scroll-forward'),
                  icon: const Icon(Icons.chevron_right),
                  iconSize: 44,
                  color: colors.ink,
                  tooltip: l10n.categoryNext,
                  onPressed: _scrollForward,
                )
              : null,
        ),
      ],
    );
  }
}
