class CoquiProfile {
  final String name;
  final String displayName;
  final String description;
  final bool isDefault;

  const CoquiProfile({
    required this.name,
    this.displayName = '',
    this.description = '',
    this.isDefault = false,
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
    );
  }

  String get label => displayName.isNotEmpty ? displayName : name;
}