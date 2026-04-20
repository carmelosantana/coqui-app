import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:coqui_app/Models/coqui_instance.dart';
import 'package:coqui_app/Models/local_server_state.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/instance_service.dart';
import 'package:coqui_app/Services/local_server_service.dart';

/// State management for the local Coqui server.
///
/// Wraps [LocalServerService] and provides reactive state updates via
/// [ChangeNotifier]. Handles installation, process lifecycle, periodic health
/// polling, and auto-configuring a local [CoquiInstance].
class LocalServerProvider extends ChangeNotifier {
  final LocalServerService _service;
  final InstanceProvider _instanceProvider;

  LocalServerInfo _info = const LocalServerInfo();
  LocalServerInfo get info => _info;

  // ── Launch flags ──────────────────────────────────────────────────────

  static const _keyAutoApprove = 'local_server_auto_approve';
  static const _keyUnsafe = 'local_server_unsafe';

  bool get autoApprove =>
      Hive.box('settings').get(_keyAutoApprove, defaultValue: false) as bool;

  bool get unsafe =>
      Hive.box('settings').get(_keyUnsafe, defaultValue: false) as bool;

  Future<void> setAutoApprove(bool value) async {
    await Hive.box('settings').put(_keyAutoApprove, value);
    notifyListeners();
  }

  Future<void> setUnsafe(bool value) async {
    await Hive.box('settings').put(_keyUnsafe, value);
    notifyListeners();
  }

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);

  StreamSubscription<String>? _logSub;
  Timer? _healthTimer;

  LocalServerProvider({
    required LocalServerService service,
    required InstanceProvider instanceProvider,
  })  : _service = service,
        _instanceProvider = instanceProvider {
    _logSub = _service.logStream.listen(_onLog);
    _initialize();
  }

  // ── Initialization ────────────────────────────────────────────────────

  Future<void> _initialize() async {
    await refresh();
    notifyListeners();
  }

  // ── Installation ──────────────────────────────────────────────────────

  /// Install the Coqui server, configure it, and auto-create a local instance.
  Future<bool> install() async {
    _updateStatus(LocalServerStatus.installing);

    final success = await _service.install();

    // Always re-detect to get accurate status from disk
    _info = await _service.detectInstallation();

    if (!success) {
      _info = _info.copyWith(
        status: _info.isInstalled
            ? LocalServerStatus.stopped
            : LocalServerStatus.notInstalled,
        errorMessage: 'Installation failed. Check the console for details.',
      );
      notifyListeners();
      return false;
    }

    // Generate API key and write config
    final apiKey = _service.generateApiKey();
    final port = _info.port;
    await _service.writeConfig(apiKey: apiKey, port: port);

    // Re-detect after config write
    _info = await _service.detectInstallation();

    // Auto-create local instance in the app
    await _autoConfigureInstance(apiKey: apiKey, port: port);
    await _refreshInstanceConfigMismatch();
    notifyListeners();

    return true;
  }

  /// Re-run the installer to update.
  Future<bool> update() async {
    if (!await _guardInstanceConfigSync(action: 'update')) {
      return false;
    }

    _updateStatus(LocalServerStatus.updating);

    final success = await _service.update();
    _info = await _service.detectInstallation();
    if (!success) {
      _updateStatus(LocalServerStatus.error,
          errorMessage: 'Update failed. Check the console for details.');
    } else {
      await _refreshInstanceConfigMismatch();
    }
    notifyListeners();
    return success;
  }

  /// Uninstall the Coqui server.
  ///
  /// Stops any running process before uninstalling. [removeWorkspace] also
  /// deletes the `.workspace` directory.
  /// [removePhpAndComposer] also removes PHP and Composer from the system.
  Future<bool> uninstall({
    bool removeWorkspace = false,
    bool removePhpAndComposer = false,
  }) async {
    _updateStatus(LocalServerStatus.uninstalling);

    if (_info.status == LocalServerStatus.running ||
        _service.isProcessRunning) {
      await stopProcess();
    }

    final success = await _service.uninstall(
      removeWorkspace: removeWorkspace,
      removePhpAndComposer: removePhpAndComposer,
    );

    _info = await _service.detectInstallation();
    await _refreshInstanceConfigMismatch();

    if (!success) {
      _info = _info.copyWith(
        errorMessage: 'Uninstall failed. Check the console for details.',
      );
    }

    notifyListeners();
    return success;
  }

  // ── Process control ───────────────────────────────────────────────────

  Future<bool> startProcess() async {
    if (!await _guardInstanceConfigSync(action: 'start')) {
      return false;
    }

    _updateStatus(LocalServerStatus.starting);

    // Ensure .env config exists before spawning — recover if missing
    await _ensureConfig();

    final success = await _service.startProcess(
      port: _info.port,
      autoApprove: autoApprove,
      unsafe: unsafe,
    );
    if (success) {
      _updateInfo(
        status: LocalServerStatus.running,
        pid: _service.processPid,
        errorMessage: null,
      );
      _startHealthPolling();
    } else {
      _updateInfo(
        status: LocalServerStatus.error,
        errorMessage: 'Failed to start server. Check the console for details.',
      );
    }
    return success;
  }

  Future<void> stopProcess() async {
    _updateStatus(LocalServerStatus.stopping);
    await _service.stopProcess();
    _stopHealthPolling();
    _updateInfo(
      status: LocalServerStatus.stopped,
      pid: null,
      errorMessage: null,
    );
  }

  Future<void> restartProcess() async {
    if (!await _guardInstanceConfigSync(action: 'restart')) {
      return;
    }

    await stopProcess();
    await _startManagedProcess();
  }

  // ── Health polling ────────────────────────────────────────────────────

  void _startHealthPolling() {
    _stopHealthPolling();
    _healthTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollHealth(),
    );
  }

  void _stopHealthPolling() {
    _healthTimer?.cancel();
    _healthTimer = null;
  }

  Future<void> _pollHealth() async {
    final healthy = await _service.checkHealth(port: _info.port);

    final newStatus = healthy
        ? LocalServerStatus.running
        : (_info.isInstalled ? LocalServerStatus.stopped : _info.status);

    if (_info.status == LocalServerStatus.running && !healthy) {
      _addLog('Local server is no longer responding on port ${_info.port}.');
    }

    if (newStatus != _info.status || _info.pid != _service.processPid) {
      _info = _info.copyWith(
        status: newStatus,
        pid: _service.processPid,
      );
      notifyListeners();
    }
  }

  /// Manually refresh the server state.
  Future<void> refresh() async {
    _info = await _service.detectInstallation();
    await _refreshInstanceConfigMismatch();
    notifyListeners();
  }

  // ── Auto-configure instance ───────────────────────────────────────────

  Future<void> _autoConfigureInstance({
    String? apiKey,
    required int port,
  }) async {
    final existing = _findLocalInstance(port);
    final baseUrl = 'http://127.0.0.1:$port';

    if (existing != null) {
      final updated = existing.copyWith(
        name: InstanceService.defaultInstanceName,
        baseUrl: baseUrl,
        apiKey: apiKey ?? existing.apiKey,
      );
      await _instanceProvider.updateInstance(updated);
      _addLog('Updated existing local server instance.');
    } else {
      final instance = CoquiInstance(
        name: InstanceService.defaultInstanceName,
        baseUrl: baseUrl,
        apiKey: apiKey ?? '',
      );
      await _instanceProvider.addInstance(instance);
      _addLog('Local server instance added and configured.');
    }
  }

  /// Ensure the workspace .env file exists before starting the server.
  ///
  /// If missing (e.g. after upgrade or partial install), generates a new
  /// API key, writes config, and updates the active instance so the app
  /// and server stay in sync.
  Future<void> _ensureConfig() async {
    if (File(_service.envPath).existsSync()) {
      await _refreshInstanceConfigMismatch();
      return;
    }

    _addLog('No .env found — generating server configuration...');
    final apiKey = _service.generateApiKey();
    final port = _info.port;
    await _service.writeConfig(apiKey: apiKey, port: port);
    _info = await _service.detectInstallation();
    await _autoConfigureInstance(apiKey: apiKey, port: port);
    await _refreshInstanceConfigMismatch();
  }

  Future<bool> syncInstanceFromConfig() async {
    final config = await _service.readConfig();
    if (config.apiKey == null || config.apiKey!.isEmpty) {
      _addLog(
          'Cannot sync local instance — COQUI_API_KEY is missing from ~/.coqui/.workspace/.env.');
      return false;
    }

    await _autoConfigureInstance(apiKey: config.apiKey, port: config.port);
    await _refreshInstanceConfigMismatch();
    _updateInfo(errorMessage: null);
    _addLog('Local server instance synced from ~/.coqui/.workspace/.env.');
    return true;
  }

  // ── Logging ───────────────────────────────────────────────────────────

  void _onLog(String line) {
    _addLog(line);
  }

  void _addLog(String line) {
    _logs.add(line);
    // Keep a rolling buffer of 500 lines
    if (_logs.length > 500) {
      _logs.removeRange(0, _logs.length - 500);
    }
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  // ── Config access ─────────────────────────────────────────────────────

  int get port => _info.port;
  String get installPath => _service.installPath;
  String get workspacePath => _service.workspacePath;

  /// Manual launch command for the user's platform.
  String get manualLaunchCommand {
    final path = _service.installPath;
    final port = _info.port;
    final flags = StringBuffer();
    if (autoApprove) flags.write(' --auto-approve');
    if (unsafe) flags.write(' --unsafe');

    return '/bin/bash "$path/bin/coqui-launcher" --api-only --host 127.0.0.1 --port $port${flags.toString()}';
  }

  Future<bool> _startManagedProcess() async {
    _updateStatus(LocalServerStatus.starting);

    await _ensureConfig();

    final success = await _service.startProcess(
      port: _info.port,
      autoApprove: autoApprove,
      unsafe: unsafe,
    );
    if (success) {
      _updateInfo(
        status: LocalServerStatus.running,
        pid: _service.processPid,
        errorMessage: null,
      );
      _startHealthPolling();
    } else {
      _updateInfo(
        status: LocalServerStatus.error,
        errorMessage: 'Failed to start server. Check the console for details.',
      );
    }
    return success;
  }

  Future<void> _refreshInstanceConfigMismatch() async {
    if (!_info.isInstalled) {
      _info = _info.copyWith(instanceConfigMismatch: false);
      return;
    }

    final config = await _service.readConfig();
    final localInstance = _findLocalInstance(config.port);
    final mismatch = config.apiKey != null &&
        (localInstance == null || localInstance.apiKey != config.apiKey);

    _info = _info.copyWith(
      apiKey: config.apiKey,
      port: config.port,
      instanceConfigMismatch: mismatch,
    );
  }

  Future<bool> _guardInstanceConfigSync({required String action}) async {
    await _refreshInstanceConfigMismatch();
    if (!_info.instanceConfigMismatch) {
      notifyListeners();
      return true;
    }

    _info = _info.copyWith(
      errorMessage:
          'Local server instance is out of sync with ~/.coqui/.workspace/.env.',
    );
    _addLog(
        'Sync the local server instance from ~/.coqui/.workspace/.env before attempting to $action the server.');
    return false;
  }

  CoquiInstance? _findLocalInstance(int port) {
    for (final instance in _instanceProvider.instances) {
      final uri = Uri.tryParse(instance.baseUrl);
      if (uri == null) continue;

      final uriPort =
          uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final isLocalHost = uri.host == '127.0.0.1' || uri.host == 'localhost';
      if (isLocalHost && uriPort == port) {
        return instance;
      }
    }

    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  void _updateStatus(LocalServerStatus status, {String? errorMessage}) {
    _info = _info.copyWith(status: status, errorMessage: errorMessage);
    notifyListeners();
  }

  void _updateInfo({
    LocalServerStatus? status,
    int? pid,
    String? errorMessage,
  }) {
    _info = _info.copyWith(
      status: status,
      pid: pid,
      errorMessage: errorMessage,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _stopHealthPolling();
    _logSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}
