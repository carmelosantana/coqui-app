class CoquiArtifactVersion {
  final String id;
  final String artifactId;
  final int version;
  final String content;
  final String? changeSummary;
  final DateTime? createdAt;

  const CoquiArtifactVersion({
    required this.id,
    required this.artifactId,
    required this.version,
    required this.content,
    required this.changeSummary,
    required this.createdAt,
  });

  factory CoquiArtifactVersion.fromJson(Map<String, dynamic> json) {
    return CoquiArtifactVersion(
      id: json['id'] as String? ?? '',
      artifactId: json['artifact_id'] as String? ?? '',
      version: _coerceInt(json['version']),
      content: json['content'] as String? ?? '',
      changeSummary: json['change_summary'] as String?,
      createdAt: _parseDateTime(json['created_at']),
    );
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
