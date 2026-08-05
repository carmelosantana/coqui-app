import 'package:flutter_test/flutter_test.dart';
import 'package:coqui_app/Models/sse_event.dart';

void main() {
  group('SseEventType.fromString', () {
    test('maps CAP turn-stream event strings', () {
      expect(SseEventType.fromString('token'), SseEventType.token);
      expect(SseEventType.fromString('tool_call'), SseEventType.toolCall);
      expect(SseEventType.fromString('tool_result'), SseEventType.toolResult);
      expect(SseEventType.fromString('question'), SseEventType.question);
      expect(SseEventType.fromString('done'), SseEventType.done);
      expect(SseEventType.fromString('error'), SseEventType.error);
    });

    test('connected is no longer a known type', () {
      expect(SseEventType.fromString('connected'), SseEventType.unknown);
    });

    test('maps unknown strings to unknown', () {
      expect(SseEventType.fromString('bogus'), SseEventType.unknown);
      expect(SseEventType.fromString(''), SseEventType.unknown);
    });
  });

  group('SseEvent.parse', () {
    test('parses token frame and exposes tokenText', () {
      final e = SseEvent.parse('event: token\ndata: {"text":"hel"}');
      expect(e, isNotNull);
      expect(e!.type, SseEventType.token);
      expect(e.tokenText, 'hel');
    });

    test('tokenText is null when text key absent', () {
      final e = SseEvent.parse('event: token\ndata: {}');
      expect(e!.tokenText, isNull);
    });

    test('parses done frame carrying the turn record', () {
      final e = SseEvent.parse(
        'event: done\ndata: {"id":"t_1","session_id":"s_1",'
        '"status":"completed","response_text":"hi","total_tokens":42}',
      );
      expect(e, isNotNull);
      expect(e!.type, SseEventType.done);
      expect(e.data['response_text'], 'hi');
      expect(e.data['status'], 'completed');
      expect(e.data['total_tokens'], 42);
    });

    test('parses question frame and exposes the question projection', () {
      final e = SseEvent.parse(
        'event: question\ndata: {"question_id":"q_1","prompt":"Pick one",'
        '"options":[{"value":"a","label":"A"}]}',
      );
      expect(e, isNotNull);
      expect(e!.type, SseEventType.question);
      expect(e.question, isNotNull);
      expect(e.question!['question_id'], 'q_1');
      expect(e.question!['prompt'], 'Pick one');
    });

    test('parses error frame with error and code', () {
      final e = SseEvent.parse(
        'event: error\ndata: {"error":"boom","code":"internal_error"}',
      );
      expect(e!.type, SseEventType.error);
      expect(e.data['error'], 'boom');
      expect(e.data['code'], 'internal_error');
    });

    test('parses a warning event and exposes warningMessage', () {
      final e = SseEvent.parse(
        'event: warning\ndata: {"message":"Title generation failed"}',
      );
      expect(e!.type, SseEventType.warning);
      expect(e.warningMessage, 'Title generation failed');
    });

    test('parses a title event and exposes titleText', () {
      final e = SseEvent.parse('event: title\ndata: {"title":"My Session"}');
      expect(e!.type, SseEventType.title);
      expect(e.titleText, 'My Session');
    });

    test('returns null for malformed block missing event line', () {
      expect(SseEvent.parse('data: {"foo":"bar"}'), isNull);
    });

    test('returns null for malformed block missing data line', () {
      expect(SseEvent.parse('event: done'), isNull);
    });
  });

  group('SseEvent.parseAll', () {
    test('parses multiple CAP frames separated by double newlines', () {
      const raw = 'event: token\ndata: {"text":"a"}\n\n'
          'event: token\ndata: {"text":"b"}\n\n'
          'event: done\ndata: {"id":"t_1","session_id":"s_1","status":"completed"}\n\n';
      final events = SseEvent.parseAll(raw);
      expect(events.length, 3);
      expect(events[0].type, SseEventType.token);
      expect(events[0].tokenText, 'a');
      expect(events[1].tokenText, 'b');
      expect(events[2].type, SseEventType.done);
    });
  });
}
