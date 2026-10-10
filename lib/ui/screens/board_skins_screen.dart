import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/board_skin_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/board_skin.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/app_glyph.dart';
import '../widgets/app_mark.dart';
import '../widgets/board_preview.dart';
import '../widgets/buttons/pill_action_button.dart';
import '../widgets/locked_preview.dart';
import '../widgets/panel_header.dart';
import '../../theme/app_assets.dart';

String boardName(AppLocalizations l10n, BoardSkin skin) => switch (skin) {
  BoardSkin.classic => l10n.boardNameClassic,
  BoardSkin.sandstone => l10n.boardNameSandstone,
  BoardSkin.rock => l10n.boardNameRock,
};

/// Board picker: a large preview, the equip action, and a tile per board.
///
/// Reached from the Custom screen's "Board" category. Tapping a tile only
/// *previews* it — equipping is a separate, deliberate act, and a board that
/// isn't owned can be previewed but not equipped (the controller is the real
/// gate; this just reflects it).
class BoardSkinsScreen extends ConsumerStatefulWidget {
  const BoardSkinsScreen({super.key});

  @override
  ConsumerState<BoardSkinsScreen> createState() => _BoardSkinsScreenState();
}

class _BoardSkinsScreenState extends ConsumerState<BoardSkinsScreen> {
  /// What the preview shows. Starts as the equipped board, then follows
  /// whatever the player taps — including locked ones, so they can see what
  /// they'd be buying. Presentation state.
  BoardSkin? _previewed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final state = ref.watch(boardSkinControllerProvider).value;

    final equipped = state?.selected;
    final previewed = _previewed ?? equipped ?? BoardSkin.defaultChoice;
    final locked = state != null && !state.isUnlocked(previewed);

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: Column(
          children: [
            PanelHeader(
              closeKey: const Key('close-board'),
              icon: AppMark(size: 34, color: colors.neutral),
              title: l10n.categoryBoard,
              subtitle: l10n.boardsSubtitle,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Sized from the space that's actually left, and the body
                  // scrolls — a short screen must not overflow.
                  final previewSide = (constraints.maxHeight * 0.45).clamp(
                    140.0,
                    300.0,
                  );
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 16,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              key: const Key('board-preview'),
                              width: previewSide,
                              height: previewSide,
                              child: LockedPreview(
                                locked: locked,
                                badgeSize: 36,
                                child: BoardPreview(skin: previewed),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              boardName(l10n, previewed).toUpperCase(),
                              style: styles.label,
                            ),
                            const SizedBox(height: 8),
                            _Action(
                              equipped: equipped == previewed,
                              locked: locked,
                              onSelect: () => ref
                                  .read(boardSkinControllerProvider.notifier)
                                  .select(previewed),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final skin in BoardSkin.values)
                                  _Tile(
                                    skin: skin,
                                    locked:
                                        state != null && !state.isUnlocked(skin),
                                    previewed: skin == previewed,
                                    onTap: () =>
                                        setState(() => _previewed = skin),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.boardsScope,
                              textAlign: TextAlign.center,
                              style: styles.labelMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.equipped,
    required this.locked,
    required this.onSelect,
  });

  final bool equipped;
  final bool locked;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;

    if (equipped) {
      return Row(
        key: const Key('board-equipped-status'),
        mainAxisSize: MainAxisSize.min,
        children: [
          AppGlyph(AppIcons.check, size: 16, color: colors.ink),
          const SizedBox(width: 4),
          Text(l10n.boardEquipped, style: styles.label),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Disabled rather than hidden on a locked board: the player can see
        // the action exists and that it's the lock standing in the way.
        PillActionButton(
          key: const Key('board-select'),
          label: locked ? l10n.skinLocked : l10n.skinSelect,
          onPressed: locked ? null : onSelect,
        ),
        if (locked) ...[
          const SizedBox(height: 4),
          Text(
            l10n.boardLockedHint,
            key: const Key('board-locked-hint'),
            textAlign: TextAlign.center,
            style: styles.labelMuted,
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.skin,
    required this.locked,
    required this.previewed,
    required this.onTap,
  });

  final BoardSkin skin;
  final bool locked;
  final bool previewed;
  final VoidCallback onTap;

  static const double size = 76;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;

    return Semantics(
      button: true,
      selected: previewed,
      label: [
        boardName(l10n, skin),
        if (locked) l10n.skinLocked,
      ].join(', '),
      child: ExcludeSemantics(
        child: GestureDetector(
          key: Key('board-tile-${skin.id}'),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              // `ground`, not `surface`: Classic's cells *are* `surface`, and
              // would vanish into a tile of the same colour.
              color: colors.ground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: previewed ? colors.ink : Colors.transparent,
                width: 2,
              ),
            ),
            child: LockedPreview(
              locked: locked,
              badgeSize: 22,
              child: BoardPreview(skin: skin),
            ),
          ),
        ),
      ),
    );
  }
}
