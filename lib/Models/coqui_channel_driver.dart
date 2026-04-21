class CoquiChannelDriver {
  final String name;
  final String displayName;
  final Map<String, dynamic> capabilities;
  final String package;

  CoquiChannelDriver({
    required this.name,
    required this.displayName,
    required this.capabilities,
    required this.package,
  });

  factory CoquiChannelDriver.fromJson(Map<String, dynamic> json) {
    return CoquiChannelDriver(
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? json['displayName'] as String? ?? json['name'] as String? ?? '',
      capabilities: _coerceDriverMap(json['capabilities']),
      package: json['package'] as String? ?? 'unknown',
    );
  }

  bool get isSignal => name == 'signal';

  bool get isScaffolded => name == 'telegram' || name == 'discord';
}

Map<String, dynamic> _coerceDriverMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return const {};
}