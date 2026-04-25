import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Models/coqui_session_channel.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/database_service.dart';
import 'package:coqui_app/Pages/channels_page/subwidgets/channel_bound_session_picker.dart';

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

  @override
  Future<List<CoquiMessage>> getMessages(String sessionId) async => const [];
}

class _FakeApiService extends CoquiApiService {
  final List<CoquiSession> sessions;

  _FakeApiService({required this.sessions});

  @override
  Future<List<CoquiSession>> listSessions({
    int limit = 50,
    String? status,
  }) async {
    return List<CoquiSession>.from(sessions);
  }
}

void main() {
  CoquiSession buildSession({
    required String id,
    String? title,
    String? profile,
    DateTime? updatedAt,
    bool isClosed = false,
    bool isArchived = false,
    bool groupEnabled = false,
    bool channelBound = false,
    CoquiSessionChannel? channel,
  }) {
    return CoquiSession(
      id: id,
      modelRole: 'orchestrator',
      model: 'gpt-test',
      profile: profile,
      title: title,
      createdAt: DateTime.utc(2026, 4, 20, 10),
      updatedAt: updatedAt ??
          DateTime.now().toUtc().subtract(const Duration(minutes: 12)),
      isClosed: isClosed,
      isArchived: isArchived,
      groupEnabled: groupEnabled,
      channelBound: channelBound,
      channel: channel,
    );
  }

  Future<void> pumpPickerHost(
    WidgetTester tester, {
    required CoquiApiService apiService,
    required Widget child,
    ChatProvider? chatProvider,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChatProvider>.value(
            value: chatProvider ??
                ChatProvider(
                  apiService: apiService,
                  databaseService: _FakeDatabaseService(),
                ),
          ),
          Provider<CoquiApiService>.value(value: apiService),
        ],
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  group('ChannelBoundSessionPicker', () {
    testWidgets(
        'shows session metadata and disabled reason for other channel bindings',
        (tester) async {
      final apiService = _FakeApiService(
        sessions: [
          buildSession(
            id: 'session-available-1234',
            title: 'Planning Session',
            profile: 'caelum',
          ),
          buildSession(
            id: 'session-bound-9999',
            title: 'Support Session',
            profile: 'nova',
            channelBound: true,
            channel: const CoquiSessionChannel(
              instanceId: 'channel-other',
              name: 'signal-primary',
              driver: 'signal',
              displayName: 'Signal Primary',
            ),
          ),
          buildSession(
            id: 'session-closed-1111',
            title: 'Closed Session',
            isClosed: true,
          ),
        ],
      );

      await pumpPickerHost(
        tester,
        apiService: apiService,
        child: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                showChannelBoundSessionPicker(
                  context: context,
                  apiService: apiService,
                  currentChannelId: 'channel-current',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Planning Session'), findsOneWidget);
      expect(find.text('Support Session'), findsOneWidget);
      expect(find.textContaining('Last active '), findsWidgets);
      expect(find.text('Closed Session'), findsNothing);
      expect(
        find.text('Already linked to Signal Primary.'),
        findsOneWidget,
      );
    });

    testWidgets('returns the selected session from the picker', (tester) async {
      final selectedSession = buildSession(
        id: 'session-available-1234',
        title: 'Planning Session',
        profile: 'caelum',
      );
      final apiService = _FakeApiService(sessions: [selectedSession]);
      CoquiSession? result;

      await pumpPickerHost(
        tester,
        apiService: apiService,
        child: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showChannelBoundSessionPicker(
                  context: context,
                  apiService: apiService,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planning Session'));
      await tester.pumpAndSettle();

      expect(result?.id, selectedSession.id);
    });
  });

  group('SessionSummaryCard', () {
    testWidgets('renders open and clear actions and triggers callbacks',
        (tester) async {
      final apiService = _FakeApiService(sessions: const []);
      var opened = false;
      var cleared = false;

      await pumpPickerHost(
        tester,
        apiService: apiService,
        child: SessionSummaryCard(
          title: 'Bound Interactive Session',
          emptyText: 'No session selected.',
          session: buildSession(
            id: 'abcdef1234567890',
            title: 'Planning Session',
            profile: 'caelum',
          ),
          onOpenSession: () => opened = true,
          onClear: () => cleared = true,
        ),
      );

      expect(find.text('Planning Session'), findsOneWidget);
      expect(find.text('Open Session'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);

      await tester.tap(find.text('Open Session'));
      await tester.pump();
      await tester.tap(find.text('Clear'));
      await tester.pump();

      expect(opened, isTrue);
      expect(cleared, isTrue);
    });

    testWidgets(
        'openChannelBoundSession refreshes chat state and returns to the root route',
        (tester) async {
      final selectedSession = buildSession(
        id: 'session-available-1234',
        title: 'Planning Session',
        profile: 'caelum',
      );
      final apiService = _FakeApiService(sessions: [selectedSession]);
      final chatProvider = ChatProvider(
        apiService: apiService,
        databaseService: _FakeDatabaseService(),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: chatProvider,
          child: MaterialApp(
            initialRoute: '/channels',
            routes: {
              '/': (_) => const Scaffold(body: Text('Chat Home')),
              '/channels': (context) => Scaffold(
                    body: Center(
                      child: ElevatedButton(
                        onPressed: () => openChannelBoundSession(
                          context,
                          selectedSession,
                        ),
                        child: const Text('Open Bound Session'),
                      ),
                    ),
                  ),
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Bound Session'));
      await tester.pumpAndSettle();

      expect(find.text('Chat Home'), findsOneWidget);
      expect(chatProvider.currentSession?.id, selectedSession.id);
    });
  });
}
