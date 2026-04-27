import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Models/coqui_session_channel.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/database_service.dart';
import 'package:coqui_app/Widgets/chat_drawer.dart';

class _FakeDatabaseService extends DatabaseService {
  @override
  Future<void> open(String databaseFile) async {}

  @override
  Future<List<CoquiSession>> getSessions({String? instanceId}) async =>
      const [];

  @override
  Future<void> upsertSession(CoquiSession session,
      {String? instanceId}) async {}

  @override
  Future<CoquiSession?> getSession(String sessionId) async => null;
}

class _FakeApiService extends CoquiApiService {
  _FakeApiService({required this.sessions});

  List<CoquiSession> sessions;
  int listSessionsCalls = 0;

  @override
  Future<List<CoquiSession>> listSessions({
    int limit = 50,
    String? status,
  }) async {
    listSessionsCalls++;
    return List<CoquiSession>.from(sessions);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final bytes = Uint8List.fromList(
      utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10" fill="#000"/></svg>',
      ),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'flutter/assets',
      (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'assets/images/logo/coqui-logo.svg') {
          return ByteData.view(bytes.buffer);
        }
        return null;
      },
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'flutter/assets',
      null,
    );
  });

  testWidgets(
      'renders bound channel sessions without overflow and without redundant channel prefix',
      (tester) async {
    final chatProvider = ChatProvider(
      apiService: _FakeApiService(
        sessions: [
          CoquiSession(
            id: 'session-1',
            modelRole: 'orchestrator',
            model: 'gpt-test',
            profile: 'trinity',
            channelBound: true,
            channel: const CoquiSessionChannel(
              instanceId: 'gvoice2',
              name: 'gvoice2',
              driver: 'signal',
              displayName: 'gvoice2',
            ),
            title: 'Channel · gvoice2 · signal-remote-conversation',
            createdAt: DateTime.utc(2026, 4, 23, 10),
            updatedAt: DateTime.utc(2026, 4, 23, 10, 5),
          ),
        ],
      ),
      databaseService: _FakeDatabaseService(),
    );

    await chatProvider.refreshSessions();

    await tester.pumpWidget(
      ChangeNotifierProvider<ChatProvider>.value(
        value: chatProvider,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: ChatNavigationDrawer(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('gvoice2 · signal-remote-conversation'), findsOneWidget);
    expect(
      find.text('Channel · gvoice2 · signal-remote-conversation'),
      findsNothing,
    );
    expect(find.text('Channel · gvoice2'), findsOneWidget);
    expect(find.text('Signal • gvoice2'), findsNothing);
    expect(find.text('trinity'), findsOneWidget);
  });

  testWidgets(
      'uses session_origin to label channel sessions without channel metadata',
      (tester) async {
    final chatProvider = ChatProvider(
      apiService: _FakeApiService(
        sessions: [
          CoquiSession.fromJson({
            'id': 'session-2',
            'model_role': 'orchestrator',
            'model': 'gpt-test',
            'session_origin': 'channel',
            'profile': 'trinity',
            'title': 'Channel · signal-dm:+18885551234',
            'created_at': '2026-04-23T10:00:00Z',
            'updated_at': '2026-04-23T10:05:00Z',
          }),
        ],
      ),
      databaseService: _FakeDatabaseService(),
    );

    await chatProvider.refreshSessions();

    await tester.pumpWidget(
      ChangeNotifierProvider<ChatProvider>.value(
        value: chatProvider,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: ChatNavigationDrawer(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('signal-dm:+18885551234'), findsOneWidget);
    expect(find.text('Channel'), findsOneWidget);
    expect(find.text('trinity'), findsOneWidget);
  });

  testWidgets('pulling down refreshes the rendered sessions list',
      (tester) async {
    final apiService = _FakeApiService(
      sessions: [
        CoquiSession(
          id: 'session-1',
          modelRole: 'orchestrator',
          model: 'gpt-test',
          title: 'Original Session',
          createdAt: DateTime.utc(2026, 4, 23, 10),
          updatedAt: DateTime.utc(2026, 4, 23, 10, 5),
        ),
      ],
    );
    final chatProvider = ChatProvider(
      apiService: apiService,
      databaseService: _FakeDatabaseService(),
    );

    await chatProvider.refreshSessions();

    await tester.pumpWidget(
      ChangeNotifierProvider<ChatProvider>.value(
        value: chatProvider,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: ChatNavigationDrawer(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Original Session'), findsOneWidget);
    expect(find.text('Refreshed Session'), findsNothing);
    expect(find.text('New Session'), findsNothing);

    apiService.sessions = [
      CoquiSession(
        id: 'session-1',
        modelRole: 'orchestrator',
        model: 'gpt-test',
        title: 'Refreshed Session',
        createdAt: DateTime.utc(2026, 4, 23, 10),
        updatedAt: DateTime.utc(2026, 4, 23, 10, 6),
      ),
      CoquiSession(
        id: 'session-2',
        modelRole: 'orchestrator',
        model: 'gpt-test',
        title: 'New Session',
        createdAt: DateTime.utc(2026, 4, 23, 11),
        updatedAt: DateTime.utc(2026, 4, 23, 11, 5),
      ),
    ];

    await tester.drag(find.byType(Scrollable), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(apiService.listSessionsCalls, greaterThanOrEqualTo(2));
    expect(find.text('Original Session'), findsNothing);
    expect(find.text('Refreshed Session'), findsOneWidget);
    expect(find.text('New Session'), findsOneWidget);
  });
}
