class CoquiTodoStats {
  final int total;
  final int pending;
  final int inProgress;
  final int completed;
  final int cancelled;

  const CoquiTodoStats({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.cancelled,
  });

  const CoquiTodoStats.empty()
      : total = 0,
        pending = 0,
        inProgress = 0,
        completed = 0,
        cancelled = 0;

  factory CoquiTodoStats.fromJson(Map<String, dynamic> json) {
    return CoquiTodoStats(
      total: _coerceInt(json['total']),
      pending: _coerceInt(json['pending']),
      inProgress: _coerceInt(json['in_progress']),
      completed: _coerceInt(json['completed']),
      cancelled: _coerceInt(json['cancelled']),
    );
  }

  int get openCount => pending + inProgress;

  bool get hasItems => total > 0;
}

int _coerceInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
