import 'package:flutter/material.dart';

import 'package:coqui_app/Models/user_profile.dart';
import 'package:coqui_app/Services/auth_service.dart';
import 'package:coqui_app/Services/saas_api_service.dart';

/// Authentication state for the SaaS platform.
///
/// Manages login/logout, user profile, and token persistence.
/// Notifies listeners on state changes so the UI can react.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final SaasApiService _apiService;

  UserProfile? _user;
  bool _isLoading = false;
  String? _error;

  UserProfile? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider({
    required AuthService authService,
    required SaasApiService apiService,
  })  : _authService = authService,
        _apiService = apiService {
    // Listen for 401 responses → auto-logout
    _apiService.onUnauthorized = _onUnauthorized;
  }

  /// Try to restore a previous session on app startup.
  Future<void> tryRestoreSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _authService.restoreToken();
      if (token != null) {
        _user = await _apiService.getMe();
      }
    } on SaasApiException catch (e) {
      // Token is invalid/expired — clear it silently
      if (e.isUnauthorized) {
        await _authService.logout();
      }
      debugPrint('AuthProvider: Session restore failed: $e');
    } catch (e) {
      debugPrint('AuthProvider: Session restore failed: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Start GitHub OAuth flow (opens browser).
  Future<void> startLogin() async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.startGithubLogin(
        redirectUri: 'coquibot://auth/callback',
      );
    } on SaasApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to start login. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Complete OAuth flow with the callback parameters.
  Future<void> completeLogin({
    required String code,
    required String state,
  }) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.completeGithubLogin(
        code: code,
        state: state,
      );
    } on SaasApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Login failed. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Log out and clear all auth state.
  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _error = null;
    notifyListeners();
  }

  /// Refresh user profile from the server.
  Future<void> refreshProfile() async {
    if (!isLoggedIn) return;
    try {
      _user = await _apiService.getMe();
      notifyListeners();
    } on SaasApiException catch (e) {
      if (e.isUnauthorized) {
        await logout();
      }
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _onUnauthorized() {
    _user = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _apiService.onUnauthorized = null;
    super.dispose();
  }
}
