import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:coqui_app/Models/user_profile.dart';
import 'package:coqui_app/Services/saas_api_service.dart';

/// Manages the GitHub OAuth flow and secure token storage.
///
/// Persists the SaaS API token in platform secure storage (Keychain on iOS,
/// KeyStore on Android). On web, falls back to sessionStorage.
class AuthService {
  final SaasApiService _api;
  final FlutterSecureStorage _storage;

  // Keys for secure storage
  static const _tokenKey = 'saas_api_token';
  static const _userIdKey = 'saas_user_id';

  /// Pending OAuth state for CSRF validation.
  String? _pendingOAuthState;

  AuthService({
    required SaasApiService api,
    FlutterSecureStorage? storage,
  })  : _api = api,
        _storage = storage ?? const FlutterSecureStorage();

  /// Load a persisted token and configure the API service.
  /// Returns the token if found, null otherwise.
  Future<String?> restoreToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) {
        _api.setToken(token);
        return token;
      }
    } catch (e) {
      debugPrint('AuthService: Failed to restore token: $e');
    }
    return null;
  }

  /// Start the GitHub OAuth flow by opening the browser.
  /// Returns the state token for later validation.
  Future<String> startGithubLogin({String? redirectUri}) async {
    final result = await _api.loginGithub(redirectUri: redirectUri);
    _pendingOAuthState = result.state;

    await launchUrlString(
      result.url,
      mode: LaunchMode.externalApplication,
    );

    return result.state;
  }

  /// Complete the GitHub OAuth flow by exchanging the code for a token.
  /// Called when the app receives the deep link callback.
  Future<UserProfile> completeGithubLogin({
    required String code,
    required String state,
  }) async {
    // Validate CSRF state
    if (_pendingOAuthState != null && state != _pendingOAuthState) {
      throw SaasApiException(
        'OAuth state mismatch — possible CSRF attack',
        code: 'oauth_state_mismatch',
      );
    }
    _pendingOAuthState = null;

    final result = await _api.callbackGithub(code: code, state: state);

    // Persist token securely
    await _storage.write(key: _tokenKey, value: result.token);
    await _storage.write(key: _userIdKey, value: result.user.id.toString());

    // Configure API service with the new token
    _api.setToken(result.token);

    return result.user;
  }

  /// Log out: clear persisted credentials and API token.
  Future<void> logout() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userIdKey);
    } catch (e) {
      debugPrint('AuthService: Failed to clear storage: $e');
    }
    _api.clearToken();
  }

  /// Whether we have a stored token (doesn't verify it's valid).
  Future<bool> hasStoredToken() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
