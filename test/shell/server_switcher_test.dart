import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Models/coqui_instance.dart';
import 'package:coqui_app/Pages/shell/popovers/server_switcher.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/instance_service.dart';

/// Fake service so [InstanceProvider]'s `_initialize()` runs without Hive.
class _FakeInstanceService extends InstanceService {
  _FakeInstanceService(this._instances);

  final List<CoquiInstance> _instances;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> ensureDefaultInstance() async {}

  @override
  List<CoquiInstance> getInstances() => List<CoquiInstance>.from(_instances);

  @override
  CoquiInstance? getActiveInstance() =>
      _instances.isNotEmpty ? _instances.first : null;
}

/// Records `setActiveInstance` calls and serves a fixed instance list.
class _RecordingInstanceProvider extends InstanceProvider {
  _RecordingInstanceProvider(this._list)
      : super(
          instanceService: _FakeInstanceService(_list),
          apiService: CoquiApiService(baseUrl: 'http://localhost:0'),
        );

  final List<CoquiInstance> _list;
  String? activatedId;

  @override
  List<CoquiInstance> get instances => _list;

  @override
  CoquiInstance? get activeInstance => _list.isNotEmpty ? _list.first : null;

  @override
  Future<void> setActiveInstance(String id) async {
    activatedId = id;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<CoquiInstance> buildInstances() => [
        CoquiInstance(
          id: 'instance-1',
          name: 'Local Coqui',
          baseUrl: 'http://localhost:3300',
          apiKey: '',
          isActive: true,
        ),
        CoquiInstance(
          id: 'instance-2',
          name: 'Remote Coqui',
          baseUrl: 'https://remote.example.com',
          apiKey: 'secret',
          isActive: false,
        ),
      ];

  Widget pumpTarget(_RecordingInstanceProvider provider) {
    return ChangeNotifierProvider<InstanceProvider>.value(
      value: provider,
      child: const MaterialApp(
        home: Scaffold(
          body: Center(child: ServerSwitcher()),
        ),
      ),
    );
  }

  testWidgets('renders a row per instance plus an add button', (tester) async {
    final provider = _RecordingInstanceProvider(buildInstances());

    await tester.pumpWidget(pumpTarget(provider));
    await tester.pump();

    expect(find.byKey(const ValueKey('server-row-instance-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('server-row-instance-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('server-add')), findsOneWidget);

    // Unmount and dispose to cancel the provider's periodic health timer.
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('tapping a row activates that instance', (tester) async {
    final provider = _RecordingInstanceProvider(buildInstances());

    await tester.pumpWidget(pumpTarget(provider));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('server-row-instance-2')));
    await tester.pump();

    expect(provider.activatedId, 'instance-2');

    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
