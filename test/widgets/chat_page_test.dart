import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:coqui_app/Models/coqui_instance.dart';
import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Models/sse_event.dart';
import 'package:coqui_app/Pages/chat_page/chat_page.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/database_service.dart';
import 'package:coqui_app/Services/instance_service.dart';

class _FakeDatabaseService extends DatabaseService {
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
  Future<void> upsertMessage(CoquiMessage message,
      {required String sessionId}) async {
    final messages = _messagesBySession.putIfAbsent(
      sessionId,
      () => <CoquiMessage>[],
    );
    messages.removeWhere((existing) => existing.id == message.id);
    messages.add(message);
  }

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

  @override
  Future<void> updateSessionTitle(String sessionId, String title) async {
    for (var index = 0; index < _sessions.length; index += 1) {
      final session = _sessions[index];
      if (session.id == sessionId) {
        _sessions[index] = session.copyWith(title: title);
        return;
      }
    }
  }
}

class _FakeApiService extends CoquiApiService {
  _FakeApiService({List<CoquiSession> sessions = const []})
      : _sessions = List<CoquiSession>.from(sessions);

  final List<CoquiSession> _sessions;
  final Map<String, List<CoquiMessage>> _messagesBySession = {};
  int createSessionCalls = 0;
  int resolveSessionCalls = 0;
  final List<String> sentPrompts = [];

  @override
  Future<Map<String, dynamic>> healthCheck() async => {'status': 'ok'};

  @override
  Future<List<CoquiSession>> listSessions({
    int limit = 50,
    String? status,
  }) async =>
      List<CoquiSession>.from(_sessions);

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
    createSessionCalls += 1;

    final session = CoquiSession(
      id: 'session-$createSessionCalls',
      modelRole: modelRole,
      model: 'gpt-test',
      profile: profile,
      createdAt: DateTime.utc(2026, 5, 11, 12, createSessionCalls),
      updatedAt: DateTime.utc(2026, 5, 11, 12, createSessionCalls),
    );
    _sessions.removeWhere((existing) => existing.id == session.id);
    _sessions.insert(0, session);

    return CoquiSessionMutationResult(
      session: session,
      created: true,
    );
  }

  @override
  Future<CoquiSessionMutationResult> resolveSession({
    String modelRole = 'orchestrator',
    String? profile,
    bool groupEnabled = false,
    List<String> members = const [],
    int groupMaxRounds = 3,
  }) async {
    resolveSessionCalls += 1;

    final existing = _sessions.where((session) {
      return session.modelRole == modelRole && session.profile == profile;
    }).firstOrNull;

    if (existing != null) {
      return CoquiSessionMutationResult(session: existing, created: false);
    }

    return await createSession(
      modelRole: modelRole,
      profile: profile,
      groupEnabled: groupEnabled,
      members: members,
      groupMaxRounds: groupMaxRounds,
    );
  }

  @override
  Future<List<CoquiMessage>> listMessages(String sessionId) async {
    return List<CoquiMessage>.from(_messagesBySession[sessionId] ?? const []);
  }

  @override
  Stream<SseEvent> sendPrompt(
    String sessionId,
    String prompt, {
    List<String> fileIds = const [],
  }) async* {
    sentPrompts.add(prompt);
    _messagesBySession[sessionId] = [
      CoquiMessage(
        id: 'user-${sentPrompts.length}',
        content: prompt,
        role: CoquiMessageRole.user,
      ),
      CoquiMessage(
        id: 'assistant-${sentPrompts.length}',
        content: 'Acknowledged',
        role: CoquiMessageRole.assistant,
      ),
    ];

    yield SseEvent(
      type: SseEventType.done,
      data: const {'content': 'Acknowledged'},
    );
    yield SseEvent(
      type: SseEventType.complete,
      data: const {'total_tokens': 1, 'duration_ms': 1},
    );
  }

  @override
  Future<List<CoquiRole>> getRoles() async {
    return [
      CoquiRole(name: 'orchestrator', model: 'gpt-test'),
      CoquiRole(name: 'coder', model: 'gpt-test'),
    ];
  }

  @override
  Future<List<CoquiProfile>> getProfiles() async {
    return const [
      CoquiProfile(name: 'caelum', displayName: 'Caelum'),
      CoquiProfile(name: 'nova', displayName: 'Nova'),
    ];
  }
}

class _FakeInstanceService extends InstanceService {
  final List<CoquiInstance> _instances = [
    CoquiInstance(
      id: 'instance-1',
      name: 'Local Coqui',
      baseUrl: 'http://localhost:3300',
      apiKey: '',
      isActive: true,
    ),
  ];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> ensureDefaultInstance() async {}

  @override
  List<CoquiInstance> getInstances() => List<CoquiInstance>.from(_instances);

  @override
  CoquiInstance? getActiveInstance() => _instances.first;
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      '/tmp/coqui_app_widget_tests';

  @override
  Future<String?> getTemporaryPath() async => '/tmp/coqui_app_widget_tests';

  @override
  Future<String?> getApplicationSupportPath() async =>
      '/tmp/coqui_app_widget_tests';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatPage', () {
    late ChatProvider chatProvider;
    late InstanceProvider instanceProvider;
    late _FakeApiService apiService;

    setUpAll(() async {
      PathProviderPlatform.instance = _FakePathProviderPlatform();
      await Hive.initFlutter();
    });

    setUp(() async {
      apiService = _FakeApiService();
      chatProvider = ChatProvider(
        apiService: apiService,
        databaseService: _FakeDatabaseService(),
      );
      instanceProvider = InstanceProvider(
        instanceService: _FakeInstanceService(),
        apiService: apiService,
      );

      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').clear();
      } else {
        await Hive.openBox('settings');
      }
    });

    tearDown(() async {
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').clear();
      }

      instanceProvider.dispose();
      chatProvider.dispose();
    });

    Future<void> pumpChatPage(
      WidgetTester tester, {
      String? navigationModeOverride,
    }) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
            ChangeNotifierProvider<InstanceProvider>.value(
              value: instanceProvider,
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => ResponsiveBreakpoints.builder(
              breakpoints: [
                const Breakpoint(start: 0, end: 450, name: MOBILE),
                const Breakpoint(start: 451, end: 800, name: TABLET),
                const Breakpoint(start: 801, end: 1920, name: DESKTOP),
              ],
              useShortestSide: true,
              child: child!,
            ),
            home: Scaffold(
              body: ChatPage(
                navigationModeOverride: navigationModeOverride,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> unmountChatPage(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    testWidgets('shows companion setup by default in human mode', (
      tester,
    ) async {
      await pumpChatPage(tester);

      expect(
        find.byWidgetPredicate((widget) => widget is SegmentedButton),
        findsNothing,
      );
      expect(find.text('Select a role'), findsOneWidget);
      expect(find.text('Select a profile'), findsOneWidget);
      expect(find.text('Select profiles'), findsNothing);
      expect(find.byKey(const ValueKey<String>('single-session-controls')),
          findsOneWidget);

      await unmountChatPage(tester);
    });

    testWidgets('shows group session controls when group mode is selected', (
      tester,
    ) async {
      await pumpChatPage(tester, navigationModeOverride: 'machine');

      await tester.tap(find.text('Group'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Select profiles'), findsOneWidget);
      expect(find.textContaining('[+]'), findsNothing);
      expect(find.text('Number of rounds'), findsOneWidget);
      expect(find.text('Select a role'), findsNothing);
      expect(find.text('Select a profile'), findsNothing);

      await unmountChatPage(tester);
    });

    testWidgets('sending from empty chat creates a fresh session', (
      tester,
    ) async {
      await pumpChatPage(tester);

      await tester.enterText(find.byType(TextField), 'Start a fresh session');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(apiService.createSessionCalls, 1);
      expect(apiService.resolveSessionCalls, 0);
      expect(apiService.sentPrompts, ['Start a fresh session']);

      await unmountChatPage(tester);
    });

    testWidgets('selecting a profile stages it without creating a session', (
      tester,
    ) async {
      await pumpChatPage(tester);

      await tester.tap(find.text('Select a profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Caelum'));
      await tester.pumpAndSettle();

      expect(find.text('Profile: caelum'), findsOneWidget);
      expect(apiService.createSessionCalls, 0);
      expect(apiService.resolveSessionCalls, 0);

      await unmountChatPage(tester);
    });
  });
}
