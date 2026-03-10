import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Services/saas_api_service.dart';

void main() {
  group('AuthProvider state transitions', () {
    // AuthProvider requires platform channels (FlutterSecureStorage),
    // so we test the underlying state logic via SaasApiService.

    test('initial state: no token, not logged in', () {
      final api = SaasApiService();
      expect(api.hasToken, false);
    });

    test('after setting token: hasToken is true', () {
      final api = SaasApiService();
      api.setToken('cqb_test_token');
      expect(api.hasToken, true);
    });

    test('after clearing token: hasToken is false', () {
      final api = SaasApiService(token: 'cqb_test');
      api.clearToken();
      expect(api.hasToken, false);
    });

    test('onUnauthorized callback is configurable', () {
      var fired = false;
      final api = SaasApiService();
      api.onUnauthorized = () => fired = true;

      // Simulate 401 trigger
      api.onUnauthorized?.call();
      expect(fired, true);
    });

    test('onUnauthorized can be cleared', () {
      final api = SaasApiService();
      api.onUnauthorized = () {};
      api.onUnauthorized = null;
      // Should not throw
      api.onUnauthorized?.call();
    });
  });
}
