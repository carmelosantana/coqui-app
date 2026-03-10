import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:coqui_app/Models/plan.dart';
import 'package:coqui_app/Models/subscription.dart';
import 'package:coqui_app/Platform/platform_info.dart';
import 'package:coqui_app/Services/saas_api_service.dart';

/// Status of the IAP subscription system.
enum IapStatus {
  /// Not yet initialized.
  uninitialized,

  /// Store is available and products are loaded.
  ready,

  /// Store is available but no subscription products were found.
  ///
  /// This happens when App Store / Google Play product listings haven't been
  /// configured yet. The app continues to work — users can subscribe via
  /// Stripe on the web instead.
  noProducts,

  /// Store is not available on this platform (web, desktop, etc.).
  unavailable,

  /// Store initialization failed.
  error,
}

/// Manages IAP auto-renewable subscriptions for hosting plans.
///
/// Works alongside [PurchaseService] (which handles one-time supporter
/// donations). This service handles subscription products only, verifying
/// receipts with the SaaS API backend.
///
/// Graceful degradation:
/// - On unsupported platforms → [IapStatus.unavailable], all methods no-op.
/// - If store products aren't configured → [IapStatus.noProducts], purchase
///   methods return false with a user-friendly error via [onError].
/// - If the SaaS API is unreachable during verification → purchase is still
///   completed with the store, and the error is surfaced for retry.
class IapSubscriptionService {
  final SaasApiService _apiService;

  IapSubscriptionService({required SaasApiService apiService})
      : _apiService = apiService;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Current IAP system status.
  IapStatus status = IapStatus.uninitialized;

  /// Subscription products fetched from the store, keyed by plan ID.
  ///
  /// Only contains plans that have a matching store product configured.
  final Map<int, ProductDetails> productsByPlanId = {};

  /// All loaded store products.
  List<ProductDetails> products = [];

  /// Whether a purchase or verification is in progress.
  bool purchasing = false;

  /// Callback fired when status, products, or purchasing state changes.
  VoidCallback? onChanged;

  /// Callback fired on errors with a user-facing message.
  void Function(String message)? onError;

  /// Callback fired when a subscription is successfully verified.
  void Function(Subscription subscription)? onSubscriptionVerified;

  // ── Lifecycle ──────────────────────────────────────────────────────────

  /// Initialize the IAP subscription system.
  ///
  /// Loads subscription products from the store based on the provided [plans]
  /// from the SaaS API. Plans without IAP product IDs are silently skipped.
  Future<void> initialize(List<Plan> plans) async {
    if (!_isSupportedPlatform) {
      status = IapStatus.unavailable;
      onChanged?.call();
      return;
    }

    try {
      final iap = InAppPurchase.instance;
      final available = await iap.isAvailable();
      if (!available) {
        status = IapStatus.unavailable;
        onChanged?.call();
        return;
      }

      // Listen for purchase updates.
      _subscription = iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (Object error) {
          debugPrint('IAP subscription stream error: $error');
        },
      );

      await _loadProducts(plans);
    } catch (e) {
      debugPrint('IAP subscription initialization failed: $e');
      status = IapStatus.error;
      onChanged?.call();
    }
  }

  void dispose() {
    _subscription?.cancel();
  }

  // ── Public API ─────────────────────────────────────────────────────────

  /// Whether IAP subscriptions are available for purchase.
  bool get isAvailable => status == IapStatus.ready;

  /// Whether the given plan has an IAP product configured in the store.
  bool hasPlanProduct(int planId) => productsByPlanId.containsKey(planId);

  /// Get the store product for a plan, if available.
  ProductDetails? getProductForPlan(int planId) => productsByPlanId[planId];

  /// Purchase a subscription for the given plan.
  ///
  /// Returns `true` if the purchase was initiated, `false` if it couldn't
  /// be started. The actual result arrives asynchronously via purchase
  /// stream events.
  Future<bool> purchasePlan(int planId) async {
    if (!_isSupportedPlatform) {
      onError?.call('In-app purchases are not available on this platform.');
      return false;
    }

    if (status == IapStatus.noProducts) {
      onError?.call(
        'Subscription products are not yet available in the app store. '
        'Please subscribe at coquibot.ai instead.',
      );
      return false;
    }

    if (status != IapStatus.ready) {
      onError?.call('The app store is not available. Please try again later.');
      return false;
    }

    final product = productsByPlanId[planId];
    if (product == null) {
      onError?.call(
        'This plan is not available for in-app purchase. '
        'Please subscribe at coquibot.ai instead.',
      );
      return false;
    }

    if (purchasing) {
      onError?.call('A purchase is already in progress.');
      return false;
    }

    purchasing = true;
    onChanged?.call();

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      // Auto-renewable subscription.
      return await InAppPurchase.instance
          .buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      purchasing = false;
      onChanged?.call();
      onError?.call('Failed to start purchase: ${e.toString()}');
      return false;
    }
  }

  /// Restore previous subscription purchases.
  Future<void> restorePurchases() async {
    if (!_isSupportedPlatform || status == IapStatus.unavailable) return;

    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      onError?.call('Failed to restore purchases: ${e.toString()}');
    }
  }

  // ── Internals ──────────────────────────────────────────────────────────

  bool get _isSupportedPlatform => PlatformInfo.isIOS || PlatformInfo.isAndroid;

  String get _platform {
    if (PlatformInfo.isIOS) return 'apple';
    if (PlatformInfo.isAndroid) return 'google';
    return 'unknown';
  }

  /// Build a set of store product IDs from the plans and load them.
  Future<void> _loadProducts(List<Plan> plans) async {
    final productIdToPlan = <String, Plan>{};

    for (final plan in plans) {
      final productId = _productIdForPlan(plan);
      if (productId != null) {
        productIdToPlan[productId] = plan;
      }
    }

    if (productIdToPlan.isEmpty) {
      // No plans have IAP product IDs configured for this platform.
      status = IapStatus.noProducts;
      debugPrint(
        'IAP: No subscription products configured for $_platform. '
        'Users can subscribe via web/Stripe.',
      );
      onChanged?.call();
      return;
    }

    final response = await InAppPurchase.instance
        .queryProductDetails(productIdToPlan.keys.toSet());

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint(
        'IAP: Subscription products not found in store: '
        '${response.notFoundIDs.join(', ')}. '
        'Ensure these are configured in App Store Connect / Google Play Console.',
      );
    }

    products = response.productDetails
      ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

    // Map loaded products back to their plan IDs.
    for (final product in products) {
      final plan = productIdToPlan[product.id];
      if (plan != null) {
        productsByPlanId[plan.id] = product;
      }
    }

    status = products.isEmpty ? IapStatus.noProducts : IapStatus.ready;
    onChanged?.call();

    if (status == IapStatus.noProducts) {
      debugPrint(
        'IAP: All subscription product IDs were configured but none found '
        'in the store. Verify product listings are approved and active.',
      );
    }
  }

  /// Get the platform-specific product ID for a plan.
  String? _productIdForPlan(Plan plan) {
    if (PlatformInfo.isIOS) return plan.iapAppleProductId;
    if (PlatformInfo.isAndroid) return plan.iapGoogleProductId;
    return null;
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _verifyWithBackend(purchase);
      case PurchaseStatus.error:
        purchasing = false;
        onChanged?.call();
        onError?.call(
          purchase.error?.message ?? 'Purchase failed. Please try again.',
        );
      case PurchaseStatus.pending:
        // Purchase is pending (e.g. waiting for parental approval).
        debugPrint('IAP: Purchase pending for ${purchase.productID}');
      case PurchaseStatus.canceled:
        purchasing = false;
        onChanged?.call();
    }

    // Always complete pending purchases to avoid store warnings.
    if (purchase.pendingCompletePurchase) {
      await InAppPurchase.instance.completePurchase(purchase);
    }
  }

  /// Verify the purchase receipt with the SaaS backend.
  Future<void> _verifyWithBackend(PurchaseDetails purchase) async {
    try {
      // Extract receipt data based on platform.
      final receiptData = _extractReceiptData(purchase);
      if (receiptData == null) {
        purchasing = false;
        onChanged?.call();
        onError?.call(
          'Could not extract receipt data. '
          'Please contact support if this persists.',
        );
        return;
      }

      final subscription = await _apiService.verifyIapReceipt(
        platform: _platform,
        receiptData: receiptData,
        productId: purchase.productID,
      );

      purchasing = false;
      onChanged?.call();
      onSubscriptionVerified?.call(subscription);
    } on SaasApiException catch (e) {
      purchasing = false;
      onChanged?.call();

      if (e.isUnauthorized) {
        onError?.call('Please sign in to verify your subscription.');
      } else {
        onError?.call(
          'Subscription verification failed: ${e.message}. '
          'Your purchase is safe — please try restoring purchases later.',
        );
      }
    } catch (e) {
      purchasing = false;
      onChanged?.call();
      onError?.call(
        'Could not verify subscription with server. '
        'Your purchase is safe — please try restoring purchases later.',
      );
    }
  }

  /// Extract the receipt / verification data from the purchase.
  String? _extractReceiptData(PurchaseDetails purchase) {
    // verificationData.serverVerificationData contains:
    // - iOS: the App Store receipt (base64)
    // - Android: the purchase token
    final data = purchase.verificationData.serverVerificationData;
    return data.isNotEmpty ? data : null;
  }
}
