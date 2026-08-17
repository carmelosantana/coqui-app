import 'package:hive/hive.dart';
import 'package:coqui_app/Models/coqui_instance.dart';
import 'package:coqui_app/Models/runtime_config.dart';

/// Manages Coqui server instances in Hive local storage.
///
/// Each instance represents a connection to a Coqui API server
/// with its own URL and API key. Users can have multiple instances
/// and switch between them.
class InstanceService {
  static const String _boxName = 'instances';
  static const String defaultInstanceName = 'Local Coqui';
  static const String defaultInstanceUrl = 'http://localhost:3300';
  static const String bundledInstanceName = 'This Server';
  static const Duration _lockRetryDelay = Duration(milliseconds: 250);
  static const int _lockRetryAttempts = 20;

  /// Per-deployment runtime config. Defaults to
  /// [RuntimeConfig.notBundled] so native, dev, and hosted builds keep the
  /// localhost default.
  final RuntimeConfig runtimeConfig;

  InstanceService({this.runtimeConfig = RuntimeConfig.notBundled});

  late Box _box;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _box = await Hive.openBox(_boxName);
    } catch (error) {
      if (_isBoxLockError(error)) {
        _box = await _openBoxWithLockRetry();
      } else if (_isRecoverableBoxSchemaError(error)) {
        await Hive.deleteBoxFromDisk(_boxName);
        _box = await Hive.openBox(_boxName);
      } else {
        rethrow;
      }
    }
    _initialized = true;
  }

  Future<Box> _openBoxWithLockRetry() async {
    Object? lastError;

    for (var attempt = 0; attempt < _lockRetryAttempts; attempt += 1) {
      if (attempt > 0) {
        await Future<void>.delayed(_lockRetryDelay);
      }

      try {
        return await Hive.openBox(_boxName);
      } catch (error) {
        if (!_isBoxLockError(error)) {
          rethrow;
        }
        lastError = error;
      }
    }

    throw lastError ??
        HiveError('Failed to open $_boxName after lock retry attempts.');
  }

  /// Seed the app's single default instance when the user has none yet.
  ///
  /// In a bundled deployment (a container serving both the web UI and its own
  /// Coqui server) that default is the same origin the page was loaded from,
  /// so the app connects with no manual server entry. Everywhere else it is
  /// the unchanged localhost default.
  Future<void> ensureDefaultInstance() async {
    if (getInstances().isNotEmpty) return;

    final bundledBaseUrl = runtimeConfig.bundled ? runtimeConfig.baseUrl : null;

    final instance = bundledBaseUrl != null
        ? CoquiInstance(
            name: bundledInstanceName,
            baseUrl: bundledBaseUrl,
            apiKey: '',
            apiVersion: runtimeConfig.apiVersion,
            isActive: true,
          )
        : CoquiInstance(
            name: defaultInstanceName,
            baseUrl: defaultInstanceUrl,
            apiKey: '',
            isActive: true,
          );

    await _box.put(instance.id, instance.toMap());
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
    final toSave =
        instances.isEmpty ? instance.copyWith(isActive: true) : instance;

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

  /// Remove all stored instances from local storage.
  Future<void> clearAllInstances() async {
    await _box.clear();
  }

  Future<void> close() async {
    if (!_initialized) {
      return;
    }

    if (_box.isOpen) {
      await _box.close();
    }

    _initialized = false;
  }

  Future<void> deleteStorageFromDisk() async {
    await close();
    await Hive.deleteBoxFromDisk(_boxName);
  }

  /// Set the active instance (deactivates all others).
  Future<void> setActiveInstance(String id) async {
    final instances = getInstances();
    for (final instance in instances) {
      final updated = instance.copyWith(isActive: instance.id == id);
      await _box.put(updated.id, updated.toMap());
    }
  }

  bool _isBoxLockError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('$_boxName.lock') ||
        message.contains('lock failed') ||
        message.contains('resource temporarily unavailable');
  }

  bool _isRecoverableBoxSchemaError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('unknown typeid') ||
        message.contains('cannot read, unknown typeid') ||
        message.contains('hiveerror');
  }
}
