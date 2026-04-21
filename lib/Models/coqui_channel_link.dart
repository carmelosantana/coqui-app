class CoquiChannelLink {
  final String id;
  final String channelInstanceId;
  final String remoteUserKey;
  final String? remoteScopeKey;
  final String profile;
  final String trustLevel;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CoquiChannelLink({
    required this.id,
    required this.channelInstanceId,
    required this.remoteUserKey,
    required this.remoteScopeKey,
    required this.profile,
    required this.trustLevel,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CoquiChannelLink.fromJson(Map<String, dynamic> json) {
    return CoquiChannelLink(
      id: json['id'] as String? ?? '',
      channelInstanceId: json['channel_instance_id'] as String? ?? '',
      remoteUserKey: json['remote_user_key'] as String? ?? '',
      remoteScopeKey: json['remote_scope_key'] as String?,
      profile: json['profile'] as String? ?? '',
      trustLevel: json['trust_level'] as String? ?? 'linked',
      metadata: _coerceLinkMap(json['metadata']),
      createdAt: _parseLinkDateTime(json['created_at']),
      updatedAt: _parseLinkDateTime(json['updated_at']),
    );
  }
}

Map<String, dynamic> _coerceLinkMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return const {};
}

DateTime? _parseLinkDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}