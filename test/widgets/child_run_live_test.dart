import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_child_run.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Models/sse_event.dart';
import 'package:coqui_app/Providers/role_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Widgets/child_run_live_detail.dart';
import 'package:coqui_app/Widgets/child_run_spawn_sheet.dart';

void main() {
  group('ChildRunLiveDetail', () {
    testWidgets('accumulates token frames and settles on done',
        (tester) async {
      final controller = StreamController<SseEvent>();
      final api = _FakeCoquiApiService(childRunStream: controller.stream);

      final running = CoquiChildRun(
        id: 'run_1',
        parentSessionId: 'session_1',
        role: 'coder',
        prompt: 'Investigate the failing test',
        status: 'running',
        createdAt: DateTime.parse('2026-08-07T10:00:00Z'),
      );

      await tester.pumpWidget(
        Provider<CoquiApiService>.value(
          value: api,
          child: MaterialApp(
            home: Scaffold(
              body: ChildRunLiveDetail(
                sessionId: 'session_1',
                childRun: running,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(api.streamCalls, [
        ('session_1', 'run_1'),
      ]);
      expect(find.textContaining('running'), findsWidgets);

      controller.add(SseEvent(
        type: SseEventType.token,
        data: const {'text': 'Hello '},
      ));
      await tester.pump();
      controller.add(SseEvent(
        type: SseEventType.token,
        data: const {'text': 'world'},
      ));
      await tester.pump();

      expect(find.textContaining('Hello world'), findsOneWidget);

      controller.add(SseEvent(
        type: SseEventType.done,
        data: const {
          'id': 'run_1',
          'parent_session_id': 'session_1',
          'role': 'coder',
          'prompt': 'Investigate the failing test',
          'result': 'All done',
          'status': 'completed',
          'total_tokens': 42,
          'created_at': '2026-08-07T10:00:00Z',
        },
      ));
      await tester.pump();
      await controller.close();
      await tester.pump();

      expect(find.textContaining('completed'), findsWidgets);
      expect(find.textContaining('42'), findsWidgets);
    });

    testWidgets('non-running run renders static detail without streaming',
        (tester) async {
      final api = _FakeCoquiApiService(childRunStream: const Stream.empty());

      final done = CoquiChildRun(
        id: 'run_2',
        parentSessionId: 'session_1',
        role: 'researcher',
        prompt: 'Summarize the doc',
        result: 'The summary text',
        status: 'completed',
        totalTokens: 17,
        createdAt: DateTime.parse('2026-08-07T10:00:00Z'),
      );

      await tester.pumpWidget(
        Provider<CoquiApiService>.value(
          value: api,
          child: MaterialApp(
            home: Scaffold(
              body: ChildRunLiveDetail(
                sessionId: 'session_1',
                childRun: done,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(api.streamCalls, isEmpty);
      expect(find.textContaining('The summary text'), findsOneWidget);
      expect(find.textContaining('completed'), findsWidgets);
    });
  });

  group('ChildRunSpawnSheet', () {
    testWidgets('spawns a child run with the chosen role and prompt',
        (tester) async {
      final api = _FakeCoquiApiService(
        childRunStream: const Stream.empty(),
        roles: [
          CoquiRole(name: 'coder', model: 'gpt-5', displayName: 'Coder'),
          CoquiRole(
              name: 'researcher', model: 'gpt-5', displayName: 'Researcher'),
        ],
      );
      final roleProvider = RoleProvider(apiService: api);
      var spawnedCallbacks = 0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<CoquiApiService>.value(value: api),
            ChangeNotifierProvider<RoleProvider>.value(value: roleProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChildRunSpawnSheet(
                sessionId: 'session_1',
                onSpawned: () => spawnedCallbacks += 1,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Pick a role.
      await tester.tap(find.byKey(const ValueKey('spawn-role-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Researcher'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Select'));
      await tester.pumpAndSettle();

      // Enter the prompt.
      await tester.enterText(
        find.byKey(const ValueKey('spawn-prompt-field')),
        'Do the thing',
      );
      await tester.pump();

      // Submit.
      await tester.tap(find.byKey(const ValueKey('spawn-submit')));
      await tester.pump();
      await tester.pump();

      expect(api.spawnCalls, [
        ('session_1', 'researcher', 'Do the thing'),
      ]);
      expect(spawnedCallbacks, 1);
    });
  });
}

class _FakeCoquiApiService extends CoquiApiService {
  final Stream<SseEvent> childRunStream;
  final List<CoquiRole> roles;
  final List<(String, String)> streamCalls = [];
  final List<(String, String, String)> spawnCalls = [];

  _FakeCoquiApiService({
    required this.childRunStream,
    this.roles = const [],
  });

  @override
  Stream<SseEvent> streamChildRunEvents(String sessionId, String childRunId) {
    streamCalls.add((sessionId, childRunId));
    return childRunStream;
  }

  @override
  Future<List<CoquiRole>> getRoles() async => roles;

  @override
  Future<CoquiChildRun> spawnChildRun(
    String sessionId, {
    required String role,
    required String prompt,
  }) async {
    spawnCalls.add((sessionId, role, prompt));
    return CoquiChildRun(
      id: 'spawned',
      parentSessionId: sessionId,
      role: role,
      prompt: prompt,
      status: 'completed',
      createdAt: DateTime.parse('2026-08-07T10:00:00Z'),
    );
  }
}
