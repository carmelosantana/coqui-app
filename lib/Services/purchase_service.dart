import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Product identifiers for one-time supporter donations.
///
/// All tiers unlock the same perks — they're just different donation amounts.
class SupporterProducts {
  static const small = 'coqui_supporter_small';
  static const medium = 'coqui_supporter_medium';
  static const large = 'coqui_supporter_large';

  static const allIds = {small, medium, large};
}

/// Stub replacing [ProductDetails] from in_app_purchase while IAP is disabled.
///
/// Re-enable by restoring the `in_app_purchase` dependency and reverting this
/// file to the original implementation.
class StubProductDetails {
  final String id;
  final String price;
  final double rawPrice;

  const StubProductDetails({
    required this.id,
    required this.price,
    this.rawPrice = 0.0,
  });
}

/// Wraps the `in_app_purchase` plugin for iOS supporter donations.
///
/// Currently stubbed — IAP is disabled until the native purchase flow is restored.
/// On all platforms this is a no-op.
// TODO: Restore in_app_purchase dependency and revert this file for IAP launch.
class PurchaseService {
  final _settingsBox = Hive.box('settings');

  /// Products fetched from the App Store.
  List<StubProductDetails> products = [];

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
    // No-op while IAP is disabled.
  }

  void dispose() {
    // No-op while IAP is disabled.
  }

  // ── Public API ─────────────────────────────────────────────────────────

  /// Initiate a purchase for the given product ID.
  Future<bool> purchase(String productId) async {
    // No-op while IAP is disabled.
    return false;
  }

  /// Restore previous purchases (e.g. after reinstall / new device).
  Future<void> restorePurchases() async {
    // No-op while IAP is disabled.
  }
}
