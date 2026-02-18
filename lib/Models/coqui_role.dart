/// A role available on a Coqui server instance.
///
/// Roles map to specific LLM models and access levels configured server-side.
/// Users select a role when creating a new session.
class CoquiRole {
  final String name;
  final String displayName;
  final String description;
  final int version;
  final String accessLevel;
  final bool isBuiltin;
  final String model;
  final String? titleModel;
  final String? instructions;

  CoquiRole({
    required this.name,
    required this.model,
    this.displayName = '',
    this.description = '',
    this.version = 1,
    this.accessLevel = 'readonly',
    this.isBuiltin = false,
    this.titleModel,
    this.instructions,
  });

  factory CoquiRole.fromJson(Map<String, dynamic> json) {
    return CoquiRole(
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      version: json['version'] as int? ?? 1,
      accessLevel: json['access_level'] as String? ?? 'readonly',
      isBuiltin: json['is_builtin'] as bool? ?? false,
      model: json['model'] as String? ?? '',
      titleModel: json['title_model'] as String?,
      instructions: json['instructions'] as String?,
    );
  }

  /// Serialize for create/update API calls.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'display_name': displayName,
      'description': description,
      'access_level': accessLevel,
      if (instructions != null) 'instructions': instructions,
      if (titleModel != null) 'model': titleModel,
    };
  }

  CoquiRole copyWith({
    String? name,
    String? displayName,
    String? description,
    int? version,
    String? accessLevel,
    bool? isBuiltin,
    String? model,
    String? titleModel,
    String? instructions,
  }) {
    return CoquiRole(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      version: version ?? this.version,
      accessLevel: accessLevel ?? this.accessLevel,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      model: model ?? this.model,
      titleModel: titleModel ?? this.titleModel,
      instructions: instructions ?? this.instructions,
    );
  }

  /// Label for display in UI — prefers displayName, falls back to name.
  String get label => displayName.isNotEmpty ? displayName : name;

  @override
  String toString() => label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoquiRole &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}
