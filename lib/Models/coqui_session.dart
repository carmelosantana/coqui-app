/// Represents a Coqui API session (conversation context).
///
/// Sessions are persistent server-side and identified by a 32-char hex ID.
/// Each session has a model role that determines which LLM model is used.
/// Session titles are generated server-side after the first turn and
/// delivered via an SSE `title` event.
class CoquiSession {
  final String id;
  final String modelRole;
  final String model;
  final String? profile;
  final String? activeProjectId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int tokenCount;
  final bool isClosed;
  final bool isArchived;
  final DateTime? closedAt;
  final DateTime? archivedAt;
  final String? closureReason;

  /// Server-generated session title, delivered via SSE `title` event.
  String? title;

  CoquiSession({
    required this.id,
    required this.modelRole,
    required this.model,
    this.profile,
    this.activeProjectId,
    required this.createdAt,
    required this.updatedAt,
    this.tokenCount = 0,
    this.isClosed = false,
    this.isArchived = false,
    this.closedAt,
    this.archivedAt,
    this.closureReason,
    this.title,
  });

  factory CoquiSession.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is! String || value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    bool parseFlag(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        return value == '1' || value.toLowerCase() == 'true';
      }
      return false;
    }

    return CoquiSession(
      id: json['id'] as String,
      modelRole: json['model_role'] as String? ?? 'orchestrator',
      model: json['model'] as String? ?? '',
      profile: json['profile'] as String?,
      activeProjectId: json['active_project_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      tokenCount: json['token_count'] as int? ?? 0,
      isClosed: parseFlag(json['is_closed']),
      isArchived: parseFlag(json['is_archived']),
      closedAt: parseDate(json['closed_at']),
      archivedAt: parseDate(json['archived_at']),
      closureReason: json['closure_reason'] as String?,
      title: json['title'] as String?,
    );
  }

  factory CoquiSession.fromDatabase(Map<String, dynamic> map) {
    final closedAtMillis = map['closed_at'] as int?;
    final archivedAtMillis = map['archived_at'] as int?;

    return CoquiSession(
      id: map['id'] as String,
      modelRole: map['model_role'] as String,
      model: map['model'] as String? ?? '',
      profile: map['profile'] as String?,
      activeProjectId: map['active_project_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      tokenCount: map['token_count'] as int? ?? 0,
      isClosed: (map['is_closed'] as int? ?? 0) != 0,
      isArchived: (map['is_archived'] as int? ?? 0) != 0,
      closedAt: closedAtMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(closedAtMillis)
          : null,
      archivedAt: archivedAtMillis != null
          ? DateTime.fromMillisecondsSinceEpoch(archivedAtMillis)
          : null,
      closureReason: map['closure_reason'] as String?,
      title: map['title'] as String?,
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'model_role': modelRole,
      'model': model,
      'profile': profile,
      'active_project_id': activeProjectId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'token_count': tokenCount,
      'is_closed': isClosed ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'closed_at': closedAt?.millisecondsSinceEpoch,
      'archived_at': archivedAt?.millisecondsSinceEpoch,
      'closure_reason': closureReason,
      'title': title,
    };
  }

  CoquiSession copyWith({
    String? modelRole,
    String? model,
    String? profile,
    String? activeProjectId,
    String? title,
    int? tokenCount,
    DateTime? updatedAt,
    bool? isClosed,
    bool? isArchived,
    DateTime? closedAt,
    DateTime? archivedAt,
    String? closureReason,
  }) {
    return CoquiSession(
      id: id,
      modelRole: modelRole ?? this.modelRole,
      model: model ?? this.model,
      profile: profile ?? this.profile,
      activeProjectId: activeProjectId ?? this.activeProjectId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tokenCount: tokenCount ?? this.tokenCount,
      isClosed: isClosed ?? this.isClosed,
      isArchived: isArchived ?? this.isArchived,
      closedAt: closedAt ?? this.closedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      closureReason: closureReason ?? this.closureReason,
      title: title ?? this.title,
    );
  }

  bool get isReadOnly => isClosed || isArchived;

  bool get isActive => !isClosed;

  String get status {
    if (isArchived) return 'archived';
    if (isClosed) return 'closed';
    return 'active';
  }

  String? get profileLabel => profile?.isNotEmpty == true ? profile : null;

  @override
  String toString() => title ?? 'Session ${id.substring(0, 8)}';
}
