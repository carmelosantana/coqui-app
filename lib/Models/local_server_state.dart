/// State model for the local Coqui server managed by the desktop app.
const _localServerInfoUnset = Object();

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

  /// Server uninstall is in progress.
  uninstalling,
}

/// Snapshot of local server information.
class LocalServerInfo {
  final LocalServerStatus status;
  final String? version;
  final String installPath;
  final String workspacePath;
  final int? pid;
  final int port;
  final String? apiKey;
  final bool instanceConfigMismatch;
  final String? errorMessage;

  const LocalServerInfo({
    this.status = LocalServerStatus.notInstalled,
    this.version,
    this.installPath = '',
    this.workspacePath = '',
    this.pid,
    this.port = 3300,
    this.apiKey,
    this.instanceConfigMismatch = false,
    this.errorMessage,
  });

  LocalServerInfo copyWith({
    LocalServerStatus? status,
    Object? version = _localServerInfoUnset,
    String? installPath,
    String? workspacePath,
    Object? pid = _localServerInfoUnset,
    int? port,
    Object? apiKey = _localServerInfoUnset,
    bool? instanceConfigMismatch,
    Object? errorMessage = _localServerInfoUnset,
  }) {
    return LocalServerInfo(
      status: status ?? this.status,
      version: identical(version, _localServerInfoUnset)
          ? this.version
          : version as String?,
      installPath: installPath ?? this.installPath,
      workspacePath: workspacePath ?? this.workspacePath,
      pid: identical(pid, _localServerInfoUnset) ? this.pid : pid as int?,
      port: port ?? this.port,
      apiKey: identical(apiKey, _localServerInfoUnset)
          ? this.apiKey
          : apiKey as String?,
      instanceConfigMismatch:
          instanceConfigMismatch ?? this.instanceConfigMismatch,
      errorMessage: identical(errorMessage, _localServerInfoUnset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  /// Whether the server is in a transitional state (installing, updating, etc.)
  bool get isBusy =>
      status == LocalServerStatus.installing ||
      status == LocalServerStatus.updating ||
      status == LocalServerStatus.starting ||
      status == LocalServerStatus.stopping ||
      status == LocalServerStatus.uninstalling;

  /// Whether the server is installed (any state except notInstalled/installing).
  bool get isInstalled =>
      status != LocalServerStatus.notInstalled &&
      status != LocalServerStatus.installing;
}
