import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_loop.dart';
import 'package:coqui_app/Pages/shell/chat/loop_card.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Theme/coqui_tokens.dart';

CoquiLoop _loop() => const CoquiLoop(
      id: 'loop-1',
      definitionName: 'Feature Loop',
      sessionId: null,
      projectId: null,
      goal: 'Ship the thing',
      status: 'running',
      currentIteration: 2,
      currentStage: 1,
      maxIterations: 5,
      deadline: null,
      terminationCriteria: null,
      configuration: {},
      startedAt: null,
      completedAt: null,
      lastActivityAt: null,
      metadata: {},
    );

CoquiLoopRoleStep _role(String role) =>
    CoquiLoopRoleStep(role: role, prompt: 'do $role', maxIterations: null);

CoquiLoopDefinition _definition() => CoquiLoopDefinition(
      name: 'Feature Loop',
      description: 'A three-role loop',
      parameters: const [],
      roles: [_role('explorer'), _role('coder'), _role('reviewer')],
      termination: const {},
    );

Future<ShellController> _pump(WidgetTester tester) async {
  final controller = ShellController();
  await tester.pumpWidget(
    ChangeNotifierProvider<ShellController>.value(
      value: controller,
      child: MaterialApp(
        home: Scaffold(
          body: LoopCard(loop: _loop(), definition: _definition()),
        ),
      ),
    ),
  );
  return controller;
}

Color _nodeColor(WidgetTester tester, int index) {
  final container = tester.widget<Container>(
    find.byKey(ValueKey('loop-stage-$index')),
  );
  return (container.decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('renders the ITER label', (tester) async {
    await _pump(tester);
    expect(find.text('ITER 2/5'), findsOneWidget);
  });

  testWidgets('renders one node per role', (tester) async {
    await _pump(tester);
    expect(find.byKey(const ValueKey('loop-stepper')), findsOneWidget);
    expect(find.byKey(const ValueKey('loop-stage-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('loop-stage-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('loop-stage-2')), findsOneWidget);
  });

  testWidgets('node 0 is done (green) and node 1 is active (lime)',
      (tester) async {
    await _pump(tester);
    expect(_nodeColor(tester, 0), CoquiTokens.status.online);
    expect(_nodeColor(tester, 1), CoquiTokens.brand.primaryLime);
  });

  testWidgets('tapping the card opens the loop panel', (tester) async {
    final controller = await _pump(tester);
    expect(controller.activeLoopId, isNull);

    await tester.tap(find.byType(LoopCard));
    await tester.pump();

    expect(controller.activeLoopId, 'loop-1');
    expect(controller.loopPanelOpen, isTrue);
  });
}
