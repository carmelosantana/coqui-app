import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/database_service.dart';

class _InMemoryDatabaseService extends DatabaseService {
  final List<CoquiSession> _sessions = [];
  final Map<String, List<CoquiMessage>> _messagesBySession = {};

  @override
  Future<void> open(String databaseFile) async {}

  @override
  Future<List<CoquiSession>> getSessions({String? instanceId}) async =>
      List<CoquiSession>.from(_sessions);

  @override
  Future<void> upsertSession(CoquiSession session,
      {String? instanceId}) async {
    _sessions.removeWhere((existing) => existing.id == session.id);
    _sessions.add(session);
  }

  @override
  Future<CoquiSession?> getSession(String sessionId) async {
    for (final session in _sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }

  @override
  Future<List<CoquiMessage>> getMessages(String sessionId) async =>
      List<CoquiMessage>.from(_messagesBySession[sessionId] ?? const []);

  @override
  Future<void> upsertMessages(
    List<CoquiMessage> messages, {
    required String sessionId,
  }) async {
    _messagesBySession[sessionId] = List<CoquiMessage>.from(messages);
  }

  @override
  Future<void> deleteMessages(String sessionId) async {
    _messagesBySession.remove(sessionId);
  }
}

class _SessionLifecycleApiService extends CoquiApiService {
  _SessionLifecycleApiService({List<CoquiSession> sessions = const []})
      : _sessions = List<CoquiSession>.from(sessions);

  final List<CoquiSession> _sessions;
  final Map<String, List<CoquiMessage>> _messagesBySession = {};
  Duration listMessagesDelay = Duration.zero;
  CoquiSessionMutationResult? nextCreateResult;

  @override
  Future<List<CoquiSession>> listSessions({
    int limit = 50,
    String? status,
  }) async {
    return List<CoquiSession>.from(_sessions);
  }

  @override
  Future<List<CoquiMessage>> listMessages(String sessionId) async {
    if (listMessagesDelay > Duration.zero) {
      await Future<void>.delayed(listMessagesDelay);
    }
    return List<CoquiMessage>.from(_messagesBySession[sessionId] ?? const []);
  }

  @override
  Future<CoquiSessionMutationResult> createSession({
    String modelRole = 'orchestrator',
    String? profile,
    bool groupEnabled = false,
    List<String> members = const [],
    int groupMaxRounds = 3,
    bool confirmCloseActiveProfileSession = false,
    bool confirmCloseActiveGroupSession = false,
  }) async {
    if (nextCreateResult != null) {
      final result = nextCreateResult!;
      _sessions
        ..removeWhere((existing) => existing.id == result.session.id)
        ..insert(0, result.session);
      return result;
    }

    final session = CoquiSession(
      id: 'created-session',
      modelRole: modelRole,
      model: 'gpt-test',
      profile: profile,
      createdAt: DateTime.utc(2026, 5, 11, 9),
      updatedAt: DateTime.utc(2026, 5, 11, 9),
    );
    _sessions.insert(0, session);
    return CoquiSessionMutationResult(session: session, created: true);
  }
}

void main() {
  group('ChatProvider session lifecycle', () {
    test('openSession completes after server messages hydrate', () async {
      final session = CoquiSession(
        id: 'session-1',
        modelRole: 'orchestrator',
        model: 'gpt-test',
        createdAt: DateTime.utc(2026, 5, 11, 9),
        updatedAt: DateTime.utc(2026, 5, 11, 9, 1),
      );
      final apiService = _SessionLifecycleApiService(sessions: [session]);
      apiService.listMessagesDelay = const Duration(milliseconds: 10);
      apiService._messagesBySession[session.id] = [
        CoquiMessage(
          id: 'assistant-1',
          content: 'Loaded from server',
          role: CoquiMessageRole.assistant,
        ),
      ];
      final provider = ChatProvider(
        apiService: apiService,
        databaseService: _InMemoryDatabaseService(),
      );

      await provider.refreshSessions();
      await provider.openSession(session.id);

      expect(provider.currentSession?.id, session.id);
      expect(provider.messages, hasLength(1));
      expect(provider.messages.single.content, 'Loaded from server');
    });

    test('createNewSession archives replaced sessions immediately', () async {
      final oldSession = CoquiSession(
        id: 'session-old',
        modelRole: 'orchestrator',
        model: 'gpt-test',
        profile: 'caelum',
        createdAt: DateTime.utc(2026, 5, 10, 9),
        updatedAt: DateTime.utc(2026, 5, 10, 9, 30),
      );
      final archivedOldSession = oldSession.copyWith(
        isClosed: true,
        isArchived: true,
        closedAt: DateTime.utc(2026, 5, 11, 9),
        archivedAt: DateTime.utc(2026, 5, 11, 9),
      );
      final newSession = CoquiSession(
        id: 'session-new',
        modelRole: 'orchestrator',
        model: 'gpt-test',
        profile: 'caelum',
        createdAt: DateTime.utc(2026, 5, 11, 9),
        updatedAt: DateTime.utc(2026, 5, 11, 9),
      );
      final apiService = _SessionLifecycleApiService(sessions: [oldSession]);
      apiService.nextCreateResult = CoquiSessionMutationResult(
        session: newSession,
        created: true,
        closedSessionIds: const ['session-old'],
      );
      apiService._sessions
        ..clear()
        ..addAll([oldSession]);

      final databaseService = _InMemoryDatabaseService();
      final provider = ChatProvider(
        apiService: apiService,
        databaseService: databaseService,
      );

      await provider.refreshSessions();
      apiService._sessions
        ..clear()
        ..addAll([newSession, archivedOldSession]);

      await provider.createNewSession(
        CoquiRole(name: 'orchestrator', model: 'gpt-test'),
        profile: 'caelum',
        confirmCloseActiveProfileSession: true,
      );

      expect(provider.currentSession?.id, 'session-new');
      expect(provider.sessions.map((session) => session.id), contains('session-new'));
      expect(provider.sessions.map((session) => session.id), isNot(contains('session-old')));
      expect(
        provider.archivedSessions.map((session) => session.id),
        contains('session-old'),
      );
    });
  });
}