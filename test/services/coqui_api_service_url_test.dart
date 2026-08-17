import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Services/coqui_api_service.dart';

void main() {
  test('a same-origin base composes the versioned api path', () {
    final service = CoquiApiService(
      baseUrl: 'http://coqui.example:8080',
      apiVersion: 'v1',
    );

    expect(
      service.apiUri('/server/restart').toString(),
      'http://coqui.example:8080/api/v1/server/restart',
    );
    expect(
      service.apiUri('/health').toString(),
      'http://coqui.example:8080/api/v1/health',
    );
  });

  test('reconfiguring to a same-origin base retargets every call', () {
    final service = CoquiApiService();

    expect(
      service.apiUri('/server/restart').toString(),
      'http://localhost:3300/api/v1/server/restart',
    );

    service.configure(baseUrl: 'https://coqui.example', apiVersion: 'v1');

    expect(
      service.apiUri('/server/restart').toString(),
      'https://coqui.example/api/v1/server/restart',
    );
  });

  test('a non-default api version is honoured', () {
    final service = CoquiApiService(
      baseUrl: 'http://coqui.example:8080',
      apiVersion: 'v2',
    );

    expect(
      service.apiUri('/server/restart').toString(),
      'http://coqui.example:8080/api/v2/server/restart',
    );
  });
}
