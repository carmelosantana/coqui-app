import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:coqui_app/Models/billing_event.dart';
import 'package:coqui_app/Models/hosted_instance.dart';
import 'package:coqui_app/Models/plan.dart';
import 'package:coqui_app/Models/region.dart';
import 'package:coqui_app/Models/subscription.dart';
import 'package:coqui_app/Models/user_profile.dart';

/// Exception for SaaS API errors.
class SaasApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  SaasApiException(this.message, {this.statusCode, this.code});

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isRateLimited => statusCode == 429;
  bool get isServerError => statusCode != null && statusCode! >= 500;

  @override
  String toString() => 'SaasApiException: $message (status: $statusCode)';
}

/// HTTP client for the CoquiBot SaaS API (/api/v1/).
///
/// Handles auth, plans, checkout, subscriptions, instances, billing, and user
/// management. All methods throw [SaasApiException] on failure.
class SaasApiService {
  String _baseUrl;
  String _token;

  /// Callback fired on 401 responses — lets AuthProvider trigger logout.
  VoidCallback? onUnauthorized;

  String get baseUrl => _baseUrl;
  String get token => _token;
  bool get hasToken => _token.isNotEmpty;

  SaasApiService({
    String baseUrl = 'https://coquibot.ai',
    String token = '',
  })  : _baseUrl = baseUrl,
        _token = token;

  /// Update the base URL (for dev/staging).
  void setBaseUrl(String url) => _baseUrl = url;

  /// Set the auth token (called after login).
  void setToken(String token) => _token = token;

  /// Clear the auth token (called on logout).
  void clearToken() => _token = '';

  // ── HTTP helpers ────────────────────────────────────────────────────

  Uri _url(String path, [Map<String, String>? query]) {
    return Uri.parse('$_baseUrl/api/v1$path').replace(queryParameters: query);
  }

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

  Map<String, String> get _publicHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Parse a JSON response, handling errors and unwrapping the API envelope.
  /// Returns the unwrapped payload (the value inside `{ "data": ... }`).
  /// Throws [SaasApiException] on HTTP errors.
  dynamic _parseResponse(http.Response response) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
      throw SaasApiException('Unauthorized',
          statusCode: 401, code: 'unauthorized');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw SaasApiException(
        'Invalid server response',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 400) {
      // API returns { error: { code, message } } envelope
      final error = body['error'];
      String message = 'Request failed';
      String? code;
      if (error is Map<String, dynamic>) {
        message = error['message'] as String? ?? message;
        code = error['code'] as String?;
      } else if (error is String) {
        message = error;
      }
      throw SaasApiException(
        message,
        statusCode: response.statusCode,
        code: code,
      );
    }

    // Unwrap { data: ..., meta: ... } API envelope
    if (body.containsKey('data')) {
      return body['data'];
    }

    return body;
  }

  /// Parse a JSON response expecting a Map payload.
  Map<String, dynamic> _parse(http.Response response) {
    final result = _parseResponse(response);
    if (result is Map<String, dynamic>) return result;
    // If the response was successful but not a map, return an empty map
    // (for void-style calls that just check status).
    return <String, dynamic>{};
  }

  /// Parse a JSON response expecting a List payload.
  List<dynamic> _parseList(http.Response response) {
    final result = _parseResponse(response);
    if (result is List) return result;
    return <dynamic>[];
  }

  // ── Auth ────────────────────────────────────────────────────────────

  /// Start GitHub OAuth flow. Returns the URL to open in a browser
  /// and a state token for CSRF validation.
  Future<({String url, String state})> loginGithub({
    String? redirectUri,
  }) async {
    final body = <String, dynamic>{};
    if (redirectUri != null) body['redirectUri'] = redirectUri;

    final response = await http.post(
      _url('/auth/login/github'),
      headers: _publicHeaders,
      body: jsonEncode(body),
    );
    final data = _parse(response);
    return (
      url: data['url'] as String,
      state: data['state'] as String,
    );
  }

  /// Exchange GitHub OAuth code for an API token.
  Future<({UserProfile user, String token})> callbackGithub({
    required String code,
    required String state,
  }) async {
    final response = await http.post(
      _url('/auth/callback/github'),
      headers: _publicHeaders,
      body: jsonEncode({'code': code, 'state': state}),
    );
    final data = _parse(response);
    return (
      user: UserProfile.fromJson(data['user'] as Map<String, dynamic>),
      token: data['token'] as String,
    );
  }

  /// Get the currently authenticated user's profile.
  Future<UserProfile> getMe() async {
    final response = await http.get(
      _url('/auth/me'),
      headers: _authHeaders,
    );
    final data = _parse(response);
    return UserProfile.fromJson(data);
  }

  // ── Plans (public) ──────────────────────────────────────────────────

  /// List all active hosting plans.
  Future<List<Plan>> getPlans() async {
    final response = await http.get(
      _url('/plans'),
      headers: _publicHeaders,
    );
    final plans = _parseList(response);
    return plans.map((p) => Plan.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// Get a single plan by ID.
  Future<Plan> getPlan(int id) async {
    final response = await http.get(
      _url('/plans/$id'),
      headers: _publicHeaders,
    );
    final data = _parse(response);
    return Plan.fromJson(data);
  }

  // ── Regions (public) ────────────────────────────────────────────────

  /// List available server regions.
  Future<List<Region>> getRegions() async {
    final response = await http.get(
      _url('/regions'),
      headers: _publicHeaders,
    );
    final regions = _parseList(response);
    return regions
        .map((r) => Region.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // ── Checkout ────────────────────────────────────────────────────────

  /// Create a Stripe checkout session. Returns the checkout URL.
  Future<({String checkoutUrl, String sessionId})> createCheckout({
    required int planId,
    String? successUrl,
    String? cancelUrl,
  }) async {
    final body = <String, dynamic>{'planId': planId};
    if (successUrl != null) body['successUrl'] = successUrl;
    if (cancelUrl != null) body['cancelUrl'] = cancelUrl;

    final response = await http.post(
      _url('/checkout'),
      headers: _authHeaders,
      body: jsonEncode(body),
    );
    final data = _parse(response);
    return (
      checkoutUrl: data['checkoutUrl'] as String,
      sessionId: data['sessionId'] as String,
    );
  }

  /// Verify an IAP receipt and create a subscription.
  Future<Subscription> verifyIapReceipt({
    required String platform,
    required String receiptData,
    required String productId,
  }) async {
    final response = await http.post(
      _url('/checkout/iap'),
      headers: _authHeaders,
      body: jsonEncode({
        'platform': platform,
        'receiptData': receiptData,
        'productId': productId,
      }),
    );
    final data = _parse(response);
    return Subscription.fromJson(data['subscription'] as Map<String, dynamic>);
  }

  // ── Subscriptions ───────────────────────────────────────────────────

  /// Get user's subscriptions (active + history).
  Future<({Subscription? active, List<Subscription> history})>
      getSubscriptions() async {
    final response = await http.get(
      _url('/subscriptions'),
      headers: _authHeaders,
    );
    final data = _parse(response);
    return (
      active: data['active'] != null
          ? Subscription.fromJson(data['active'] as Map<String, dynamic>)
          : null,
      history: (data['history'] as List)
          .map((s) => Subscription.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Get a single subscription by ID.
  Future<Subscription> getSubscription(int id) async {
    final response = await http.get(
      _url('/subscriptions/$id'),
      headers: _authHeaders,
    );
    final data = _parse(response);
    return Subscription.fromJson(data);
  }

  /// Cancel a subscription (sets cancel_at_period_end).
  Future<void> cancelSubscription(int id) async {
    final response = await http.post(
      _url('/subscriptions/$id'),
      headers: _authHeaders,
      body: jsonEncode({'action': 'cancel'}),
    );
    _parse(response);
  }

  /// Reactivate a subscription that was set to cancel.
  Future<void> reactivateSubscription(int id) async {
    final response = await http.post(
      _url('/subscriptions/$id'),
      headers: _authHeaders,
      body: jsonEncode({'action': 'reactivate'}),
    );
    _parse(response);
  }

  // ── Instances ───────────────────────────────────────────────────────

  /// List user's hosted instances.
  Future<List<HostedInstance>> getInstances() async {
    final response = await http.get(
      _url('/instances'),
      headers: _authHeaders,
    );
    final instances = _parseList(response);
    return instances
        .map((i) => HostedInstance.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  /// Deploy a new hosted instance.
  Future<HostedInstance> deployInstance({
    required String label,
    String? region,
  }) async {
    final body = <String, dynamic>{'label': label};
    if (region != null) body['region'] = region;

    final response = await http.post(
      _url('/instances'),
      headers: _authHeaders,
      body: jsonEncode(body),
    );
    final data = _parse(response);
    return HostedInstance.fromJson(data);
  }

  /// Get a single hosted instance by ID.
  Future<HostedInstance> getInstance(int id) async {
    final response = await http.get(
      _url('/instances/$id'),
      headers: _authHeaders,
    );
    final data = _parse(response);
    return HostedInstance.fromJson(data['instance'] as Map<String, dynamic>);
  }

  /// Destroy a hosted instance.
  Future<void> destroyInstance(int id) async {
    final response = await http.delete(
      _url('/instances/$id'),
      headers: _authHeaders,
    );
    _parse(response);
  }

  /// Perform an action on a hosted instance (start, stop, reboot, backup, restore).
  Future<void> instanceAction(
    int id,
    String action, {
    String? snapshotId,
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (snapshotId != null) body['snapshotId'] = snapshotId;
    if (description != null) body['description'] = description;

    final response = await http.post(
      _url('/instances/$id/$action'),
      headers: _authHeaders,
      body: jsonEncode(body),
    );
    _parse(response);
  }

  /// Get snapshots for a hosted instance.
  Future<List<InstanceSnapshot>> getSnapshots(int id) async {
    final response = await http.get(
      _url('/instances/$id/snapshots'),
      headers: _authHeaders,
    );
    final snapshots = _parseList(response);
    return snapshots
        .map((s) => InstanceSnapshot.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Get metrics for a hosted instance.
  Future<List<InstanceMetric>> getMetrics(int id, {int hours = 24}) async {
    final since =
        DateTime.now().subtract(Duration(hours: hours)).toIso8601String();
    final response = await http.get(
      _url('/instances/$id/metrics', {'since': since}),
      headers: _authHeaders,
    );
    final metrics = _parseList(response);
    return metrics
        .map((m) => InstanceMetric.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  // ── Billing ─────────────────────────────────────────────────────────

  /// Get billing event history.
  Future<List<BillingEvent>> getBillingHistory() async {
    final response = await http.get(
      _url('/billing'),
      headers: _authHeaders,
    );
    final events = _parseList(response);
    return events
        .map((e) => BillingEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a Stripe billing portal session. Returns the portal URL.
  Future<String> getPortalUrl() async {
    final response = await http.post(
      _url('/billing/portal'),
      headers: _authHeaders,
      body: jsonEncode({}),
    );
    final data = _parse(response);
    return data['portalUrl'] as String;
  }

  // ── User ────────────────────────────────────────────────────────────

  /// Get user profile.
  Future<UserProfile> getProfile() async {
    final response = await http.get(
      _url('/user'),
      headers: _authHeaders,
    );
    final data = _parse(response);
    return UserProfile.fromJson(data);
  }

  /// Update user profile.
  Future<UserProfile> updateProfile({
    String? displayName,
    String? sshPublicKey,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (sshPublicKey != null) body['sshPublicKey'] = sshPublicKey;

    final response = await http.patch(
      _url('/user'),
      headers: _authHeaders,
      body: jsonEncode(body),
    );
    final data = _parse(response);
    return UserProfile.fromJson(data);
  }

  /// Regenerate API token. Returns the new token.
  Future<String> regenerateToken() async {
    final response = await http.post(
      _url('/user/token'),
      headers: _authHeaders,
      body: jsonEncode({}),
    );
    final data = _parse(response);
    return data['token'] as String;
  }
}
