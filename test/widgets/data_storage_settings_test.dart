import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coqui_app/Pages/settings_page/subwidgets/data_storage_settings.dart';
import 'package:coqui_app/Models/coqui_instance.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Providers/chat_provider.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/app_restart_service.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/database_service.dart';
import 'package:coqui_app/Services/instance_service.dart';
import 'package:coqui_app/Services/local_data_reset_service.dart';

class _FakeDatabaseService extends DatabaseService {
  @override
  Future<void> open(String databaseFile) async {}

  @override
  Future<List<CoquiSession>> getSessions({String? instanceId}) async =>
      const [];

  @override
  Future<void> clearSessionCache() async {}

  @override
  Future<void> deleteDatabaseFile({String? databaseFile}) async {}
}

class _FakeApiService extends CoquiApiService {}

class _FakeInstanceService extends InstanceService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> ensureDefaultInstance() async {}

  @override
  List<CoquiInstance> getInstances() => const [];

  @override
  CoquiInstance? getActiveInstance() => null;

  @override
  Future<void> clearAllInstances() async {}
}

class _RecordingLocalDataResetService extends LocalDataResetService {
  int clearSessionCacheCalls = 0;
  int clearAllStoredDataCalls = 0;
  int deleteAllStoredDataForRestartCalls = 0;

  _RecordingLocalDataResetService()
      : super(
          databaseService: _FakeDatabaseService(),
          instanceService: _FakeInstanceService(),
        );

  @override
  Future<void> clearSessionCache() async {
    clearSessionCacheCalls += 1;
  }

  @override
  Future<void> clearAllStoredData() async {
    clearAllStoredDataCalls += 1;
  }

  @override
  Future<void> deleteAllStoredDataForRestart() async {
    deleteAllStoredDataForRestartCalls += 1;
  }
}

class _RecordingAppRestartService extends AppRestartService {
  bool supported;
  int restartCalls = 0;

  _RecordingAppRestartService({
    required this.supported,
  });

  @override
  Future<bool> isRestartSupported() async => supported;

  @override
  Future<AppRestartResult> restartApplication() async {
    restartCalls += 1;
    return AppRestartResult.restarted;
  }
}

class _RecordingChatProvider extends ChatProvider {
  int clearLocalSessionStateCalls = 0;

  _RecordingChatProvider()
      : super(
          apiService: _FakeApiService(),
          databaseService: _FakeDatabaseService(),
        );

  @override
  void clearLocalSessionState() {
    clearLocalSessionStateCalls += 1;
    super.clearLocalSessionState();
  }
}

class _RecordingInstanceProvider extends InstanceProvider {
  int clearStoredInstancesCalls = 0;
  int pauseForDestructiveResetCalls = 0;

  _RecordingInstanceProvider()
      : super(
          instanceService: _FakeInstanceService(),
          apiService: _FakeApiService(),
        ) {
    scheduleMicrotask(pauseForDestructiveReset);
  }

  @override
  Future<void> clearStoredInstances({bool ensureDefaultInstance = false}) async {
    clearStoredInstancesCalls += 1;
  }

  @override
  void pauseForDestructiveReset() {
    pauseForDestructiveResetCalls += 1;
    super.pauseForDestructiveReset();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSubject({
    required _RecordingLocalDataResetService resetService,
    required _RecordingAppRestartService restartService,
    required _RecordingChatProvider chatProvider,
    required _RecordingInstanceProvider instanceProvider,
  }) {
    return MultiProvider(
      providers: [
        Provider<LocalDataResetService>.value(value: resetService),
        Provider<AppRestartService>.value(value: restartService),
        ChangeNotifierProvider<ChatProvider>(create: (_) => chatProvider),
        ChangeNotifierProvider<InstanceProvider>(
          create: (_) => instanceProvider,
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: DataStorageSettings(),
        ),
      ),
    );
  }

  testWidgets('clears the local session cache from the settings panel',
      (tester) async {
    final resetService = _RecordingLocalDataResetService();
    final restartService = _RecordingAppRestartService(supported: true);
    final chatProvider = _RecordingChatProvider();
    final instanceProvider = _RecordingInstanceProvider();

    await tester.pumpWidget(buildSubject(
      resetService: resetService,
      restartService: restartService,
      chatProvider: chatProvider,
      instanceProvider: instanceProvider,
    ));
    instanceProvider.pauseForDestructiveReset();

    await tester.tap(find.text('Clear Session Cache'));
    await tester.pumpAndSettle();
    expect(find.text('Clear Session Cache?'), findsOneWidget);

    await tester.tap(find.text('Clear Cache'));
    await tester.pumpAndSettle();

    expect(resetService.clearSessionCacheCalls, 1);
    expect(chatProvider.clearLocalSessionStateCalls, 1);
  });

  testWidgets('shows automatic restart copy when supported', (tester) async {
    final resetService = _RecordingLocalDataResetService();
    final restartService = _RecordingAppRestartService(
      supported: true,
    );
    final chatProvider = _RecordingChatProvider();
    final instanceProvider = _RecordingInstanceProvider();

    await tester.pumpWidget(buildSubject(
      resetService: resetService,
      restartService: restartService,
      chatProvider: chatProvider,
      instanceProvider: instanceProvider,
    ));
    instanceProvider.pauseForDestructiveReset();

    await tester.tap(find.text('Delete All Stored Data'));
    await tester.pumpAndSettle();
    expect(find.text('Delete All Stored Data?'), findsOneWidget);
    expect(find.textContaining('then restarts the app'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete All Stored Data?'), findsNothing);
  });

  testWidgets('shows manual restart copy when auto restart is unsupported',
      (tester) async {
    final resetService = _RecordingLocalDataResetService();
    final restartService = _RecordingAppRestartService(supported: false);
    final chatProvider = _RecordingChatProvider();
    final instanceProvider = _RecordingInstanceProvider();

    await tester.pumpWidget(buildSubject(
      resetService: resetService,
      restartService: restartService,
      chatProvider: chatProvider,
      instanceProvider: instanceProvider,
    ));
    instanceProvider.pauseForDestructiveReset();

    await tester.tap(find.text('Delete All Stored Data'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('you will need to close and reopen the app'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete All Stored Data?'), findsNothing);
  });
}