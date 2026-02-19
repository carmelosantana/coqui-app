import 'package:flutter/material.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

/// Manages role state for the role management UI.
///
/// Provides CRUD operations for roles and tracks loading/error state
/// independently from the chat provider.
class RoleProvider extends ChangeNotifier {
  final CoquiApiService _apiService;

  List<CoquiRole> _roles = [];
  List<CoquiRole> get roles => _roles;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  RoleProvider({required CoquiApiService apiService})
      : _apiService = apiService;

  /// Fetch all roles from the server.
  Future<void> fetchRoles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _roles = await _apiService.getRoles();
    } on CoquiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load roles: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new custom role.
  Future<bool> createRole({
    required String name,
    required String instructions,
    String? displayName,
    String? description,
    String accessLevel = 'readonly',
    String? model,
  }) async {
    try {
      final role = await _apiService.createRole(
        name: name,
        instructions: instructions,
        displayName: displayName,
        description: description,
        accessLevel: accessLevel,
        model: model,
      );
      _roles.add(role);
      notifyListeners();
      return true;
    } on CoquiException catch (e) {
      _error = _roleErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Update an existing role.
  Future<bool> updateRole(
    String name, {
    String? displayName,
    String? description,
    String? accessLevel,
    String? model,
    String? instructions,
  }) async {
    try {
      final updated = await _apiService.updateRole(
        name,
        displayName: displayName,
        description: description,
        accessLevel: accessLevel,
        model: model,
        instructions: instructions,
      );
      final index = _roles.indexWhere((r) => r.name == name);
      if (index >= 0) {
        _roles[index] = updated;
      }
      notifyListeners();
      return true;
    } on CoquiException catch (e) {
      _error = _roleErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Delete a custom role.
  Future<bool> deleteRole(String name) async {
    try {
      await _apiService.deleteRole(name);
      _roles.removeWhere((r) => r.name == name);
      notifyListeners();
      return true;
    } on CoquiException catch (e) {
      _error = _roleErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Map API error codes to user-friendly messages for role operations.
  String _roleErrorMessage(CoquiException e) {
    return switch (e.code) {
      'role_builtin' =>
        'This role is managed by the system and cannot be modified.',
      'role_reserved' => 'This role name is reserved and cannot be used.',
      'conflict' => 'A role with this name already exists.',
      'missing_field' => e.message,
      'validation_error' => e.message,
      _ => e.message,
    };
  }

  /// Clear the current error.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Fetch a single role with full details (including instructions).
  Future<CoquiRole?> getRole(String name) async {
    try {
      return await _apiService.getRole(name);
    } on CoquiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }
}
