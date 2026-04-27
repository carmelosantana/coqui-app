import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Models/local_server_state.dart';

void main() {
  group('LocalServerInfo', () {
    test('copyWith can clear nullable fields', () {
      const original = LocalServerInfo(
        status: LocalServerStatus.error,
        version: '0.1.0',
        pid: 1234,
        apiKey: 'secret',
        errorMessage: 'failed',
      );

      final updated = original.copyWith(
        status: LocalServerStatus.stopped,
        version: null,
        pid: null,
        apiKey: null,
        errorMessage: null,
      );

      expect(updated.status, LocalServerStatus.stopped);
      expect(updated.version, isNull);
      expect(updated.pid, isNull);
      expect(updated.apiKey, isNull);
      expect(updated.errorMessage, isNull);
    });
  });
}
