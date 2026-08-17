import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:coqui_app/Services/coqui_api_service.dart';

/// Runs a real `restartServer()` call against a mock client and returns the
/// URL it landed on.
///
/// The service uses package:http's top-level functions (no injected client),
/// so scope the mock client with runWithClient rather than a constructor seam
/// that does not exist. Asserting on the wire proves the method actually
/// routes through the versioned URL builder.
Future<Uri> capturedRestartUrl(CoquiApiService api) async {
  late http.Request captured;
  final client = MockClient((req) async {
    captured = req;
    // `restartServer()` reads a `restart` key; a bare object parses cleanly
    // and yields CoquiRestartState.empty without throwing.
    return http.Response('{"restart": {}}', 200);
  });

  await http.runWithClient(() async {
    await api.restartServer();
  }, () => client);

  expect(captured.method, 'POST');
  return captured.url;
}

void main() {
  test('a same-origin base composes the versioned api path', () async {
    final api = CoquiApiService(
      baseUrl: 'http://coqui.example:8080',
      apiVersion: 'v1',
    );

    final url = await capturedRestartUrl(api);

    // Scheme, host and port all matter for the same-origin property, so
    // assert the full URL rather than just the path.
    expect(url.toString(), 'http://coqui.example:8080/api/v1/server/restart');
  });

  test('reconfiguring to a same-origin base retargets every call', () async {
    final api = CoquiApiService();

    expect(
      (await capturedRestartUrl(api)).toString(),
      'http://localhost:3300/api/v1/server/restart',
    );

    api.configure(baseUrl: 'https://coqui.example', apiVersion: 'v1');

    expect(
      (await capturedRestartUrl(api)).toString(),
      'https://coqui.example/api/v1/server/restart',
    );
  });

  test('a non-default api version is honoured', () async {
    final api = CoquiApiService(
      baseUrl: 'http://coqui.example:8080',
      apiVersion: 'v2',
    );

    final url = await capturedRestartUrl(api);

    expect(url.toString(), 'http://coqui.example:8080/api/v2/server/restart');
  });
}
