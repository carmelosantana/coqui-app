import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_mcp_server.dart';
import 'package:coqui_app/Models/coqui_mcp_tool.dart';
import 'package:coqui_app/Models/coqui_tool_visibility.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

class McpProvider extends ChangeNotifier {
  final CoquiApiService _apiService;

  List<CoquiMcpServer> _servers = [];
  final Map<String, CoquiMcpServer> _detailsByName = {};
  final Map<String, List<CoquiMcpTool>> _toolsByServerName = {};
  Map<String, CoquiToolVisibility> _toolVisibilityByName = {};
  final Set<String> _loadingDetailNames = {};
  final Set<String> _mutatingServerNames = {};
  final Set<String> _runtimeServerNames = {};
  final Set<String> _mutatingToolNames = {};
  Timer? _pollTimer;

  bool _isLoading = false;
  String? _error;

  McpProvider({required CoquiApiService apiService}) : _apiService = apiService;

  List<CoquiMcpServer> get servers => _servers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get hasIssues => _servers.any((server) => server.hasError);

  bool get hasConnectedServers =>
      _servers.any((server) => server.connected && !server.disabled);

  bool get hasConfiguredServers => _servers.isNotEmpty;

  CoquiMcpServer? serverByName(String name) =>
      _detailsByName[name] ??
      _servers.cast<CoquiMcpServer?>().firstWhere(
            (server) => server?.name == name,
            orElse: () => null,
          );

  List<CoquiMcpTool> toolsForServer(String serverName) =>
      List.unmodifiable(_toolsByServerName[serverName] ?? const []);

  bool isDetailLoading(String name) => _loadingDetailNames.contains(name);

  bool isServerMutating(String name) => _mutatingServerNames.contains(name);

  bool isRuntimeBusy(String name) => _runtimeServerNames.contains(name);

  bool isToolMutating(String namespacedName) =>
      _mutatingToolNames.contains(namespacedName);

  Future<void> refreshDashboard({bool silent = false}) async {
    await Future.wait([
      fetchServers(silent: silent),
      fetchToolVisibilities(),
    ]);
  }

  Future<void> fetchServers({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _servers = await _apiService.listMcpServers();
      _synchronizeDetails();
      _error = null;
    } catch (error) {
      _error = CoquiException.friendly(error).message;
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> fetchToolVisibilities() async {
    try {
      final entries = await _apiService.listToolVisibilities();
      _toolVisibilityByName = {
        for (final entry in entries) entry.name: entry,
      };
      _remapLoadedTools();
      _error = null;
      notifyListeners();
    } catch (error) {
      _error = CoquiException.friendly(error).message;
      notifyListeners();
    }
  }

  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(refreshDashboard(silent: true));
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<CoquiMcpServer?> loadServerDetail(
    String name, {
    bool force = false,
  }) async {
    if (_loadingDetailNames.contains(name)) {
      return serverByName(name);
    }
    if (!force &&
        _detailsByName.containsKey(name) &&
        _toolsByServerName.containsKey(name)) {
      return _detailsByName[name];
    }

    _loadingDetailNames.add(name);
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>([
        _apiService.getMcpServer(name),
        _apiService.listMcpServerTools(name),
      ]);
      final server = results[0] as CoquiMcpServer;
      final tools = results[1] as List<CoquiMcpTool>;

      _detailsByName.remove(name);
      _detailsByName[server.name] = server;
      _replaceServer(server);
      _toolsByServerName.remove(name);
      _toolsByServerName[server.name] = _mergeTools(tools);
      _error = null;
      return server;
    } catch (error) {
      _error = CoquiException.friendly(error).message;
      return null;
    } finally {
      _loadingDetailNames.remove(name);
      notifyListeners();
    }
  }

  Future<CoquiMcpServer?> createServer({
    required String name,
    required String command,
    List<String> args = const [],
    String? description,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.createMcpServer(
        name: name,
        command: command,
        args: args,
        description: description,
      );
      final server = result.server;
      _detailsByName[server.name] = server;
      _servers = [
        server,
        ..._servers.where((item) => item.name != server.name),
      ];
      _error = null;
      return server;
    } catch (error) {
      _error = CoquiException.friendly(error).message;
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CoquiMcpServer?> updateServer(
    String currentName, {
    required String name,
    required String command,
    List<String> args = const [],
    String? description,
    bool clearDescription = false,
  }) async {
    _mutatingServerNames.add(currentName);
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.updateMcpServer(
        currentName,
        name: name,
        command: command,
        args: args,
        description: description,
        clearDescription: clearDescription,
      );
      final server = result.server;
      _removeServerData(currentName);
      _detailsByName[server.name] = server;
      _servers = [
        server,
        ..._servers.where((item) => item.name != server.name),
      ];
      await loadServerDetail(server.name, force: true);
      return server;
    } catch (error) {
      _error = CoquiException.friendly(error).message;
      return null;
    } finally {
      _mutatingServerNames.remove(currentName);
      notifyListeners();
    }
  }

  Future<bool> deleteServer(String name) async {
    _mutatingServerNames.add(name);
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteMcpServer(name);
      _removeServerData(name);
      _servers.removeWhere((server) => server.name == name);
      return true;
    } catch (error) {
      _error = CoquiException.friendly(error).message;
      return false;
    } finally {
      _mutatingServerNames.remove(name);
      notifyListeners();
    }
  }

  Future<CoquiMcpServer?> toggleServerEnabled(String name, bool enabled) async {
    _mutatingServerNames.add(name);
    _error = null;
    notifyListeners();

    try {
      final result = enabled
          ? await _apiService.enableMcpServer(name)
          : await _apiService.disableMcpServer(name);
      final server = result.server;
      _detailsByName[server.name] = server;
      _replaceServer(server);
      return server;
    } catch (error) {
      _error = CoquiException.friendly(error).message;
      return null;
    } finally {
      _mutatingServerNames.remove(name);
      notifyListeners();
    }
  }

  Future<CoquiMcpServer?> setLoadingMode(String name, String mode) async {
    _mutatingServerNames.add(name);
    _error = null;
    notifyListeners();

    try {
      final result = switch (mode) {
        'eager' => await _apiService.promoteMcpServer(name),
        'deferred' => await _apiService.demoteMcpServer(name),
        _ => await _apiService.autoMcpServer(name),
      };
      final server = result.server;
      _detailsByName[server.name] = server;
      _replaceServer(server);
      return server;
    } catch (error) {
      _error = CoquiException.friendly(error).message;
      return null;
    } finally {
      _mutatingServerNames.remove(name);
      notifyListeners();
    }
  }

  Future<CoquiMcpServer?> connectServer(String name) async {
    return _runRuntimeMutation(
      name,
      () async => (await _apiService.connectMcpServer(name)).server,
    );
  }

  Future<CoquiMcpServer?> refreshServer(String name) async {
    return _runRuntimeMutation(
      name,
      () async => (await _apiService.refreshMcpServer(name)).server,
    );
  }

  Future<CoquiMcpServer?> testServer(String name) async {
    return _runRuntimeMutation(
      name,
      () async => (await _apiService.testMcpServer(name)).server,
    );
  }

  Future<CoquiMcpServer?> disconnectServer(String name) async {
    _runtimeServerNames.add(name);
    _error = null;
    notifyListeners();

    try {
      await _apiService.disconnectMcpServer(name);
      return await loadServerDetail(name, force: true);
    } catch (error) {
      _error = CoquiException.friendly(error).message;
      return null;
    } finally {
      _runtimeServerNames.remove(name);
      notifyListeners();
    }
  }

  Future<CoquiMcpTool?> setToolVisibility(
    String serverName,
    String namespacedName,
    String visibility,
  ) async {
    _mutatingToolNames.add(namespacedName);
    _error = null;
    notifyListeners();

    try {
      final current = _toolVisibilityByName[namespacedName];
      final updated = await _apiService.setToolVisibility(
        namespacedName,
        visibility,
      );
      _toolVisibilityByName[namespacedName] = updated.copyWith(
        protection: current?.protection,
      );
      _remapLoadedTools();
      _error = null;

      final tools = _toolsByServerName[serverName];
      if (tools == null) {
        return null;
      }

      return tools.cast<CoquiMcpTool?>().firstWhere(
            (tool) => tool?.namespacedName == namespacedName,
            orElse: () => null,
          );
    } catch (error) {
      _error = CoquiException.friendly(error).message;
      return null;
    } finally {
      _mutatingToolNames.remove(namespacedName);
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<CoquiMcpServer?> _runRuntimeMutation(
    String name,
    Future<CoquiMcpServer> Function() callback,
  ) async {
    _runtimeServerNames.add(name);
    _error = null;
    notifyListeners();

    try {
      final server = await callback();
      _detailsByName[server.name] = server;
      _replaceServer(server);
      await loadServerDetail(server.name, force: true);
      return server;
    } catch (error) {
      _error = CoquiException.friendly(error).message;
      return null;
    } finally {
      _runtimeServerNames.remove(name);
      notifyListeners();
    }
  }

  void _replaceServer(CoquiMcpServer server) {
    final index = _servers.indexWhere((item) => item.name == server.name);
    if (index == -1) {
      _servers = [server, ..._servers];
      return;
    }

    final next = [..._servers];
    next[index] = server;
    _servers = next;
  }

  void _synchronizeDetails() {
    final validNames = _servers.map((server) => server.name).toSet();

    _detailsByName.removeWhere((name, _) => !validNames.contains(name));
    _toolsByServerName.removeWhere((name, _) => !validNames.contains(name));

    for (final server in _servers) {
      _detailsByName[server.name] = server;
    }
  }

  List<CoquiMcpTool> _mergeTools(List<CoquiMcpTool> tools) {
    return tools.map((tool) {
      final visibility = _toolVisibilityByName[tool.namespacedName];
      return tool.copyWith(
        visibility: visibility?.visibility ?? 'enabled',
        protection: visibility?.protection,
      );
    }).toList(growable: false);
  }

  void _remapLoadedTools() {
    final next = <String, List<CoquiMcpTool>>{};
    for (final entry in _toolsByServerName.entries) {
      next[entry.key] = _mergeTools(entry.value);
    }
    _toolsByServerName
      ..clear()
      ..addAll(next);
  }

  void _removeServerData(String name) {
    _detailsByName.remove(name);
    _toolsByServerName.remove(name);
    _loadingDetailNames.remove(name);
    _mutatingServerNames.remove(name);
    _runtimeServerNames.remove(name);
  }
}
