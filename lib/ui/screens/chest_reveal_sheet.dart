import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/chest_controller.dart';
import '../../controllers/chest_reveal_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/rarity.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/rarity_display.dart';
import 'celebration_skins_screen.dart' show celebrationName;
import 'chip_skins_screen.dart' show skinName;
import 'emote_skins_screen.dart' show emoteName;

/// Starts the cycling reveal and shows it modally. [reward] must be one of
/// [ChestReward]'s three fragment variants — a whole-cosmetic unlock has no
/// rarity of its own to reveal (`ChestController`'s doc comment), so
/// `_ClaimBar._claim` never calls this for the other three.
Future<void> showChestRevealSheet(
  BuildContext context,
  WidgetRef ref, {
  required ChestReward reward,
}) {
  final rarity = switch (reward) {
    SkinFragmentReward(:final rarity) => rarity,
    EmoteFragmentReward(:final rarity) => rarity,
    CelebrationFragmentReward(:final rarity) => rarity,
    SkinReward() ||
    EmoteReward() ||
    CelebrationReward() => throw ArgumentError(
      'showChestRevealSheet requires a fragment reward',
    ),
  };
  ref.read(chestRevealControllerProvider.notifier).start(rarity);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ChestRevealDialog(reward: reward),
  );
}

/// What the sheet actually shows, pulled out of whichever fragment variant
/// [reward] is — one lookup instead of three near-identical widget branches.
({String name, Rarity rarity, int amount, int totalAfter, int required})
_details(AppLocalizations l10n, ChestReward reward) => switch (reward) {
  SkinFragmentReward(:final skin, :final rarity, :final totalAfter) => (
    name: skinName(l10n, skin),
    rarity: rarity,
    amount: rarity.fragments,
    totalAfter: totalAfter,
    required: skin.fragmentsRequired!,
  ),
  EmoteFragmentReward(:final emote, :final rarity, :final totalAfter) => (
    name: emoteName(l10n, emote),
    rarity: rarity,
    amount: rarity.fragments,
    totalAfter: totalAfter,
    required: emote.fragmentsRequired!,
  ),
  CelebrationFragmentReward(
    :final celebration,
    :final rarity,
    :final totalAfter,
  ) =>
    (
      name: celebrationName(l10n, celebration),
      rarity: rarity,
      amount: rarity.fragments,
      totalAfter: totalAfter,
      required: celebration.fragmentsRequired!,
    ),
  SkinReward() || EmoteReward() || CelebrationReward() => throw ArgumentError(
    'not a fragment reward',
  ),
};

class _ChestRevealDialog extends ConsumerWidget {
  const _ChestRevealDialog({required this.reward});

  final ChestReward reward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revealState = ref.watch(chestRevealControllerProvider);
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;

    // The controller clears its state on auto-dismiss or a post-landing
    // tap; when it does, close the dialog that's showing it.
    ref.listen<ChestRevealState?>(chestRevealControllerProvider, (
      previous,
      next,
    ) {
      if (previous != null && next == null) {
        Navigator.of(context).maybePop();
      }
    });

    // A stray frame between the controller clearing and the pop landing.
    if (revealState == null) return const SizedBox.shrink();

    final details = _details(l10n, reward);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final controller = ref.read(chestRevealControllerProvider.notifier);
        if (revealState.phase == ChestRevealPhase.landed) {
          controller.dismiss();
        } else {
          controller.skipToLanded();
        }
      },
      child: Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  for (final tier in Rarity.values)
                    _TierPill(
                      tier: tier,
                      lit: tier == revealState.displayedTier,
                    ),
                ],
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: reduceMotion
                    ? Duration.zero
                    : context.gameAnimations.chestRevealLanding,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  child: child,
                ),
                child: revealState.phase == ChestRevealPhase.landed
                    ? Column(
                        key: const ValueKey('landed'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rarityName(l10n, details.rarity).toUpperCase(),
                            style: styles.cardTitle.copyWith(
                              color: rarityColor(context, details.rarity),
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('+${details.amount}', style: styles.display),
                          const SizedBox(height: 4),
                          Text(details.name, style: styles.label),
                          const SizedBox(height: 4),
                          Text(
                            l10n.skinFragmentProgress(
                              details.totalAfter,
                              details.required,
                            ),
                            style: styles.caption,
                          ),
                        ],
                      )
                    : const SizedBox(key: ValueKey('cycling'), height: 112),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TierPill extends StatelessWidget {
  const _TierPill({required this.tier, required this.lit});

  final Rarity tier;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final accent = rarityColor(context, tier);

    return AnimatedContainer(
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : ChestRevealController.tick,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: lit ? accent.withValues(alpha: 0.16) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent, width: lit ? 2 : 1),
      ),
      child: Text(
        rarityName(l10n, tier).toUpperCase(),
        style: styles.caption.copyWith(
          color: lit ? accent : colors.neutral,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
