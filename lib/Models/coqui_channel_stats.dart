class CoquiChannelStats {
  final int total;
  final int enabled;
  final int ready;
  final int errors;
  final int activeRuntimes;
  final int registeredDrivers;

  const CoquiChannelStats({
    required this.total,
    required this.enabled,
    required this.ready,
    required this.errors,
    required this.activeRuntimes,
    required this.registeredDrivers,
  });

  factory CoquiChannelStats.fromJson(Map<String, dynamic> json) {
    return CoquiChannelStats(
      total: _coerceStatsInt(json['total']),
      enabled: _coerceStatsInt(json['enabled']),
      ready: _coerceStatsInt(json['ready']),
      errors: _coerceStatsInt(json['errors']),
      activeRuntimes: _coerceStatsInt(json['active_runtimes']),
      registeredDrivers: _coerceStatsInt(json['registered_drivers']),
    );
  }

  static const empty = CoquiChannelStats(
    total: 0,
    enabled: 0,
    ready: 0,
    errors: 0,
    activeRuntimes: 0,
    registeredDrivers: 0,
  );
}

int _coerceStatsInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}