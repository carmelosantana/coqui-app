import 'package:hive/hive.dart';
import 'package:coqui_app/Models/coqui_instance.dart';

/// Manages Coqui server instances in Hive local storage.
///
/// Each instance represents a connection to a Coqui API server
/// with its own URL and API key. Users can have multiple instances
/// and switch between them.
class InstanceService {
  static const String _boxName = 'instances';

  late Box _box;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _box = await Hive.openBox(_boxName);
    _initialized = true;
  }

  /// Get all configured instances.
  List<CoquiInstance> getInstances() {
    final entries = _box.toMap();
    return entries.entries.map((e) {
      final map = Map<String, dynamic>.from(e.value as Map);
      return CoquiInstance.fromMap(map);
    }).toList();
  }

  /// Get the currently active instance, if any.
  CoquiInstance? getActiveInstance() {
    final instances = getInstances();
    try {
      return instances.firstWhere((i) => i.isActive);
    } catch (_) {
      return instances.isNotEmpty ? instances.first : null;
    }
  }

  /// Add a new instance.
  Future<void> addInstance(CoquiInstance instance) async {
    // If this is the first instance, make it active
    final instances = getInstances();
    final toSave = instances.isEmpty
        ? instance.copyWith(isActive: true)
        : instance;

    await _box.put(toSave.id, toSave.toMap());
  }

  /// Update an existing instance.
  Future<void> updateInstance(CoquiInstance instance) async {
    await _box.put(instance.id, instance.toMap());
  }

  /// Delete an instance.
  Future<void> deleteInstance(String id) async {
    await _box.delete(id);
  }

  /// Set the active instance (deactivates all others).
  Future<void> setActiveInstance(String id) async {
    final instances = getInstances();
    for (final instance in instances) {
      final updated = instance.copyWith(isActive: instance.id == id);
      await _box.put(updated.id, updated.toMap());
    }
  }
}
