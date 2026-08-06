class CoquiProfile {
  final String name;
  final String displayName;
  final String description;
  final bool isDefault;
  final String? model;
  final String? soul;
  final Map<String, dynamic>? preferences;
  final Map<String, dynamic>? preferenceValues;
  final Map<String, dynamic>? preferenceDocument;
  final List<String> allowedRoles;

  /// CAP `persona.json` identity fields.
  ///
  /// The persona LIST summary and detail responses omit [id] and [avatar];
  /// only the served `persona.json` wire (create/update responses) carries
  /// them, so both are nullable. [version] is the optimistic-concurrency
  /// token (server-assigned, >= 1) present across all persona wire shapes.
  final String? id;
  final int version;
  final Map<String, dynamic>? avatar;

  const CoquiProfile({
    required this.name,
    this.displayName = '',
    this.description = '',
    this.isDefault = false,
    this.model,
    this.soul,
    this.preferences,
    this.preferenceValues,
    this.preferenceDocument,
    this.allowedRoles = const [],
    this.id,
    this.version = 1,
    this.avatar,
  });

  factory CoquiProfile.fromJson(
    Map<String, dynamic> json, {
    bool isDefault = false,
  }) {
    return CoquiProfile(
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isDefault: isDefault,
      model: json['model'] as String?,
      soul: json['soul'] as String?,
      preferences: (json['preferences'] as Map?)?.cast<String, dynamic>(),
        preferenceValues:
          (json['preference_values'] as Map?)?.cast<String, dynamic>(),
        preferenceDocument:
          (json['preference_document'] as Map?)?.cast<String, dynamic>(),
      allowedRoles: (json['allowed_roles'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      id: json['id'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      avatar: (json['avatar'] as Map?)?.cast<String, dynamic>(),
    );
  }

  String get label => displayName.isNotEmpty ? displayName : name;

  CoquiProfile copyWith({
    String? name,
    String? displayName,
    String? description,
    bool? isDefault,
    String? model,
    String? soul,
    Map<String, dynamic>? preferences,
    Map<String, dynamic>? preferenceValues,
    Map<String, dynamic>? preferenceDocument,
    List<String>? allowedRoles,
    String? id,
    int? version,
    Map<String, dynamic>? avatar,
  }) {
    return CoquiProfile(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      isDefault: isDefault ?? this.isDefault,
      model: model ?? this.model,
      soul: soul ?? this.soul,
      preferences: preferences ?? this.preferences,
      preferenceValues: preferenceValues ?? this.preferenceValues,
      preferenceDocument: preferenceDocument ?? this.preferenceDocument,
      allowedRoles: allowedRoles ?? this.allowedRoles,
      id: id ?? this.id,
      version: version ?? this.version,
      avatar: avatar ?? this.avatar,
    );
  }
}
