import 'dart:io';

import 'service_manager_stub.dart' show ServiceManager;

/// Linux service management via systemd user units.
///
/// Installs a user-level systemd service (no sudo required) that keeps the
/// Coqui API running in the background and auto-starts on login.
class LinuxServiceManager implements ServiceManager {
  static const _serviceName = 'coqui-api';
  static const _serviceFile = '$_serviceName.service';

  String get _unitDir {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.config/systemd/user';
  }

  String get _unitPath => '$_unitDir/$_serviceFile';

  @override
  bool get serviceSupported => _systemctlAvailable();

  bool _systemctlAvailable() {
    try {
      final result = Process.runSync('which', ['systemctl']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isServiceInstalled() async {
    return File(_unitPath).existsSync();
  }

  @override
  Future<bool> isServiceRunning() async {
    try {
      final result = await Process.run(
        'systemctl',
        ['--user', 'is-active', _serviceName],
      );
      return result.stdout.toString().trim() == 'active';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> installService({
    required String coquiPath,
    required int port,
  }) async {
    final phpPath = await _resolvePhpPath();
    final unit = _buildUnit(
      phpPath: phpPath,
      coquiPath: coquiPath,
      port: port,
    );

    final dir = Directory(_unitDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    File(_unitPath).writeAsStringSync(unit);

    await Process.run('systemctl', ['--user', 'daemon-reload']);
    await Process.run('systemctl', ['--user', 'enable', _serviceName]);
  }

  @override
  Future<void> uninstallService() async {
    if (await isServiceRunning()) {
      await stopService();
    }
    await Process.run('systemctl', ['--user', 'disable', _serviceName]);

    final file = File(_unitPath);
    if (file.existsSync()) {
      file.deleteSync();
    }

    await Process.run('systemctl', ['--user', 'daemon-reload']);
  }

  @override
  Future<void> startService() async {
    await Process.run('systemctl', ['--user', 'start', _serviceName]);
  }

  @override
  Future<void> stopService() async {
    await Process.run('systemctl', ['--user', 'stop', _serviceName]);
  }

  Future<String> _resolvePhpPath() async {
    final result = await Process.run('which', ['php']);
    final path = result.stdout.toString().trim();
    return path.isNotEmpty ? path : '/usr/bin/php';
  }

  String _buildUnit({
    required String phpPath,
    required String coquiPath,
    required int port,
  }) {
    return '''[Unit]
Description=Coqui Bot API
After=network.target

[Service]
Type=simple
WorkingDirectory=$coquiPath
ExecStart=$phpPath $coquiPath/bin/coqui api --host 127.0.0.1 --port $port
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
''';
  }
}
