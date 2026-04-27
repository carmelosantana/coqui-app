class CoquiToolVisibility {
  final String name;
  final String visibility;
  final String? protection;

  const CoquiToolVisibility({
    required this.name,
    required this.visibility,
    required this.protection,
  });

  factory CoquiToolVisibility.fromJson(Map<String, dynamic> json) {
    return CoquiToolVisibility(
      name: json['name'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'enabled',
      protection: json['protected'] as String?,
    );
  }

  bool get isAlwaysEnabled => protection == 'always_enabled';

  bool get cannotDisable => protection == 'cannot_disable';

  CoquiToolVisibility copyWith({
    String? name,
    String? visibility,
    String? protection,
  }) {
    return CoquiToolVisibility(
      name: name ?? this.name,
      visibility: visibility ?? this.visibility,
      protection: protection ?? this.protection,
    );
  }
}
