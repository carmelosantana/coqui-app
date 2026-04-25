class CoquiRestartState {
  final bool required;
  final bool supported;
  final bool managedByLauncher;
  final String? reason;
  final String? source;
  final DateTime? requiredAt;
  final DateTime? startedAt;
  final int? pid;

  const CoquiRestartState({
    required this.required,
    required this.supported,
    required this.managedByLauncher,
    this.reason,
    this.source,
    this.requiredAt,
    this.startedAt,
    this.pid,
  });

  factory CoquiRestartState.fromJson(Map<String, dynamic> json) {
    return CoquiRestartState(
      required: json['required'] as bool? ?? false,
      supported: json['supported'] as bool? ?? false,
      managedByLauncher: json['managed_by_launcher'] as bool? ?? false,
      reason: json['reason'] as String?,
      source: json['source'] as String?,
      requiredAt: _parseDateTime(json['required_at']),
      startedAt: _parseDateTime(json['started_at']),
      pid: _coerceInt(json['pid']),
    );
  }

  static const empty = CoquiRestartState(
    required: false,
    supported: false,
    managedByLauncher: false,
  );
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