import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:coqui_app/Services/runtime_config_service.dart';

const _origin = 'http://coqui.example:8080';

const _indexHtml = '<!DOCTYPE html><html><head><title>Coqui</title></head>'
    '<body><script src="flutter_bootstrap.js"></script></body></html>';

RuntimeConfigService _service(
  MockClient client, {
  bool isWeb = true,
  Duration timeout = const Duration(seconds: 3),
}) {
  return RuntimeConfigService(
    client: client,
    isWeb: isWeb,
    timeout: timeout,
    originResolver: () => _origin,
  );
}

void main() {
  test('fetches config.json from the page origin', () async {
    final requested = <Uri>[];
    final client = MockClient((request) async {
      requested.add(request.url);
      return http.Response('{"bundled":true,"apiBaseUrl":"/api/v1"}', 200);
    });

    final config = await _service(client).load();

    expect(requested.single.toString(), '$_origin/config.json');
    expect(config.bundled, isTrue);
    expect(config.baseUrl, _origin);
    expect(config.apiVersion, 'v1');
  });

  test('never fetches on non-web platforms', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      return http.Response('{"bundled":true}', 200);
    });

    final config = await _service(client, isWeb: false).load();

    expect(calls, 0);
    expect(config.bundled, isFalse);
  });

  test('treats an SPA index.html fallback as not bundled', () async {
    final client = MockClient((request) async => http.Response(_indexHtml, 200));

    final config = await _service(client).load();

    expect(config.bundled, isFalse);
    expect(config.baseUrl, isNull);
  });

  test('treats a 404 as not bundled', () async {
    final client = MockClient((request) async => http.Response('', 404));

    expect((await _service(client).load()).bundled, isFalse);
  });

  test('treats a non-200 JSON body as not bundled', () async {
    final client = MockClient(
      (request) async => http.Response('{"bundled":true}', 500),
    );

    expect((await _service(client).load()).bundled, isFalse);
  });

  test('treats a transport failure as not bundled', () async {
    final client = MockClient(
      (request) async => throw http.ClientException('connection refused'),
    );

    expect((await _service(client).load()).bundled, isFalse);
  });

  test('treats a slow response as not bundled', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return http.Response('{"bundled":true}', 200);
    });

    final config = await _service(
      client,
      timeout: const Duration(milliseconds: 20),
    ).load();

    expect(config.bundled, isFalse);
  });

  test('treats an origin that cannot be resolved as not bundled', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      return http.Response('{"bundled":true}', 200);
    });

    final service = RuntimeConfigService(
      client: client,
      isWeb: true,
      originResolver: () => throw StateError('no origin'),
    );

    expect((await service.load()).bundled, isFalse);
    expect(calls, 0);
  });
}
