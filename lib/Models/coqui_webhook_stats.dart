class CoquiWebhookStats {
  final int total;
  final int enabled;
  final int disabled;
  final int totalTriggers;

  const CoquiWebhookStats({
    required this.total,
    required this.enabled,
    required this.disabled,
    required this.totalTriggers,
  });

  static const empty = CoquiWebhookStats(
    total: 0,
    enabled: 0,
    disabled: 0,
    totalTriggers: 0,
  );

  factory CoquiWebhookStats.fromJson(Map<String, dynamic> json) {
    return CoquiWebhookStats(
      total: _coerceInt(json['total']),
      enabled: _coerceInt(json['enabled']),
      disabled: _coerceInt(json['disabled']),
      totalTriggers: _coerceInt(json['total_triggers']),
    );
  }
}

int _coerceInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
