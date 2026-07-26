import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_loop.dart';
import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Pages/shell/chat/chat_column.dart';
import 'package:coqui_app/Pages/shell/chat/loop_card.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/loop_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/database_service.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

class _InMemoryDatabaseService extends DatabaseService {
  @override
  Future<void> open(String databaseFile) async {}
  @override
  Future<List<CoquiSession>> getSessions({String? instanceId}) async => const [];
  @override
  Future<List<CoquiMessage>> getMessages(String sessionId) async => const [];
}

class _FakeChatProvider extends ChatProvider {
  _FakeChatProvider(this._session)
      : super(
          apiService: CoquiApiService(baseUrl: 'http://localhost:0'),
          databaseService: _InMemoryDatabaseService(),
        );
  final CoquiSession? _session;
  @override
  CoquiSession? get currentSession => _session;
  @override
  List<CoquiMessage> get displayMessages => const [];
  @override
  List<CoquiMessage> get messages => const [];
  @override
  bool get isCurrentSessionStreaming => false;
  @override
  bool get isCurrentSessionThinking => false;
}

class _FakeLoopProvider extends LoopProvider {
  _FakeLoopProvider({
    List<CoquiLoop> loops = const [],
    List<CoquiLoopDefinition> definitions = const [],
  })  : _loops = loops,
        _definitions = definitions,
        super(apiService: CoquiApiService(baseUrl: 'http://localhost:0'));
  final List<CoquiLoop> _loops;
  final List<CoquiLoopDefinition> _definitions;
  @override
  List<CoquiLoop> get loops => _loops;
  @override
  List<CoquiLoopDefinition> get definitions => _definitions;
  @override
  Future<void> fetchLoops({String? status, bool silent = false}) async {}
  @override
  Future<void> fetchDefinitions({bool force = false}) async {}
}

CoquiSession _session({String? title}) => CoquiSession(
      id: 'session-1',
      modelRole: 'orchestrator',
      model: 'gpt-test',
      createdAt: DateTime.utc(2026, 7, 25),
      updatedAt: DateTime.utc(2026, 7, 25),
      title: title,
    );

CoquiLoop _loop({required String id, required String? sessionId}) => CoquiLoop(
      id: id,
      definitionName: 'Feature Loop',
      sessionId: sessionId,
      projectId: null,
      goal: 'Ship it',
      status: 'running',
      currentIteration: 1,
      currentStage: 0,
      maxIterations: 3,
      deadline: null,
      terminationCriteria: null,
      configuration: const {},
      startedAt: null,
      completedAt: null,
      lastActivityAt: null,
      metadata: const {},
    );

CoquiLoopDefinition _definition() => CoquiLoopDefinition(
      name: 'Feature Loop',
      description: 'A loop',
      parameters: const [],
      roles: [
        const CoquiLoopRoleStep(role: 'coder', prompt: '', maxIterations: null),
      ],
      termination: const {},
    );

Future<void> _pump(
  WidgetTester tester,
  CoquiSession? session, {
  LoopProvider? loopProvider,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatProvider>.value(
          value: _FakeChatProvider(session),
        ),
        ChangeNotifierProvider<LoopProvider>.value(
          value: loopProvider ?? _FakeLoopProvider(),
        ),
        ChangeNotifierProvider<ShellController>(create: (_) => ShellController()),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ChatColumn()),
      ),
    ),
  );
}

void main() {
  testWidgets('renders session title in a channel-header-height header',
      (tester) async {
    await _pump(tester, _session(title: 'WebSocket lib comparison'));

    expect(find.text('WebSocket lib comparison'), findsOneWidget);

    final header = find.byKey(const ValueKey('channel-header'));
    expect(header, findsOneWidget);
    expect(
      tester.getSize(header).height,
      CoquiTokens.channelHeader,
    );

    expect(find.byKey(const ValueKey('composer-slot')), findsOneWidget);
  });

  testWidgets('shows empty state when no session is selected', (tester) async {
    await _pump(tester, null);

    expect(find.text('Select or start a session'), findsOneWidget);
  });

  testWidgets('renders a LoopCard for a loop belonging to the current session',
      (tester) async {
    final loopProvider = _FakeLoopProvider(
      loops: [_loop(id: 'loop-1', sessionId: 'session-1')],
      definitions: [_definition()],
    );
    await _pump(tester, _session(title: 'Chat'), loopProvider: loopProvider);
    await tester.pump();

    expect(find.byType(LoopCard), findsOneWidget);
    expect(find.byKey(const ValueKey('loop-card-loop-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('loop-strip')), findsOneWidget);
  });

  testWidgets('renders no loop strip when no loop matches the session',
      (tester) async {
    final loopProvider = _FakeLoopProvider(
      loops: [_loop(id: 'loop-2', sessionId: 'other-session')],
      definitions: [_definition()],
    );
    await _pump(tester, _session(title: 'Chat'), loopProvider: loopProvider);
    await tester.pump();

    expect(find.byType(LoopCard), findsNothing);
    expect(find.byKey(const ValueKey('loop-strip')), findsNothing);
  });
}
