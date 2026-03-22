import 'package:flutter_test/flutter_test.dart';
import 'package:coqui_app/Models/agent_activity_event.dart';
import 'package:coqui_app/Models/sse_event.dart';

void main() {
  group('AgentActivityEvent.fromSseEvent', () {
    SseEvent makeEvent(String type, Map<String, dynamic> data) {
      return SseEvent(type: SseEventType.fromString(type), data: data);
    }

    test('warning event creates warning activity', () {
      final event = makeEvent('warning', {'message': 'Title failed'});
      final activity = AgentActivityEvent.fromSseEvent(event);
      expect(activity, isNotNull);
      expect(activity!.type, AgentActivityType.warning);
      expect(activity.detail, 'Title failed');
      expect(activity.label, 'Warning');
    });

    test('connected event returns null', () {
      final event = makeEvent('connected', {'turn_process_id': 'tp_1'});
      final activity = AgentActivityEvent.fromSseEvent(event);
      expect(activity, isNull);
    });

    test('unknown event returns null', () {
      final event = makeEvent('some_future_type', {});
      final activity = AgentActivityEvent.fromSseEvent(event);
      expect(activity, isNull);
    });

    test('text_delta returns null', () {
      final event = makeEvent('text_delta', {'content': 'hello'});
      expect(AgentActivityEvent.fromSseEvent(event), isNull);
    });

    test('agent_start creates start activity', () {
      final event = makeEvent('agent_start', {});
      final activity = AgentActivityEvent.fromSseEvent(event);
      expect(activity!.type, AgentActivityType.start);
    });

    test('error event creates error activity with detail', () {
      final event = makeEvent('error', {'message': 'boom'});
      final activity = AgentActivityEvent.fromSseEvent(event);
      expect(activity!.type, AgentActivityType.error);
      expect(activity.detail, 'boom');
    });

    test('description combines label and detail', () {
      final activity = AgentActivityEvent(
        type: AgentActivityType.warning,
        label: 'Warning',
        detail: 'something went wrong',
      );
      expect(activity.description, 'Warning: something went wrong');
    });

    test('description returns label alone when detail is empty', () {
      final activity = AgentActivityEvent(
        type: AgentActivityType.info,
        label: 'Info',
        detail: '',
      );
      expect(activity.description, 'Info');
    });
  });
}
