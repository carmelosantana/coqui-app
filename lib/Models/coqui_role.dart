/// A role available on a Coqui server instance.
///
/// Roles map to specific LLM models configured server-side.
/// Users select a role when creating a new session.
class CoquiRole {
  final String name;
  final String model;

  CoquiRole({
    required this.name,
    required this.model,
  });

  factory CoquiRole.fromJson(String name, String model) {
    return CoquiRole(name: name, model: model);
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoquiRole &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}
