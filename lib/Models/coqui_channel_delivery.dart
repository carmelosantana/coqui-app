class CoquiChannelDelivery {
  final String id;
  final String channelInstanceId;
  final String? conversationId;
  final String? sessionId;
  final String? replyToEventId;
  final String idempotencyKey;
  final Map<String, dynamic> payload;
  final String status;
  final int attemptCount;
  final String? providerMessageId;
  final String? lastError;
  final DateTime? queuedAt;
  final DateTime? sentAt;
  final DateTime? failedAt;

  CoquiChannelDelivery({
    required this.id,
    required this.channelInstanceId,
    required this.conversationId,
    required this.sessionId,
    required this.replyToEventId,
    required this.idempotencyKey,
    required this.payload,
    required this.status,
    required this.attemptCount,
    required this.providerMessageId,
    required this.lastError,
    required this.queuedAt,
    required this.sentAt,
    required this.failedAt,
  });

  factory CoquiChannelDelivery.fromJson(Map<String, dynamic> json) {
    return CoquiChannelDelivery(
      id: json['id'] as String? ?? '',
      channelInstanceId: json['channel_instance_id'] as String? ?? '',
      conversationId: json['conversation_id'] as String?,
      sessionId: json['session_id'] as String?,
      replyToEventId: json['reply_to_event_id'] as String?,
      idempotencyKey: json['idempotency_key'] as String? ?? '',
      payload: _coerceDeliveryMap(json['payload']),
      status: json['status'] as String? ?? 'queued',
      attemptCount: _coerceDeliveryInt(json['attempt_count']),
      providerMessageId: json['provider_message_id'] as String?,
      lastError: json['last_error'] as String?,
      queuedAt: _parseDeliveryDateTime(json['queued_at']),
      sentAt: _parseDeliveryDateTime(json['sent_at']),
      failedAt: _parseDeliveryDateTime(json['failed_at']),
    );
  }

  bool get isFailed => status == 'failed';
}

Map<String, dynamic> _coerceDeliveryMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return const {};
}

DateTime? _parseDeliveryDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

int _coerceDeliveryInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}