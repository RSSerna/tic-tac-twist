# 08 — STORE ITEMS: How to Add Things to the Shop

Developer guide for adding purchasable items to the in-app **Shop**
(`lib/ui/screens/shop_screen.dart`). Read alongside:

- `03-PRODUCT.md` §2–3 — the monetization rules this guide must obey (the *why*).
- `07-SKINS.md` — if the item is a skin, that covers the rendering/unlock side.
- `lib/services/purchase_service.dart` — the IAP plumbing you wire into.

Everything here is additive and cosmetic-only. **No mechanic, mode, or gameplay
advantage is ever sold** (`03-PRODUCT.md` §2). If a proposed item would change
how the game plays, it does not belong in the store.

---

## 1. Decision: direct purchase, not a purchasable currency

**Sell named items for real money. Do not add a currency that players buy with
money.** Recorded here so it isn't relitigated per-item.

Why, for *this* project:

- `03-PRODUCT.md` §2/§3 already require it: *"Anything sold for money must
  remain a specific, named item shown before purchase."* A paid coin/gem pack
  (buy 500 coins → spend on skins) is exactly the indirection that rule avoids —
  it hides each item's real-money cost.
- **Mixed / effectively child-directed audience** (§1, neutral age gate).
  Premium currency is a known dark-pattern flag in kids' monetization and draws
  store + regulator scrutiny.
- **Paid currency + randomness = loot-box exposure** (Belgium/NL enforcement,
  mandatory paid-odds disclosure). The doc deliberately removes that by making
  chests unpurchasable; a buyable currency would reopen it.
- **Small catalog.** A currency economy (wallet, balancing, "not enough coins"
  up-sell funnels, a sink to spend on) only pays off with a large, refreshed
  catalog. For a handful of skins it's pure overhead.

### The one legitimate currency variant

A currency is only a problem when it's **buyable with money.** A *play-only*
soft currency — earned by playing, **never purchasable** — is a fine,
deterministic alternative to chests for the earned route (no randomness, players
pick exactly what they want). If you ever want an "earn and spend" loop, build
*that*, not a paid wallet. The hard line: **no real-money → currency path,
ever.**

### The two routes, mapped to this codebase

| Route | How | Where it's wired |
|---|---|---|
| **Direct purchase** (real money) | A named IAP product | This doc — `ShopItem` + `ProductId` |
| **Earned through play** (free) | Achievement unlock, chest, or play-only soft currency | `07-SKINS.md` §6 (achievements), `03-PRODUCT.md` §3 (chests, still deferred) |

The shop is the **direct-purchase** surface. Earned items don't need a shop
entry unless you also want to sell them.

---

## 2. Anatomy of a store item

Two pieces, one per layer:

```
ShopItem            (presentation)   lib/ui/screens/shop_screen.dart
   └── maps to →
ProductId           (billing)        lib/services/purchase_service.dart
   └── maps to →
storeId string      (the store)      App Store Connect + Play Console
```

- **`ShopItem`** — what the player sees: icon, localized name/description, and a
  price *label*. Today it's UI-only; a real item also carries the `ProductId`
  it sells.
- **`ProductId`** — the app's internal enum of billable products, each with a
  `storeId` (the reverse-DNS identifier registered in both stores).
- **`storeId`** — the actual product you create in each store's console. This is
  the step only you can do; there is **no universal IAP test id** (unlike
  AdMob's test ad units), because every product is registered per-app.

---

## 2a. Sellable cosmetics that exist but have no product yet

Two cosmetic lines are built and carry a locked state, but **neither has a
`ProductId`** — nothing can be bought until products are registered in both
stores (§3 Step 1).

| Cosmetic | Locked entries | Where the unlock lands |
|---|---|---|
| Chip skins (`GameSkin`) | `nesting_dolls` | `SkinController.unlockSkin` — already wired to `ProductId.skinNestingDolls` |
| Emotes (`Emote`) | 6 of 10 (`free: false`) | `EmoteController.unlock` — **no `ProductId` yet** |
| Celebrations (`Celebration`) | 12 of 16 (`free: false`) | `CelebrationController.unlock` — **no `ProductId` yet** |

Both controllers already expose `unlock(...)` and persist it, so the purchase
route is a `ProductId` plus a grant call, not new plumbing. Follow §3 as
written; the grant in Step 4 is `emoteControllerProvider.notifier.unlock(...)`
or `celebrationControllerProvider.notifier.unlock(...)`.

**Decide before building:** whether these sell individually or as packs.
Individually means one `ProductId` and one store product per item, which
grows badly — 12 locked celebrations would mean 12 products. A pack means one
product granting several ids, which is cheaper to run and matches how the
catalogues are laid out (celebrations are already grouped into blocks of 12).
Listed as undecided in `CLAUDE.md`.

**Neither has art yet** (see `07-SKINS.md` §2a). Selling a cosmetic whose art
is still a Material icon fallback would be selling a placeholder — land the
art first. For celebrations, also settle the playback format: a player buying
a "celebration" that never plays has bought nothing.

---

## 3. Recipe — add a directly-purchased item

### Step 1 — Create the product in BOTH stores

- **App Store Connect** → your app → In-App Purchases → **Non-Consumable**
  (cosmetics are one-time, permanent). Set a product id, e.g.
  `dev.rsaldarris.nested.skin_stone_stack`, price tier, name, review screenshot.
- **Google Play Console** → your app → Monetize → Products → **In-app products**
  → create one with the **same** id and price.

Until both exist and are approved, `buy()` cannot complete — the query returns
no product and the call no-ops. That's expected pre-setup.

### Step 2 — Add a `ProductId`

In `lib/services/purchase_service.dart`:

```dart
enum ProductId { removeAds, skinNestingDolls, skinStoneStack } // add

extension ProductIdStoreId on ProductId {
  String get storeId => switch (this) {
        ProductId.removeAds        => 'dev.rsaldarris.nested.remove_ads',
        ProductId.skinNestingDolls => 'dev.rsaldarris.nested.skin_nesting_dolls',
        ProductId.skinStoneStack   => 'dev.rsaldarris.nested.skin_stone_stack', // add
      };
}
```

The `storeId` **must** match what you registered in Step 1, byte for byte.

### Step 3 — Give the `ShopItem` its product and call `buy()`

In `shop_screen.dart`, add an `optional` `ProductId` to `ShopItem` and replace
the placeholder `_buy` with the real call:

```dart
class ShopItem {
  const ShopItem({
    required this.id,
    required this.icon,
    required this.name,
    required this.description,
    required this.priceLabel,
    this.product,               // null = not yet sellable (placeholder)
  });
  final ProductId? product;
  // …
}

// in _ShopItemCard:
void _buy(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
  final product = item.product;
  if (product == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.shopPaymentsUnavailable)));
    return;
  }
  ref.read(purchaseServiceProvider).buy(product); // store shows its own UI
}
```

`PurchaseService.buy()` queries the product, then launches the platform's own
purchase sheet. You never build a payment form — the store owns that flow (and
`_NullPurchaseService` no-ops it on web and under `flutter test`).

### Step 4 — Grant what was bought (never from the button)

**Do not unlock the item in `_buy`.** A purchase can be pending, deferred
(ask-to-buy / parental approval), or restored on another device — the only
source of truth is the `PurchaseService.purchases` stream. Grant there:

```dart
// AdsController._onPurchased (the existing dispatcher for purchase results)
switch (product) {
  case ProductId.removeAds:        await purchases.markRemoved();
  case ProductId.skinNestingDolls: await skins.unlockSkin(GameSkin.nestingDolls);
  case ProductId.skinStoneStack:   await skins.unlockSkin(GameSkin.stoneStack); // add
}
```

This is why granting is decoupled from the tap: the stream also fires for
**restored** purchases (Step 5) and for purchases that complete minutes later.

### Step 5 — Restore purchases

Non-consumables must be re-grantable after a reinstall or on a second device.
`PurchaseService.restorePurchases()` re-emits owned products through the same
`purchases` stream, so Step 4's handler already re-grants them. Surface a
**"Restore purchases"** button wherever the item is sold (the Settings screen
already has one for remove-ads — mirror it). Apple *requires* a visible restore
control for non-consumables.

---

## 4. Pricing & display rules

- **Never hardcode a real price per locale.** The store returns the correct
  currency, amount, and formatting for the user's region. The `priceLabel` on
  the placeholder item (`$0.99`) is a stand-in only.
- Once wired, read the price from the queried product details
  (`ProductDetails.price`, already localized) and show *that*.
- Name and description stay in the ARB files (`shop*` keys), localized like the
  rest of the UI. Add a `shop<Item>Name` / `shop<Item>Desc` pair to **both**
  `app_en.arb` and `app_es.arb`, and a case in the shop's lookup.

---

## 5. Compliance guardrails (must hold for every item)

From `03-PRODUCT.md` — treat as hard requirements, not suggestions:

- **Named, shown-before-purchase.** The player sees exactly what they get. No
  mystery boxes for money, no "spin to win" behind a paywall.
- **Cosmetic only.** Never sell or time-limit anything that touches gameplay.
- **No paid randomness.** Chests are earned-only and unpurchasable; keep it that
  way. If you ever sell a *bundle*, it must be a fixed, listed set — not a random
  draw.
- **Child-audience safe.** No urgency timers, no "currency running low" nags, no
  obscured cost. Direct price, direct item.
- **Restore + offline.** Restore must exist (§3.5); the purchase check must fail
  closed and gracefully offline (the item simply isn't grantable until the store
  is reachable).

---

## 6. Testing checklist

- `flutter analyze` clean — adding a `ProductId` forces the `storeId` switch to
  stay exhaustive (compiler-enforced).
- `flutter test` — `test/ui/shop_test.dart` covers opening the shop and the
  placeholder buy notice. For a real item, assert the tap calls `buy()` by
  overriding `purchaseServiceProvider` with a fake that records the call
  (mirror how the ads/skin tests inject fakes) — the real store can't run in a
  widget test.
- **Sandbox testing** is the only way to exercise a real purchase: a
  StoreKit/TestFlight sandbox account (iOS) or a Play **internal testing** track
  + license tester (Android). This needs Steps 1–2 done first.
- `flutter build web` — the shop must still build; purchases are no-ops on web
  (`_NullPurchaseService`), so the buy button should stay inert there, not
  throw.

---

## 7. Quick checklist

Adding one directly-purchased item, end to end:

- [ ] Create the non-consumable product in **App Store Connect** and **Play
      Console** with a shared `storeId`.
- [ ] Add a `ProductId` + `storeId` mapping in `purchase_service.dart`.
- [ ] Add a `ShopItem` (with its `product`) to the shop catalog; add localized
      name/description to both ARB files.
- [ ] Replace the placeholder `_buy` path with `purchaseServiceProvider.buy()`
      for items that have a product.
- [ ] Grant the unlock in the `purchases`-stream handler (never from the tap).
- [ ] Ensure a **Restore purchases** control is reachable.
- [ ] `flutter analyze`, `flutter test`, then sandbox-test a real purchase.
- [ ] Confirm no compliance guardrail (§5) is violated.
