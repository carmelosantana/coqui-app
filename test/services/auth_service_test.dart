import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Services/saas_api_service.dart';

void main() {
  group('AuthService token management', () {
    // Note: FlutterSecureStorage requires platform channels, so we test
    // the SaasApiService token lifecycle directly (which AuthService wraps).

    test('token is set and cleared correctly', () {
      final api = SaasApiService();
      expect(api.hasToken, false);

      api.setToken('cqb_testtoken123');
      expect(api.hasToken, true);
      expect(api.token, 'cqb_testtoken123');

      api.clearToken();
      expect(api.hasToken, false);
      expect(api.token, '');
    });

    test('SaasApiException state mismatch', () {
      final e = SaasApiException(
        'OAuth state mismatch — possible CSRF attack',
        code: 'oauth_state_mismatch',
      );
      expect(e.code, 'oauth_state_mismatch');
      expect(e.message, contains('CSRF'));
    });
  });
}
