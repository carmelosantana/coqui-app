/// Stub implementation for web/mobile where OS service management is not
/// available.
abstract interface class ServiceManager {
  bool get serviceSupported;
  Future<bool> isServiceInstalled();
  Future<bool> isServiceRunning();
  Future<void> installService({
    required String coquiPath,
    required int port,
    bool autoApprove = false,
    bool unsafe = false,
  });
  Future<void> uninstallService();
  Future<void> startService();
  Future<void> stopService();
  Future<void> restartService();
}

ServiceManager createServiceManager() => _StubServiceManager();

class _StubServiceManager implements ServiceManager {
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
