import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_instance.dart';
import 'package:coqui_app/Models/coqui_restart_state.dart';
import 'package:coqui_app/Models/runtime_config.dart';
import 'package:coqui_app/Pages/settings_page/subwidgets/instance_settings.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/instance_service.dart';

final _bundledInstance = CoquiInstance(
  name: 'This Server',
  baseUrl: 'http://coqui.example:8080',
  apiKey: '',
  isActive: true,
);

class _FakeInstanceService extends InstanceService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> ensureDefaultInstance() async {}

  @override
  List<CoquiInstance> getInstances() => [_bundledInstance];

  @override
  CoquiInstance? getActiveInstance() => _bundledInstance;
}

class _FakeInstanceProvider extends InstanceProvider {
  _FakeInstanceProvider({required this.supported, this.restarting = false})
      : super(
          instanceService: _FakeInstanceService(),
          apiService: CoquiApiService(),
        );

  final bool supported;
  final bool restarting;
  int restartCalls = 0;

  @override
  List<CoquiInstance> get instances => [_bundledInstance];

  @override
  CoquiInstance? get activeInstance => _bundledInstance;

  @override
  CoquiRestartState get restartState => CoquiRestartState(
        required: false,
        supported: supported,
        managedByLauncher: supported,
      );

  @override
  bool get restartRequired => false;

  @override
  bool get isRestarting => restarting;

  @override
  bool? get isOnline => true;

  @override
  Future<void> refreshHealth() async {}

  @override
  Future<bool> requestServerRestart({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    restartCalls += 1;
    return true;
  }
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required RuntimeConfig runtimeConfig,
  required _FakeInstanceProvider provider,
  bool settle = true,
}) async {
  addTearDown(provider.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<RuntimeConfig>.value(value: runtimeConfig),
        ChangeNotifierProvider<InstanceProvider>.value(value: provider),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: InstanceSettings()),
        ),
      ),
    ),
  );
  // The restarting state renders an indeterminate spinner, which never
  // settles — pump a single frame for that case instead.
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }

  // InstanceProvider's constructor starts a periodic health timer. Cancel it
  // inside the test body so the pending-timer invariant check passes — the
  // same approach test/widgets/profiles_page_test.dart uses.
  provider.pauseForDestructiveReset();
}

void main() {
  testWidgets('no restart control outside a bundled deployment',
      (tester) async {
    await _pumpSettings(
      tester,
      runtimeConfig: RuntimeConfig.notBundled,
      provider: _FakeInstanceProvider(supported: true),
    );

    expect(find.text('Restart server'), findsNothing);
  });

  testWidgets('no restart control when the server does not support it',
      (tester) async {
    await _pumpSettings(
      tester,
      runtimeConfig: const RuntimeConfig(
        bundled: true,
        baseUrl: 'http://coqui.example:8080',
      ),
      provider: _FakeInstanceProvider(supported: false),
    );

    expect(find.text('Restart server'), findsNothing);
  });

  testWidgets('a bundled deployment can restart its co-located server',
      (tester) async {
    final provider = _FakeInstanceProvider(supported: true);

    await _pumpSettings(
      tester,
      runtimeConfig: const RuntimeConfig(
        bundled: true,
        baseUrl: 'http://coqui.example:8080',
      ),
      provider: provider,
    );

    expect(find.text('Restart server'), findsOneWidget);

    await tester.tap(find.text('Restart server'));
    await tester.pumpAndSettle();

    expect(find.text('Restart this server?'), findsOneWidget);
    expect(provider.restartCalls, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Restart'));
    await tester.pumpAndSettle();

    expect(provider.restartCalls, 1);
    // The modal progress dialog must be gone, and the success SnackBar shown.
    expect(
      find.text(
        'Restarting the API server and waiting for it to come back online...',
      ),
      findsNothing,
    );
    expect(find.text('API restarted and is back online.'), findsOneWidget);
  });

  testWidgets('a restart already in flight renders as busy and cannot re-fire',
      (tester) async {
    final provider = _FakeInstanceProvider(supported: true, restarting: true);

    await _pumpSettings(
      tester,
      runtimeConfig: const RuntimeConfig(
        bundled: true,
        baseUrl: 'http://coqui.example:8080',
      ),
      provider: provider,
      settle: false,
    );

    expect(find.text('Restarting server'), findsOneWidget);
    expect(find.text('Restart server'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ListTile),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Restarting server'));
    await tester.pump();

    expect(find.text('Restart this server?'), findsNothing);
    expect(provider.restartCalls, 0);
  });

  testWidgets('cancelling the confirmation does not restart', (tester) async {
    final provider = _FakeInstanceProvider(supported: true);

    await _pumpSettings(
      tester,
      runtimeConfig: const RuntimeConfig(
        bundled: true,
        baseUrl: 'http://coqui.example:8080',
      ),
      provider: provider,
    );

    await tester.tap(find.text('Restart server'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(provider.restartCalls, 0);
  });
}
