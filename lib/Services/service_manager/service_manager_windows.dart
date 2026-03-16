import 'service_manager_stub.dart' show ServiceManager;

/// Windows service management — stub.
///
/// Windows Service support is planned for a future release. For now, the
/// Coqui API runs as a foreground process only.
class WindowsServiceManager implements ServiceManager {
  @override
  bool get serviceSupported => false;

  @override
  Future<bool> isServiceInstalled() async => false;

  @override
  Future<bool> isServiceRunning() async => false;

  @override
  Future<void> installService({
    required String coquiPath,
    required int port,
    bool autoApprove = false,
    bool unsafe = false,
  }) async {}

  @override
  Future<void> uninstallService() async {}

  @override
  Future<void> startService() async {}

  @override
  Future<void> stopService() async {}

  @override
  Future<void> restartService() async {}
}
