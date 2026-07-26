import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Pages/shell/session_rail/session_rail.dart';
import 'package:coqui_app/Pages/shell/session_rail/session_section.dart';
import 'package:coqui_app/Pages/shell/session_rail/session_tile.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/profile_provider.dart';
import 'package:coqui_app/Providers/role_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/database_service.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

/// Minimal in-memory database so the base [ChatProvider] constructor is happy.
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
      if (session.id == sessionId) return session;
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

class _FakeChatProvider extends ChatProvider {
  _FakeChatProvider(this._sessions, {CoquiSession? createdSession})
      : _createdSession = createdSession,
        super(
          apiService: CoquiApiService(baseUrl: 'http://localhost:0'),
          databaseService: _InMemoryDatabaseService(),
        );
  final List<CoquiSession> _sessions;
  final CoquiSession? _createdSession;

  /// Records of ([role], [profile]) passed to [createNewSession].
  final List<({CoquiRole role, String? profile})> createdWith = [];
  CoquiSession? _current;

  @override
  List<CoquiSession> get sessions => _sessions;
  @override
  bool isSessionStreaming(String id) => false;
  @override
  Future<void> openSession(String id) async {}

  @override
  CoquiSession? get currentSession => _current;

  @override
  Future<void> createNewSession(
    CoquiRole role, {
    String? profile,
    List<String> groupProfiles = const [],
    int groupMaxRounds = 3,
    bool confirmCloseActiveProfileSession = false,
    bool confirmCloseActiveGroupSession = false,
  }) async {
    createdWith.add((role: role, profile: profile));
    _current = _createdSession;
  }
}

class _FakeProfileProvider extends ProfileProvider {
  _FakeProfileProvider(this._list)
      : super(apiService: CoquiApiService(baseUrl: 'http://localhost:0'));
  final List<CoquiProfile> _list;
  @override
  List<CoquiProfile> get profiles => _list;
  @override
  Future<void> fetchProfiles() async {}
}

class _FakeRoleProvider extends RoleProvider {
  _FakeRoleProvider(this._list)
      : super(apiService: CoquiApiService(baseUrl: 'http://localhost:0'));
  final List<CoquiRole> _list;
  int fetchCount = 0;
  @override
  List<CoquiRole> get roles => _list;
  @override
  Future<void> fetchRoles() async {
    fetchCount++;
  }
}

CoquiSession _session({
  required String id,
  String? title,
  String? profile,
  bool groupEnabled = false,
  bool isClosed = false,
}) {
  final now = DateTime(2026, 1, 1);
  return CoquiSession(
    id: id,
    modelRole: 'orchestrator',
    model: 'gpt-test',
    profile: profile,
    groupEnabled: groupEnabled,
    isClosed: isClosed,
    createdAt: now,
    updatedAt: now,
    title: title,
  );
}

Widget _wrap({
  required List<CoquiSession> sessions,
  required ShellController controller,
  List<CoquiProfile> profiles = const [],
  List<CoquiRole> roles = const [],
  _FakeChatProvider? chat,
  _FakeRoleProvider? roleProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ChatProvider>.value(
        value: chat ?? _FakeChatProvider(sessions),
      ),
      ChangeNotifierProvider<ProfileProvider>.value(
        value: _FakeProfileProvider(profiles),
      ),
      ChangeNotifierProvider<RoleProvider>.value(
        value: roleProvider ?? _FakeRoleProvider(roles),
      ),
      ChangeNotifierProvider<ShellController>.value(value: controller),
    ],
    child: const MaterialApp(home: Scaffold(body: SessionRail())),
  );
}

Finder _sectionChild(String label, Type childType) {
  return find.descendant(
    of: find.byWidgetPredicate(
      (w) => w is SessionSection && w.label == label,
    ),
    matching: find.byType(childType),
  );
}

void main() {
  final normal = _session(id: 'a1', title: 'Normal chat');
  final group = _session(id: 'b2', title: 'Group chat', groupEnabled: true);
  final closed = _session(id: 'c3', title: 'Closed chat', isClosed: true);

  testWidgets('group session appears under GROUP, not SESSIONS', (t) async {
    final controller = ShellController();
    await t.pumpWidget(
      _wrap(sessions: [normal, group, closed], controller: controller),
    );
    await t.pump();

    // GROUP holds only the group session.
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is SessionSection && w.label == 'Group',
        ),
        matching: find.text('Group chat'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is SessionSection && w.label == 'Sessions',
        ),
        matching: find.text('Group chat'),
      ),
      findsNothing,
    );
  });

  testWidgets('non-group sessions appear under SESSIONS', (t) async {
    final controller = ShellController();
    await t.pumpWidget(
      _wrap(sessions: [normal, group, closed], controller: controller),
    );
    await t.pump();

    final sessionsTiles = _sectionChild('Sessions', SessionTile);
    // Normal + closed (both non-group) live in SESSIONS.
    expect(sessionsTiles, findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is SessionSection && w.label == 'Sessions',
        ),
        matching: find.text('Normal chat'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('footer band height is 74', (t) async {
    final controller = ShellController();
    await t.pumpWidget(
      _wrap(sessions: [normal], controller: controller),
    );
    await t.pump();

    final size =
        t.getSize(find.byKey(const ValueKey('session-footer-band')));
    expect(size.height, CoquiTokens.footerBand);
    expect(size.height, 74);
  });

  testWidgets('tapping a tile sets the active session on the controller',
      (t) async {
    final controller = ShellController();
    await t.pumpWidget(
      _wrap(sessions: [normal, group, closed], controller: controller),
    );
    await t.pump();

    expect(controller.activeSessionId, isNull);
    await t.tap(find.byKey(const ValueKey('session-tile-a1')));
    await t.pump();
    expect(controller.activeSessionId, 'a1');
  });

  testWidgets('persona filter narrows sessions to the active persona',
      (t) async {
    final controller = ShellController()..selectPersona('caelum');
    final caelumSession =
        _session(id: 'd4', title: 'Caelum chat', profile: 'caelum');
    final otherSession =
        _session(id: 'e5', title: 'Nova chat', profile: 'nova');
    await t.pumpWidget(
      _wrap(
        sessions: [caelumSession, otherSession],
        controller: controller,
        profiles: const [
          CoquiProfile(name: 'caelum', displayName: 'Caelum', model: 'm'),
        ],
      ),
    );
    await t.pump();

    expect(find.text('Caelum chat'), findsOneWidget);
    expect(find.text('Nova chat'), findsNothing);
  });

  testWidgets('PINNED section is hidden (empty)', (t) async {
    final controller = ShellController();
    await t.pumpWidget(
      _wrap(sessions: [normal], controller: controller),
    );
    await t.pump();

    // SessionSection('Pinned') renders SizedBox.shrink when empty, so no
    // 'PINNED' label is painted.
    expect(find.text('PINNED'), findsNothing);
  });

  testWidgets(
      'tapping + New session creates a session with the orchestrator role '
      'and active profile, then selects it', (t) async {
    final controller = ShellController()..selectPersona('caelum');
    final orchestrator = CoquiRole(name: 'orchestrator', model: 'gpt-o');
    final other = CoquiRole(name: 'coder', model: 'gpt-c');
    final createdSession = _session(id: 'new-1', title: 'Fresh');
    final chat = _FakeChatProvider(const [], createdSession: createdSession);

    await t.pumpWidget(
      _wrap(
        sessions: const [],
        controller: controller,
        chat: chat,
        roles: [other, orchestrator],
      ),
    );
    await t.pump();

    await t.tap(find.byKey(const ValueKey('new-session')));
    await t.pump();

    expect(chat.createdWith.length, 1);
    expect(chat.createdWith.single.role.name, 'orchestrator');
    expect(chat.createdWith.single.profile, 'caelum');
    expect(controller.activeSessionId, 'new-1');
  });

  testWidgets('+ New session is disabled while no roles are available',
      (t) async {
    final controller = ShellController();
    final roleProvider = _FakeRoleProvider(const []);
    final chat = _FakeChatProvider(const []);

    await t.pumpWidget(
      _wrap(
        sessions: const [],
        controller: controller,
        chat: chat,
        roleProvider: roleProvider,
      ),
    );
    await t.pump();

    await t.tap(find.byKey(const ValueKey('new-session')));
    await t.pump();

    // Disabled InkWell: no session is created on tap.
    expect(chat.createdWith, isEmpty);
    // initState kicked off exactly one fetch to populate roles.
    expect(roleProvider.fetchCount, 1);
  });
}
