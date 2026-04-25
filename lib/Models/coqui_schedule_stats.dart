class CoquiScheduleStats {
  final int total;
  final int enabled;
  final int disabled;
  final int totalRuns;

  const CoquiScheduleStats({
    required this.total,
    required this.enabled,
    required this.disabled,
    required this.totalRuns,
  });

  static const empty = CoquiScheduleStats(
    total: 0,
    enabled: 0,
    disabled: 0,
    totalRuns: 0,
  );

  factory CoquiScheduleStats.fromJson(Map<String, dynamic> json) {
    return CoquiScheduleStats(
      total: _coerceInt(json['total']),
      enabled: _coerceInt(json['enabled']),
      disabled: _coerceInt(json['disabled']),
      totalRuns: _coerceInt(json['total_runs']),
    );
  }
}

int _coerceInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
