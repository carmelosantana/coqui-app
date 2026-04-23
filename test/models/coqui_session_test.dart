import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Models/coqui_session_channel.dart';
import 'package:coqui_app/Models/coqui_session_member.dart';

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
        'channel_bound': true,
        'channel': {
          'instance_id': 'channel-1',
          'name': 'signal-primary',
          'driver': 'signal',
          'display_name': 'Signal Primary',
        },
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
      expect(session.isChannelBound, isTrue);
      expect(session.channel?.instanceId, 'channel-1');
      expect(session.displayTitle, 'Session Title');
      expect(session.shortId, 'session-');
      expect(session.channelSummaryLabel, 'Signal • Signal Primary');
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
        channelBound: true,
        channel: const CoquiSessionChannel(
          instanceId: 'channel-2',
          name: 'discord-primary',
          driver: 'discord',
          displayName: 'Discord Primary',
        ),
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
      expect(restored.isChannelBound, isTrue);
      expect(restored.displayTitle, 'Closed Session');
      expect(restored.channel?.summaryLabel, 'Discord • Discord Primary');
      expect(restored.title, 'Closed Session');
    });

    test('falls back to session id when no title exists', () {
      final session = CoquiSession.fromJson({
        'id': 'abcdef1234567890',
        'model_role': 'orchestrator',
        'model': 'gpt-test',
        'created_at': '2026-04-21T10:00:00Z',
        'updated_at': '2026-04-21T11:00:00Z',
      });

      expect(session.shortId, 'abcdef12');
      expect(session.displayTitle, 'Session abcdef12');
    });

    test('parses group session fields from API payloads', () {
      final session = CoquiSession.fromJson({
        'id': 'group-session-1',
        'model_role': 'orchestrator',
        'model': 'gpt-test',
        'profile': null,
        'group_enabled': 1,
        'group_max_rounds': 4,
        'group_composition_key': 'caelum|nova|trinity',
        'group_members': [
          {'profile': 'caelum', 'position': 0},
          {'profile': 'nova', 'position': 1},
          {'profile': 'trinity', 'position': 2},
        ],
        'created_at': '2026-04-21T10:00:00Z',
        'updated_at': '2026-04-21T11:00:00Z',
      });

      expect(session.isGroupSession, isTrue);
      expect(session.groupMaxRounds, 4);
      expect(session.groupCompositionKey, 'caelum|nova|trinity');
      expect(session.groupProfileNames, ['caelum', 'nova', 'trinity']);
      expect(session.primaryProfileLabel, 'caelum');
      expect(session.participantSummary, 'caelum, nova, trinity');
      expect(session.compactParticipantSummary, 'caelum, nova, trinity');
    });

    test('round-trips group session fields through database maps', () {
      final session = CoquiSession(
        id: 'group-session-2',
        modelRole: 'orchestrator',
        model: 'gpt-test',
        groupEnabled: true,
        groupMaxRounds: 5,
        groupCompositionKey: 'caelum|nova|trinity|iris',
        groupMembers: const [
          CoquiSessionMember(profile: 'caelum', position: 0),
          CoquiSessionMember(profile: 'nova', position: 1),
          CoquiSessionMember(profile: 'trinity', position: 2),
          CoquiSessionMember(profile: 'iris', position: 3),
        ],
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000005000),
      );

      final restored = CoquiSession.fromDatabase(session.toDatabaseMap());

      expect(restored.isGroupSession, isTrue);
      expect(restored.groupMaxRounds, 5);
      expect(restored.groupCompositionKey, 'caelum|nova|trinity|iris');
      expect(
        restored.groupProfileNames,
        ['caelum', 'nova', 'trinity', 'iris'],
      );
      expect(restored.compactParticipantSummary, 'caelum, nova +2');
    });

    test('fromDatabase tolerates missing cached group members', () {
      final session = CoquiSession.fromDatabase({
        'id': 'group-session-3',
        'model_role': 'orchestrator',
        'model': 'gpt-test',
        'profile': null,
        'group_enabled': 1,
        'group_max_rounds': 3,
        'group_composition_key': 'caelum|nova',
        'group_members_json': null,
        'active_project_id': null,
        'created_at': 1700000000000,
        'updated_at': 1700000005000,
        'token_count': 0,
        'is_closed': 0,
        'is_archived': 0,
        'closed_at': null,
        'archived_at': null,
        'closure_reason': null,
        'title': 'Group Session',
      });

      expect(session.isGroupSession, isTrue);
      expect(session.groupMembers, isEmpty);
      expect(session.compactParticipantSummary, 'Group session');
    });
  });
}
