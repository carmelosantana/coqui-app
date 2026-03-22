import 'package:flutter_test/flutter_test.dart';
import 'package:coqui_app/Models/sse_event.dart';

void main() {
  group('SseEventType.fromString', () {
    test('maps all known server event strings', () {
      expect(SseEventType.fromString('agent_start'), SseEventType.agentStart);
      expect(SseEventType.fromString('iteration'), SseEventType.iteration);
      expect(SseEventType.fromString('tool_call'), SseEventType.toolCall);
      expect(SseEventType.fromString('tool_result'), SseEventType.toolResult);
      expect(SseEventType.fromString('child_start'), SseEventType.childStart);
      expect(SseEventType.fromString('child_end'), SseEventType.childEnd);
      expect(SseEventType.fromString('text_delta'), SseEventType.textDelta);
      expect(SseEventType.fromString('done'), SseEventType.done);
      expect(SseEventType.fromString('error'), SseEventType.error);
      expect(SseEventType.fromString('complete'), SseEventType.complete);
      expect(SseEventType.fromString('title'), SseEventType.title);
      expect(SseEventType.fromString('warning'), SseEventType.warning);
      expect(SseEventType.fromString('connected'), SseEventType.connected);
    });

    test('maps unknown strings to unknown', () {
      expect(SseEventType.fromString('bogus'), SseEventType.unknown);
      expect(SseEventType.fromString(''), SseEventType.unknown);
    });
  });

  group('SseEvent.parse', () {
    test('parses a warning event and exposes warningMessage', () {
      const block =
          'event: warning\ndata: {"message":"Title generation failed"}';
      final event = SseEvent.parse(block);
      expect(event, isNotNull);
      expect(event!.type, SseEventType.warning);
      expect(event.warningMessage, 'Title generation failed');
    });

    test('parses a connected event and exposes turnProcessId', () {
      const block =
          'event: connected\ndata: {"turn_process_id":"tp_abc123"}';
      final event = SseEvent.parse(block);
      expect(event, isNotNull);
      expect(event!.type, SseEventType.connected);
      expect(event.turnProcessId, 'tp_abc123');
    });

    test('warningMessage returns empty string when message key absent', () {
      const block = 'event: warning\ndata: {}';
      final event = SseEvent.parse(block);
      expect(event!.warningMessage, '');
    });

    test('turnProcessId returns empty string when key absent', () {
      const block = 'event: connected\ndata: {}';
      final event = SseEvent.parse(block);
      expect(event!.turnProcessId, '');
    });

    test('returns null for malformed block missing event line', () {
      const block = 'data: {"foo":"bar"}';
      expect(SseEvent.parse(block), isNull);
    });

    test('returns null for malformed block missing data line', () {
      const block = 'event: done';
      expect(SseEvent.parse(block), isNull);
    });

    test('parses a title event and exposes titleText', () {
      const block = 'event: title\ndata: {"title":"My Session"}';
      final event = SseEvent.parse(block);
      expect(event!.type, SseEventType.title);
      expect(event.titleText, 'My Session');
    });
  });

  group('SseEvent.parseAll', () {
    test('parses multiple events separated by double newlines', () {
      const raw =
          'event: agent_start\ndata: {}\n\n'
          'event: warning\ndata: {"message":"oops"}\n\n'
          'event: connected\ndata: {"turn_process_id":"tp_1"}\n\n';
      final events = SseEvent.parseAll(raw);
      expect(events.length, 3);
      expect(events[0].type, SseEventType.agentStart);
      expect(events[1].type, SseEventType.warning);
      expect(events[2].type, SseEventType.connected);
    });
  });
}
