import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:coqui_app/Platform/platform_info.dart';

/// Product identifiers for one-time supporter donations.
///
/// All tiers unlock the same perks — they're just different donation amounts.
class SupporterProducts {
  static const small = 'coqui_supporter_small';
  static const medium = 'coqui_supporter_medium';
  static const large = 'coqui_supporter_large';

  static const allIds = {small, medium, large};
}

/// Wraps the `in_app_purchase` plugin for iOS supporter donations.
///
/// On non-iOS platforms this is a no-op — all purchase methods return
/// immediately without interacting with any store.
class PurchaseService {
  final _settingsBox = Hive.box('settings');
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Products fetched from the App Store.
  List<ProductDetails> products = [];

  /// Whether the store is available and ready.
  bool storeAvailable = false;

  /// Callback fired when supporter status changes.
  VoidCallback? onSupporterStatusChanged;

  /// Callback fired when a purchase fails with an error message.
  void Function(String message)? onPurchaseError;

  /// Callback fired when products are loaded.
  VoidCallback? onProductsLoaded;

  // ── Hive keys ──────────────────────────────────────────────────────────

  static const _isSupporterKey = 'is_supporter';

  bool get isSupporter =>
      _settingsBox.get(_isSupporterKey, defaultValue: false);

  // ── Lifecycle ──────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (!PlatformInfo.isIOS) return;

    final iap = InAppPurchase.instance;
    storeAvailable = await iap.isAvailable();
    if (!storeAvailable) return;

    // Listen for purchase updates (completions, failures, restores).
    _subscription = iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (_) {},
    );

    await _loadProducts();
  }

  void dispose() {
    _subscription?.cancel();
  }

  // ── Public API ─────────────────────────────────────────────────────────

  /// Initiate a purchase for the given product ID.
  Future<bool> purchase(String productId) async {
    if (!PlatformInfo.isIOS || !storeAvailable) return false;

    final product = products.cast<ProductDetails?>().firstWhere(
          (p) => p!.id == productId,
          orElse: () => null,
        );
    if (product == null) return false;

    final purchaseParam = PurchaseParam(productDetails: product);
    // Non-consumable: user buys once, unlocks forever.
    return InAppPurchase.instance
        .buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Restore previous purchases (e.g. after reinstall / new device).
  Future<void> restorePurchases() async {
    if (!PlatformInfo.isIOS || !storeAvailable) return;
    await InAppPurchase.instance.restorePurchases();
  }

  // ── Internals ──────────────────────────────────────────────────────────

  Future<void> _loadProducts() async {
    final response = await InAppPurchase.instance
        .queryProductDetails(SupporterProducts.allIds);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('IAP: products not found: ${response.notFoundIDs.join(', ')}');
    }
    products = response.productDetails
      ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    onProductsLoaded?.call();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      // Grant supporter status.
      await _settingsBox.put(_isSupporterKey, true);
      onSupporterStatusChanged?.call();
    } else if (purchase.status == PurchaseStatus.error) {
      onPurchaseError?.call(
          purchase.error?.message ?? 'Purchase failed. Please try again.');
    }

    // Always complete pending purchases to avoid store warnings.
    if (purchase.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(purchase);
    }
  }
}
