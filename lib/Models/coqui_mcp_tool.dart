class CoquiMcpTool {
  final String name;
  final String namespacedName;
  final String description;
  final Map<String, dynamic> inputSchema;
  final String? visibility;
  final String? protection;

  const CoquiMcpTool({
    required this.name,
    required this.namespacedName,
    required this.description,
    required this.inputSchema,
    required this.visibility,
    required this.protection,
  });

  factory CoquiMcpTool.fromJson(Map<String, dynamic> json) {
    return CoquiMcpTool(
      name: json['name'] as String? ?? '',
      namespacedName: json['namespacedName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      inputSchema: json['inputSchema'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              json['inputSchema'] as Map<String, dynamic>,
            )
          : const {},
      visibility: json['visibility'] as String?,
      protection: json['protected'] as String?,
    );
  }

  bool get hasDescription => description.isNotEmpty;

  String get effectiveVisibility => visibility ?? 'enabled';

  bool get isAlwaysEnabled => protection == 'always_enabled';

  bool get cannotDisable => protection == 'cannot_disable';

  CoquiMcpTool copyWith({
    String? name,
    String? namespacedName,
    String? description,
    Map<String, dynamic>? inputSchema,
    String? visibility,
    String? protection,
  }) {
    return CoquiMcpTool(
      name: name ?? this.name,
      namespacedName: namespacedName ?? this.namespacedName,
      description: description ?? this.description,
      inputSchema: inputSchema ?? this.inputSchema,
      visibility: visibility ?? this.visibility,
      protection: protection ?? this.protection,
    );
  }

  List<String> get requiredParameters {
    final required = inputSchema['required'];
    if (required is! List) return const [];
    return required.map((item) => item.toString()).toList(growable: false);
  }

  Map<String, dynamic> get properties {
    final properties = inputSchema['properties'];
    if (properties is! Map<String, dynamic>) return const {};
    return properties;
  }
}
