import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:coqui_app/Models/hosted_instance.dart';
import 'package:coqui_app/Models/region.dart';
import 'package:coqui_app/Services/saas_api_service.dart';

/// Manages hosted instance state — list, deploy, actions, metrics.
class HostedProvider extends ChangeNotifier {
  final SaasApiService _apiService;

  HostedProvider({required SaasApiService apiService})
      : _apiService = apiService;

  // ── State ──────────────────────────────────────────────────────────────

  List<HostedInstance> _instances = [];
  List<Region> _regions = [];
  bool _isLoading = false;
  String? _error;

  List<HostedInstance> get instances => _instances;
  List<Region> get regions => _regions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Load ───────────────────────────────────────────────────────────────

  /// Load instances and regions in parallel.
  Future<void> loadAll() async {
    if (!_apiService.hasToken) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getInstances(),
        _apiService.getRegions(),
      ]);
      _instances = results[0] as List<HostedInstance>;
      _regions = results[1] as List<Region>;
    } on SaasApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load instances: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh just the instance list.
  Future<void> refreshInstances() async {
    if (!_apiService.hasToken) return;

    try {
      _instances = await _apiService.getInstances();
      notifyListeners();
    } on SaasApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  // ── Deploy ─────────────────────────────────────────────────────────────

  /// Deploy a new instance with the given label and optional region.
  Future<HostedInstance?> deploy({
    required String label,
    String? region,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final instance = await _apiService.deployInstance(
        label: label,
        region: region,
      );
      _instances = [instance, ..._instances];
      notifyListeners();
      return instance;
    } on SaasApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────

  /// Start, stop, reboot, or backup an instance.
  Future<bool> performAction(
    int id,
    String action, {
    String? snapshotId,
    String? description,
  }) async {
    _error = null;
    notifyListeners();

    try {
      await _apiService.instanceAction(
        id,
        action,
        snapshotId: snapshotId,
        description: description,
      );
      // Refresh to get updated status.
      await refreshInstances();
      return true;
    } on SaasApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  /// Destroy an instance.
  Future<bool> destroy(int id) async {
    _error = null;
    notifyListeners();

    try {
      await _apiService.destroyInstance(id);
      _instances = _instances.where((i) => i.id != id).toList();
      notifyListeners();
      return true;
    } on SaasApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  // ── Detail ─────────────────────────────────────────────────────────────

  /// Get a single instance by ID (with fresh data from API).
  Future<HostedInstance?> getInstance(int id) async {
    try {
      return await _apiService.getInstance(id);
    } on SaasApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  /// Get snapshots for an instance.
  Future<List<InstanceSnapshot>> getSnapshots(int id) async {
    try {
      return await _apiService.getSnapshots(id);
    } on SaasApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return [];
    }
  }

  /// Get metrics for an instance.
  Future<List<InstanceMetric>> getMetrics(int id, {int hours = 24}) async {
    try {
      return await _apiService.getMetrics(id, hours: hours);
    } on SaasApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return [];
    }
  }
}
