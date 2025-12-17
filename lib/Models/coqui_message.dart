/// A message within a Coqui session.
///
/// Messages have a role (user, assistant, or tool) and content.
/// Tool messages may include tool_calls or tool_call_id metadata.
class CoquiMessage {
  final String id;
  final String content;
  final CoquiMessageRole role;
  final String? toolCalls;
  final String? toolCallId;
  final DateTime createdAt;

  CoquiMessage({
    required this.id,
    required this.content,
    required this.role,
    this.toolCalls,
    this.toolCallId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CoquiMessage.fromJson(Map<String, dynamic> json) {
    return CoquiMessage(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      role: CoquiMessageRole.fromString(json['role'] as String? ?? 'assistant'),
      toolCalls: json['tool_calls'] as String?,
      toolCallId: json['tool_call_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  factory CoquiMessage.fromDatabase(Map<String, dynamic> map) {
    return CoquiMessage(
      id: map['id'] as String,
      content: map['content'] as String,
      role: CoquiMessageRole.fromString(map['role'] as String),
      toolCalls: map['tool_calls'] as String?,
      toolCallId: map['tool_call_id'] as String?,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'content': content,
      'role': role.name,
      'tool_calls': toolCalls,
      'tool_call_id': toolCallId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Whether this message should be displayed in the chat UI.
  /// Tool messages are typically hidden from the user view.
  bool get isDisplayable => role != CoquiMessageRole.tool;

  @override
  String toString() => '${role.name}: $content';
}

enum CoquiMessageRole {
  user,
  assistant,
  tool;

  factory CoquiMessageRole.fromString(String role) {
    return switch (role) {
      'user' => CoquiMessageRole.user,
      'assistant' => CoquiMessageRole.assistant,
      'tool' => CoquiMessageRole.tool,
      _ => CoquiMessageRole.assistant,
    };
  }
}
