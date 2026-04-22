class CoquiSessionMember {
  final String profile;
  final int position;

  const CoquiSessionMember({
    required this.profile,
    required this.position,
  });

  factory CoquiSessionMember.fromJson(Map<String, dynamic> json) {
    return CoquiSessionMember(
      profile: json['profile'] as String? ?? '',
      position: json['position'] as int? ?? 0,
    );
  }

  factory CoquiSessionMember.fromDatabase(Map<String, dynamic> json) {
    return CoquiSessionMember(
      profile: json['profile'] as String? ?? '',
      position: json['position'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toDatabaseMap() {
    return {
      'profile': profile,
      'position': position,
    };
  }
}
