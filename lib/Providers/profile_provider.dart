import 'package:flutter/material.dart';

import 'package:coqui_app/Models/coqui_backstory_inspection.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Models/coqui_profile_preference_schema.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

class ProfileProvider extends ChangeNotifier {
  final CoquiApiService _apiService;

  List<CoquiProfile> _profiles = [];
  final Map<String, CoquiProfile> _profileDetails = {};
  final Map<String, CoquiBackstoryInspection> _backstoryInspections = {};
  final Map<String, String> _backstoryEntryContents = {};
  CoquiProfilePreferenceSchema? _preferenceSchema;
  final Set<String> _loadingBackstoryNames = <String>{};
  bool _isLoading = false;
  bool _isMutating = false;
  String? _error;

  List<CoquiProfile> get profiles => _profiles;
  CoquiProfilePreferenceSchema? get preferenceSchema => _preferenceSchema;
  bool get isLoading => _isLoading;
  bool get isMutating => _isMutating;
  String? get error => _error;

  ProfileProvider({required CoquiApiService apiService})
      : _apiService = apiService;

  CoquiProfile? detailFor(String name) => _profileDetails[name];

  CoquiBackstoryInspection? backstoryFor(String name) =>
      _backstoryInspections[name];

  String? backstoryEntryContentFor(String name, String path) =>
      _backstoryEntryContents[_entryCacheKey(name, path)];

  bool isLoadingBackstory(String name) => _loadingBackstoryNames.contains(name);

  Future<CoquiProfilePreferenceSchema?> fetchPreferenceSchema() async {
    _error = null;
    notifyListeners();

    try {
      final schema = await _apiService.getProfilePreferenceSchema();
      _preferenceSchema = schema;
      notifyListeners();
      return schema;
    } on CoquiException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = CoquiException.friendly(error).message;
    }

    notifyListeners();
    return null;
  }

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
    final listProfile = _profiles.cast<CoquiProfile?>().firstWhere(
          (profile) => profile?.name == name,
          orElse: () => null,
        );

    _error = null;
    notifyListeners();

    try {
      final detail = await _apiService.getProfile(name);
      final mergedDetail = listProfile == null
          ? detail
          : detail.copyWith(isDefault: listProfile.isDefault);
      _profileDetails[name] = mergedDetail;
      _replaceProfile(mergedDetail);
      notifyListeners();
      return mergedDetail;
    } on CoquiException catch (error) {
      if (_isSoftNotFound(error)) {
        if (listProfile != null) {
          _profileDetails[name] = listProfile;
          notifyListeners();
          return listProfile;
        }
      } else {
        _error = error.message;
      }
    } catch (error) {
      _error = CoquiException.friendly(error).message;
    }

    notifyListeners();
    return null;
  }

  Future<CoquiBackstoryInspection?> fetchBackstoryInspection(
      String name) async {
    _error = null;
    _loadingBackstoryNames.add(name);
    notifyListeners();

    try {
      final inspection = await _apiService.inspectProfileBackstory(name);
      _backstoryInspections[name] = inspection;
      return inspection;
    } on CoquiException catch (error) {
      if (_isSoftNotFound(error)) {
        _backstoryInspections.remove(name);
      } else {
        _error = error.message;
      }
    } catch (error) {
      _error = CoquiException.friendly(error).message;
    } finally {
      _loadingBackstoryNames.remove(name);
      notifyListeners();
    }

    return null;
  }

  Future<String?> fetchBackstoryEntryContent(
    String profileName,
    String path,
  ) async {
    _error = null;
    notifyListeners();

    try {
      final content = await _apiService.getProfileBackstoryEntry(
        profileName,
        path: path,
      );
      _backstoryEntryContents[_entryCacheKey(profileName, path)] = content;
      notifyListeners();
      return content;
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

  Future<CoquiBackstoryInspection?> createBackstoryFolder(
    String profileName, {
    required String path,
  }) async {
    return _runMutation(() async {
      final inspection = await _apiService.createProfileBackstoryFolder(
        profileName,
        path: path,
      );
      _backstoryInspections[profileName] = inspection;
      return inspection;
    });
  }

  Future<CoquiBackstoryInspection?> saveBackstoryEntry(
    String profileName, {
    required String path,
    required String content,
  }) async {
    return _runMutation(() async {
      final inspection = await _apiService.upsertProfileBackstoryEntry(
        profileName,
        path: path,
        content: content,
      );
      _backstoryInspections[profileName] = inspection;
      _backstoryEntryContents[_entryCacheKey(profileName, path)] = content;
      return inspection;
    });
  }

  Future<CoquiBackstoryInspection?> deleteBackstoryEntry(
    String profileName, {
    required String path,
  }) async {
    return _runMutation(() async {
      final inspection = await _apiService.deleteProfileBackstoryEntry(
        profileName,
        path: path,
      );
      _backstoryInspections[profileName] = inspection;
      _backstoryEntryContents.remove(_entryCacheKey(profileName, path));
      return inspection;
    });
  }

  void clear() {
    _profiles = [];
    _profileDetails.clear();
    _backstoryInspections.clear();
    _backstoryEntryContents.clear();
    _preferenceSchema = null;
    _loadingBackstoryNames.clear();
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

  bool _isSoftNotFound(CoquiException error) {
    return error.isNotFound || error.statusCode == 404;
  }

  String _entryCacheKey(String profileName, String path) {
    return '$profileName::$path';
  }
}
