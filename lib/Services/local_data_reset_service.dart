import 'package:hive_flutter/hive_flutter.dart';

import 'package:coqui_app/Services/database_service.dart';
import 'package:coqui_app/Services/instance_service.dart';

/// Coordinates destructive local-only data resets for the app.
class LocalDataResetService {
  static const String settingsBoxName = 'settings';

  final DatabaseService _databaseService;
  final InstanceService _instanceService;

  const LocalDataResetService({
    required DatabaseService databaseService,
    required InstanceService instanceService,
  })  : _databaseService = databaseService,
        _instanceService = instanceService;

  /// Delete the local cached session/message data while preserving settings.
  Future<void> clearSessionCache() async {
    await _databaseService.clearSessionCache();
  }

  /// Delete locally stored app state while leaving server-side data untouched.
  Future<void> clearAllStoredData() async {
    await _databaseService.clearSessionCache();
    await Hive.box(settingsBoxName).clear();
    await _instanceService.clearAllInstances();
  }

  /// Close and delete device-local stores before a full app restart.
  Future<void> deleteAllStoredDataForRestart() async {
    await _databaseService.deleteDatabaseFile();
    await _deleteHiveBox(settingsBoxName);
    await _instanceService.deleteStorageFromDisk();
  }

  Future<void> _deleteHiveBox(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box(boxName).close();
    }

    await Hive.deleteBoxFromDisk(boxName);
  }
}