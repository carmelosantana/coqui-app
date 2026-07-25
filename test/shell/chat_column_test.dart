import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Pages/shell/chat/chat_column.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
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

CoquiSession _session({String? title}) => CoquiSession(
      id: 'session-1',
      modelRole: 'orchestrator',
      model: 'gpt-test',
      createdAt: DateTime.utc(2026, 7, 25),
      updatedAt: DateTime.utc(2026, 7, 25),
      title: title,
    );

Future<void> _pump(WidgetTester tester, CoquiSession? session) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ChatProvider>.value(
      value: _FakeChatProvider(session),
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
}
