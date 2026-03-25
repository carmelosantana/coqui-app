import 'dart:async';

import 'package:flutter/material.dart';
import 'package:coqui_app/Models/coqui_instance.dart';
import 'package:coqui_app/Services/analytics_service.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/instance_service.dart';

/// Manages Coqui server instances and provides the active API service.
///
/// When the active instance changes, [CoquiApiService] is reconfigured
/// and listeners are notified so the chat provider can refresh.
class InstanceProvider extends ChangeNotifier {
  final InstanceService _instanceService;
  final CoquiApiService _apiService;

  List<CoquiInstance> _instances = [];
  List<CoquiInstance> get instances => _instances;

  CoquiInstance? _activeInstance;
  CoquiInstance? get activeInstance => _activeInstance;

  CoquiApiService get apiService => _apiService;

  bool get hasActiveInstance => _activeInstance != null;

  bool? _isOnline;
  bool? get isOnline => _isOnline;

  Timer? _healthTimer;
  bool _isCheckingHealth = false;

  InstanceProvider({
    required InstanceService instanceService,
    required CoquiApiService apiService,
  })  : _instanceService = instanceService,
        _apiService = apiService {
    _initialize();
  }

  Future<void> _initialize() async {
    await _instanceService.initialize();
    _instances = _instanceService.getInstances();
    _activeInstance = _instanceService.getActiveInstance();

    if (_activeInstance != null) {
      _apiService.configure(
        baseUrl: _activeInstance!.baseUrl,
        apiKey: _activeInstance!.apiKey,
        apiVersion: _activeInstance!.apiVersion,
      );
      _checkHealth();
    }

    _startHealthTimer();
    notifyListeners();
  }

  /// Add a new instance and optionally make it active.
  Future<void> addInstance(CoquiInstance instance) async {
    await _instanceService.addInstance(instance);
    _instances = _instanceService.getInstances();

    // If it's the first instance, it becomes active automatically
    if (_instances.length == 1) {
      _activeInstance = _instanceService.getActiveInstance();
      _configureApiService();
    }

    AnalyticsService.trackEvent('server_configured');

    notifyListeners();
  }

  /// Update an existing instance.
  Future<void> updateInstance(CoquiInstance instance) async {
    await _instanceService.updateInstance(instance);
    _instances = _instanceService.getInstances();

    // If the active instance was updated, reconfigure the API service
    if (_activeInstance?.id == instance.id) {
      _activeInstance = instance;
      _configureApiService();
    }

    notifyListeners();
  }

  /// Delete an instance.
  Future<void> removeInstance(String id) async => deleteInstance(id);

  /// Delete an instance.
  Future<void> deleteInstance(String id) async {
    await _instanceService.deleteInstance(id);
    _instances = _instanceService.getInstances();

    if (_activeInstance?.id == id) {
      _activeInstance = _instanceService.getActiveInstance();
      _configureApiService();
    }

    notifyListeners();
  }

  /// Switch the active instance.
  Future<void> setActiveInstance(String id) async {
    await _instanceService.setActiveInstance(id);
    _instances = _instanceService.getInstances();
    _activeInstance = _instanceService.getActiveInstance();
    _configureApiService();
    notifyListeners();
  }

  void _configureApiService() {
    if (_activeInstance != null) {
      _apiService.configure(
        baseUrl: _activeInstance!.baseUrl,
        apiKey: _activeInstance!.apiKey,
        apiVersion: _activeInstance!.apiVersion,
      );
      _isOnline = null; // Show checking status
      _checkHealth();
    }
  }

  void _startHealthTimer() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkHealth();
    });
  }

  Future<void> _checkHealth() async {
    if (_isCheckingHealth) return;
    _isCheckingHealth = true;

    try {
      if (_activeInstance == null) {
        if (_isOnline != null) {
          _isOnline = null;
          notifyListeners();
        }
        return;
      }

      await _apiService.healthCheck();
      if (_isOnline != true) {
        _isOnline = true;
        notifyListeners();
      }
    } catch (_) {
      if (_isOnline != false) {
        _isOnline = false;
        notifyListeners();
      }
    } finally {
      _isCheckingHealth = false;
    }
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    super.dispose();
  }
}
