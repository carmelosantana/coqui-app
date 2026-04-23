class CoquiChannel {
  final String id;
  final String name;
  final String driver;
  final String displayName;
  final bool enabled;
  final String? defaultProfile;
  final String? boundSessionId;
  final Map<String, dynamic> settings;
  final List<String> allowedScopes;
  final Map<String, dynamic> security;
  final Map<String, dynamic> capabilities;
  final String workerStatus;
  final bool ready;
  final String summary;
  final DateTime? lastHeartbeatAt;
  final DateTime? lastReceiveAt;
  final DateTime? lastSendAt;
  final int inboundBacklog;
  final int outboundBacklog;
  final int consecutiveFailures;
  final String? lastError;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CoquiChannel({
    required this.id,
    required this.name,
    required this.driver,
    required this.displayName,
    required this.enabled,
    required this.defaultProfile,
    required this.boundSessionId,
    required this.settings,
    required this.allowedScopes,
    required this.security,
    required this.capabilities,
    required this.workerStatus,
    required this.ready,
    required this.summary,
    required this.lastHeartbeatAt,
    required this.lastReceiveAt,
    required this.lastSendAt,
    required this.inboundBacklog,
    required this.outboundBacklog,
    required this.consecutiveFailures,
    required this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CoquiChannel.fromJson(Map<String, dynamic> json) {
    return CoquiChannel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      driver: json['driver'] as String? ?? '',
      displayName: json['display_name'] as String? ??
          json['displayName'] as String? ??
          json['name'] as String? ??
          '',
      enabled: json['enabled'] as bool? ?? true,
      defaultProfile: json['default_profile'] as String? ??
          json['defaultProfile'] as String?,
      boundSessionId: json['bound_session_id'] as String? ??
          json['boundSessionId'] as String?,
      settings: _coerceMap(json['settings']),
      allowedScopes:
          _coerceStringList(json['allowed_scopes'] ?? json['allowedScopes']),
      security: _coerceMap(json['security']),
      capabilities: _coerceMap(json['capabilities']),
      workerStatus: json['worker_status'] as String? ?? 'missing',
      ready: json['ready'] as bool? ?? false,
      summary: json['summary'] as String? ?? '',
      lastHeartbeatAt: _parseDateTime(json['last_heartbeat_at']),
      lastReceiveAt: _parseDateTime(json['last_receive_at']),
      lastSendAt: _parseDateTime(json['last_send_at']),
      inboundBacklog: _coerceInt(json['inbound_backlog']),
      outboundBacklog: _coerceInt(json['outbound_backlog']),
      consecutiveFailures: _coerceInt(json['consecutive_failures']),
      lastError: json['last_error'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  bool get isHealthy => enabled && ready;

  bool get isDisabled => !enabled || workerStatus == 'disabled';

  bool get isPlaceholder => workerStatus == 'placeholder';

  bool get hasIssues => enabled && !ready;

  bool get hasActivity => lastReceiveAt != null || lastSendAt != null;

  String get driverLabel => switch (driver) {
        'signal' => 'Signal',
        'telegram' => 'Telegram',
        'discord' => 'Discord',
        _ => driver,
      };

  String get statusLabel => switch (workerStatus) {
        'running' when ready => 'Healthy',
        'running' => 'Starting',
        'disabled' => 'Disabled',
        'invalid_configuration' => 'Needs Setup',
        'driver_missing' => 'Driver Missing',
        'error' => 'Error',
        'placeholder' => 'Scaffolded',
        'stopped' => 'Stopped',
        _ => workerStatus.replaceAll('_', ' '),
      };

  CoquiChannel copyWith({
    String? displayName,
    bool? enabled,
    String? defaultProfile,
    String? boundSessionId,
    Map<String, dynamic>? settings,
    List<String>? allowedScopes,
    Map<String, dynamic>? security,
    Map<String, dynamic>? capabilities,
    String? workerStatus,
    bool? ready,
    String? summary,
    DateTime? lastHeartbeatAt,
    DateTime? lastReceiveAt,
    DateTime? lastSendAt,
    int? inboundBacklog,
    int? outboundBacklog,
    int? consecutiveFailures,
    String? lastError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CoquiChannel(
      id: id,
      name: name,
      driver: driver,
      displayName: displayName ?? this.displayName,
      enabled: enabled ?? this.enabled,
      defaultProfile: defaultProfile ?? this.defaultProfile,
      boundSessionId: boundSessionId ?? this.boundSessionId,
      settings: settings ?? this.settings,
      allowedScopes: allowedScopes ?? this.allowedScopes,
      security: security ?? this.security,
      capabilities: capabilities ?? this.capabilities,
      workerStatus: workerStatus ?? this.workerStatus,
      ready: ready ?? this.ready,
      summary: summary ?? this.summary,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
      lastReceiveAt: lastReceiveAt ?? this.lastReceiveAt,
      lastSendAt: lastSendAt ?? this.lastSendAt,
      inboundBacklog: inboundBacklog ?? this.inboundBacklog,
      outboundBacklog: outboundBacklog ?? this.outboundBacklog,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isSessionBound => boundSessionId?.isNotEmpty == true;
}

Map<String, dynamic> _coerceMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return const {};
}

List<String> _coerceStringList(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

int _coerceInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
