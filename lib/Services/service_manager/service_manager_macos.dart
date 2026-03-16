import 'dart:io';

import 'service_manager_stub.dart' show ServiceManager;

/// macOS service management via launchd.
///
/// Installs a user-level LaunchAgent plist that keeps the Coqui API running
/// in the background and auto-starts on login. No sudo required.
///
/// Uses modern launchd APIs (macOS 10.15+):
///   bootstrap / bootout  instead of deprecated  load -w / unload -w
///   kickstart -k         instead of deprecated  start
///   kill TERM            instead of deprecated  stop
class MacOSServiceManager implements ServiceManager {
  static const _label = 'ai.coquibot.api';

  String? _realHome;

  // ── Home resolution ──────────────────────────────────────────────────

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

  // ── Launchd domain helper ────────────────────────────────────────────

  /// Returns the current user's numeric UID as a string.
  Future<String> _uid() async {
    try {
      final result = await Process.run('id', ['-u']);
      return result.stdout.toString().trim();
    } catch (_) {
      return '501'; // sane default for the first normal macOS user
    }
  }

  /// The launchd domain target for the current user, e.g. `gui/501`.
  Future<String> _domain() async => 'gui/${await _uid()}';

  /// The fully-qualified launchd service target, e.g. `gui/501/ai.coquibot.api`.
  Future<String> _target() async => '${await _domain()}/$_label';

  // ── ServiceManager interface ─────────────────────────────────────────

  @override
  bool get serviceSupported => true;

  @override
  Future<bool> isServiceInstalled() async {
    final path = await _getPlistPath();
    return File(path).existsSync();
  }

  /// Returns true only when the job has an active PID (i.e., is running),
  /// not just registered with launchd.
  ///
  /// `launchctl list` output columns: PID  Status  Label
  /// A running job has a numeric PID; a stopped-but-registered job shows `-`.
  @override
  Future<bool> isServiceRunning() async {
    try {
      final result = await Process.run('launchctl', ['list']);
      final lines = result.stdout.toString().split('\n');
      for (final line in lines) {
        if (line.contains(_label)) {
          // Column 0 is PID (`-` when not running, a number when running)
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.isNotEmpty && parts[0] != '-') {
            return true;
          }
          return false;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Install (bootstrap) the LaunchAgent.
  ///
  /// Uses `launchctl bootstrap` (macOS 10.15+) instead of the deprecated
  /// `launchctl load -w`.
  ///
  /// Bakes the user's full login PATH into the plist `EnvironmentVariables`
  /// so that launchd can find PHP (Homebrew, nix, etc.) without relying on
  /// the bare system PATH that launchd provides by default.
  @override
  Future<void> installService({
    required String coquiPath,
    required int port,
    bool autoApprove = false,
    bool unsafe = false,
  }) async {
    final home = await _resolveHome();
    final loginPath = await _resolveLoginPath(home);

    final plist = _buildPlist(
      realHome: home,
      loginPath: loginPath,
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

    final domain = await _domain();

    // If the job is already bootstrapped, bootout first to avoid conflict.
    final listResult = await Process.run('launchctl', ['list']);
    if (listResult.stdout.toString().contains(_label)) {
      await Process.run('launchctl', ['bootout', domain, plistPath]);
    }

    final result =
        await Process.run('launchctl', ['bootstrap', domain, plistPath]);
    if (result.exitCode != 0) {
      final err = result.stderr.toString().trim();
      throw Exception('launchctl bootstrap failed (exit ${result.exitCode})'
          '${err.isNotEmpty ? ": $err" : ""}');
    }
  }

  /// Resolve the user's full login PATH by sourcing their default shell.
  ///
  /// This mirrors `LocalServerService._loginEnvironment()` so the service
  /// plist gets the same PATH as the interactive process start path.
  Future<String> _resolveLoginPath(String home) async {
    try {
      final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
      final result = await Process.run(
        shell,
        ['-l', '-c', 'echo \$PATH 2>/dev/null'],
        environment: {...Platform.environment, 'HOME': home},
      );
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty) return path;
      }
    } catch (_) {}
    // Sane fallback that covers Homebrew on both Intel and Apple Silicon.
    return '/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin';
  }

  /// Uninstall (bootout) the LaunchAgent and remove the plist.
  ///
  /// Uses `launchctl bootout` (macOS 10.15+) instead of the deprecated
  /// `launchctl unload -w`.
  @override
  Future<void> uninstallService() async {
    final plistPath = await _getPlistPath();
    final domain = await _domain();

    await Process.run('launchctl', ['bootout', domain, plistPath]);

    final file = File(plistPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  /// Start the service.
  ///
  /// Uses `launchctl kickstart -k` (macOS 10.15+) which forcibly starts the
  /// job even if it is already registered. The deprecated `launchctl start`
  /// silently fails on modern macOS.
  @override
  Future<void> startService() async {
    final target = await _target();
    final result =
        await Process.run('launchctl', ['kickstart', '-k', target]);
    if (result.exitCode != 0) {
      final err = result.stderr.toString().trim();
      throw Exception(
          'launchctl kickstart failed (exit ${result.exitCode})'
          '${err.isNotEmpty ? ": $err" : ""}');
    }
  }

  /// Stop the service by sending SIGTERM.
  ///
  /// Uses `launchctl kill TERM` (macOS 10.15+) instead of the deprecated
  /// `launchctl stop`.
  @override
  Future<void> stopService() async {
    final target = await _target();
    final result =
        await Process.run('launchctl', ['kill', 'TERM', target]);
    if (result.exitCode != 0) {
      final err = result.stderr.toString().trim();
      // Exit code 3 means the process wasn't running — that's fine.
      if (result.exitCode != 3) {
        throw Exception(
            'launchctl kill failed (exit ${result.exitCode})'
            '${err.isNotEmpty ? ": $err" : ""}');
      }
    }
  }

  /// Restart the service by kicking it with the `-k` (kill) flag, which
  /// terminates any running instance and immediately relaunches it.
  @override
  Future<void> restartService() async {
    final target = await _target();
    final result =
        await Process.run('launchctl', ['kickstart', '-k', target]);
    if (result.exitCode != 0) {
      final err = result.stderr.toString().trim();
      throw Exception(
          'launchctl kickstart (restart) failed (exit ${result.exitCode})'
          '${err.isNotEmpty ? ": $err" : ""}');
    }
  }

  // ── Plist builder ────────────────────────────────────────────────────

  String _buildPlist({
    required String realHome,
    required String loginPath,
    required String coquiPath,
    required int port,
    bool autoApprove = false,
    bool unsafe = false,
  }) {
    final flagArgs = StringBuffer();
    if (autoApprove) flagArgs.write('\n        <string>--auto-approve</string>');
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
        <string>$realHome</string>
        <key>PATH</key>
        <string>$loginPath</string>
    </dict>
</dict>
</plist>
''';
  }
}
