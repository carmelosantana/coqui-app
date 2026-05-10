import 'package:flutter/material.dart';

import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

class ProfileProvider extends ChangeNotifier {
  final CoquiApiService _apiService;

  List<CoquiProfile> _profiles = [];
  final Map<String, CoquiProfile> _profileDetails = {};
  bool _isLoading = false;
  bool _isMutating = false;
  String? _error;

  List<CoquiProfile> get profiles => _profiles;
  bool get isLoading => _isLoading;
  bool get isMutating => _isMutating;
  String? get error => _error;

  ProfileProvider({required CoquiApiService apiService})
      : _apiService = apiService;

  CoquiProfile? detailFor(String name) => _profileDetails[name];

  Future<void> fetchProfiles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _profiles = await _apiService.getProfiles();
      _sortProfiles();
    } on CoquiException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = CoquiException.friendly(error).message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CoquiProfile?> fetchProfileDetail(String name) async {
    _error = null;
    notifyListeners();

    try {
      final detail = await _apiService.getProfile(name);
      final listProfile = _profiles.cast<CoquiProfile?>().firstWhere(
            (profile) => profile?.name == name,
            orElse: () => null,
          );
      final mergedDetail = listProfile == null
          ? detail
          : detail.copyWith(isDefault: listProfile.isDefault);
      _profileDetails[name] = mergedDetail;
      _replaceProfile(mergedDetail);
      notifyListeners();
      return mergedDetail;
    } on CoquiException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = CoquiException.friendly(error).message;
    }

    notifyListeners();
    return null;
  }

  Future<CoquiProfile?> createProfile({
    required String name,
    String? description,
    String? soul,
    String? backstory,
    Map<String, dynamic>? preferences,
  }) async {
    return _runMutation(() async {
      final profile = await _apiService.createProfile(
        name: name,
        description: description,
        soul: soul,
        backstory: backstory,
        preferences: preferences,
      );
      _profileDetails[profile.name] = profile;
      _replaceProfile(profile);
      return profile;
    });
  }

  Future<CoquiProfile?> updateProfile(
    String name, {
    String? description,
    String? soul,
    String? backstory,
    Map<String, dynamic>? preferences,
    bool clearBackstory = false,
    bool clearPreferences = false,
  }) async {
    return _runMutation(() async {
      final profile = await _apiService.updateProfile(
        name,
        description: description,
        soul: soul,
        backstory: backstory,
        preferences: preferences,
        clearBackstory: clearBackstory,
        clearPreferences: clearPreferences,
      );
      final existing = _profiles.cast<CoquiProfile?>().firstWhere(
            (entry) => entry?.name == name,
            orElse: () => null,
          );
      final mergedProfile = profile.copyWith(isDefault: existing?.isDefault);
      _profileDetails[name] = mergedProfile;
      _replaceProfile(mergedProfile);
      return mergedProfile;
    });
  }

  Future<bool> deleteProfile(String name) async {
    final deleted = await _runMutation(() async {
      await _apiService.deleteProfile(name);
      _profiles.removeWhere((profile) => profile.name == name);
      _profileDetails.remove(name);
      return true;
    });

    return deleted ?? false;
  }

  void clear() {
    _profiles = [];
    _profileDetails.clear();
    _error = null;
    _isLoading = false;
    _isMutating = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<T?> _runMutation<T>(Future<T> Function() action) async {
    _isMutating = true;
    _error = null;
    notifyListeners();

    try {
      return await action();
    } on CoquiException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = CoquiException.friendly(error).message;
    } finally {
      _isMutating = false;
      _sortProfiles();
      notifyListeners();
    }

    return null;
  }

  void _replaceProfile(CoquiProfile profile) {
    final index = _profiles.indexWhere((entry) => entry.name == profile.name);
    if (index == -1) {
      _profiles.add(profile);
    } else {
      _profiles[index] = profile;
    }

    _sortProfiles();
  }

  void _sortProfiles() {
    _profiles.sort((left, right) => left.label.compareTo(right.label));
  }
}