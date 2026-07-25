import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_loop.dart';
import 'package:coqui_app/Pages/shell/popovers/loop_launcher.dart';
import 'package:coqui_app/Providers/loop_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

class _FakeLoopProvider extends LoopProvider {
  _FakeLoopProvider(this._defs)
      : super(apiService: CoquiApiService(baseUrl: 'http://localhost:0'));

  final List<CoquiLoopDefinition> _defs;
  String? sentDefinition;
  String? sentGoal;

  @override
  List<CoquiLoopDefinition> get definitions => _defs;

  @override
  Future<void> fetchDefinitions({bool force = false}) async {}

  @override
  Future<CoquiLoopDetail?> createLoop({
    required String definition,
    required String goal,
    String? projectId,
    String? sprintId,
    Map<String, String>? parameters,
    int? maxIterations,
  }) async {
    sentDefinition = definition;
    sentGoal = goal;
    return null;
  }
}

CoquiLoopDefinition _def(String name, List<String> roles) {
  return CoquiLoopDefinition(
    name: name,
    description: '$name description',
    parameters: const [],
    roles: roles
        .map((r) => CoquiLoopRoleStep(role: r, prompt: '', maxIterations: null))
        .toList(),
    termination: const {},
  );
}

Future<void> _pump(
  WidgetTester tester,
  _FakeLoopProvider provider, {
  VoidCallback? onClose,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<LoopProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(body: LoopLauncher(onClose: onClose)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final defs = [
    _def('build-fix', ['planner', 'coder', 'reviewer']),
    _def('research', ['researcher', 'writer']),
  ];

  testWidgets('renders one row per definition', (tester) async {
    await _pump(tester, _FakeLoopProvider(defs));

    expect(find.byKey(const ValueKey('loop-def-build-fix')), findsOneWidget);
    expect(find.byKey(const ValueKey('loop-def-research')), findsOneWidget);
  });

  testWidgets('run passes selected definition and goal, then closes',
      (tester) async {
    final provider = _FakeLoopProvider(defs);
    var closed = false;
    await _pump(tester, provider, onClose: () => closed = true);

    await tester.enterText(
      find.byKey(const ValueKey('loop-goal-input')),
      'Ship the release',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('loop-def-build-fix')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('loop-run')));
    await tester.pump();

    expect(provider.sentDefinition, 'build-fix');
    expect(provider.sentGoal, 'Ship the release');
    expect(closed, isTrue);
  });

  testWidgets('run is a no-op while the goal is empty', (tester) async {
    final provider = _FakeLoopProvider(defs);
    await _pump(tester, provider);

    await tester.tap(find.byKey(const ValueKey('loop-def-build-fix')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('loop-run')));
    await tester.pump();

    expect(provider.sentDefinition, isNull);
    expect(provider.sentGoal, isNull);
  });
}
