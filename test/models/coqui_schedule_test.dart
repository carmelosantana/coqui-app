import 'package:flutter_test/flutter_test.dart';
import 'package:coqui_app/Models/coqui_schedule.dart';

void main() {
  test('parses a turn-action schedule', () {
    final s = CoquiSchedule.fromJson({
      'id': 'sch_1',
      'name': 'daily',
      'cron': '0 9 * * *',
      'persona_id': 'caelum',
      'action': {'kind': 'turn', 'prompt': 'Summarize inbox'},
      'status': 'enabled',
      'created_at': '2026-08-04T00:00:00Z',
    });
    expect(s.cron, '0 9 * * *');
    expect(s.personaId, 'caelum');
    expect(s.action.kind, 'turn');
    expect(s.action.prompt, 'Summarize inbox');
    expect(s.action.definitionName, isNull);
    expect(s.status, 'enabled');
    expect(s.isEnabled, isTrue);
  });

  test('parses a loop-action schedule', () {
    final s = CoquiSchedule.fromJson({
      'id': 'sch_2',
      'name': 'nightly',
      'cron': '0 2 * * *',
      'persona_id': 'caelum',
      'action': {'kind': 'loop', 'definition_name': 'research'},
      'status': 'disabled',
      'created_at': '2026-08-04T00:00:00Z',
    });
    expect(s.action.kind, 'loop');
    expect(s.action.definitionName, 'research');
    expect(s.action.prompt, isNull);
    expect(s.status, 'disabled');
    expect(s.isEnabled, isFalse);
  });

  test('toJson emits the CAP create/update body shape for a turn', () {
    const s = CoquiSchedule(
      id: 'sch_1',
      name: 'daily',
      cron: '0 9 * * *',
      personaId: 'caelum',
      action: ScheduleAction(kind: 'turn', prompt: 'Summarize inbox'),
      status: 'enabled',
    );
    expect(s.toJson(), {
      'name': 'daily',
      'cron': '0 9 * * *',
      'persona_id': 'caelum',
      'action': {'kind': 'turn', 'prompt': 'Summarize inbox'},
      'status': 'enabled',
    });
  });

  test('ScheduleAction.loop toJson emits definition_name, not prompt', () {
    const action = ScheduleAction(kind: 'loop', definitionName: 'research');
    expect(action.toJson(), {'kind': 'loop', 'definition_name': 'research'});
  });

  test('tolerates a raw store row missing the action union', () {
    final s = CoquiSchedule.fromJson({
      'id': 'sch_3',
      'name': 'raw',
      'cron': '0 0 * * *',
      'persona_id': 'caelum',
      'status': 'enabled',
    });
    expect(s.action.kind, '');
    expect(s.action.prompt, isNull);
    expect(s.action.definitionName, isNull);
  });
}
