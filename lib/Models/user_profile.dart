/// User profile from the CoquiBot SaaS API.
class UserProfile {
  final String id;
  final String? displayName;
  final String? githubUsername;
  final String? image;
  final String? email;
  final String role;
  final String? sshPublicKey;
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    this.displayName,
    this.githubUsername,
    this.image,
    this.email,
    required this.role,
    this.sshPublicKey,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'].toString(),
      displayName: json['displayName'] as String?,
      githubUsername: json['githubUsername'] as String?,
      image: json['image'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'user',
      sshPublicKey: json['sshPublicKey'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  /// Display-friendly name: prefers displayName, falls back to GitHub username.
  String get displayLabel => displayName ?? githubUsername ?? 'User';
}
