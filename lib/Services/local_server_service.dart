import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:coqui_app/Models/local_server_state.dart';

class LocalServerConfigSnapshot {
  final String? apiKey;
  final int port;
  final String host;

  const LocalServerConfigSnapshot({
    required this.apiKey,
    required this.port,
    required this.host,
  });
}

/// Manages the local Coqui server installation, process lifecycle, and
/// configuration. Desktop-only — guarded by [PlatformInfo.isDesktop] at the
/// call-site.
class LocalServerService {
  static const _installerUrlUnix =
      'https://raw.githubusercontent.com/AgentCoqui/coqui-installer/main/install.sh';

  static const defaultPort = 3300;
  static const defaultHost = '127.0.0.1';

  /// Regex to strip ANSI escape sequences from process output.
  /// Catches CSI sequences, OSC sequences, and character-set selects (sgr0).
  static final _ansiRegex = RegExp(
    r'\x1B'
    r'(?:'
    r'\[[0-9;?]*[A-Za-z]' // CSI: ESC [ ... letter
    r'|\][^\x07]*\x07' // OSC: ESC ] ... BEL
    r'|\][^\x1B]*\x1B\\' // OSC: ESC ] ... ST
    r'|[()][A-Z0-9]' // Character set: ESC ( B, ESC ) 0, etc.
    r'|[=>NOM78H]' // Simple ESC sequences
    r')',
  );

  Process? _serverProcess;
  String? _resolvedHome;

  final _logController = StreamController<String>.broadcast();

  /// Stream of log lines from the server process and installer.
  Stream<String> get logStream => _logController.stream;

  // ── Path helpers ──────────────────────────────────────────────────────

  /// Resolve the real user home directory.
  ///
  /// On macOS, sandboxed apps redirect `$HOME` to the container. We detect
  /// this and recover the real home via `dscl` or the `USER` env var.
  Future<String> _resolveHome() async {
    if (_resolvedHome != null) return _resolvedHome!;

    var home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';

    // Detect macOS sandbox container redirect
    if (Platform.isMacOS && home.contains('/Library/Containers/')) {
      // Try dscl (directory services) first
      try {
        final user = Platform.environment['USER'] ?? '';
        if (user.isNotEmpty) {
          final result = await Process.run(
            '/usr/bin/dscl',
            ['.', '-read', '/Users/$user', 'NFSHomeDirectory'],
          );
          if (result.exitCode == 0) {
            final output = result.stdout.toString().trim();
            final match =
                RegExp(r'NFSHomeDirectory:\s*(.+)').firstMatch(output);
            if (match != null) {
              home = match.group(1)!.trim();
            }
          }
        }
      } catch (_) {}

      // Fallback: construct from USER env var
      if (home.contains('/Library/Containers/')) {
        final user = Platform.environment['USER'] ?? '';
        if (user.isNotEmpty) {
          home = '/Users/$user';
        }
      }
    }

    _resolvedHome = home;
    return home;
  }

  /// Synchronous accessor — only valid after first call to [_resolveHome].
  String get _home => _resolvedHome ?? Platform.environment['HOME'] ?? '';

  String get installPath => '$_home/.coqui';
  String get workspacePath => '$installPath/.workspace';
  String get envPath => '$workspacePath/.env';

  String get _binPath => '$installPath/bin/coqui';
  String get _launcherPath => '$installPath/bin/coqui-launcher';
  String get _versionFile => '$installPath/.coqui-version';
  String get _logsDir => '$workspacePath/logs';
  String get _apiPidPath => '$workspacePath/pids/api.pid';

  /// Resolve the user's default shell and build an environment map that
  /// inherits the full login PATH (Homebrew, nix, etc.).
  Future<Map<String, String>> _loginEnvironment() async {
    final env = Map<String, String>.from(Platform.environment);
    final home = await _resolveHome();
    env['HOME'] = home;

    try {
      // Source the login shell to get PATH with Homebrew etc.
      final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
      final result = await Process.run(
        shell,
        ['-l', '-c', 'echo \$PATH 2>/dev/null'],
      );
      if (result.exitCode == 0) {
        final loginPath = result.stdout.toString().trim();
        if (loginPath.isNotEmpty) {
          env['PATH'] = loginPath;
        }
      }
    } catch (_) {}

    return env;
  }

  // ── Detection ─────────────────────────────────────────────────────────

  /// Detect whether Coqui is installed and return current info.
  Future<LocalServerInfo> detectInstallation() async {
    await _resolveHome();

    final installed =
        Directory(installPath).existsSync() && File(_binPath).existsSync();

    if (!installed) {
      return LocalServerInfo(
        status: LocalServerStatus.notInstalled,
        installPath: installPath,
        workspacePath: workspacePath,
      );
    }

    final version = _readVersion();
    final config = await readConfig();

    // Check if server process is responding
    final healthy = await checkHealth(port: config.port);

    return LocalServerInfo(
      status: healthy ? LocalServerStatus.running : LocalServerStatus.stopped,
      version: version,
      installPath: installPath,
      workspacePath: workspacePath,
      port: config.port,
      apiKey: config.apiKey,
      pid: processPid,
    );
  }

  int? _readTrackedPid() {
    try {
      final file = File(_apiPidPath);
      if (!file.existsSync()) {
        return null;
      }

      return int.tryParse(file.readAsStringSync().trim());
    } catch (_) {
      return null;
    }
  }

  Future<LocalServerConfigSnapshot> readConfig() async {
    await _resolveHome();

    return LocalServerConfigSnapshot(
      apiKey: _readApiKey(),
      port: _readPort(),
      host: _readHost(),
    );
  }

  String? _readVersion() {
    try {
      final file = File(_versionFile);
      if (file.existsSync()) {
        return file.readAsStringSync().trim();
      }
    } catch (_) {}
    return null;
  }

  String? _readApiKey() {
    try {
      final file = File(envPath);
      if (file.existsSync()) {
        for (final line in file.readAsLinesSync()) {
          if (line.startsWith('COQUI_API_KEY=')) {
            return line.substring('COQUI_API_KEY='.length).trim();
          }
        }
      }
    } catch (_) {}
    return null;
  }

  int _readPort() {
    try {
      final file = File(envPath);
      if (file.existsSync()) {
        for (final line in file.readAsLinesSync()) {
          if (line.startsWith('COQUI_API_PORT=')) {
            return int.tryParse(
                    line.substring('COQUI_API_PORT='.length).trim()) ??
                defaultPort;
          }
        }
      }
    } catch (_) {}
    return defaultPort;
  }

  String _readHost() {
    try {
      final file = File(envPath);
      if (file.existsSync()) {
        for (final line in file.readAsLinesSync()) {
          if (line.startsWith('COQUI_API_HOST=')) {
            final host = line.substring('COQUI_API_HOST='.length).trim();
            if (host.isNotEmpty) return host;
          }
        }
      }
    } catch (_) {}
    return defaultHost;
  }

  // ── PHP check ─────────────────────────────────────────────────────────

  Future<bool> isPhpAvailable() async {
    try {
      final env = await _loginEnvironment();
      final result = await Process.run('php', ['--version'], environment: env);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  // ── Install ───────────────────────────────────────────────────────────

  /// Install the Coqui server. Streams output to [logStream].
  Future<bool> install() async {
    _log('Starting Coqui server installation...');
    await _resolveHome();

    if (Platform.isWindows) {
      _log(
          'Managed local server installation is only available on macOS and Linux.');
      return false;
    }

    try {
      return await _installUnix();
    } catch (e) {
      _log('Installation failed: $e');
      return false;
    }
  }

  Future<bool> _installUnix() async {
    // Download installer script to temp
    _log('Downloading installer...');
    final response = await http.get(Uri.parse(_installerUrlUnix));
    if (response.statusCode != 200) {
      _log('Failed to download installer (HTTP ${response.statusCode})');
      return false;
    }

    final tempDir = Directory.systemTemp.createTempSync('coqui_install_');
    final scriptFile = File('${tempDir.path}/install.sh');
    scriptFile.writeAsStringSync(response.body);

    // Make executable
    await Process.run('chmod', ['+x', scriptFile.path]);

    _log('Running installer...');
    final env = await _loginEnvironment();
    env['COQUI_INSTALL_DIR'] = installPath;
    // Prevent tput from emitting ANSI escapes and suppress sudo prompts
    env['TERM'] = 'dumb';
    env['SUDO_ASKPASS'] = '/bin/false';

    final process = await Process.start(
      'bash',
      [scriptFile.path, '--non-interactive', '--quiet'],
      environment: env,
      // Redirect stdin from /dev/null so sudo cannot prompt for a password.
      // The symlink step will fall back to ~/.local/bin instead.
      mode: ProcessStartMode.normal,
    );
    // Close stdin so sudo gives up immediately
    process.stdin.close();

    await _pipeProcessOutput(process);
    final exitCode = await process.exitCode;

    // Cleanup
    tempDir.deleteSync(recursive: true);

    if (exitCode == 0) {
      _log('Installation completed successfully.');
      return true;
    } else {
      _log('Installer exited with code $exitCode');
      return false;
    }
  }

  // ── Update ────────────────────────────────────────────────────────────

  /// Re-run the installer to update to the latest version.
  Future<bool> update() async {
    _log('Checking for updates...');
    return install();
  }

  // ── Uninstall ─────────────────────────────────────────────────────────

  static const _uninstallerUrlUnix =
      'https://raw.githubusercontent.com/AgentCoqui/coqui-installer/main/uninstall.sh';

  /// Uninstall the Coqui server. Streams output to [logStream].
  ///
  /// [removeWorkspace] — also deletes the `.workspace` directory (sessions,
  /// packages, logs).
  /// [removePhpAndComposer] — also removes PHP and Composer from the system.
  Future<bool> uninstall({
    bool removeWorkspace = false,
    bool removePhpAndComposer = false,
  }) async {
    _log('Starting Coqui server uninstall...');
    await _resolveHome();

    if (Platform.isWindows) {
      _log(
          'Managed local server uninstall is only available on macOS and Linux.');
      return false;
    }

    try {
      return await _uninstallUnix(
        removeWorkspace: removeWorkspace,
        removePhpAndComposer: removePhpAndComposer,
      );
    } catch (e) {
      _log('Uninstall failed: $e');
      return false;
    }
  }

  Future<bool> _uninstallUnix({
    required bool removeWorkspace,
    required bool removePhpAndComposer,
  }) async {
    _log('Downloading uninstaller...');
    final response = await http.get(Uri.parse(_uninstallerUrlUnix));
    if (response.statusCode != 200) {
      _log('Failed to download uninstaller (HTTP ${response.statusCode})');
      return false;
    }

    final tempDir = Directory.systemTemp.createTempSync('coqui_uninstall_');
    final scriptFile = File('${tempDir.path}/uninstall.sh');
    scriptFile.writeAsStringSync(response.body);

    await Process.run('chmod', ['+x', scriptFile.path]);

    _log('Running uninstaller...');
    final env = await _loginEnvironment();
    env['COQUI_INSTALL_DIR'] = installPath;
    env['TERM'] = 'dumb';
    env['SUDO_ASKPASS'] = '/bin/false';

    final args = [scriptFile.path, '--force', '--quiet'];
    if (removeWorkspace) args.add('--remove-workspace');
    if (removePhpAndComposer) args.add('--all');

    final process = await Process.start(
      'bash',
      args,
      environment: env,
      mode: ProcessStartMode.normal,
    );
    process.stdin.close();

    await _pipeProcessOutput(process);
    final exitCode = await process.exitCode;

    tempDir.deleteSync(recursive: true);

    if (exitCode == 0) {
      _log('Uninstall completed successfully.');
      return true;
    } else {
      _log('Uninstaller exited with code $exitCode');
      return false;
    }
  }

  // ── Configuration ─────────────────────────────────────────────────────

  /// Generate a random API key and write it to the workspace .env.
  String generateApiKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return key;
  }

  /// Write server configuration to the workspace .env file.
  Future<void> writeConfig({
    required String apiKey,
    int port = defaultPort,
    String host = defaultHost,
  }) async {
    final wsDir = Directory(workspacePath);
    if (!wsDir.existsSync()) {
      wsDir.createSync(recursive: true);
    }

    // Ensure the logs directory exists before the launcher writes output.
    final logsDir = Directory(_logsDir);
    if (!logsDir.existsSync()) {
      logsDir.createSync(recursive: true);
    }

    final envContent = StringBuffer();

    // Read existing .env and preserve non-Coqui lines
    final envFile = File(envPath);
    if (envFile.existsSync()) {
      for (final line in envFile.readAsLinesSync()) {
        if (!line.startsWith('COQUI_API_KEY=') &&
            !line.startsWith('COQUI_API_PORT=') &&
            !line.startsWith('COQUI_API_HOST=')) {
          envContent.writeln(line);
        }
      }
    }

    envContent.writeln('COQUI_API_KEY=$apiKey');
    envContent.writeln('COQUI_API_PORT=$port');
    envContent.writeln('COQUI_API_HOST=$host');

    envFile.writeAsStringSync(envContent.toString());
    _log('Server configuration written.');
  }

  // ── Process management ────────────────────────────────────────────────

  /// Start the Coqui API server as a child process.
  ///
  /// On Unix, uses `bin/coqui-launcher --api-only` when the launcher is
  /// present (handles restart logic and crash recovery). Falls back to
  /// `php bin/coqui api` when the launcher is missing or on Windows.
  Future<bool> startProcess({
    int port = defaultPort,
    String host = defaultHost,
    bool autoApprove = false,
    bool unsafe = false,
  }) async {
    if (Platform.isWindows) {
      _log(
          'Managed local server startup is only available on macOS and Linux.');
      return false;
    }

    if (isProcessRunning) {
      _log('Server process is already running.');
      return true;
    }

    if (!File(_binPath).existsSync()) {
      _log('Error: Coqui binary not found at $_binPath');
      return false;
    }

    _log('Starting Coqui API on $host:$port...');

    try {
      final env = await _loginEnvironment();
      final useLauncher = File(_launcherPath).existsSync();

      if (useLauncher) {
        final args = [
          _launcherPath,
          '--api-only',
          '--background',
          '--host',
          host,
          '--port',
          '$port',
          if (autoApprove) '--auto-approve',
          if (unsafe) '--unsafe',
        ];
        final launcherProcess = await Process.start(
          '/bin/bash',
          args,
          workingDirectory: installPath,
          environment: env,
        );
        await _pipeProcessOutput(launcherProcess);

        final exitCode = await launcherProcess.exitCode;
        if (exitCode != 0) {
          _log('Launcher start command exited with code $exitCode');
          return false;
        }

        final healthy = await _waitForHealth(
          port: port,
          timeout: const Duration(seconds: 20),
          requireManagedProcess: false,
        );

        if (healthy) {
          _log('Server started (PID: ${processPid ?? 'unknown'}).');
        } else {
          _log('Server launch acknowledged. Waiting for API health...');
        }

        return true;
      }

      final phpAvailable = await isPhpAvailable();
      if (!phpAvailable) {
        _log('Error: PHP is not available in PATH.');
        return false;
      }
      final args = [
        _binPath,
        'api',
        '--host',
        host,
        '--port',
        '$port',
        if (autoApprove) '--auto-approve',
        if (unsafe) '--unsafe',
      ];
      final serverProcess = await Process.start(
        'php',
        args,
        workingDirectory: installPath,
        environment: env,
      );

      _serverProcess = serverProcess;

      await _pipeProcessOutput(serverProcess);

      // Monitor process exit
      serverProcess.exitCode.then((code) {
        if (identical(_serverProcess, serverProcess)) {
          _serverProcess = null;
        }
        _log('Server process exited with code $code');
      });

      final healthy = await _waitForHealth(port: port);
      if (healthy) {
        _log('Server started (PID: ${_serverProcess?.pid}).');
        return true;
      } else {
        _log('Server process started but never became healthy. '
            'Check the console for errors.');
        await stopProcess();
        return false;
      }
    } catch (e) {
      _log('Failed to start server: $e');
      _serverProcess = null;
      return false;
    }
  }

  /// Stop the running server process.
  Future<void> stopProcess() async {
    final useLauncher = !Platform.isWindows && File(_launcherPath).existsSync();

    if (useLauncher) {
      final trackedPid = _readTrackedPid();
      if (trackedPid == null && _serverProcess == null) {
        _log('No server process to stop.');
        return;
      }

      _log('Stopping server...');
      try {
        final env = await _loginEnvironment();
        final config = await readConfig();
        final stopProcess = await Process.start(
          '/bin/bash',
          [
            _launcherPath,
            'stop-api',
            '--port',
            '${config.port}',
          ],
          workingDirectory: installPath,
          environment: env,
        );

        await _pipeProcessOutput(stopProcess);
        final exitCode = await stopProcess.exitCode;
        if (exitCode != 0) {
          _log('Launcher stop command exited with code $exitCode');
        }
      } catch (e) {
        _log('Failed to stop server: $e');
      } finally {
        _serverProcess = null;
      }

      _log('Server stopped.');
      return;
    }

    final process = _serverProcess;
    if (process == null) {
      _log('No server process to stop.');
      return;
    }

    _log('Stopping server...');
    final sentSigterm = process.kill(ProcessSignal.sigterm);
    if (!sentSigterm) {
      _log('Server process was already exiting.');
    }

    // Wait briefly, then force kill if needed
    try {
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _log('Forcing server shutdown...');
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    } catch (_) {}

    _serverProcess = null;
    _log('Server stopped.');
  }

  /// Whether a managed server process is running.
  bool get isProcessRunning =>
      _serverProcess != null || _readTrackedPid() != null;

  /// PID of the managed server process, if running.
  int? get processPid => _serverProcess?.pid ?? _readTrackedPid();

  // ── Health check ──────────────────────────────────────────────────────

  /// Check if the Coqui API at the given port is responding.
  Future<bool> checkHealth({int port = defaultPort}) async {
    try {
      final uri = Uri.parse('http://127.0.0.1:$port/api/v1/health');
      final response = await http.get(uri).timeout(
            const Duration(seconds: 3),
          );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _waitForHealth({
    required int port,
    Duration timeout = const Duration(seconds: 12),
    bool requireManagedProcess = true,
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      if (await checkHealth(port: port)) {
        return true;
      }

      if (requireManagedProcess && _serverProcess == null) {
        return false;
      }

      await Future.delayed(const Duration(milliseconds: 400));
    }

    return false;
  }

  // ── Logging ───────────────────────────────────────────────────────────

  void _log(String message) {
    _logController.add(message);
  }

  Future<void> _pipeProcessOutput(Process process) async {
    process.stdout.transform(utf8.decoder).listen((data) {
      for (final line in data.split('\n')) {
        final cleaned = line.replaceAll(_ansiRegex, '').trim();
        if (cleaned.isNotEmpty) _log(cleaned);
      }
    });
    process.stderr.transform(utf8.decoder).listen((data) {
      for (final line in data.split('\n')) {
        final cleaned = line.replaceAll(_ansiRegex, '').trim();
        if (cleaned.isNotEmpty) _log('[stderr] $cleaned');
      }
    });
  }

  /// Clean up resources.
  void dispose() {
    _serverProcess?.kill();
    _logController.close();
  }
}
