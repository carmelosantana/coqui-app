import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Models/runtime_config.dart';

const _origin = 'http://coqui.example:8080';

void main() {
  group('RuntimeConfig.notBundled', () {
    test('is not bundled and carries no base url', () {
      expect(RuntimeConfig.notBundled.bundled, isFalse);
      expect(RuntimeConfig.notBundled.baseUrl, isNull);
      expect(RuntimeConfig.notBundled.apiVersion, 'v1');
    });
  });

  group('RuntimeConfig.apiVersionFromBase', () {
    test('defaults to v1 when absent or not a string', () {
      expect(RuntimeConfig.apiVersionFromBase(null), 'v1');
      expect(RuntimeConfig.apiVersionFromBase(7), 'v1');
    });

    test('extracts the version segment from /api/<version>', () {
      expect(RuntimeConfig.apiVersionFromBase('/api/v1'), 'v1');
      expect(RuntimeConfig.apiVersionFromBase('/api/v2/'), 'v2');
      expect(RuntimeConfig.apiVersionFromBase('api/v3'), 'v3');
    });

    test('falls back to v1 for shapes it cannot read', () {
      expect(RuntimeConfig.apiVersionFromBase('/'), 'v1');
      expect(RuntimeConfig.apiVersionFromBase('/api'), 'v1');
      expect(RuntimeConfig.apiVersionFromBase('/gateway/v9'), 'v1');
    });

    test('rejects a segment that is not a version', () {
      // `..` is the dangerous one: Uri.replace normalizes dot segments away,
      // so an unvalidated `..` strips the whole /api/<version> prefix and
      // every request lands in the SPA catch-all.
      expect(RuntimeConfig.apiVersionFromBase('/api/..'), 'v1');
      expect(RuntimeConfig.apiVersionFromBase('/api/.'), 'v1');
      expect(RuntimeConfig.apiVersionFromBase('/api/admin'), 'v1');
      expect(RuntimeConfig.apiVersionFromBase('/api/v1beta'), 'v1');
      expect(RuntimeConfig.apiVersionFromBase('/api/V1'), 'v1');
    });
  });

  group('RuntimeConfig.fromResponseBody', () {
    test('accepts the bundled contract and pins the base url to the origin', () {
      final config = RuntimeConfig.fromResponseBody(
        '{"bundled":true,"apiBaseUrl":"/api/v1"}',
        origin: _origin,
      );

      expect(config.bundled, isTrue);
      expect(config.baseUrl, _origin);
      expect(config.apiVersion, 'v1');
    });

    test('treats an absent apiBaseUrl as the same-origin default', () {
      final config = RuntimeConfig.fromResponseBody(
        '{"bundled":true}',
        origin: _origin,
      );

      expect(config.bundled, isTrue);
      expect(config.baseUrl, _origin);
      expect(config.apiVersion, 'v1');
    });

    test('honours a non-default api version', () {
      final config = RuntimeConfig.fromResponseBody(
        '{"bundled":true,"apiBaseUrl":"/api/v2"}',
        origin: _origin,
      );

      expect(config.apiVersion, 'v2');
    });

    test('rejects an SPA fallback that returns index.html', () {
      const html = '<!DOCTYPE html><html><head><title>Coqui</title></head>'
          '<body><script src="flutter_bootstrap.js"></script></body></html>';

      expect(
        RuntimeConfig.fromResponseBody(html, origin: _origin).bundled,
        isFalse,
      );
    });

    test('rejects bodies that are not a JSON object', () {
      expect(
        RuntimeConfig.fromResponseBody('[1,2,3]', origin: _origin).bundled,
        isFalse,
      );
      expect(
        RuntimeConfig.fromResponseBody('""', origin: _origin).bundled,
        isFalse,
      );
      expect(
        RuntimeConfig.fromResponseBody('', origin: _origin).bundled,
        isFalse,
      );
    });

    test('rejects anything other than a literal boolean true', () {
      expect(
        RuntimeConfig.fromResponseBody('{"bundled":false}', origin: _origin)
            .bundled,
        isFalse,
      );
      expect(
        RuntimeConfig.fromResponseBody('{"bundled":"true"}', origin: _origin)
            .bundled,
        isFalse,
      );
      expect(
        RuntimeConfig.fromResponseBody('{"bundled":1}', origin: _origin)
            .bundled,
        isFalse,
      );
      expect(
        RuntimeConfig.fromResponseBody('{}', origin: _origin).bundled,
        isFalse,
      );
    });
  });
}
