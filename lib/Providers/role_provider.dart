import 'package:flutter/material.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

/// Manages read-only role state for role pickers and metadata display.
///
/// Tracks loading/error state independently from the chat provider.
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
      _error = CoquiException.friendly(e).message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear the current error.
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
