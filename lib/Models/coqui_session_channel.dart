class CoquiSessionChannel {
  final String instanceId;
  final String name;
  final String driver;
  final String displayName;

  const CoquiSessionChannel({
    required this.instanceId,
    required this.name,
    required this.driver,
    required this.displayName,
  });

  factory CoquiSessionChannel.fromJson(Map<String, dynamic> json) {
    return CoquiSessionChannel(
      instanceId: json['instance_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      driver: json['driver'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
    );
  }

  factory CoquiSessionChannel.fromDatabase(Map<String, dynamic> map) {
    return CoquiSessionChannel.fromJson(map);
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'instance_id': instanceId,
      'name': name,
      'driver': driver,
      'display_name': displayName,
    };
  }

  String get driverLabel => switch (driver) {
        'signal' => 'Signal',
        'telegram' => 'Telegram',
        'discord' => 'Discord',
        _ => driver,
      };

  String get displayLabel => displayName.isNotEmpty ? displayName : name;

  String get summaryLabel {
    final label = displayLabel;
    final source = driverLabel;

    if (source.isEmpty) return label;
    if (label.isEmpty) return source;
    if (label.toLowerCase() == source.toLowerCase()) {
      return source;
    }

    return '$source • $label';
  }
}
