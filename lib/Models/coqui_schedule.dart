/// The action a schedule fires: a discriminated union keyed on [kind].
///
/// `turn` actions carry a [prompt]; `loop` actions carry a [definitionName].
/// Matches the CAP `scheduled-task` `action` union
/// (`{"kind":"turn","prompt":…}` | `{"kind":"loop","definition_name":…}`).
class ScheduleAction {
  final String kind;
  final String? prompt;
  final String? definitionName;

  const ScheduleAction({
    required this.kind,
    this.prompt,
    this.definitionName,
  });

  const ScheduleAction.turn(this.prompt)
      : kind = 'turn',
        definitionName = null;

  const ScheduleAction.loop(this.definitionName)
      : kind = 'loop',
        prompt = null;

  factory ScheduleAction.fromJson(Map<String, dynamic> json) {
    return ScheduleAction(
      kind: json['kind'] as String? ?? '',
      prompt: json['prompt'] as String?,
      definitionName: json['definition_name'] as String?,
    );
  }

  /// Emit the CAP action union body. A `loop` action serializes
  /// `definition_name`; every other kind serializes `prompt`.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'kind': kind};
    if (kind == 'loop') {
      if (definitionName != null) map['definition_name'] = definitionName;
    } else {
      if (prompt != null) map['prompt'] = prompt;
    }
    return map;
  }

  bool get isLoop => kind == 'loop';

  /// A short human-readable summary of the action for list/detail rows.
  String get summary => isLoop ? (definitionName ?? '') : (prompt ?? '');
}

/// A CAP scheduled task.
///
/// Wire shape (`ScheduleStore::toWire`):
/// `{id, name, cron, persona_id, action, status, last_run_at, next_run_at,
/// created_at, updated_at}`. The enable/disable/trigger endpoints return a raw
/// store row that may omit the [action] union — [fromJson] parses tolerantly.
class CoquiSchedule {
  final String id;
  final String name;
  final String cron;
  final String personaId;
  final ScheduleAction action;
  final String status;
  final DateTime? lastRunAt;
  final DateTime? nextRunAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CoquiSchedule({
    required this.id,
    required this.name,
    required this.cron,
    required this.personaId,
    required this.action,
    required this.status,
    this.lastRunAt,
    this.nextRunAt,
    this.createdAt,
    this.updatedAt,
  });

  factory CoquiSchedule.fromJson(Map<String, dynamic> json) {
    final rawAction = json['action'];
    return CoquiSchedule(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      cron: json['cron'] as String? ?? '',
      personaId: json['persona_id'] as String? ?? '',
      action: rawAction is Map<String, dynamic>
          ? ScheduleAction.fromJson(rawAction)
          : const ScheduleAction(kind: ''),
      status: json['status'] as String? ?? '',
      lastRunAt: _parseDateTime(json['last_run_at']),
      nextRunAt: _parseDateTime(json['next_run_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  bool get isEnabled => status == 'enabled';

  String get statusLabel => isEnabled ? 'Enabled' : 'Disabled';

  /// Emit the CAP create/update body shape.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'cron': cron,
      'persona_id': personaId,
      'action': action.toJson(),
      'status': status,
    };
  }
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
