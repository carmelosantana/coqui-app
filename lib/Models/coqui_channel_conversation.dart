class CoquiChannelConversation {
  final String id;
  final String channelInstanceId;
  final String remoteConversationKey;
  final String? remoteThreadKey;
  final String? sessionId;
  final String? profile;
  final String? lastInboundEventId;
  final DateTime? lastMessageAt;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CoquiChannelConversation({
    required this.id,
    required this.channelInstanceId,
    required this.remoteConversationKey,
    required this.remoteThreadKey,
    required this.sessionId,
    required this.profile,
    required this.lastInboundEventId,
    required this.lastMessageAt,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CoquiChannelConversation.fromJson(Map<String, dynamic> json) {
    return CoquiChannelConversation(
      id: json['id'] as String? ?? '',
      channelInstanceId: json['channel_instance_id'] as String? ?? '',
      remoteConversationKey: json['remote_conversation_key'] as String? ?? '',
      remoteThreadKey: json['remote_thread_key'] as String?,
      sessionId: json['session_id'] as String?,
      profile: json['profile'] as String?,
      lastInboundEventId: json['last_inbound_event_id'] as String?,
      lastMessageAt: _parseConversationDateTime(json['last_message_at']),
      metadata: _coerceConversationMap(json['metadata']),
      createdAt: _parseConversationDateTime(json['created_at']),
      updatedAt: _parseConversationDateTime(json['updated_at']),
    );
  }
}

Map<String, dynamic> _coerceConversationMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return const {};
}

DateTime? _parseConversationDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}