import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

void main() {
  test('answerQuestion POSTs question-scoped route with {selected, text}',
      () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response('{"answered": true}', 200);
    });

    // The service uses package:http's top-level functions (no injected
    // client), so scope the mock client with runWithClient rather than a
    // constructor seam that does not exist.
    await http.runWithClient(() async {
      final api = CoquiApiService(baseUrl: 'http://x');
      await api.answerQuestion('sess1', 'q123', selected: ['staging'], text: null);
    }, () => client);

    expect(captured.method, 'POST');
    // _url prepends the versioned `/api/{version}` prefix.
    expect(captured.url.path, '/api/v1/sessions/sess1/questions/q123/answer');
    expect(captured.body, contains('"selected":["staging"]'));
  });
}
