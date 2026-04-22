class CoquiWebhookDelivery {
  final String id;
  final String webhookId;
  final String? eventType;
  final String? payloadSummary;
  final String? taskId;
  final String status;
  final String? sourceIp;
  final DateTime? createdAt;

  const CoquiWebhookDelivery({
    required this.id,
    required this.webhookId,
    required this.eventType,
    required this.payloadSummary,
    required this.taskId,
    required this.status,
    required this.sourceIp,
    required this.createdAt,
  });

  factory CoquiWebhookDelivery.fromJson(Map<String, dynamic> json) {
    return CoquiWebhookDelivery(
      id: json['id'] as String? ?? '',
      webhookId: json['webhook_id'] as String? ?? '',
      eventType: json['event_type'] as String?,
      payloadSummary: json['payload_summary'] as String?,
      taskId: json['task_id'] as String?,
      status: json['status'] as String? ?? 'unknown',
      sourceIp: json['source_ip'] as String?,
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  String get statusLabel => switch (status) {
        'delivered' => 'Delivered',
        'filtered' => 'Filtered',
        'rejected_signature' => 'Signature Rejected',
        'rejected_disabled' => 'Disabled',
        'rejected_empty' => 'Empty Payload',
        'rejected_too_large' => 'Too Large',
        _ => status.replaceAll('_', ' '),
      };
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
