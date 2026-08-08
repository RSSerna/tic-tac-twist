import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// A single purchasable entry in the shop.
///
/// For now the catalog holds one placeholder [ShopItem] so the layout and
/// buy flow can be exercised end to end without a real store product. When
/// payments are wired (see [_ShopItemCard._buy]), each real item gains a
/// `ProductId` (from `purchase_service.dart`) and [priceLabel] is replaced by
/// the store's localized price string rather than a hardcoded one.
@immutable
class ShopItem {
  const ShopItem({
    required this.id,
    required this.icon,
    required this.name,
    required this.description,
    required this.priceLabel,
  });

  /// Stable identity — will map 1:1 to a `ProductId.storeId` once real
  /// products exist. Never shown to players.
  final String id;
  final IconData icon;
  final String name;
  final String description;

  /// Placeholder price. Real prices come from the store product details
  /// (currency, formatting, and amount are the store's to decide, never
  /// hardcoded per-locale) once payments are set up.
  final String priceLabel;
}

/// The in-app shop (product doc §2: cosmetic-only, "no mechanic, mode, or
/// gameplay advantage is ever sold"). This is the scaffold: one test item and
/// a buy button whose payment path is still a TODO — see [_ShopItemCard._buy].
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;

    // The catalog. One placeholder entry for now; add real items here once
    // their products exist in the stores (see _ShopItemCard._buy).
    final items = <ShopItem>[
      ShopItem(
        id: 'test_item',
        icon: Icons.card_giftcard,
        name: l10n.shopTestItemName,
        description: l10n.shopTestItemDesc,
        priceLabel: r'$0.99',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shopTitle),
        backgroundColor: colors.ground,
        foregroundColor: colors.ink,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              l10n.shopIntro,
              style: styles.bodyMuted,
            ),
            const SizedBox(height: 20),
            for (final item in items) ...[
              _ShopItemCard(item: item),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShopItemCard extends ConsumerWidget {
  const _ShopItemCard({required this.item});

  final ShopItem item;

  // ---------------------------------------------------------------- payments
  //
  // TODO(payments): wire this button to a real in-app purchase. The plumbing
  // in `lib/services/purchase_service.dart` already exists (PurchaseService,
  // ProductId, the purchases stream); what's missing is store setup, which is
  // a console action only the developer can do:
  //
  //   1. Create the matching non-consumable product in App Store Connect AND
  //      the Play Console. IAP has no universal test ID (unlike AdMob's test
  //      ad units), so a real product must exist per store before a purchase
  //      can complete.
  //   2. Add a `ProductId` for it in `purchase_service.dart` and map its
  //      `storeId` to the id you registered above.
  //   3. Add that `ProductId` to this `ShopItem` and call
  //      `ref.read(purchaseServiceProvider).buy(product)` here instead of the
  //      placeholder snackbar.
  //   4. Grant whatever the item unlocks by listening to
  //      `PurchaseService.purchases` (see `AdsController._onPurchased` for the
  //      existing pattern) — never grant it optimistically from this button.
  //   5. Add a "Restore purchases" action (see the Settings screen) so a
  //      reinstall re-grants non-consumables.
  //
  // Until then this is a placeholder that only confirms the layout/flow.
  void _buy(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.shopPaymentsUnavailable)),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;

    return Material(
      key: Key('shop-item-${item.id}'),
      color: colors.surface,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(item.icon, size: 40, color: colors.ink),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: styles.cardTitle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: styles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: Key('shop-buy-${item.id}'),
              onPressed: () => _buy(context, ref, l10n),
              child: Text('${l10n.shopBuyButton}  ${item.priceLabel}'),
            ),
          ],
        ),
      ),
    );
  }
}
