import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Models/coqui_session.dart';

void main() {
  group('CoquiSession', () {
    test('parses lifecycle fields from API payloads', () {
      final session = CoquiSession.fromJson({
        'id': 'session-1',
        'model_role': 'orchestrator',
        'model': 'gpt-test',
        'profile': 'trinity',
        'active_project_id': 'project-123',
        'created_at': '2026-04-21T10:00:00Z',
        'updated_at': '2026-04-21T11:00:00Z',
        'token_count': 42,
        'is_closed': 1,
        'is_archived': 1,
        'closed_at': '2026-04-21T12:00:00Z',
        'archived_at': '2026-04-21T12:05:00Z',
        'closure_reason': 'profile_rotation',
        'title': 'Session Title',
      });

      expect(session.profile, 'trinity');
      expect(session.activeProjectId, 'project-123');
      expect(session.isClosed, isTrue);
      expect(session.isArchived, isTrue);
      expect(session.isReadOnly, isTrue);
      expect(session.status, 'archived');
      expect(session.closureReason, 'profile_rotation');
      expect(session.closedAt, DateTime.parse('2026-04-21T12:00:00Z'));
      expect(session.archivedAt, DateTime.parse('2026-04-21T12:05:00Z'));
      expect(session.title, 'Session Title');
    });

    test('round-trips lifecycle fields through database maps', () {
      final session = CoquiSession(
        id: 'session-2',
        modelRole: 'coder',
        model: 'gpt-test',
        profile: 'trinity',
        activeProjectId: 'project-456',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000005000),
        tokenCount: 18,
        isClosed: true,
        isArchived: false,
        closedAt: DateTime.fromMillisecondsSinceEpoch(1700000010000),
        closureReason: 'manual_close',
        title: 'Closed Session',
      );

      final restored = CoquiSession.fromDatabase(session.toDatabaseMap());

      expect(restored.id, session.id);
      expect(restored.modelRole, session.modelRole);
      expect(restored.profile, session.profile);
      expect(restored.activeProjectId, session.activeProjectId);
      expect(restored.isClosed, isTrue);
      expect(restored.isArchived, isFalse);
      expect(restored.status, 'closed');
      expect(restored.closedAt, session.closedAt);
      expect(restored.closureReason, 'manual_close');
      expect(restored.title, 'Closed Session');
    });
  });
}
