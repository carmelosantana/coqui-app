import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:coqui_app/Models/coqui_instance.dart';
import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Pages/chat_page/chat_page.dart';
import 'package:coqui_app/Pages/chat_page/subwidgets/chat_text_field.dart';
import 'package:coqui_app/Pages/chat_page/subwidgets/question_card.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/database_service.dart';
import 'package:coqui_app/Services/instance_service.dart';

/// Minimal database that never touches disk — the composer tests only care
/// about the provider's in-memory pending-question state.
class _NoopDatabaseService extends DatabaseService {
  @override
  Future<void> open(String databaseFile) async {}

  @override
  Future<List<CoquiSession>> getSessions({String? instanceId}) async => const [];

  @override
  Future<List<CoquiMessage>> getMessages(String sessionId) async => const [];
}

/// Drives [ChatProvider] with a fixed active session, a non-empty message list
/// (so the chat list — and its composer — render) and a togglable pending
/// question so the pill + send-blocking behavior can be exercised in isolation.
class _FakeChatProvider extends ChatProvider {
  _FakeChatProvider({
    required super.apiService,
    required super.databaseService,
  });

  Map<String, dynamic>? _pending;

  /// When true, [displayMessages] is empty — used to reproduce the "session
  /// active but messages still loading" frame where the answer card must still
  /// render because a question is pending.
  bool emptyMessages = false;

  void setPending(Map<String, dynamic>? question) {
    _pending = question;
    notifyListeners();
  }

  @override
  Map<String, dynamic>? get pendingQuestion => _pending;

  final CoquiSession _session = CoquiSession(
    id: 'sess1',
    modelRole: 'orchestrator',
    model: 'test-model',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  @override
  CoquiSession? get currentSession => _session;

  @override
  List<CoquiMessage> get displayMessages => emptyMessages
      ? const []
      : [
          CoquiMessage(
            id: 'm1',
            content: 'Hello there',
            role: CoquiMessageRole.assistant,
          ),
        ];

  @override
  List<CoquiMessage> get messages => displayMessages;

  @override
  Future<void> refreshSessions() async {}
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
      '/tmp/coqui_app_composer_pending_tests';

  @override
  Future<String?> getTemporaryPath() async => '/tmp/coqui_app_composer_pending_tests';

  @override
  Future<String?> getApplicationSupportPath() async =>
      '/tmp/coqui_app_composer_pending_tests';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeChatProvider chatProvider;
  late InstanceProvider instanceProvider;
  late CoquiApiService apiService;

  setUpAll(() async {
    PathProviderPlatform.instance = _FakePathProviderPlatform();
    await Hive.initFlutter();
  });

  setUp(() async {
    apiService = CoquiApiService();
    chatProvider = _FakeChatProvider(
      apiService: apiService,
      databaseService: _NoopDatabaseService(),
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

  Future<void> pumpComposer(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CoquiApiService>.value(value: apiService),
          ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
          ChangeNotifierProvider<InstanceProvider>.value(
            value: instanceProvider,
          ),
        ],
        child: MaterialApp(
          builder: (context, child) => ResponsiveBreakpoints.builder(
            breakpoints: const [
              Breakpoint(start: 0, end: 450, name: MOBILE),
              Breakpoint(start: 451, end: 800, name: TABLET),
              Breakpoint(start: 801, end: 1920, name: DESKTOP),
            ],
            useShortestSide: true,
            child: child!,
          ),
          home: const Scaffold(body: ChatPage()),
        ),
      ),
    );
    await tester.pump();
  }

  Finder composerField() => find.descendant(
        of: find.byType(ChatTextField),
        matching: find.byType(TextField),
      );

  IconButton? sendButton(WidgetTester tester) {
    final finder = find.widgetWithIcon(IconButton, Icons.arrow_upward_rounded);
    if (finder.evaluate().isEmpty) return null;
    return tester.widget<IconButton>(finder.first);
  }

  testWidgets(
    'pill shows and send is disabled while a question is pending',
    (tester) async {
      chatProvider.setPending({
        'question_id': 'q1',
        'prompt': 'Describe the issue',
      });

      await pumpComposer(tester);

      // Type into the composer so a send affordance would normally appear.
      await tester.enterText(composerField(), 'my prompt');
      await tester.pump();

      // Pill is visible.
      expect(find.text('1 answer needed'), findsOneWidget);

      // Send is present but disabled while the question is outstanding.
      final send = sendButton(tester);
      expect(send, isNotNull);
      expect(send!.onPressed, isNull);
    },
  );

  testWidgets(
    'clearing the pending question restores the composer',
    (tester) async {
      chatProvider.setPending({
        'question_id': 'q1',
        'prompt': 'Describe the issue',
      });

      await pumpComposer(tester);
      await tester.enterText(composerField(), 'my prompt');
      await tester.pump();

      // Precondition: blocked.
      expect(find.text('1 answer needed'), findsOneWidget);
      expect(sendButton(tester)!.onPressed, isNull);

      // Clear it.
      chatProvider.setPending(null);
      await tester.pump();

      // Pill is gone and send is enabled again.
      expect(find.text('1 answer needed'), findsNothing);
      final send = sendButton(tester);
      expect(send, isNotNull);
      expect(send!.onPressed, isNotNull);
    },
  );

  testWidgets(
    'answer card renders when a question is pending and messages are empty',
    (tester) async {
      // Reproduce the reachable frame: an active session with a stored pending
      // question while its messages are still loading (empty for a frame).
      chatProvider.emptyMessages = true;
      chatProvider.setPending({
        'question_id': 'q1',
        'prompt': 'Describe the issue',
      });

      await pumpComposer(tester);

      // The QuestionCard must render (so the pill's scroll-tap has a target and
      // the user has a visible answer affordance), not the empty placeholder.
      expect(find.byType(QuestionCard), findsOneWidget);
      expect(find.text('No messages yet!'), findsNothing);

      // Pill is visible and send stays blocked until the question is answered.
      expect(find.text('1 answer needed'), findsOneWidget);
      final send = sendButton(tester);
      expect(send, isNotNull);
      expect(send!.onPressed, isNull);
    },
  );
}
