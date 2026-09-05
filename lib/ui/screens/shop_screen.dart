import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/celebration_controller.dart';
import '../../controllers/chest_controller.dart';
import '../../controllers/daily_challenge_controller.dart';
import '../../controllers/emote_controller.dart';
import '../../controllers/skin_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/daily_challenge_service.dart';
import '../../theme/celebration.dart';
import '../../theme/emote.dart';
import '../../theme/skin.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/app_mark.dart';
import '../widgets/buttons/pill_action_button.dart';
import '../widgets/panel_header.dart';

/// What kind of cosmetic a shop card sells. The badge across the top of a
/// card; also decides which catalogue its "owned" state is read from.
enum ShopItemKind { markX, markO, combo, board, emote, flexing }

/// A single purchasable entry.
///
/// Nothing here is buyable yet: no product exists in either store, so a card
/// the player doesn't own reports that rather than opening a payment sheet
/// (see `08-STORE-ITEMS.md` §3 for what turning one on requires).
@immutable
class ShopItem {
  const ShopItem({
    required this.id,
    required this.kind,
    required this.name,
    this.skin,
    this.emote,
    this.celebration,
  });

  /// Stable identity — maps 1:1 to a `ProductId.storeId` once real products
  /// exist. Never shown to players.
  final String id;
  final ShopItemKind kind;

  /// The pack's display name. A proper noun (FIRE, SAKURA…), so it is not
  /// translated — same rule as the mode names (design system §8).
  final String name;

  /// What owning this pack means, in whichever catalogue it belongs to. All
  /// null on a pack whose contents don't exist yet.
  final GameSkin? skin;
  final Emote? emote;
  final Celebration? celebration;
}

/// The in-app shop (product doc §2: cosmetic-only, "no mechanic, mode, or
/// gameplay advantage is ever sold"), plus the daily claim meter.
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  /// The catalogue. Packs point at real cosmetics where one exists, so their
  /// owned state is truthful rather than decorative.
  static const _items = <ShopItem>[
    ShopItem(
      id: 'fire',
      kind: ShopItemKind.markX,
      name: 'Fire',
      skin: GameSkin.nestingDolls,
    ),
    ShopItem(id: 'apple', kind: ShopItemKind.markO, name: 'Apple'),
    ShopItem(id: 'elements', kind: ShopItemKind.combo, name: 'Elements'),
    ShopItem(id: 'sakura', kind: ShopItemKind.board, name: 'Sakura'),
    ShopItem(
      id: 'troll',
      kind: ShopItemKind.emote,
      name: 'Troll',
      emote: Emote.thinking,
    ),
    ShopItem(
      id: 'loser',
      kind: ShopItemKind.flexing,
      name: 'Loser',
      celebration: Celebration.shrug,
    ),
  ];

  bool _owned(WidgetRef ref, ShopItem item) {
    if (item.skin case final skin?) {
      return ref.watch(skinControllerProvider).value?.isUnlocked(skin) ?? false;
    }
    if (item.emote case final emote?) {
      return ref.watch(emoteControllerProvider).value?.isUnlocked(emote) ??
          false;
    }
    if (item.celebration case final celebration?) {
      return ref
              .watch(celebrationControllerProvider)
              .value
              ?.isUnlocked(celebration) ??
          false;
    }
    // A pack with nothing behind it yet can't be owned.
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, screen) => Column(
            children: [
              PanelHeader(
                closeKey: const Key('close-shop'),
                icon: Icon(Icons.inventory_2, size: 34, color: colors.neutral),
                title: l10n.shopTitle,
                // The blurb wraps to three lines in Spanish on a 320pt screen,
                // and the header then doesn't fit the screen it heads.
                subtitle: screen.maxHeight >= 520 ? l10n.shopIntro : null,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Sized from width alone, and the whole body scrolls — the
                    // header and the claim meter can leave as little as 32pt
                    // here on a small phone, and a card that fought for that
                    // space just overflowed it.
                    final cardWidth = (constraints.maxWidth / 6).clamp(
                      84.0,
                      200.0,
                    );
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth - 48,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                spacing: 16,
                                children: [
                                  for (final item in _items)
                                    _ShopCard(
                                      key: Key('shop-item-${item.id}'),
                                      item: item,
                                      owned: _owned(ref, item),
                                      width: cardWidth,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const _ClaimBar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    super.key,
    required this.item,
    required this.owned,
    required this.width,
  });

  final ShopItem item;
  final bool owned;
  final double width;

  static Widget _badge(BuildContext context, ShopItemKind kind, Color color) {
    final style = context.gameTextStyles.label.copyWith(color: color);
    return switch (kind) {
      // The two marks are separate purchases, so the badge says which one a
      // pack dresses (see SkinPair).
      ShopItemKind.markX => Icon(Icons.close, size: 20, color: color),
      ShopItemKind.markO => Icon(Icons.circle_outlined, size: 20, color: color),
      ShopItemKind.combo => Text('COMBO', style: style),
      ShopItemKind.board => AppMark(size: 20, color: color),
      ShopItemKind.emote => Icon(Icons.emoji_emotions, size: 20, color: color),
      ShopItemKind.flexing => Icon(
        Icons.accessibility_new,
        size: 20,
        color: color,
      ),
    };
  }

  static String _kindLabel(AppLocalizations l10n, ShopItemKind kind) =>
      switch (kind) {
        ShopItemKind.markX => l10n.shopItemMarkX,
        ShopItemKind.markO => l10n.shopItemMarkO,
        ShopItemKind.combo => l10n.shopItemCombo,
        ShopItemKind.board => l10n.shopItemBoard,
        ShopItemKind.emote => l10n.shopItemEmote,
        ShopItemKind.flexing => l10n.shopItemFlexing,
      };

  void _tap(BuildContext context, AppLocalizations l10n) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(owned ? l10n.shopOwned : l10n.shopPaymentsUnavailable),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final elevations = context.gameElevations;
    final radius = BorderRadius.circular(20);
    final bar = width * 0.22;

    return Semantics(
      button: true,
      label: [
        item.name,
        _kindLabel(l10n, item.kind),
        if (owned) l10n.shopOwned,
      ].join(', '),
      child: ExcludeSemantics(
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: colors.ink,
            borderRadius: radius,
            boxShadow: elevations.raised,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _tap(context, l10n),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: bar,
                    child: Center(
                      child: _badge(context, item.kind, colors.surface),
                    ),
                  ),
                  // The art window. Empty until packs carry real art — the
                  // card still shows what kind of thing it is and whether
                  // it's owned.
                  Container(
                    height: width * 0.9,
                    width: double.infinity,
                    color: colors.surface,
                    alignment: Alignment.center,
                    child: owned
                        ? Icon(
                            Icons.check_circle,
                            size: width * 0.28,
                            color: colors.ink,
                          )
                        : Icon(
                            Icons.lock,
                            size: width * 0.24,
                            color: colors.neutral,
                          ),
                  ),
                  SizedBox(
                    height: bar,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          item.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: styles.label.copyWith(color: colors.surface),
                        ),
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

/// The Claim button and the meter that fills with the day's challenges.
class _ClaimBar extends ConsumerWidget {
  const _ClaimBar();

  Future<void> _claim(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final reward = await ref.read(chestControllerProvider).claimDaily();
    if (!context.mounted) return;

    final message = switch (reward) {
      SkinReward() ||
      EmoteReward() ||
      CelebrationReward() => l10n.shopClaimGranted(_rewardName(l10n, reward!)),
      // Claimed, but the player already owns everything there is.
      null => l10n.shopClaimNothingLeft,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _rewardName(AppLocalizations l10n, ChestReward reward) =>
      switch (reward) {
        SkinReward(:final skin) => skin.id,
        EmoteReward(:final emote) => emote.id,
        CelebrationReward(:final celebration) => celebration.id,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final progress =
        ref.watch(dailyChallengeControllerProvider).value ??
        DailyProgress.empty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress.claimed)
            Text(l10n.shopClaimedToday, style: styles.labelMuted)
          else
            PillActionButton(
              key: const Key('shop-claim'),
              label: l10n.shopClaim,
              // Disabled rather than hidden, so the meter under it reads as
              // the thing standing between you and the reward.
              onPressed: progress.canClaim
                  ? () => _claim(context, ref, l10n)
                  : null,
            ),
          const SizedBox(height: 4),
          // The hint wraps to three lines in Spanish on a 320pt screen, which
          // is exactly where there's no room for it. The disabled button and
          // the empty meter already say the same thing.
          if (!progress.canClaim &&
              !progress.claimed &&
              MediaQuery.sizeOf(context).height >= 520)
            Text(
              l10n.shopClaimHint,
              textAlign: TextAlign.center,
              style: styles.caption,
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                progress.isFull
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                color: progress.isFull ? colors.ink : colors.neutral,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    key: const Key('shop-claim-meter'),
                    value: progress.fraction,
                    minHeight: 20,
                    backgroundColor: colors.ink,
                    valueColor: AlwaysStoppedAnimation(colors.surface),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
