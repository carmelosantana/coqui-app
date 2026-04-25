class CoquiConfiguredModel {
  final String provider;
  final String id;
  final String name;
  final bool reasoning;
  final List<String> input;
  final int contextWindow;
  final int maxTokens;
  final String? family;
  final bool toolCalls;
  final bool vision;
  final bool thinking;
  final String? metadataSource;

  const CoquiConfiguredModel({
    required this.provider,
    required this.id,
    required this.name,
    required this.reasoning,
    required this.input,
    required this.contextWindow,
    required this.maxTokens,
    required this.family,
    required this.toolCalls,
    required this.vision,
    required this.thinking,
    required this.metadataSource,
  });

  factory CoquiConfiguredModel.fromJson(Map<String, dynamic> json) {
    return CoquiConfiguredModel(
      provider: json['provider'] as String? ?? '',
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      reasoning: json['reasoning'] as bool? ?? false,
      input: (json['input'] as List? ?? []).cast<String>(),
      contextWindow: json['contextWindow'] as int? ?? 0,
      maxTokens: json['maxTokens'] as int? ?? 0,
      family: json['family'] as String?,
      toolCalls: json['toolCalls'] as bool? ?? false,
      vision: json['vision'] as bool? ?? false,
      thinking: json['thinking'] as bool? ?? false,
      metadataSource: json['metadataSource'] as String?,
    );
  }

  String? get version {
    final slashIndex = id.indexOf('/');
    final modelPart = slashIndex >= 0 ? id.substring(slashIndex + 1) : id;
    final versionIndex = modelPart.lastIndexOf(':');
    if (versionIndex == -1 || versionIndex == modelPart.length - 1) {
      return null;
    }
    return modelPart.substring(versionIndex + 1);
  }
}
