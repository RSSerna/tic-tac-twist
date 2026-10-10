import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/board_skin_controller.dart';
import '../../controllers/celebration_controller.dart';
import '../../controllers/chest_controller.dart';
import '../../controllers/daily_challenge_controller.dart';
import '../../controllers/emote_controller.dart';
import '../../controllers/skin_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/purchase_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../theme/board_skin.dart';
import '../../theme/celebration.dart';
import '../../theme/emote.dart';
import '../../theme/rarity.dart';
import '../../theme/skin.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/app_mark.dart';
import '../widgets/asset_glyph.dart';
import '../widgets/board_preview.dart';
import '../widgets/chip_view.dart';
import '../widgets/emote_view.dart';
import '../widgets/locked_preview.dart';
import '../widgets/buttons/pill_action_button.dart';
import '../widgets/panel_header.dart';
import '../widgets/app_glyph.dart';
import '../../theme/app_assets.dart';
import 'chest_reveal_sheet.dart';

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
    this.board,
    this.emote,
    this.celebration,
    this.product,
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
  final BoardSkin? board;
  final Emote? emote;
  final Celebration? celebration;

  /// The store product behind this card, if it has one. Only acted on in debug
  /// builds for now (see [_ShopCard.onBuy]); release builds still report
  /// "payments unavailable" until the product is registered in the stores.
  final ProductId? product;
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
    // One purchase unlocks the skin for either mark (SkinController.unlockSkin
    // isn't per-mark), so this reads as a combo rather than an X- or O-only
    // pack. purchaseOnly: it's the one skin with no achievement/chest route.
    ShopItem(
      id: 'burger',
      kind: ShopItemKind.combo,
      name: 'Burger',
      skin: GameSkin.burgerStack,
      product: ProductId.skinBurgerStack,
    ),
    ShopItem(id: 'elements', kind: ShopItemKind.combo, name: 'Elements'),
    ShopItem(id: 'sakura', kind: ShopItemKind.board, name: 'Sakura'),
    // The first board skin that is sold. Bought through the purchases stream
    // like Burger (`MonetizationController._onPurchased`).
    ShopItem(
      id: 'rock',
      kind: ShopItemKind.board,
      name: 'Rock',
      board: BoardSkin.rock,
      product: ProductId.boardRock,
    ),
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
    if (item.board case final board?) {
      return ref.watch(boardSkinControllerProvider).value?.isUnlocked(board) ??
          false;
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
                icon: AppGlyph(AppIcons.chest, size: 34, color: colors.neutral),
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
                                      // TEMP: debug-only, pairs with the debug
                                      // shortcut in InAppPurchaseService.buy.
                                      onBuy: kDebugMode && item.product != null
                                          ? () => ref
                                                .read(purchaseServiceProvider)
                                                .buy(item.product!)
                                          : null,
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
              // TEMP: remove with _TempRevealTestButton below.
              if (kDebugMode) const _TempRevealTestButton(),
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
    this.onBuy,
    required this.width,
  });

  final ShopItem item;
  final bool owned;
  final double width;

  /// Buys this card's product when tapped while unowned. Null on release
  /// builds and on cards with no product, which fall back to the snackbar.
  final VoidCallback? onBuy;

  static Widget _badge(BuildContext context, ShopItemKind kind, Color color) {
    final style = context.gameTextStyles.label.copyWith(color: color);
    return switch (kind) {
      // The two marks are separate purchases, so the badge says which one a
      // pack dresses (see SkinPair).
      ShopItemKind.markX => Icon(Icons.close, size: 20, color: color),
      ShopItemKind.markO => Icon(Icons.circle_outlined, size: 20, color: color),
      ShopItemKind.combo => Text('COMBO', style: style),
      ShopItemKind.board => AppMark(size: 20, color: color),
      ShopItemKind.emote => AppGlyph(AppIcons.emoji, size: 20, color: color),
      ShopItemKind.flexing => AppGlyph(
        AppIcons.flex,
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

  /// The pack's real art, or a stand-in when none exists yet. A new cosmetic
  /// kind (board skins, later) adds one case here.
  Widget _art(BuildContext context) {
    final colors = context.gameColors;
    if (item.skin case final skin?) {
      return ChipView(
        color: colors.playerA,
        ringColor: colors.surface,
        level: 4,
        isFirstPerson: true,
        appearance: skin.appearance,
      );
    }
    if (item.board case final board?) return BoardPreview(skin: board);
    if (item.emote case final emote?) return EmoteView(emote: emote);
    if (item.celebration case final celebration?) {
      return AssetGlyph(
        assetPath: celebration.assetPath,
        fallbackIcon: celebration.fallbackIcon,
        color: colors.neutral,
      );
    }
    return AppGlyph(AppIcons.skins, size: width * 0.5, color: colors.neutral);
  }

  void _tap(BuildContext context, AppLocalizations l10n) {
    final buy = onBuy;
    if (!owned && buy != null) {
      buy();
      return;
    }
    if (!owned) {
      showCosmeticPreview(
        context,
        art: _art(context),
        title: item.name,
        status: l10n.shopPaymentsUnavailable,
      );
      return;
    }
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
                  // The art window: the pack's real art, badged locked or
                  // owned. Packs with nothing behind them yet show a stand-in
                  // so the card still says what a pack looks like.
                  Container(
                    height: width * 0.9,
                    width: double.infinity,
                    color: colors.surface,
                    padding: EdgeInsets.all(width * 0.12),
                    alignment: Alignment.center,
                    child: LockedPreview(
                      locked: !owned,
                      ownedBadge: owned,
                      badgeSize: width * 0.24,
                      child: _art(context),
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

/// TEMPORARY, debug builds only — delete this class and its one use in
/// [ShopScreen.build]. Plays the chest reveal with a fake fragment reward so
/// the animation can be watched without finishing the day's challenges. Each
/// tap lands on the next rarity tier (Common → Legendary, then around).
/// Touches no real state: nothing is granted, saved or unlocked. The label is
/// hardcoded on purpose — it's throwaway, not user-facing.
class _TempRevealTestButton extends ConsumerStatefulWidget {
  const _TempRevealTestButton();

  @override
  ConsumerState<_TempRevealTestButton> createState() =>
      _TempRevealTestButtonState();
}

class _TempRevealTestButtonState extends ConsumerState<_TempRevealTestButton> {
  int _next = 0;

  void _play() {
    final tier = Rarity.values[_next % Rarity.values.length];
    _next++;
    showChestRevealSheet(
      context,
      ref,
      reward: SkinFragmentReward(
        skin: GameSkin.fragmentShard,
        rarity: tier,
        totalAfter: 42,
        unlockedNow: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: PillActionButton(
        key: const Key('temp-reveal-test'),
        label: 'TEST CHEST REVEAL',
        onPressed: _play,
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

    // Claimed, but every fragment-gated cosmetic is already unlocked.
    if (reward == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.shopClaimNothingLeft)));
      return;
    }

    // Every chest grants fragments, so every claim gets the cycling reveal —
    // unless the OS wants reduced motion, in which case it's the same
    // information in a snackbar rather than a silent grant with no feedback.
    if (!MediaQuery.of(context).disableAnimations) {
      await showChestRevealSheet(context, ref, reward: reward);
      return;
    }
    final required = switch (reward) {
      SkinFragmentReward(:final skin) => skin.fragmentsRequired!,
      EmoteFragmentReward(:final emote) => emote.fragmentsRequired!,
      CelebrationFragmentReward(:final celebration) =>
        celebration.fragmentsRequired!,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.skinFragmentProgress(reward.totalAfter, required)),
        ),
      );
  }

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
              // Dimmed until the meter fills — the same unavailable idiom
              // used for a locked pack, since there's no drawn "empty check".
              Opacity(
                opacity: progress.isFull ? 1 : 0.45,
                child: AppGlyph(
                  AppIcons.check,
                  size: 24,
                  color: progress.isFull ? colors.ink : colors.neutral,
                ),
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
