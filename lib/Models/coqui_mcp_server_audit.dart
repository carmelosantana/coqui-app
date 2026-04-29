class CoquiMcpServerAudit {
  final DateTime? lastConnectedAt;
  final String? lastConnectionError;
  final int? lastConnectionDurationMs;
  final DateTime? lastDisconnectedAt;
  final DateTime? lastTestedAt;
  final bool? lastTestSucceeded;
  final String? lastTestError;
  final int? lastTestDurationMs;
  final int? lastToolDiscoveryCount;

  const CoquiMcpServerAudit({
    required this.lastConnectedAt,
    required this.lastConnectionError,
    required this.lastConnectionDurationMs,
    required this.lastDisconnectedAt,
    required this.lastTestedAt,
    required this.lastTestSucceeded,
    required this.lastTestError,
    required this.lastTestDurationMs,
    required this.lastToolDiscoveryCount,
  });

  static const empty = CoquiMcpServerAudit(
    lastConnectedAt: null,
    lastConnectionError: null,
    lastConnectionDurationMs: null,
    lastDisconnectedAt: null,
    lastTestedAt: null,
    lastTestSucceeded: null,
    lastTestError: null,
    lastTestDurationMs: null,
    lastToolDiscoveryCount: null,
  );

  factory CoquiMcpServerAudit.fromJson(Map<String, dynamic> json) {
    return CoquiMcpServerAudit(
      lastConnectedAt: _parseDateTime(json['last_connected_at']),
      lastConnectionError: json['last_connection_error'] as String?,
      lastConnectionDurationMs: _coerceInt(json['last_connection_duration_ms']),
      lastDisconnectedAt: _parseDateTime(json['last_disconnected_at']),
      lastTestedAt: _parseDateTime(json['last_tested_at']),
      lastTestSucceeded: _coerceNullableBool(json['last_test_succeeded']),
      lastTestError: json['last_test_error'] as String?,
      lastTestDurationMs: _coerceInt(json['last_test_duration_ms']),
      lastToolDiscoveryCount: _coerceInt(json['last_tool_discovery_count']),
    );
  }

  bool get hasConnectionHistory =>
      lastConnectedAt != null ||
      (lastConnectionError != null && lastConnectionError!.isNotEmpty) ||
      lastDisconnectedAt != null;

  bool get hasTestHistory => lastTestedAt != null;
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

int? _coerceInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool? _coerceNullableBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    if (normalized == 'true' || value == '1') return true;
    if (normalized == 'false' || value == '0') return false;
  }
  return null;
}
