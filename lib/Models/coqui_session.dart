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
  final DateTime createdAt;
  final DateTime updatedAt;
  final int tokenCount;

  /// Server-generated session title, delivered via SSE `title` event.
  String? title;

  CoquiSession({
    required this.id,
    required this.modelRole,
    required this.model,
    this.profile,
    required this.createdAt,
    required this.updatedAt,
    this.tokenCount = 0,
    this.title,
  });

  factory CoquiSession.fromJson(Map<String, dynamic> json) {
    return CoquiSession(
      id: json['id'] as String,
      modelRole: json['model_role'] as String? ?? 'orchestrator',
      model: json['model'] as String? ?? '',
      profile: json['profile'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      tokenCount: json['token_count'] as int? ?? 0,
      title: json['title'] as String?,
    );
  }

  factory CoquiSession.fromDatabase(Map<String, dynamic> map) {
    return CoquiSession(
      id: map['id'] as String,
      modelRole: map['model_role'] as String,
      model: map['model'] as String? ?? '',
      profile: map['profile'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      tokenCount: map['token_count'] as int? ?? 0,
      title: map['title'] as String?,
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'model_role': modelRole,
      'model': model,
      'profile': profile,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'token_count': tokenCount,
      'title': title,
    };
  }

  CoquiSession copyWith({
    String? modelRole,
    String? model,
    String? profile,
    String? title,
    int? tokenCount,
    DateTime? updatedAt,
  }) {
    return CoquiSession(
      id: id,
      modelRole: modelRole ?? this.modelRole,
      model: model ?? this.model,
      profile: profile ?? this.profile,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tokenCount: tokenCount ?? this.tokenCount,
      title: title ?? this.title,
    );
  }

  @override
  String toString() => title ?? 'Session ${id.substring(0, 8)}';
}
