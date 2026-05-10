class CoquiProfile {
  final String name;
  final String displayName;
  final String description;
  final bool isDefault;
  final String? model;
  final String? soul;
  final Map<String, dynamic>? preferences;
  final List<String> allowedRoles;

  const CoquiProfile({
    required this.name,
    this.displayName = '',
    this.description = '',
    this.isDefault = false,
    this.model,
    this.soul,
    this.preferences,
    this.allowedRoles = const [],
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
      allowedRoles: (json['allowed_roles'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
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
    List<String>? allowedRoles,
  }) {
    return CoquiProfile(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      isDefault: isDefault ?? this.isDefault,
      model: model ?? this.model,
      soul: soul ?? this.soul,
      preferences: preferences ?? this.preferences,
      allowedRoles: allowedRoles ?? this.allowedRoles,
    );
  }
}
