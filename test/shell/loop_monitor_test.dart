import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_loop.dart';
import 'package:coqui_app/Pages/shell/loop_monitor/loop_monitor.dart';
import 'package:coqui_app/Pages/shell/shell_controller.dart';
import 'package:coqui_app/Providers/loop_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

class _FakeLoopProvider extends LoopProvider {
  _FakeLoopProvider(this._loop, this._iters)
      : super(apiService: CoquiApiService(baseUrl: 'http://localhost:0'));
  final CoquiLoop? _loop;
  final List<CoquiLoopIteration> _iters;
  String? stoppedId;
  String? pausedId;

  @override
  CoquiLoop? loopById(String id) => _loop;
  @override
  List<CoquiLoopIteration> iterationsForLoop(String id) => _iters;
  @override
  Future<CoquiLoopDetail?> loadLoopDetail(String id, {bool force = false}) async =>
      null;
  @override
  Future<CoquiLoop?> stopLoop(String id) async {
    stoppedId = id;
    return null;
  }

  @override
  Future<CoquiLoop?> pauseLoop(String id) async {
    pausedId = id;
    return null;
  }
}

CoquiLoop _loop({String status = 'running'}) => CoquiLoop(
      id: 'loop-1',
      definitionName: 'code-review',
      sessionId: null,
      projectId: null,
      goal: 'Ship it',
      status: status,
      currentIteration: 1,
      currentStage: 0,
      maxIterations: 5,
      deadline: null,
      terminationCriteria: null,
      configuration: const {},
      startedAt: DateTime.utc(2026, 7, 25, 12, 0, 0),
      completedAt: null,
      lastActivityAt: DateTime.utc(2026, 7, 25, 12, 2, 14),
      metadata: const {'tokens': 4200},
    );

CoquiLoopIteration _iter(int n, {String status = 'completed', String? outcome}) =>
    CoquiLoopIteration(
      id: 'iter-$n',
      loopId: 'loop-1',
      iterationNumber: n,
      sprintId: null,
      status: status,
      outcomeSummary: outcome,
      startedAt: null,
      completedAt: null,
    );

Widget _wrap(_FakeLoopProvider provider, ShellController controller) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LoopProvider>.value(value: provider),
      ChangeNotifierProvider<ShellController>.value(value: controller),
    ],
    child: const MaterialApp(home: Scaffold(body: LoopMonitor())),
  );
}

void main() {
  testWidgets('renders TOKENS/ELAPSED stats and Pause/Stop controls',
      (t) async {
    final provider = _FakeLoopProvider(_loop(), [
      _iter(1, outcome: 'Baseline established'),
      _iter(2, status: 'running'),
    ]);
    final controller = ShellController()..openLoopPanel('loop-1');

    await t.pumpWidget(_wrap(provider, controller));
    await t.pump();

    expect(find.text('TOKENS'), findsOneWidget);
    expect(find.text('ELAPSED'), findsOneWidget);
    expect(find.byKey(const ValueKey('loop-pause')), findsOneWidget);
    expect(find.byKey(const ValueKey('loop-stop')), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
  });

  testWidgets('tapping Stop calls stopLoop with the active loop id', (t) async {
    final provider = _FakeLoopProvider(_loop(), [_iter(1)]);
    final controller = ShellController()..openLoopPanel('loop-1');

    await t.pumpWidget(_wrap(provider, controller));
    await t.pump();

    await t.tap(find.byKey(const ValueKey('loop-stop')));
    await t.pump();

    expect(provider.stoppedId, 'loop-1');
  });

  testWidgets('close button closes the loop panel', (t) async {
    final provider = _FakeLoopProvider(_loop(), const []);
    final controller = ShellController()..openLoopPanel('loop-1');

    await t.pumpWidget(_wrap(provider, controller));
    await t.pump();

    await t.tap(find.byKey(const ValueKey('loop-monitor-close')));
    await t.pump();

    expect(controller.loopPanelOpen, isFalse);
  });

  testWidgets('paused loop shows Resume label on the pause control', (t) async {
    final provider = _FakeLoopProvider(_loop(status: 'paused'), const []);
    final controller = ShellController()..openLoopPanel('loop-1');

    await t.pumpWidget(_wrap(provider, controller));
    await t.pump();

    expect(find.text('Resume'), findsOneWidget);
  });
}
