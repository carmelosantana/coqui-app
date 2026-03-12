import 'dart:io';

import 'service_manager_stub.dart' show ServiceManager;
import 'service_manager_macos.dart';
import 'service_manager_linux.dart';
import 'service_manager_windows.dart';

export 'service_manager_stub.dart' show ServiceManager;

ServiceManager createServiceManager() {
  if (Platform.isMacOS) return MacOSServiceManager();
  if (Platform.isLinux) return LinuxServiceManager();
  if (Platform.isWindows) return WindowsServiceManager();
  return _FallbackServiceManager();
}

class _FallbackServiceManager implements ServiceManager {
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
  }) async {}

  @override
  Future<void> uninstallService() async {}

  @override
  Future<void> startService() async {}

  @override
  Future<void> stopService() async {}
}
