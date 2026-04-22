class CoquiLoop {
  final String id;
  final String definitionName;
  final String? sessionId;
  final String? projectId;
  final String goal;
  final String status;
  final int currentIteration;
  final int currentStage;
  final int? maxIterations;
  final String? deadline;
  final String? terminationCriteria;
  final Map<String, dynamic> configuration;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? lastActivityAt;
  final Map<String, dynamic> metadata;

  const CoquiLoop({
    required this.id,
    required this.definitionName,
    required this.sessionId,
    required this.projectId,
    required this.goal,
    required this.status,
    required this.currentIteration,
    required this.currentStage,
    required this.maxIterations,
    required this.deadline,
    required this.terminationCriteria,
    required this.configuration,
    required this.startedAt,
    required this.completedAt,
    required this.lastActivityAt,
    required this.metadata,
  });

  factory CoquiLoop.fromJson(Map<String, dynamic> json) {
    return CoquiLoop(
      id: json['id'] as String? ?? '',
      definitionName: json['definition_name'] as String? ?? '',
      sessionId: json['session_id'] as String?,
      projectId: json['project_id'] as String?,
      goal: json['goal'] as String? ?? '',
      status: json['status'] as String? ?? 'running',
      currentIteration: _coerceInt(json['current_iteration']),
      currentStage: _coerceInt(json['current_stage']),
      maxIterations: json['max_iterations'] == null
          ? null
          : _coerceInt(json['max_iterations']),
      deadline: json['deadline'] as String?,
      terminationCriteria: json['termination_criteria'] as String?,
      configuration: _coerceMap(json['configuration']),
      startedAt: _parseDateTime(json['started_at']),
      completedAt: _parseDateTime(json['completed_at']),
      lastActivityAt: _parseDateTime(json['last_activity_at']),
      metadata: _coerceMap(json['metadata']),
    );
  }

  bool get isRunning => status == 'running';

  bool get isPaused => status == 'paused';

  bool get isFinished =>
      status == 'completed' || status == 'failed' || status == 'cancelled';

  String get statusLabel => switch (status) {
        'running' => 'Running',
        'paused' => 'Paused',
        'completed' => 'Completed',
        'failed' => 'Failed',
        'cancelled' => 'Cancelled',
        _ => status,
      };

  CoquiLoop copyWith({
    String? status,
    int? currentIteration,
    int? currentStage,
    DateTime? completedAt,
    DateTime? lastActivityAt,
    Map<String, dynamic>? metadata,
  }) {
    return CoquiLoop(
      id: id,
      definitionName: definitionName,
      sessionId: sessionId,
      projectId: projectId,
      goal: goal,
      status: status ?? this.status,
      currentIteration: currentIteration ?? this.currentIteration,
      currentStage: currentStage ?? this.currentStage,
      maxIterations: maxIterations,
      deadline: deadline,
      terminationCriteria: terminationCriteria,
      configuration: configuration,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

class CoquiLoopDefinition {
  final String name;
  final String description;
  final List<CoquiLoopDefinitionParameter> parameters;
  final List<CoquiLoopRoleStep> roles;
  final Map<String, dynamic> termination;

  const CoquiLoopDefinition({
    required this.name,
    required this.description,
    required this.parameters,
    required this.roles,
    required this.termination,
  });

  factory CoquiLoopDefinition.fromJson(Map<String, dynamic> json) {
    return CoquiLoopDefinition(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      parameters: (json['parameters'] as List? ?? [])
          .map(
            (item) => CoquiLoopDefinitionParameter.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      roles: (json['roles'] as List? ?? [])
          .map(
            (item) => CoquiLoopRoleStep.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      termination: _coerceMap(json['termination']),
    );
  }
}

class CoquiLoopDefinitionParameter {
  final String name;
  final String description;
  final bool required;
  final String? defaultValue;
  final String? example;

  const CoquiLoopDefinitionParameter({
    required this.name,
    required this.description,
    required this.required,
    required this.defaultValue,
    required this.example,
  });

  factory CoquiLoopDefinitionParameter.fromJson(Map<String, dynamic> json) {
    return CoquiLoopDefinitionParameter(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      required: _coerceBool(json['required']),
      defaultValue: json['default']?.toString(),
      example: json['example']?.toString(),
    );
  }
}

class CoquiLoopRoleStep {
  final String role;
  final String prompt;
  final int? maxIterations;

  const CoquiLoopRoleStep({
    required this.role,
    required this.prompt,
    required this.maxIterations,
  });

  factory CoquiLoopRoleStep.fromJson(Map<String, dynamic> json) {
    return CoquiLoopRoleStep(
      role: json['role'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      maxIterations: json['max_iterations'] == null
          ? null
          : _coerceInt(json['max_iterations']),
    );
  }
}

class CoquiLoopIteration {
  final String id;
  final String loopId;
  final int iterationNumber;
  final String? sprintId;
  final String status;
  final String? outcomeSummary;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const CoquiLoopIteration({
    required this.id,
    required this.loopId,
    required this.iterationNumber,
    required this.sprintId,
    required this.status,
    required this.outcomeSummary,
    required this.startedAt,
    required this.completedAt,
  });

  factory CoquiLoopIteration.fromJson(Map<String, dynamic> json) {
    return CoquiLoopIteration(
      id: json['id'] as String? ?? '',
      loopId: json['loop_id'] as String? ?? '',
      iterationNumber: _coerceInt(json['iteration_number']),
      sprintId: json['sprint_id'] as String?,
      status: json['status'] as String? ?? 'pending',
      outcomeSummary: json['outcome_summary'] as String?,
      startedAt: _parseDateTime(json['started_at']),
      completedAt: _parseDateTime(json['completed_at']),
    );
  }

  String get statusLabel => switch (status) {
        'pending' => 'Pending',
        'running' => 'Running',
        'completed' => 'Completed',
        'failed' => 'Failed',
        'needs_rework' => 'Needs Rework',
        _ => status,
      };
}

class CoquiLoopStage {
  final String id;
  final String iterationId;
  final int stageIndex;
  final String role;
  final String? taskId;
  final String? artifactId;
  final Map<String, dynamic> metadata;
  final String status;
  final String? resultSummary;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const CoquiLoopStage({
    required this.id,
    required this.iterationId,
    required this.stageIndex,
    required this.role,
    required this.taskId,
    required this.artifactId,
    required this.metadata,
    required this.status,
    required this.resultSummary,
    required this.startedAt,
    required this.completedAt,
  });

  factory CoquiLoopStage.fromJson(Map<String, dynamic> json) {
    return CoquiLoopStage(
      id: json['id'] as String? ?? '',
      iterationId: json['iteration_id'] as String? ?? '',
      stageIndex: _coerceInt(json['stage_index']),
      role: json['role'] as String? ?? '',
      taskId: json['task_id'] as String?,
      artifactId: json['artifact_id'] as String?,
      metadata: _coerceMap(json['metadata']),
      status: json['status'] as String? ?? 'pending',
      resultSummary: json['result_summary'] as String?,
      startedAt: _parseDateTime(json['started_at']),
      completedAt: _parseDateTime(json['completed_at']),
    );
  }

  String get statusLabel => switch (status) {
        'pending' => 'Pending',
        'running' => 'Running',
        'completed' => 'Completed',
        'failed' => 'Failed',
        _ => status,
      };
}

class CoquiLoopDetail {
  final CoquiLoop loop;
  final CoquiLoopIteration? iteration;
  final List<CoquiLoopStage> stages;

  const CoquiLoopDetail({
    required this.loop,
    required this.iteration,
    required this.stages,
  });
}

class CoquiLoopIterationDetail {
  final CoquiLoopIteration iteration;
  final List<CoquiLoopStage> stages;

  const CoquiLoopIterationDetail({
    required this.iteration,
    required this.stages,
  });
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

bool _coerceBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    return normalized == '1' || normalized == 'true';
  }
  return false;
}

Map<String, dynamic> _coerceMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const {};
}
