import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/celebration_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/celebration.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/asset_glyph.dart';
import '../widgets/buttons/pill_action_button.dart';
import '../widgets/panel_header.dart';
import '../widgets/rarity_legend.dart';
import '../widgets/app_glyph.dart';
import '../../theme/app_assets.dart';

String celebrationName(AppLocalizations l10n, Celebration c) => switch (c) {
  Celebration.happy => l10n.celebrationNameHappy,
  Celebration.cheer => l10n.celebrationNameCheer,
  Celebration.dance => l10n.celebrationNameDance,
  Celebration.bow => l10n.celebrationNameBow,
  Celebration.flex => l10n.celebrationNameFlex,
  Celebration.wave => l10n.celebrationNameWave,
  Celebration.spin => l10n.celebrationNameSpin,
  Celebration.jump => l10n.celebrationNameJump,
  Celebration.salute => l10n.celebrationNameSalute,
  Celebration.shrug => l10n.celebrationNameShrug,
  Celebration.facepalm => l10n.celebrationNameFacepalm,
  Celebration.fistbump => l10n.celebrationNameFistbump,
  Celebration.crown => l10n.celebrationNameCrown,
  Celebration.trophy => l10n.celebrationNameTrophy,
  Celebration.sparkle => l10n.celebrationNameSparkle,
  Celebration.rocket => l10n.celebrationNameRocket,
};

/// Victory-celebration picker: a preview beside a paged grid.
///
/// Reached from the Custom screen's "Flexing" category. Choosing one is local
/// and works today; **nothing plays a celebration yet** — the format (image,
/// sprite sequence, video) isn't decided, so the preview frame renders the
/// same art the grid does.
class CelebrationSkinsScreen extends ConsumerStatefulWidget {
  const CelebrationSkinsScreen({super.key});

  @override
  ConsumerState<CelebrationSkinsScreen> createState() =>
      _CelebrationSkinsScreenState();
}

class _CelebrationSkinsScreenState
    extends ConsumerState<CelebrationSkinsScreen> {
  /// Which block of the grid is showing. Presentation state.
  int _block = 0;

  /// What the preview frame shows. Starts as the equipped celebration, then
  /// follows whatever the player taps — including locked ones, so they can
  /// see what they'd be buying.
  Celebration? _previewed;

  static int get _blockCount =>
      (Celebration.values.length / Celebration.perBlock).ceil();

  List<Celebration> get _currentBlock {
    final start = _block * Celebration.perBlock;
    return Celebration.values.skip(start).take(Celebration.perBlock).toList();
  }

  /// Tapping a tile only *previews* it. Equipping is a separate, deliberate
  /// act via the button under the preview — you look before you commit.
  void _preview(Celebration celebration) =>
      setState(() => _previewed = celebration);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final state = ref.watch(celebrationControllerProvider).value;

    final previewed =
        _previewed ?? state?.selected ?? Celebration.defaultChoice;
    final previewLocked = state != null && !state.isUnlocked(previewed);

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, screen) {
            // A phone can't seat badge + title + lock pill + close on one
            // line — squeezed, the title wraps until the header is taller
            // than the screen. Below this the lock moves down beside the
            // preview it describes, which is arguably where it belongs.
            final lockFitsHeader = screen.maxWidth >= 640;

            // Side-by-side is a question about the *screen*, not about
            // whatever height the body has left. Deciding it from the body
            // put the preview and grid side by side on a 320pt phone —
            // because a tall header had made the body wider than it was
            // deep — leaving the grid 26pt across.
            final sideBySide = screen.maxWidth >= 640;

            return Column(
              children: [
                PanelHeader(
                  closeKey: const Key('close-flexing'),
                  icon: AppGlyph(
                    AppIcons.flex,
                    size: 34,
                    color: colors.neutral,
                  ),
                  title: l10n.categoryFlexing,
                  subtitle: l10n.celebrationsSubtitle,
                  trailing: lockFitsHeader
                      ? _LockStatus(locked: previewLocked)
                      : null,
                ),
                // The body measures itself rather than the whole screen: the
                // header's height varies with the translation, and the
                // preview has to be sized against what's actually left over.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = sideBySide;

                        // Preview height comes from the space available; the grid
                        // is then sized from the *width* it has left and given
                        // its natural height. Nothing competes for the leftover
                        // vertical space, so nothing can overflow — a screen too
                        // short for both simply scrolls.
                        final previewHeight = wide
                            ? (constraints.maxHeight - 40).clamp(140.0, 320.0)
                            : (constraints.maxHeight * 0.38).clamp(
                                140.0,
                                280.0,
                              );
                        final previewWidth = previewHeight * 0.66;

                        final gridWidth = wide
                            ? constraints.maxWidth - previewWidth - 24
                            : constraints.maxWidth;
                        final tile = _CelebrationGrid.tileFor(gridWidth);

                        final preview = _PreviewFrame(
                          celebration: previewed,
                          action: _PreviewAction(
                            previewed: previewed,
                            equipped: state?.selected,
                            locked: previewLocked,
                            fragmentCount:
                                state?.fragmentCounts[previewed.id] ?? 0,
                            onSelect: () => ref
                                .read(celebrationControllerProvider.notifier)
                                .select(previewed),
                          ),
                          // Roughly a phone's aspect, so the frame reads as a
                          // screen at any size.
                          width: previewWidth,
                          height: previewHeight,
                          locked: lockFitsHeader ? null : previewLocked,
                        );
                        final grid = _CelebrationGrid(
                          celebrations: _currentBlock,
                          blockLabel: l10n.celebrationsBlock(_block + 1),
                          tileSize: tile,
                          isUnlocked: (c) => state?.isUnlocked(c) ?? c.free,
                          isSelected: (c) => state?.selectedId == c.id,
                          onTap: _preview,
                          hasPrevious: _block > 0,
                          hasNext: _block < _blockCount - 1,
                          onPrevious: () => setState(() => _block--),
                          onNext: () => setState(() => _block++),
                        );

                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(
                              child: wide
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        preview,
                                        const SizedBox(width: 24),
                                        Flexible(child: grid),
                                      ],
                                    )
                                  : Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        preview,
                                        const SizedBox(height: 12),
                                        grid,
                                      ],
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
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

/// Lights up when the previewed celebration isn't unlocked. Status, not a
/// control — the buy route needs store products that don't exist yet.
class _LockStatus extends StatelessWidget {
  const _LockStatus({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final elevations = context.gameElevations;

    return Semantics(
      label: locked ? l10n.celebrationLockedStatus : '',
      child: ExcludeSemantics(
        child: Opacity(
          opacity: locked ? 1 : 0.35,
          child: Container(
            key: const Key('celebration-lock-status'),
            width: 88,
            height: 44,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: elevations.resting,
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: locked ? colors.ink : colors.neutral,
              // Always the lock, never a tick: this pill *is* the lock
              // status, and the dimming plus the neutral avatar above
              // already say which way round it is. A tick here would put a
              // second one on screen competing with the equipped marker.
              child: AppGlyph(
                AppIcons.locked,
                size: 18,
                color: colors.surface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The phone-shaped frame: name bar above, celebration below.
class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({
    required this.celebration,
    required this.action,
    required this.width,
    required this.height,
    this.locked,
  });

  /// Whatever commits (or reports) the choice, rendered under the frame. Built
  /// by the screen, which is the layer holding the controller.
  final Widget action;

  final Celebration celebration;
  final double width;
  final double height;

  /// Non-null when the header had no room for the lock indicator, so it
  /// rides alongside the "Preview" label instead.
  final bool? locked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final elevations = context.gameElevations;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Flexible, because "Vista previa" plus the lock pill is wider
            // than a 320pt phone — the label gives way rather than the row
            // overflowing.
            Flexible(
              child: Text(
                l10n.celebrationsPreview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: styles.subtitle,
              ),
            ),
            if (locked != null) ...[
              const SizedBox(width: 8),
              _LockStatus(locked: locked!),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          key: const Key('celebration-preview'),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: colors.ink,
            borderRadius: BorderRadius.circular(20),
            boxShadow: elevations.raised,
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  celebrationName(l10n, celebration).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: styles.caption.copyWith(
                    color: colors.surface,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: colors.surface,
                  padding: const EdgeInsets.all(20),
                  child: AssetGlyph(
                    assetPath: celebration.assetPath,
                    fallbackIcon: celebration.fallbackIcon,
                    color: colors.neutral,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(width: width, child: action),
      ],
    );
  }
}

/// What sits under the preview: the button that commits the choice, or — when
/// you're already looking at the equipped one — a statement that you are.
///
/// Separate from [_PreviewFrame] because it needs the controller, and the
/// frame is a plain presentational widget.
class _PreviewAction extends StatelessWidget {
  const _PreviewAction({
    required this.previewed,
    required this.equipped,
    required this.locked,
    required this.fragmentCount,
    required this.onSelect,
  });

  final Celebration previewed;
  final Celebration? equipped;
  final bool locked;

  /// Fragments collected so far toward [previewed] — read only when
  /// [Celebration.isFragmentGated] is true.
  final int fragmentCount;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;

    // Still loading: no claim about what's equipped rather than a wrong one.
    if (equipped == null) return const SizedBox.shrink();

    if (previewed == equipped) {
      return Row(
        key: const Key('celebration-equipped-status'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppGlyph(AppIcons.check, size: 16, color: colors.ink),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              l10n.celebrationEquipped,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styles.label,
            ),
          ),
        ],
      );
    }

    return Column(
      // Keyed on the wrapper, matching the equipped branch above, so a test
      // can look *inside* the status for either state.
      key: const Key('celebration-equipped-status'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Disabled rather than hidden on a locked celebration: the player can
        // see the action exists and that it's the lock standing in the way.
        PillActionButton(
          key: const Key('celebration-select'),
          label: !locked
              ? l10n.skinSelect
              : previewed.isFragmentGated
              ? l10n.skinFragmentProgress(
                  fragmentCount,
                  previewed.fragmentsRequired!,
                )
              : l10n.skinLocked,
          onPressed: locked ? null : onSelect,
        ),
        const SizedBox(height: 4),
        // Previewing something else must not make the equipped one
        // unknowable — including from a block that doesn't contain it.
        Text(
          l10n.celebrationEquippedIs(celebrationName(l10n, equipped!)),
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: styles.labelMuted,
        ),
      ],
    );
  }
}

/// One block of celebrations: a 4×3 grid with its label and page arrows.
class _CelebrationGrid extends StatelessWidget {
  const _CelebrationGrid({
    required this.celebrations,
    required this.blockLabel,
    required this.tileSize,
    required this.isUnlocked,
    required this.isSelected,
    required this.onTap,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  static const _columns = 4;
  static const _gap = 12.0;
  static const _arrowSlot = 40.0;

  /// Square tiles sized from the width the grid has, minus both arrow slots.
  /// Height never enters into it — the grid takes the height it needs and the
  /// body scrolls if that's more than there is.
  static double tileFor(double available) =>
      ((available - _arrowSlot * 2 - _gap * (_columns - 1)) / _columns).clamp(
        28.0,
        150.0,
      );

  final List<Celebration> celebrations;
  final String blockLabel;
  final double tileSize;
  final bool Function(Celebration) isUnlocked;
  final bool Function(Celebration) isSelected;
  final void Function(Celebration) onTap;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;

    Widget arrow({
      required bool shown,
      required VoidCallback onPressed,
      required Key key,
      bool flipped = false,
    }) => SizedBox(
      width: _arrowSlot,
      child: shown
          ? IconButton(
              key: key,
              // One chevron file, mirrored for the backwards direction, so
              // the pair can't drift apart.
              icon: AppGlyph(
                AppIcons.chevronRight,
                size: 32,
                color: colors.ink,
                flipped: flipped,
              ),
              iconSize: 32,
              padding: EdgeInsets.zero,
              color: colors.ink,
              tooltip: l10n.celebrationsNextBlock,
              onPressed: onPressed,
            )
          : null,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(blockLabel, style: styles.subtitle),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The mockup only draws the forward arrow, but a paged grid needs
            // a way back — otherwise the last block is a dead end.
            arrow(
              shown: hasPrevious,
              flipped: true,
              onPressed: onPrevious,
              key: const Key('celebration-previous-block'),
            ),
            Flexible(
              child: SizedBox(
                width: tileSize * _columns + _gap * (_columns - 1),
                child: Wrap(
                  spacing: _gap,
                  runSpacing: _gap,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final celebration in celebrations)
                      _CelebrationTile(
                        key: Key('celebration-${celebration.id}'),
                        celebration: celebration,
                        size: tileSize,
                        unlocked: isUnlocked(celebration),
                        selected: isSelected(celebration),
                        onTap: () => onTap(celebration),
                      ),
                  ],
                ),
              ),
            ),
            arrow(
              shown: hasNext,
              onPressed: onNext,
              key: const Key('celebration-next-block'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CelebrationTile extends StatelessWidget {
  const _CelebrationTile({
    super.key,
    required this.celebration,
    required this.size,
    required this.unlocked,
    required this.selected,
    required this.onTap,
  });

  final Celebration celebration;
  final double size;
  final bool unlocked;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final elevations = context.gameElevations;
    final radius = BorderRadius.circular(size * 0.22);

    return Semantics(
      button: true,
      selected: selected,
      label: [
        celebrationName(l10n, celebration),
        if (!unlocked) l10n.skinLocked else if (selected) l10n.skinSelected,
      ].join(', '),
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: elevations.resting,
            border: selected ? Border.all(color: colors.ink, width: 3) : null,
          ),
          child: Material(
            color: colors.surface,
            borderRadius: radius,
            child: InkWell(
              // Locked celebrations stay tappable — tapping previews one so
              // the player can see what they'd be buying. Equipping is what
              // the lock prevents.
              borderRadius: radius,
              onTap: onTap,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(size * 0.18),
                      child: unlocked
                          ? AssetGlyph(
                              assetPath: celebration.assetPath,
                              fallbackIcon: celebration.fallbackIcon,
                              color: colors.neutral,
                            )
                          : Center(
                              child: CircleAvatar(
                                radius: size * 0.22,
                                backgroundColor: colors.ink,
                                child: AppGlyph(
                                  AppIcons.locked,
                                  size: size * 0.24,
                                  color: colors.surface,
                                  semanticLabel: l10n.skinLocked,
                                ),
                              ),
                            ),
                    ),
                  ),
                  // A tick, not just the outline: a 3pt border on a pale tile
                  // is easy to miss, and easier still to confuse with the
                  // hover/press state.
                  if (selected)
                    Positioned(
                      top: size * 0.06,
                      right: size * 0.06,
                      child: CircleAvatar(
                        radius: size * 0.14,
                        backgroundColor: colors.ink,
                        child: AppGlyph(
                          AppIcons.check,
                          size: size * 0.18,
                          color: colors.surface,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
