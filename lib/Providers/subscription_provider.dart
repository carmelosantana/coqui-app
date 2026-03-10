import 'package:flutter/foundation.dart';

import 'package:coqui_app/Models/plan.dart';
import 'package:coqui_app/Models/subscription.dart';
import 'package:coqui_app/Services/iap_subscription_service.dart';
import 'package:coqui_app/Services/saas_api_service.dart';

/// Manages subscription state across IAP and Stripe purchase sources.
///
/// Coordinates between [IapSubscriptionService] (App Store / Google Play)
/// and [SaasApiService] (Stripe / backend). Provides a unified view of the
/// user's subscription regardless of purchase source.
class SubscriptionProvider extends ChangeNotifier {
  final SaasApiService _apiService;
  final IapSubscriptionService _iapService;

  SubscriptionProvider({
    required SaasApiService apiService,
    required IapSubscriptionService iapService,
  })  : _apiService = apiService,
        _iapService = iapService {
    _iapService.onChanged = () => notifyListeners();
    _iapService.onError = (msg) {
      _lastError = msg;
      notifyListeners();
    };
    _iapService.onSubscriptionVerified = _onSubscriptionVerified;
  }

  // ── State ──────────────────────────────────────────────────────────────

  List<Plan> _plans = [];
  Subscription? _activeSubscription;
  bool _isLoading = false;
  String? _lastError;

  List<Plan> get plans => _plans;
  Subscription? get activeSubscription => _activeSubscription;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get hasActiveSubscription => _activeSubscription?.isActive == true;

  /// IAP system status — exposes whether in-app purchases are available.
  IapStatus get iapStatus => _iapService.status;

  /// Whether IAP is in a purchasing flow.
  bool get isPurchasing => _iapService.purchasing;

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  // ── Initialization ─────────────────────────────────────────────────────

  /// Load plans from the API and initialize IAP products.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _plans = await _apiService.getPlans();
      await _iapService.initialize(_plans);
    } on SaasApiException catch (e) {
      _lastError = 'Failed to load plans: ${e.message}';
    } catch (e) {
      _lastError = 'Failed to initialize subscriptions: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load the current subscription from the backend.
  Future<void> loadSubscription() async {
    if (!_apiService.hasToken) return;

    try {
      final result = await _apiService.getSubscriptions();
      _activeSubscription = result.active;
      notifyListeners();
    } on SaasApiException catch (e) {
      debugPrint('Failed to load subscription: ${e.message}');
    }
  }

  // ── Purchase ───────────────────────────────────────────────────────────

  /// Whether a plan can be purchased via IAP on this device.
  bool canPurchaseViaPlan(int planId) => _iapService.hasPlanProduct(planId);

  /// Get the store price string for a plan (e.g. "$19.99").
  String? getStorePriceForPlan(int planId) {
    return _iapService.getProductForPlan(planId)?.price;
  }

  /// Purchase a subscription via IAP.
  ///
  /// The result arrives asynchronously — listen for [notifyListeners] and
  /// check [activeSubscription] or [lastError].
  Future<bool> purchaseViaPlan(int planId) async {
    clearError();
    return _iapService.purchasePlan(planId);
  }

  /// Restore previous IAP purchases.
  Future<void> restorePurchases() async {
    clearError();
    await _iapService.restorePurchases();
  }

  // ── Internal ───────────────────────────────────────────────────────────

  void _onSubscriptionVerified(Subscription subscription) {
    _activeSubscription = subscription;
    notifyListeners();
  }
}
