/// A delegated sub-agent run spawned by a parent turn or child agent.
///
/// Mirrors the CAP `schema/child-run.json` wire object produced by
/// `SessionHandler::childRunToWire` (list, get, spawn response, and the
/// terminal `done` stream frame). Parsed tolerantly: only
/// `id, parent_session_id, role, prompt, status, created_at` are required;
/// the rest may be null or absent.
class CoquiChildRun {
  final String id;
  final String parentSessionId;
  final String? parentTurnId;
  final String role;

  /// Model the child ran under. `null` ⇒ inherit per persona precedence.
  final String? model;
  final String prompt;
  final String? result;

  /// Lifecycle status: `pending | running | completed | failed | cancelled`.
  final String status;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final DateTime createdAt;

  CoquiChildRun({
    required this.id,
    required this.parentSessionId,
    this.parentTurnId,
    required this.role,
    this.model,
    required this.prompt,
    this.result,
    required this.status,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    required this.createdAt,
  });

  factory CoquiChildRun.fromJson(Map<String, dynamic> json) {
    return CoquiChildRun(
      id: json['id'] as String? ?? '',
      parentSessionId: json['parent_session_id'] as String? ?? '',
      parentTurnId: json['parent_turn_id'] as String?,
      role: json['role'] as String? ?? '',
      model: json['model'] as String?,
      prompt: json['prompt'] as String? ?? '',
      result: json['result'] as String?,
      status: json['status'] as String? ?? '',
      promptTokens: json['prompt_tokens'] as int? ?? 0,
      completionTokens: json['completion_tokens'] as int? ?? 0,
      totalTokens: json['total_tokens'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  String get promptPreview =>
      prompt.length > 120 ? '${prompt.substring(0, 120)}…' : prompt;

  String get resultPreview {
    final value = result ?? '';
    return value.length > 160 ? '${value.substring(0, 160)}…' : value;
  }
}
