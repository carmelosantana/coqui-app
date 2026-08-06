import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Models/coqui_child_run.dart';

void main() {
  group('CoquiChildRun', () {
    test('parses the CAP child-run wire object including status', () {
      final run = CoquiChildRun.fromJson({
        'id': 'child-1',
        'parent_session_id': 'session-1',
        'parent_turn_id': 'turn-9',
        'role': 'researcher',
        'model': 'gpt-test',
        'prompt': 'Investigate the failing test',
        'result': 'All green.',
        'status': 'completed',
        'prompt_tokens': 120,
        'completion_tokens': 80,
        'total_tokens': 200,
        'created_at': '2026-08-04T10:00:00Z',
      });

      expect(run.id, 'child-1');
      expect(run.parentSessionId, 'session-1');
      expect(run.parentTurnId, 'turn-9');
      expect(run.role, 'researcher');
      expect(run.model, 'gpt-test');
      expect(run.prompt, 'Investigate the failing test');
      expect(run.result, 'All green.');
      expect(run.status, 'completed');
      expect(run.promptTokens, 120);
      expect(run.completionTokens, 80);
      expect(run.totalTokens, 200);
      expect(run.createdAt, DateTime.parse('2026-08-04T10:00:00Z'));
    });

    test('parses tolerantly when optional fields are null or absent', () {
      // Required-only payload per schema/child-run.json:
      // id, parent_session_id, role, prompt, status, created_at.
      final run = CoquiChildRun.fromJson({
        'id': 'child-2',
        'parent_session_id': 'session-1',
        'parent_turn_id': null,
        'role': 'orchestrator',
        'model': null,
        'prompt': 'Do the thing',
        'result': null,
        'status': 'running',
        'created_at': '2026-08-04T11:00:00Z',
      });

      expect(run.id, 'child-2');
      expect(run.parentSessionId, 'session-1');
      expect(run.parentTurnId, isNull);
      expect(run.role, 'orchestrator');
      expect(run.model, isNull, reason: 'null model ⇒ inherit');
      expect(run.result, isNull);
      expect(run.status, 'running');
      expect(run.promptTokens, 0);
      expect(run.completionTokens, 0);
      expect(run.totalTokens, 0);
    });

    test('previews clip long prompt and null-safe result', () {
      final run = CoquiChildRun.fromJson({
        'id': 'child-3',
        'parent_session_id': 'session-1',
        'role': 'researcher',
        'prompt': 'x' * 200,
        'result': null,
        'status': 'failed',
        'created_at': '2026-08-04T12:00:00Z',
      });

      expect(run.promptPreview.endsWith('…'), isTrue);
      expect(run.promptPreview.length, 121);
      expect(run.resultPreview, '');
    });
  });
}
