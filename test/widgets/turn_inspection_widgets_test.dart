import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coqui_app/Models/agent_activity_event.dart';
import 'package:coqui_app/Models/coqui_turn.dart';
import 'package:coqui_app/Widgets/turn_inspection_widgets.dart';

void main() {
  group('TurnActivityPanel', () {
    testWidgets('renders empty state when no activity exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TurnActivityPanel(activity: []),
          ),
        ),
      );

      expect(find.text('Agent Activity'), findsOneWidget);
      expect(find.text('No activity recorded for this turn.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders live activity rows when active', (tester) async {
      final events = [
        AgentActivityEvent(
          type: AgentActivityType.toolCall,
          label: 'write_file',
          detail: 'path: notes.md',
        ),
        AgentActivityEvent(
          type: AgentActivityType.warning,
          label: 'Warning',
          detail: 'Near context limit',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TurnActivityPanel(
              activity: events,
              isActive: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('write_file: path: notes.md'), findsOneWidget);
      expect(find.text('Warning: Near context limit'), findsOneWidget);
    });
  });

  group('TurnSummaryCard', () {
    testWidgets('renders rich turn metadata and detail sections', (tester) async {
      final turn = CoquiTurn(
        id: 'turn_1',
        sessionId: 'session_1',
        turnNumber: 7,
        userPrompt: 'Summarize the current turn',
        responseText: 'Done',
        content: 'Done',
        model: 'gpt-5.4',
        totalTokens: 1234,
        iterations: 3,
        durationMs: 2400,
        toolsUsed: const ['read_file', 'apply_patch'],
        childAgentCount: 1,
        contextUsage: const CoquiTurnContextUsage(
          maxTokens: 200000,
          reservedTokens: 5000,
          usedTokens: 64000,
          usagePercent: 32.0,
          availableTokens: 131000,
          effectiveBudget: 195000,
          breakdown: {'messages': 12000, 'tools': 8000},
        ),
        fileEdits: const [
          CoquiTurnFileEdit(
            filePath: '/tmp/example.dart',
            operation: 'update',
          ),
        ],
        reviewFeedback: 'Looks good after the last pass.',
        reviewApproved: true,
        backgroundTasks: const CoquiTurnBackgroundTasks(
          agents: [
            CoquiTurnBackgroundTaskEntry(
              id: 'agent_1',
              status: 'running',
              title: 'Draft docs',
              role: 'writer',
            ),
          ],
          tools: [
            CoquiTurnBackgroundTaskEntry(
              id: 'tool_1',
              status: 'queued',
              title: 'Index repository',
              toolName: 'ripgrep',
            ),
          ],
          totalCount: 2,
        ),
        restartRequested: true,
        createdAt: DateTime.parse('2026-04-21T10:00:00Z'),
        completedAt: DateTime.parse('2026-04-21T10:00:02Z'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TurnSummaryCard(turn: turn),
            ),
          ),
        ),
      );

      expect(find.text('Turn Summary'), findsOneWidget);
      expect(find.text('#7'), findsOneWidget);
      expect(find.text('3 iterations · 2 tools · 1 child · 1234 tokens · 2.4s'), findsOneWidget);
      expect(find.text('Context Usage'), findsOneWidget);
      expect(find.text('64000/195000 tokens used (32.0%)'), findsOneWidget);
      expect(find.text('File Edits'), findsOneWidget);
      expect(find.text('UPDATE example.dart'), findsOneWidget);
      expect(find.text('Background Tasks'), findsOneWidget);
      expect(find.text('Draft docs'), findsOneWidget);
      expect(find.text('Index repository'), findsOneWidget);
      expect(find.text('Review Feedback'), findsOneWidget);
      expect(find.text('Looks good after the last pass.'), findsOneWidget);
      expect(find.text('Restart requested'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('renders error state when turn failed', (tester) async {
      final turn = CoquiTurn(
        id: 'turn_error',
        sessionId: 'session_1',
        turnNumber: 1,
        userPrompt: 'Trigger a failure',
        responseText: '',
        content: '',
        model: 'gpt-5.4',
        error: 'Tool execution failed',
        createdAt: DateTime.parse('2026-04-21T10:00:00Z'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TurnSummaryCard(turn: turn),
          ),
        ),
      );

      expect(find.text('Tool execution failed'), findsOneWidget);
      expect(find.text('No token usage'), findsOneWidget);
    });
  });
}