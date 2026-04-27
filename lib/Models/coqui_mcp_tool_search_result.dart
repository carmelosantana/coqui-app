class CoquiMcpToolSearchResult {
  final String server;
  final String name;
  final String namespacedName;
  final String description;

  const CoquiMcpToolSearchResult({
    required this.server,
    required this.name,
    required this.namespacedName,
    required this.description,
  });

  factory CoquiMcpToolSearchResult.fromJson(Map<String, dynamic> json) {
    return CoquiMcpToolSearchResult(
      server: json['server'] as String? ?? '',
      name: json['name'] as String? ?? '',
      namespacedName: json['namespacedName'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  bool get hasDescription => description.isNotEmpty;
}
