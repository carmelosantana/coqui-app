import 'dart:convert';

/// Represents a single prompt-response cycle within a session.
///
/// Turns record detailed metadata: token usage, duration, tools used,
/// and child agent counts.
class CoquiTurn {
  final String id;
  final String sessionId;
  final int turnNumber;
  final String userPrompt;
  final String responseText;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int iterations;
  final int durationMs;
  final List<String> toolsUsed;
  final int childAgentCount;
  final DateTime createdAt;
  final DateTime? completedAt;

  CoquiTurn({
    required this.id,
    required this.sessionId,
    required this.turnNumber,
    required this.userPrompt,
    required this.responseText,
    required this.model,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.iterations = 0,
    this.durationMs = 0,
    this.toolsUsed = const [],
    this.childAgentCount = 0,
    required this.createdAt,
    this.completedAt,
  });

  factory CoquiTurn.fromJson(Map<String, dynamic> json) {
    List<String> tools = [];
    if (json['tools_used'] is String) {
      final decoded = jsonDecode(json['tools_used'] as String);
      if (decoded is List) {
        tools = decoded.cast<String>();
      }
    } else if (json['tools_used'] is List) {
      tools = (json['tools_used'] as List).cast<String>();
    }

    return CoquiTurn(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      turnNumber: json['turn_number'] as int? ?? 0,
      userPrompt: json['user_prompt'] as String? ?? '',
      responseText: json['response_text'] as String? ?? '',
      model: json['model'] as String? ?? '',
      promptTokens: json['prompt_tokens'] as int? ?? 0,
      completionTokens: json['completion_tokens'] as int? ?? 0,
      totalTokens: json['total_tokens'] as int? ?? 0,
      iterations: json['iterations'] as int? ?? 0,
      durationMs: json['duration_ms'] as int? ?? 0,
      toolsUsed: tools,
      childAgentCount: json['child_agent_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  /// Duration as a human-readable string.
  String get durationFormatted {
    if (durationMs < 1000) return '${durationMs}ms';
    final seconds = (durationMs / 1000).toStringAsFixed(1);
    return '${seconds}s';
  }

  /// Summary line for the turn metadata.
  String get summary {
    final parts = <String>[];
    if (iterations > 0) parts.add('$iterations iteration${iterations > 1 ? 's' : ''}');
    if (toolsUsed.isNotEmpty) parts.add('${toolsUsed.length} tool${toolsUsed.length > 1 ? 's' : ''}');
    if (childAgentCount > 0) parts.add('$childAgentCount child${childAgentCount > 1 ? 'ren' : ''}');
    if (totalTokens > 0) parts.add('$totalTokens tokens');
    if (durationMs > 0) parts.add(durationFormatted);
    return parts.join(' · ');
  }
}
