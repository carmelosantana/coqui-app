import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_turn.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Widgets/turn_history_sheet.dart';

void main() {
  group('TurnHistorySheet', () {
    testWidgets('loads turns and opens turn detail', (tester) async {
      final olderTurn = _makeTurn(
        id: 'turn_1',
        turnNumber: 1,
        prompt: 'First prompt',
        tokens: 120,
      );
      final newerTurn = _makeTurn(
        id: 'turn_2',
        turnNumber: 2,
        prompt: 'Second prompt',
        tokens: 300,
        iterations: 2,
      );

      final detail = CoquiTurnDetail(
        turn: newerTurn,
        messages: [
          CoquiMessage(
            id: 'msg_1',
            content: 'Explain the second turn',
            role: CoquiMessageRole.user,
          ),
          CoquiMessage(
            id: 'msg_2',
            content: 'Here is the assistant response.',
            role: CoquiMessageRole.assistant,
          ),
        ],
        events: [
          CoquiTurnEvent(
            id: 1,
            eventType: 'tool_call',
            data: {
              'tool': 'read_file',
              'arguments': {'path': 'README.md'},
            },
            createdAt: DateTime.parse('2026-04-21T10:00:01Z'),
          ),
        ],
      );

      final api = _FakeCoquiApiService(
        turns: [olderTurn, newerTurn],
        details: {'turn_2': detail},
      );

      await tester.pumpWidget(
        Provider<CoquiApiService>.value(
          value: api,
          child: MaterialApp(
            home: Scaffold(
              body: TurnHistorySheet(
                sessionId: 'session_1',
                highlightedTurn: newerTurn,
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.text('Turn History'), findsOneWidget);
      expect(find.text('Second prompt'), findsOneWidget);
      expect(find.text('First prompt'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);

      await tester.tap(find.text('Second prompt'));
      await tester.pumpAndSettle();

      expect(find.text('Turn 2'), findsWidgets);
      expect(find.text('Turn Activity'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('User'), findsOneWidget);
      expect(find.text('Assistant'), findsOneWidget);
      expect(find.text('read_file: path: README.md'), findsOneWidget);
      expect(api.listTurnsCalls, 1);
      expect(api.getTurnDetailCalls, ['turn_2']);
    });

    testWidgets('renders retry state when loading turns fails', (tester) async {
      final api = _FakeCoquiApiService(
        turnsError: Exception('Network unavailable'),
      );

      await tester.pumpWidget(
        Provider<CoquiApiService>.value(
          value: api,
          child: const MaterialApp(
            home: Scaffold(
              body: TurnHistorySheet(sessionId: 'session_1'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Network unavailable'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);

      api.turns = [_makeTurn(id: 'turn_ok', turnNumber: 1, prompt: 'Recovered', tokens: 42)];
      api.turnsError = null;

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Recovered'), findsOneWidget);
      expect(api.listTurnsCalls, 2);
    });
  });
}

CoquiTurn _makeTurn({
  required String id,
  required int turnNumber,
  required String prompt,
  required int tokens,
  int iterations = 1,
}) {
  return CoquiTurn(
    id: id,
    sessionId: 'session_1',
    turnNumber: turnNumber,
    userPrompt: prompt,
    responseText: 'Response for $prompt',
    content: 'Response for $prompt',
    model: 'gpt-5.4',
    totalTokens: tokens,
    iterations: iterations,
    durationMs: 1500,
    toolsUsed: const ['read_file'],
    createdAt: DateTime.parse('2026-04-21T10:00:00Z'),
    completedAt: DateTime.parse('2026-04-21T10:00:01Z'),
  );
}

class _FakeCoquiApiService extends CoquiApiService {
  List<CoquiTurn> turns;
  final Map<String, CoquiTurnDetail> details;
  Exception? turnsError;
  int listTurnsCalls = 0;
  final List<String> getTurnDetailCalls = [];

  _FakeCoquiApiService({
    this.turns = const [],
    this.details = const {},
    this.turnsError,
  });

  @override
  Future<List<CoquiTurn>> listTurns(String sessionId) async {
    listTurnsCalls += 1;
    if (turnsError != null) {
      throw turnsError!;
    }
    return turns;
  }

  @override
  Future<CoquiTurnDetail> getTurnDetail(String sessionId, String turnId) async {
    getTurnDetailCalls.add(turnId);
    final detail = details[turnId];
    if (detail == null) {
      throw Exception('Missing detail for $turnId');
    }
    return detail;
  }
}