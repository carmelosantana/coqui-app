/// Represents a background task running in a separate process.
///
/// Tasks run long-running agent work independently from the main conversation.
/// Each task has its own dedicated session and process lifecycle.
class CoquiTask {
  final String id;
  final String sessionId;
  final String? parentSessionId;
  final String? profile;
  final String status;
  final String? title;
  final String prompt;
  final String role;
  final int? pid;
  final String? result;
  final String? error;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool? processAlive;

  CoquiTask({
    required this.id,
    required this.sessionId,
    this.parentSessionId,
    this.profile,
    required this.status,
    this.title,
    required this.prompt,
    required this.role,
    this.pid,
    this.result,
    this.error,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.processAlive,
  });

  factory CoquiTask.fromJson(Map<String, dynamic> json) {
    return CoquiTask(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      parentSessionId: json['parent_session_id'] as String?,
      profile: json['profile'] as String?,
      status: json['status'] as String? ?? 'unknown',
      title: json['title'] as String?,
      prompt: json['prompt'] as String? ?? '',
      role: json['role'] as String? ?? 'orchestrator',
      pid: json['pid'] as int?,
      result: json['result'] as String?,
      error: json['error'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      processAlive: json['process_alive'] as bool?,
    );
  }

  // ── Status helpers ────────────────────────────────────────────────────

  bool get isPending => status == 'pending';
  bool get isRunning => status == 'running';
  bool get isCancelling => status == 'cancelling';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';

  /// Whether the task has reached a terminal state.
  bool get isTerminal => isCompleted || isFailed || isCancelled;

  /// Whether the task is actively doing work or waiting to.
  bool get isActive => isPending || isRunning || isCancelling;

  /// Short display label for the task — title or truncated prompt.
  String get displayTitle {
    if (title != null && title!.isNotEmpty) return title!;
    return prompt.length > 60 ? '${prompt.substring(0, 60)}…' : prompt;
  }

  /// Human-readable status string.
  String get statusLabel => switch (status) {
        'pending' => 'Pending',
        'running' => 'Running',
        'cancelling' => 'Cancelling',
        'completed' => 'Completed',
        'failed' => 'Failed',
        'cancelled' => 'Cancelled',
        _ => status,
      };

  /// Duration since task was created (for pending tasks) or runtime.
  Duration get age => DateTime.now().difference(startedAt ?? createdAt);

  String get ageFormatted {
    final d = age;
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  CoquiTask copyWith({
    String? status,
    String? profile,
    String? result,
    String? error,
    DateTime? completedAt,
    bool? processAlive,
  }) {
    return CoquiTask(
      id: id,
      sessionId: sessionId,
      parentSessionId: parentSessionId,
      profile: profile ?? this.profile,
      status: status ?? this.status,
      title: title,
      prompt: prompt,
      role: role,
      pid: pid,
      result: result ?? this.result,
      error: error ?? this.error,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt ?? this.completedAt,
      processAlive: processAlive ?? this.processAlive,
    );
  }
}
