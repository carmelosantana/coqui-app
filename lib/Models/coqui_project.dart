class CoquiProject {
  final String id;
  final String title;
  final String slug;
  final String? description;
  final String status;
  final String? directory;
  final String? activeSprintId;
  final int sprintCount;
  final int sprintsCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CoquiProject({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.status,
    required this.directory,
    required this.activeSprintId,
    required this.sprintCount,
    required this.sprintsCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CoquiProject.fromJson(Map<String, dynamic> json) {
    return CoquiProject(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'active',
      directory: json['directory'] as String?,
      activeSprintId: json['active_sprint_id'] as String?,
      sprintCount: _coerceInt(json['sprint_count']),
      sprintsCompleted: _coerceInt(json['sprints_completed']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  String get label => title.isNotEmpty ? title : slug;

  bool get hasDescription => description != null && description!.isNotEmpty;

  bool get hasActiveSprint =>
      activeSprintId != null && activeSprintId!.isNotEmpty;

  bool get isActive => status == 'active';

  bool get isArchived => status == 'archived';

  bool get isCompleted => status == 'completed';

  bool get isReadOnlyInApp => isCompleted;

  bool get canDelete => isArchived;
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
