class CoquiSchedule {
  final String id;
  final String name;
  final String? description;
  final String scheduleExpression;
  final String prompt;
  final String role;
  final int maxIterations;
  final bool enabled;
  final String? createdBy;
  final String timezone;
  final DateTime? nextRunAt;
  final DateTime? lastRunAt;
  final String? lastTaskId;
  final String? lastStatus;
  final int runCount;
  final int failureCount;
  final int maxFailures;
  final String source;
  final String? sourcePath;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CoquiSchedule({
    required this.id,
    required this.name,
    required this.description,
    required this.scheduleExpression,
    required this.prompt,
    required this.role,
    required this.maxIterations,
    required this.enabled,
    required this.createdBy,
    required this.timezone,
    required this.nextRunAt,
    required this.lastRunAt,
    required this.lastTaskId,
    required this.lastStatus,
    required this.runCount,
    required this.failureCount,
    required this.maxFailures,
    required this.source,
    required this.sourcePath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CoquiSchedule.fromJson(Map<String, dynamic> json) {
    return CoquiSchedule(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      scheduleExpression: json['schedule_expression'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      role: json['role'] as String? ?? 'orchestrator',
      maxIterations: _coerceInt(json['max_iterations'], fallback: 48),
      enabled: _coerceBool(json['enabled'], fallback: true),
      createdBy: json['created_by'] as String?,
      timezone: json['timezone'] as String? ?? 'UTC',
      nextRunAt: _parseDateTime(json['next_run_at']),
      lastRunAt: _parseDateTime(json['last_run_at']),
      lastTaskId: json['last_task_id'] as String?,
      lastStatus: json['last_status'] as String?,
      runCount: _coerceInt(json['run_count']),
      failureCount: _coerceInt(json['failure_count']),
      maxFailures: _coerceInt(json['max_failures'], fallback: 3),
      source: json['source'] as String? ?? 'system',
      sourcePath: json['source_path'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  bool get hasDescription => description != null && description!.isNotEmpty;

  bool get isFilesystemSource => source == 'filesystem';

  String get sourceLabel =>
      isFilesystemSource ? 'Workspace file' : 'App managed';

  String get statusLabel => enabled ? 'Enabled' : 'Disabled';

  CoquiSchedule copyWith({
    String? name,
    String? description,
    String? scheduleExpression,
    String? prompt,
    String? role,
    int? maxIterations,
    bool? enabled,
    String? createdBy,
    String? timezone,
    DateTime? nextRunAt,
    DateTime? lastRunAt,
    String? lastTaskId,
    String? lastStatus,
    int? runCount,
    int? failureCount,
    int? maxFailures,
    String? source,
    String? sourcePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CoquiSchedule(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      scheduleExpression: scheduleExpression ?? this.scheduleExpression,
      prompt: prompt ?? this.prompt,
      role: role ?? this.role,
      maxIterations: maxIterations ?? this.maxIterations,
      enabled: enabled ?? this.enabled,
      createdBy: createdBy ?? this.createdBy,
      timezone: timezone ?? this.timezone,
      nextRunAt: nextRunAt ?? this.nextRunAt,
      lastRunAt: lastRunAt ?? this.lastRunAt,
      lastTaskId: lastTaskId ?? this.lastTaskId,
      lastStatus: lastStatus ?? this.lastStatus,
      runCount: runCount ?? this.runCount,
      failureCount: failureCount ?? this.failureCount,
      maxFailures: maxFailures ?? this.maxFailures,
      source: source ?? this.source,
      sourcePath: sourcePath ?? this.sourcePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

int _coerceInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _coerceBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    return normalized == '1' || normalized == 'true';
  }
  return fallback;
}
