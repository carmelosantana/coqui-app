class CoquiChildRun {
  final String id;
  final int parentIteration;
  final String agentRole;
  final String model;
  final String prompt;
  final String result;
  final int tokenCount;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  CoquiChildRun({
    required this.id,
    required this.parentIteration,
    required this.agentRole,
    required this.model,
    required this.prompt,
    required this.result,
    required this.tokenCount,
    required this.createdAt,
    this.metadata,
  });

  factory CoquiChildRun.fromJson(Map<String, dynamic> json) {
    return CoquiChildRun(
      id: json['id'] as String? ?? '',
      parentIteration: json['parent_iteration'] as int? ?? 0,
      agentRole: json['agent_role'] as String? ?? '',
      model: json['model'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      result: json['result'] as String? ?? '',
      tokenCount: json['token_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  String get promptPreview =>
      prompt.length > 120 ? '${prompt.substring(0, 120)}…' : prompt;

  String get resultPreview =>
      result.length > 160 ? '${result.substring(0, 160)}…' : result;
}