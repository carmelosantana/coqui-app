/// User profile from the CoquiBot SaaS API.
class UserProfile {
  final int id;
  final String? displayName;
  final String? githubUsername;
  final String? image;
  final String? email;
  final String role;
  final String? sshPublicKey;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    this.displayName,
    this.githubUsername,
    this.image,
    this.email,
    required this.role,
    this.sshPublicKey,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      displayName: json['displayName'] as String?,
      githubUsername: json['githubUsername'] as String?,
      image: json['image'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'user',
      sshPublicKey: json['sshPublicKey'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Display-friendly name: prefers displayName, falls back to GitHub username.
  String get displayLabel => displayName ?? githubUsername ?? 'User';
}
