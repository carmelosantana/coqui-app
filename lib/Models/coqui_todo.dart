import 'package:coqui_app/Models/coqui_todo_stats.dart';

class CoquiTodo {
  final String id;
  final String sessionId;
  final String? artifactId;
  final String? parentId;
  final String? sprintId;
  final String title;
  final String status;
  final String priority;
  final String? createdBy;
  final String? completedBy;
  final String? notes;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final List<CoquiTodo> subtasks;

  const CoquiTodo({
    required this.id,
    required this.sessionId,
    required this.artifactId,
    required this.parentId,
    required this.sprintId,
    required this.title,
    required this.status,
    required this.priority,
    required this.createdBy,
    required this.completedBy,
    required this.notes,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.completedAt,
    required this.subtasks,
  });

  factory CoquiTodo.fromJson(Map<String, dynamic> json) {
    final subtasks = (json['subtasks'] as List? ?? [])
        .whereType<Map>()
        .map((item) => CoquiTodo.fromJson(item.cast<String, dynamic>()))
        .toList();

    return CoquiTodo(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      artifactId: json['artifact_id'] as String?,
      parentId: json['parent_id'] as String?,
      sprintId: json['sprint_id'] as String?,
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      priority: json['priority'] as String? ?? 'medium',
      createdBy: json['created_by'] as String?,
      completedBy: json['completed_by'] as String?,
      notes: json['notes'] as String?,
      sortOrder: _coerceInt(json['sort_order']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      completedAt: _parseDateTime(json['completed_at']),
      subtasks: subtasks,
    );
  }

  String get label => title;

  bool get hasNotes => notes != null && notes!.isNotEmpty;

  bool get hasArtifactLink => artifactId != null && artifactId!.isNotEmpty;

  bool get hasSprintLink => sprintId != null && sprintId!.isNotEmpty;

  bool get hasSubtasks => subtasks.isNotEmpty;

  bool get isPending => status == 'pending';

  bool get isInProgress => status == 'in_progress';

  bool get isCompleted => status == 'completed';

  bool get isCancelled => status == 'cancelled';

  bool get canComplete => isPending || isInProgress;

  bool get canReopen => isCompleted || isCancelled;

  bool get canCancel => isPending || isInProgress;
}

class CoquiTodoListResult {
  final List<CoquiTodo> todos;
  final CoquiTodoStats stats;

  const CoquiTodoListResult({
    required this.todos,
    required this.stats,
  });
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
