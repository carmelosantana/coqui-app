import 'dart:io';

import 'service_manager_stub.dart' show ServiceManager;

/// macOS service management via launchd.
///
/// Installs a user-level LaunchAgent plist that keeps the Coqui API running
/// in the background and auto-starts on login. No sudo required.
class MacOSServiceManager implements ServiceManager {
  static const _label = 'ai.coquibot.api';

  String? _realHome;

  /// Resolve the real user home, avoiding sandbox container paths.
  Future<String> _resolveHome() async {
    if (_realHome != null) return _realHome!;

    var home = Platform.environment['HOME'] ?? '';

    if (home.contains('/Library/Containers/')) {
      try {
        final user = Platform.environment['USER'] ?? '';
        if (user.isNotEmpty) {
          final result = await Process.run(
            '/usr/bin/dscl',
            ['.', '-read', '/Users/$user', 'NFSHomeDirectory'],
          );
          if (result.exitCode == 0) {
            final match = RegExp(r'NFSHomeDirectory:\s*(.+)')
                .firstMatch(result.stdout.toString().trim());
            if (match != null) {
              home = match.group(1)!.trim();
            }
          }
        }
      } catch (_) {}

      if (home.contains('/Library/Containers/')) {
        final user = Platform.environment['USER'] ?? '';
        if (user.isNotEmpty) home = '/Users/$user';
      }
    }

    _realHome = home;
    return home;
  }

  Future<String> _getPlistDir() async {
    final home = await _resolveHome();
    return '$home/Library/LaunchAgents';
  }

  Future<String> _getPlistPath() async {
    final dir = await _getPlistDir();
    return '$dir/$_label.plist';
  }

  @override
  bool get serviceSupported => true;

  @override
  Future<bool> isServiceInstalled() async {
    final path = await _getPlistPath();
    return File(path).existsSync();
  }

  @override
  Future<bool> isServiceRunning() async {
    try {
      final result = await Process.run('launchctl', ['list']);
      return result.stdout.toString().contains(_label);
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
    final plist = _buildPlist(
      coquiPath: coquiPath,
      port: port,
      autoApprove: autoApprove,
      unsafe: unsafe,
    );

    final plistDir = await _getPlistDir();
    final dir = Directory(plistDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final plistPath = await _getPlistPath();
    File(plistPath).writeAsStringSync(plist);

    await Process.run('launchctl', ['load', '-w', plistPath]);
  }

  @override
  Future<void> uninstallService() async {
    if (await isServiceRunning()) {
      await stopService();
    }
    final plistPath = await _getPlistPath();
    await Process.run('launchctl', ['unload', '-w', plistPath]);
    final file = File(plistPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  @override
  Future<void> startService() async {
    await Process.run('launchctl', ['start', _label]);
  }

  @override
  Future<void> stopService() async {
    await Process.run('launchctl', ['stop', _label]);
  }

  String _buildPlist({
    required String coquiPath,
    required int port,
    bool autoApprove = false,
    bool unsafe = false,
  }) {
    final flagArgs = StringBuffer();
    if (autoApprove)
      flagArgs.write('\n        <string>--auto-approve</string>');
    if (unsafe) flagArgs.write('\n        <string>--unsafe</string>');

    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$_label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$coquiPath/bin/coqui-launcher</string>
        <string>--api-only</string>
        <string>--host</string>
        <string>127.0.0.1</string>
        <string>--port</string>
        <string>$port</string>${flagArgs.toString()}
    </array>
    <key>WorkingDirectory</key>
    <string>$coquiPath</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>$coquiPath/.workspace/logs/api-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$coquiPath/.workspace/logs/api-stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>${Platform.environment['HOME'] ?? ''}</string>
    </dict>
</dict>
</plist>
''';
  }
}
