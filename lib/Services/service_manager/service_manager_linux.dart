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
    bool autoApprove = false,
    bool unsafe = false,
  }) async {
    final unit = _buildUnit(
      coquiPath: coquiPath,
      port: port,
      autoApprove: autoApprove,
      unsafe: unsafe,
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
    final result = await Process.run(
        'systemctl', ['--user', 'start', _serviceName]);
    if (result.exitCode != 0) {
      final err = result.stderr.toString().trim();
      throw Exception(
          'systemctl start failed (exit ${result.exitCode})'
          '${err.isNotEmpty ? ": $err" : ""}');
    }
  }

  @override
  Future<void> stopService() async {
    final result = await Process.run(
        'systemctl', ['--user', 'stop', _serviceName]);
    if (result.exitCode != 0) {
      final err = result.stderr.toString().trim();
      throw Exception(
          'systemctl stop failed (exit ${result.exitCode})'
          '${err.isNotEmpty ? ": $err" : ""}');
    }
  }

  @override
  Future<void> restartService() async {
    final result = await Process.run(
        'systemctl', ['--user', 'restart', _serviceName]);
    if (result.exitCode != 0) {
      final err = result.stderr.toString().trim();
      throw Exception(
          'systemctl restart failed (exit ${result.exitCode})'
          '${err.isNotEmpty ? ": $err" : ""}');
    }
  }

  String _buildUnit({
    required String coquiPath,
    required int port,
    bool autoApprove = false,
    bool unsafe = false,
  }) {
    final flags = StringBuffer();
    if (autoApprove) flags.write(' --auto-approve');
    if (unsafe) flags.write(' --unsafe');

    return '''[Unit]
Description=Coqui Bot API
After=network.target

[Service]
Type=simple
WorkingDirectory=$coquiPath
ExecStart=/bin/bash $coquiPath/bin/coqui-launcher --api-only --host 127.0.0.1 --port $port${flags.toString()}
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
''';
  }
}
