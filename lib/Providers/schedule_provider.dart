import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_schedule.dart';
import 'package:coqui_app/Models/coqui_schedule_stats.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

class ScheduleProvider extends ChangeNotifier {
  final CoquiApiService _apiService;

  List<CoquiSchedule> _schedules = [];
  CoquiScheduleStats _stats = CoquiScheduleStats.empty;
  final Map<String, CoquiSchedule> _detailsById = {};
  final Set<String> _mutatingIds = {};

  bool _isLoading = false;
  bool _isCreating = false;
  String? _error;
  bool? _enabledFilter;

  ScheduleProvider({required CoquiApiService apiService})
      : _apiService = apiService;

  List<CoquiSchedule> get schedules => _schedules;
  CoquiScheduleStats get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get error => _error;
  bool? get enabledFilter => _enabledFilter;

  CoquiSchedule? scheduleById(String id) =>
      _detailsById[id] ??
      _schedules.cast<CoquiSchedule?>().firstWhere(
            (schedule) => schedule?.id == id,
            orElse: () => null,
          );

  bool isMutating(String id) => _mutatingIds.contains(id);

  Future<void> fetchSchedules({bool? enabled, bool silent = false}) async {
    _enabledFilter = enabled;
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final result = await _apiService.listSchedules(enabled: enabled);
      _schedules = result.schedules;
      _stats = result.stats;
      _syncDetails();
      _error = null;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<CoquiSchedule?> loadScheduleDetail(
    String id, {
    bool force = false,
  }) async {
    if (!force && _detailsById.containsKey(id)) return _detailsById[id];

    try {
      final schedule = await _apiService.getSchedule(id);
      _detailsById[id] = schedule;
      _replaceSchedule(schedule);
      _error = null;
      notifyListeners();
      return schedule;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      notifyListeners();
      return null;
    }
  }

  Future<CoquiSchedule?> createSchedule({
    required String name,
    required String scheduleExpression,
    required String prompt,
    String role = 'orchestrator',
    String timezone = 'UTC',
    int maxIterations = 48,
    int maxFailures = 3,
    String? description,
  }) async {
    _isCreating = true;
    _error = null;
    notifyListeners();

    try {
      final schedule = await _apiService.createSchedule(
        name: name,
        scheduleExpression: scheduleExpression,
        prompt: prompt,
        role: role,
        timezone: timezone,
        maxIterations: maxIterations,
        maxFailures: maxFailures,
        description: description,
      );
      _detailsById[schedule.id] = schedule;
      _schedules = [
        schedule,
        ..._schedules.where((item) => item.id != schedule.id)
      ];
      unawaited(fetchSchedules(enabled: _enabledFilter, silent: true));
      return schedule;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<CoquiSchedule?> updateSchedule(
    String id, {
    String? name,
    String? description,
    String? scheduleExpression,
    String? prompt,
    String? role,
    String? timezone,
    int? maxIterations,
    int? maxFailures,
  }) async {
    _mutatingIds.add(id);
    _error = null;
    notifyListeners();

    try {
      final schedule = await _apiService.updateSchedule(
        id,
        name: name,
        description: description,
        scheduleExpression: scheduleExpression,
        prompt: prompt,
        role: role,
        timezone: timezone,
        maxIterations: maxIterations,
        maxFailures: maxFailures,
      );
      _detailsById[id] = schedule;
      _replaceSchedule(schedule);
      unawaited(fetchSchedules(enabled: _enabledFilter, silent: true));
      return schedule;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingIds.remove(id);
      notifyListeners();
    }
  }

  Future<bool> deleteSchedule(String id) async {
    _mutatingIds.add(id);
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteSchedule(id);
      _schedules = _schedules.where((schedule) => schedule.id != id).toList();
      _detailsById.remove(id);
      unawaited(fetchSchedules(enabled: _enabledFilter, silent: true));
      return true;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return false;
    } finally {
      _mutatingIds.remove(id);
      notifyListeners();
    }
  }

  Future<CoquiSchedule?> setScheduleEnabled(String id, bool enabled) async {
    _mutatingIds.add(id);
    _error = null;
    notifyListeners();

    try {
      final schedule = enabled
          ? await _apiService.enableSchedule(id)
          : await _apiService.disableSchedule(id);
      _detailsById[id] = schedule;
      _replaceSchedule(schedule);
      unawaited(fetchSchedules(enabled: _enabledFilter, silent: true));
      return schedule;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingIds.remove(id);
      notifyListeners();
    }
  }

  Future<CoquiSchedule?> triggerSchedule(String id) async {
    _mutatingIds.add(id);
    _error = null;
    notifyListeners();

    try {
      final schedule = await _apiService.triggerSchedule(id);
      _detailsById[id] = schedule;
      _replaceSchedule(schedule);
      unawaited(fetchSchedules(enabled: _enabledFilter, silent: true));
      return schedule;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingIds.remove(id);
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _replaceSchedule(CoquiSchedule schedule) {
    final index = _schedules.indexWhere((item) => item.id == schedule.id);
    if (index == -1) {
      _schedules = [schedule, ..._schedules];
      return;
    }
    _schedules[index] = schedule;
  }

  void _syncDetails() {
    for (final schedule in _schedules) {
      _detailsById[schedule.id] = schedule;
    }
  }
}
