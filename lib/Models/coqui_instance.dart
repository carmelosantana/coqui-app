import 'package:uuid/uuid.dart';

/// Represents a configured Coqui server instance.
///
/// Each instance has a unique ID, a user-defined name, the server URL,
/// and an API key for authentication.
class CoquiInstance {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final String apiVersion;
  final bool isActive;

  CoquiInstance({
    String? id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    this.apiVersion = 'v1',
    this.isActive = false,
  }) : id = id ?? const Uuid().v4();

  factory CoquiInstance.fromMap(Map<String, dynamic> map) {
    return CoquiInstance(
      id: map['id'] as String,
      name: map['name'] as String,
      baseUrl: map['base_url'] as String,
      apiKey: map['api_key'] as String,
      apiVersion: (map['api_version'] as String?) ?? 'v1',
      isActive: (map['is_active'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'base_url': baseUrl,
      'api_key': apiKey,
      'api_version': apiVersion,
      'is_active': isActive ? 1 : 0,
    };
  }

  CoquiInstance copyWith({
    String? name,
    String? baseUrl,
    String? apiKey,
    String? apiVersion,
    bool? isActive,
  }) {
    return CoquiInstance(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      apiVersion: apiVersion ?? this.apiVersion,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() => name;
}
