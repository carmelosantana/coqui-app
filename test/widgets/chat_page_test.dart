import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:coqui_app/Models/coqui_instance.dart';
import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Pages/chat_page/chat_page.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/database_service.dart';
import 'package:coqui_app/Services/instance_service.dart';

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
  @override
  Future<Map<String, dynamic>> healthCheck() async => {'status': 'ok'};

  @override
  Future<List<CoquiSession>> listSessions({
    int limit = 50,
    String? status,
  }) async =>
      const [];

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

void main() {
  group('ChatPage', () {
    late ChatProvider chatProvider;
    late InstanceProvider instanceProvider;

    setUp(() {
      final apiService = _FakeApiService();
      chatProvider = ChatProvider(
        apiService: apiService,
        databaseService: _FakeDatabaseService(),
      );
      instanceProvider = InstanceProvider(
        instanceService: _FakeInstanceService(),
        apiService: apiService,
      );
    });

    Future<void> pumpChatPage(WidgetTester tester) async {
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
            home: const Scaffold(
              body: ChatPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
    }

    testWidgets('shows single-session setup by default', (tester) async {
      await pumpChatPage(tester);

      expect(find.text('Single'), findsOneWidget);
      expect(find.text('Group'), findsOneWidget);
      expect(find.text('Select a role'), findsOneWidget);
      expect(find.text('Select a profile'), findsOneWidget);
      expect(find.text('Select profiles'), findsNothing);
    });

    testWidgets('shows group session controls when group mode is selected', (
      tester,
    ) async {
      await pumpChatPage(tester);

      await tester.tap(find.text('Group'));
      await tester.pumpAndSettle();

      expect(find.text('Select profiles'), findsOneWidget);
      expect(find.textContaining('[+]'), findsNothing);
      expect(find.text('Number of rounds'), findsOneWidget);
      expect(find.text('Select a role'), findsNothing);
      expect(find.text('Select a profile'), findsNothing);
    });
  });
}
