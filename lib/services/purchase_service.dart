import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cosmetic-only purchases (product doc §2: "No mechanic, mode, or gameplay
/// advantage is ever sold or locked"). All are one-time, non-consumable —
/// remove-ads; the Nesting Dolls skin pack (its other unlock route is the
/// Phase 8 achievement set; this is the direct-purchase route design doc
/// §2.2 also names); and the Burger Stack skin pack, which has **no other
/// route** (`GameSkin.purchaseOnly`) — purchase is the only way to own it.
///
/// These IDs are placeholders: they still need matching products created in
/// App Store Connect and the Play Console before a real purchase can
/// complete — creating those is a console action only the developer can do,
/// the same kind of blocker as AdMob's app ID vs. its universal test ad
/// units (test IDs exist for ads; they don't for IAP, since every product
/// must be registered per-app).
enum ProductId { removeAds, skinNestingDolls, skinBurgerStack }

extension ProductIdStoreId on ProductId {
  String get storeId => switch (this) {
        ProductId.removeAds => 'dev.rsaldarris.nested.remove_ads',
        ProductId.skinNestingDolls => 'dev.rsaldarris.nested.skin_nesting_dolls',
        ProductId.skinBurgerStack => 'dev.rsaldarris.nested.skin_burger_stack',
      };
}

abstract interface class PurchaseService {
  Future<bool> storeAvailable();

  /// Completed purchases (including ones restored from a previous install),
  /// as they arrive — the caller persists whatever each one unlocks.
  Stream<ProductId> get purchases;

  Future<void> buy(ProductId product);
  Future<void> restorePurchases();

  Future<bool> isRemoved();
  Future<void> markRemoved();
}

/// No-ops on web (design doc §9: "in_app_purchase is mobile-only... no
/// delivery mechanism" — remove-ads and skin packs simply have nothing to
/// sell there) and under `flutter_test` (in_app_purchase has no real
/// platform channel there, same situation `audioServiceProvider`
/// documents). `kIsWeb` must be checked before `Platform.environment` —
/// that's dart:io, which throws `UnsupportedError` on web rather than
/// simply being unavailable at compile time.
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  if (kIsWeb || Platform.environment['FLUTTER_TEST'] == 'true') {
    return _NullPurchaseService();
  }
  final service = InAppPurchaseService();
  ref.onDispose(service.dispose);
  return service;
});

class InAppPurchaseService implements PurchaseService {
  InAppPurchaseService() {
    _subscription = InAppPurchase.instance.purchaseStream.listen(_onPurchaseUpdate);
  }

  static const _removedKey = 'nested_game.purchases.ads_removed';

  final _purchases = StreamController<ProductId>.broadcast();
  late final StreamSubscription<List<PurchaseDetails>> _subscription;

  @override
  Stream<ProductId> get purchases => _purchases.stream;

  @override
  Future<bool> storeAvailable() => InAppPurchase.instance.isAvailable();

  @override
  Future<void> buy(ProductId product) async {
    final response = await InAppPurchase.instance
        .queryProductDetails({product.storeId});
    final details = response.productDetails.firstOrNull;
    if (details == null) return;
    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
  }

  @override
  Future<void> restorePurchases() => InAppPurchase.instance.restorePurchases();

  @override
  Future<bool> isRemoved() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_removedKey) ?? false;
  }

  @override
  Future<void> markRemoved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_removedKey, true);
  }

  void _onPurchaseUpdate(List<PurchaseDetails> updates) {
    for (final purchase in updates) {
      if (purchase.status != PurchaseStatus.purchased &&
          purchase.status != PurchaseStatus.restored) {
        continue;
      }
      final product = ProductId.values
          .where((p) => p.storeId == purchase.productID)
          .firstOrNull;
      if (product != null) _purchases.add(product);
      if (purchase.pendingCompletePurchase) {
        InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _purchases.close();
  }
}

class _NullPurchaseService implements PurchaseService {
  @override
  Future<bool> storeAvailable() async => false;

  @override
  Stream<ProductId> get purchases => const Stream.empty();

  @override
  Future<void> buy(ProductId product) async {}

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<bool> isRemoved() async => false;

  @override
  Future<void> markRemoved() async {}
}
