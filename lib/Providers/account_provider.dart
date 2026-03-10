import 'package:flutter/material.dart';

import 'package:coqui_app/Models/billing_event.dart';
import 'package:coqui_app/Models/plan.dart';
import 'package:coqui_app/Models/subscription.dart';
import 'package:coqui_app/Models/user_profile.dart';
import 'package:coqui_app/Services/saas_api_service.dart';

/// Manages subscription, billing, and profile state.
class AccountProvider extends ChangeNotifier {
  final SaasApiService _api;

  Subscription? _activeSubscription;
  List<Subscription> _subscriptionHistory = [];
  List<Plan> _plans = [];
  List<BillingEvent> _billingEvents = [];
  UserProfile? _profile;
  bool _isLoading = false;
  String? _error;

  Subscription? get activeSubscription => _activeSubscription;
  List<Subscription> get subscriptionHistory => _subscriptionHistory;
  List<Plan> get plans => _plans;
  List<BillingEvent> get billingEvents => _billingEvents;
  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get hasSubscription => _activeSubscription != null;
  bool get hasActivePlan =>
      _activeSubscription != null && _activeSubscription!.isActive;

  AccountProvider({required SaasApiService api}) : _api = api;

  /// Load all account data (subscriptions, plans, billing, profile).
  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadSubscriptions(),
        _loadPlans(),
        _loadBilling(),
        _loadProfile(),
      ]);
    } catch (e) {
      _error = 'Failed to load account data.';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh subscriptions only.
  Future<void> refreshSubscriptions() async {
    try {
      await _loadSubscriptions();
      notifyListeners();
    } on SaasApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  /// Refresh plans only.
  Future<void> refreshPlans() async {
    try {
      await _loadPlans();
      notifyListeners();
    } on SaasApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  /// Cancel the active subscription.
  Future<bool> cancelSubscription() async {
    if (_activeSubscription == null) return false;
    try {
      await _api.cancelSubscription(_activeSubscription!.id);
      await _loadSubscriptions();
      notifyListeners();
      return true;
    } on SaasApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Reactivate a subscription set to cancel.
  Future<bool> reactivateSubscription() async {
    if (_activeSubscription == null) return false;
    try {
      await _api.reactivateSubscription(_activeSubscription!.id);
      await _loadSubscriptions();
      notifyListeners();
      return true;
    } on SaasApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Update user profile fields.
  Future<bool> updateProfile(
      {String? displayName, String? sshPublicKey}) async {
    try {
      _profile = await _api.updateProfile(
        displayName: displayName,
        sshPublicKey: sshPublicKey,
      );
      notifyListeners();
      return true;
    } on SaasApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Regenerate the API token. Returns the new token.
  Future<String?> regenerateToken() async {
    try {
      final token = await _api.regenerateToken();
      notifyListeners();
      return token;
    } on SaasApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  /// Open the Stripe billing portal.
  Future<String?> getPortalUrl() async {
    try {
      return await _api.getPortalUrl();
    } on SaasApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Private loaders ─────────────────────────────────────────────────

  Future<void> _loadSubscriptions() async {
    try {
      final result = await _api.getSubscriptions();
      _activeSubscription = result.active;
      _subscriptionHistory = result.history;
    } on SaasApiException catch (e) {
      if (!e.isUnauthorized) rethrow;
    }
  }

  Future<void> _loadPlans() async {
    _plans = await _api.getPlans();
  }

  Future<void> _loadBilling() async {
    try {
      _billingEvents = await _api.getBillingHistory();
    } on SaasApiException catch (e) {
      if (!e.isUnauthorized) rethrow;
    }
  }

  Future<void> _loadProfile() async {
    try {
      _profile = await _api.getProfile();
    } on SaasApiException catch (e) {
      if (!e.isUnauthorized) rethrow;
    }
  }
}
