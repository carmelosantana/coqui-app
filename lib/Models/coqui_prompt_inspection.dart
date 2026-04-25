class CoquiPromptInspection {
  final String? profile;
  final String role;
  final String? resolvedModel;
  final String prompt;
  final int toolCount;
  final int toolkitCount;
  final int promptTokens;
  final int toolTokens;
  final int totalTokens;
  final Map<String, dynamic> budget;
  final Map<String, dynamic> promptSources;
  final Map<String, dynamic>? profilePolicy;

  const CoquiPromptInspection({
    required this.profile,
    required this.role,
    required this.resolvedModel,
    required this.prompt,
    required this.toolCount,
    required this.toolkitCount,
    required this.promptTokens,
    required this.toolTokens,
    required this.totalTokens,
    required this.budget,
    required this.promptSources,
    required this.profilePolicy,
  });

  factory CoquiPromptInspection.fromJson(Map<String, dynamic> json) {
    return CoquiPromptInspection(
      profile: json['profile'] as String?,
      role: json['role'] as String? ?? 'orchestrator',
      resolvedModel: json['resolved_model'] as String?,
      prompt: json['prompt'] as String? ?? '',
      toolCount: json['tool_count'] as int? ?? 0,
      toolkitCount: json['toolkit_count'] as int? ?? 0,
      promptTokens: json['prompt_tokens'] as int? ?? 0,
      toolTokens: json['tool_tokens'] as int? ?? 0,
      totalTokens: json['total_tokens'] as int? ?? 0,
      budget: (json['budget'] as Map?)?.cast<String, dynamic>() ?? const {},
      promptSources:
          (json['prompt_sources'] as Map?)?.cast<String, dynamic>() ?? const {},
      profilePolicy: (json['profile_policy'] as Map?)?.cast<String, dynamic>(),
    );
  }
}
