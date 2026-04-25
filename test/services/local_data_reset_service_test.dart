import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:coqui_app/Services/database_service.dart';
import 'package:coqui_app/Services/instance_service.dart';
import 'package:coqui_app/Services/local_data_reset_service.dart';

class _FakeDatabaseService extends DatabaseService {
  bool cleared = false;
  bool deleted = false;

  @override
  Future<void> clearSessionCache() async {
    cleared = true;
  }

  @override
  Future<void> deleteDatabaseFile({String? databaseFile}) async {
    deleted = true;
  }
}

class _FakeInstanceService extends InstanceService {
  bool cleared = false;
  bool deleted = false;

  @override
  Future<void> clearAllInstances() async {
    cleared = true;
  }

  @override
  Future<void> deleteStorageFromDisk() async {
    deleted = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('coqui-app-reset-service-');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  tearDown(() async {
    if (Hive.isBoxOpen('settings')) {
      await Hive.box('settings').clear();
      await Hive.box('settings').close();
    }
    if (await Hive.boxExists('settings')) {
      await Hive.deleteBoxFromDisk('settings');
    }
    await tempDir.delete(recursive: true);
  });

  test('clearSessionCache only clears the database cache', () async {
    final databaseService = _FakeDatabaseService();
    final instanceService = _FakeInstanceService();
    final service = LocalDataResetService(
      databaseService: databaseService,
      instanceService: instanceService,
    );

    await Hive.box('settings').put('default_role', 'coder');
    await service.clearSessionCache();

    expect(databaseService.cleared, isTrue);
    expect(instanceService.cleared, isFalse);
    expect(Hive.box('settings').get('default_role'), 'coder');
  });

  test('clearAllStoredData clears cache, instances, and settings', () async {
    final databaseService = _FakeDatabaseService();
    final instanceService = _FakeInstanceService();
    final service = LocalDataResetService(
      databaseService: databaseService,
      instanceService: instanceService,
    );

    await Hive.box('settings').put('default_role', 'coder');
    await Hive.box('settings').put('brightness', 'dark');

    await service.clearAllStoredData();

    expect(databaseService.cleared, isTrue);
    expect(instanceService.cleared, isTrue);
    expect(Hive.box('settings').isEmpty, isTrue);
  });

  test('deleteAllStoredDataForRestart deletes on-disk stores for restart', () async {
    final databaseService = _FakeDatabaseService();
    final instanceService = _FakeInstanceService();
    final service = LocalDataResetService(
      databaseService: databaseService,
      instanceService: instanceService,
    );

    await Hive.box('settings').put('default_role', 'coder');

    await service.deleteAllStoredDataForRestart();

    expect(databaseService.deleted, isTrue);
    expect(instanceService.deleted, isTrue);
    expect(Hive.isBoxOpen('settings'), isFalse);
    expect(await Hive.boxExists('settings'), isFalse);
  });
}