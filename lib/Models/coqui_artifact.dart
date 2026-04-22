class CoquiArtifact {
  final String id;
  final String sessionId;
  final String? turnId;
  final String title;
  final String type;
  final String content;
  final String? language;
  final String? filepath;
  final String stage;
  final int version;
  final Map<String, dynamic>? metadata;
  final String? projectId;
  final String? sprintId;
  final bool persistent;
  final String storageMode;
  final String? canonicalPath;
  final String? contentHash;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CoquiArtifact({
    required this.id,
    required this.sessionId,
    required this.turnId,
    required this.title,
    required this.type,
    required this.content,
    required this.language,
    required this.filepath,
    required this.stage,
    required this.version,
    required this.metadata,
    required this.projectId,
    required this.sprintId,
    required this.persistent,
    required this.storageMode,
    required this.canonicalPath,
    required this.contentHash,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CoquiArtifact.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    return CoquiArtifact(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      turnId: json['turn_id'] as String?,
      title: json['title'] as String? ?? '',
      type: json['type'] as String? ?? 'code',
      content: json['content'] as String? ?? '',
      language: json['language'] as String?,
      filepath: json['filepath'] as String?,
      stage: json['stage'] as String? ?? 'draft',
      version: _coerceInt(json['version']),
      metadata: metadata is Map ? metadata.cast<String, dynamic>() : null,
      projectId: json['project_id'] as String?,
      sprintId: json['sprint_id'] as String?,
      persistent: _coerceBool(json['persistent']),
      storageMode: json['storage_mode'] as String? ?? 'database',
      canonicalPath: json['canonical_path'] as String?,
      contentHash: json['content_hash'] as String?,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  String get label => title;

  bool get hasLanguage => language != null && language!.isNotEmpty;

  bool get hasFilePath => filepath != null && filepath!.isNotEmpty;

  bool get hasProjectLink => projectId != null && projectId!.isNotEmpty;

  bool get hasSprintLink => sprintId != null && sprintId!.isNotEmpty;

  bool get isDraft => stage == 'draft';

  bool get isReview => stage == 'review';

  bool get isFinal => stage == 'final';

  String? get summary {
    final value = metadata?['summary'];
    return value is String && value.isNotEmpty ? value : null;
  }

  List<String> get tags {
    final raw = metadata?['tags'];
    if (raw is! List) return const [];
    return raw.whereType<String>().where((item) => item.isNotEmpty).toList();
  }
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

bool _coerceBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    return normalized == '1' || normalized == 'true';
  }
  return false;
}
