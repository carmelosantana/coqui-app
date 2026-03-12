/// State model for the local Coqui server managed by the desktop app.
enum LocalServerStatus {
  /// Server is not installed at all.
  notInstalled,

  /// Installed but not running.
  stopped,

  /// Server process is running and healthy.
  running,

  /// Server is in an error state (crashed, health check failed, etc.)
  error,

  /// Installation is in progress.
  installing,

  /// Update is in progress.
  updating,

  /// Server is starting up.
  starting,

  /// Server is stopping.
  stopping,
}

/// Snapshot of local server information.
class LocalServerInfo {
  final LocalServerStatus status;
  final String? version;
  final String installPath;
  final int? pid;
  final int port;
  final String? apiKey;
  final bool serviceInstalled;
  final bool serviceRunning;
  final bool serviceSupported;
  final String? errorMessage;
  final List<String> logs;

  const LocalServerInfo({
    this.status = LocalServerStatus.notInstalled,
    this.version,
    this.installPath = '',
    this.pid,
    this.port = 3300,
    this.apiKey,
    this.serviceInstalled = false,
    this.serviceRunning = false,
    this.serviceSupported = true,
    this.errorMessage,
    this.logs = const [],
  });

  LocalServerInfo copyWith({
    LocalServerStatus? status,
    String? version,
    String? installPath,
    int? pid,
    int? port,
    String? apiKey,
    bool? serviceInstalled,
    bool? serviceRunning,
    bool? serviceSupported,
    String? errorMessage,
    List<String>? logs,
  }) {
    return LocalServerInfo(
      status: status ?? this.status,
      version: version ?? this.version,
      installPath: installPath ?? this.installPath,
      pid: pid ?? this.pid,
      port: port ?? this.port,
      apiKey: apiKey ?? this.apiKey,
      serviceInstalled: serviceInstalled ?? this.serviceInstalled,
      serviceRunning: serviceRunning ?? this.serviceRunning,
      serviceSupported: serviceSupported ?? this.serviceSupported,
      errorMessage: errorMessage ?? this.errorMessage,
      logs: logs ?? this.logs,
    );
  }

  /// Whether the server is in a transitional state (installing, updating, etc.)
  bool get isBusy =>
      status == LocalServerStatus.installing ||
      status == LocalServerStatus.updating ||
      status == LocalServerStatus.starting ||
      status == LocalServerStatus.stopping;

  /// Whether the server is installed (any state except notInstalled/installing).
  bool get isInstalled =>
      status != LocalServerStatus.notInstalled &&
      status != LocalServerStatus.installing;
}
