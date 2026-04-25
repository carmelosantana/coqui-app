class CoquiChannelEvent {
  final String id;
  final String channelInstanceId;
  final String conversationId;
  final String? providerEventId;
  final String dedupeKey;
  final String eventType;
  final String? remoteUserKey;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> normalized;
  final String status;
  final String? error;
  final String? sessionId;
  final String? taskId;
  final DateTime? receivedAt;
  final DateTime? processedAt;

  CoquiChannelEvent({
    required this.id,
    required this.channelInstanceId,
    required this.conversationId,
    required this.providerEventId,
    required this.dedupeKey,
    required this.eventType,
    required this.remoteUserKey,
    required this.payload,
    required this.normalized,
    required this.status,
    required this.error,
    required this.sessionId,
    required this.taskId,
    required this.receivedAt,
    required this.processedAt,
  });

  factory CoquiChannelEvent.fromJson(Map<String, dynamic> json) {
    return CoquiChannelEvent(
      id: json['id'] as String? ?? '',
      channelInstanceId: json['channel_instance_id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      providerEventId: json['provider_event_id'] as String?,
      dedupeKey: json['dedupe_key'] as String? ?? '',
      eventType: json['event_type'] as String? ?? 'message',
      remoteUserKey: json['remote_user_key'] as String?,
      payload: _coerceEventMap(json['payload']),
      normalized: _coerceEventMap(json['normalized']),
      status: json['status'] as String? ?? 'received',
      error: json['error'] as String?,
      sessionId: json['session_id'] as String?,
      taskId: json['task_id'] as String?,
      receivedAt: _parseEventDateTime(json['received_at']),
      processedAt: _parseEventDateTime(json['processed_at']),
    );
  }

  bool get isProcessed => status == 'processed';
}

Map<String, dynamic> _coerceEventMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return const {};
}

DateTime? _parseEventDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}