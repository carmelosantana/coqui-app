import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_loop.dart';
import 'package:coqui_app/Models/coqui_project.dart';
import 'package:coqui_app/Models/coqui_sprint.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

class LoopProvider extends ChangeNotifier {
  final CoquiApiService _apiService;

  List<CoquiLoop> _loops = [];
  int _activeCount = 0;
  List<CoquiLoopDefinition> _definitions = [];
  final Map<String, CoquiLoopDetail> _detailsById = {};
  final Map<String, List<CoquiLoopIteration>> _iterationsByLoopId = {};
  final Map<String, CoquiLoopIterationDetail> _iterationDetailsById = {};
  List<CoquiProject> _projects = [];
  final Map<String, List<CoquiSprint>> _sprintsByProjectId = {};
  final Set<String> _mutatingIds = {};
  final Set<String> _loadingDetailIds = {};

  bool _isLoading = false;
  bool _isCreating = false;
  bool _isDefinitionsLoading = false;
  bool _isProjectsLoading = false;
  String? _error;
  String? _statusFilter;

  LoopProvider({required CoquiApiService apiService})
      : _apiService = apiService;

  List<CoquiLoop> get loops => _loops;
  int get activeCount => _activeCount;
  List<CoquiLoopDefinition> get definitions => _definitions;
  List<CoquiProject> get projects => _projects;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  bool get isDefinitionsLoading => _isDefinitionsLoading;
  bool get isProjectsLoading => _isProjectsLoading;
  String? get error => _error;
  String? get statusFilter => _statusFilter;

  CoquiLoop? loopById(String id) =>
      _detailsById[id]?.loop ??
      _loops.cast<CoquiLoop?>().firstWhere(
            (loop) => loop?.id == id,
            orElse: () => null,
          );

  CoquiLoopDetail? detailById(String id) => _detailsById[id];

  List<CoquiLoopIteration> iterationsForLoop(String loopId) =>
      List.unmodifiable(_iterationsByLoopId[loopId] ?? const []);

  CoquiLoopIterationDetail? iterationDetailById(String iterationId) =>
      _iterationDetailsById[iterationId];

  List<CoquiSprint> sprintsForProject(String projectId) =>
      List.unmodifiable(_sprintsByProjectId[projectId] ?? const []);

  bool isMutating(String id) => _mutatingIds.contains(id);

  bool isDetailLoading(String id) => _loadingDetailIds.contains(id);

  Future<void> fetchLoops({String? status, bool silent = false}) async {
    _statusFilter = status;
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final result = await _apiService.listLoops(status: status);
      _loops = result.loops;
      _activeCount = result.activeCount;
      for (final loop in _loops) {
        final detail = _detailsById[loop.id];
        if (detail != null) {
          _detailsById[loop.id] = CoquiLoopDetail(
            loop: loop,
            iteration: detail.iteration,
            stages: detail.stages,
          );
        }
      }
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

  Future<void> fetchDefinitions({bool force = false}) async {
    if (_definitions.isNotEmpty && !force) return;

    _isDefinitionsLoading = true;
    _error = null;
    notifyListeners();

    try {
      _definitions = await _apiService.listLoopDefinitions();
    } catch (e) {
      _error = CoquiException.friendly(e).message;
    } finally {
      _isDefinitionsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchProjects({bool force = false}) async {
    if (_projects.isNotEmpty && !force) return;

    _isProjectsLoading = true;
    _error = null;
    notifyListeners();

    try {
      _projects = await _apiService.listProjects(status: 'active');
    } catch (e) {
      _error = CoquiException.friendly(e).message;
    } finally {
      _isProjectsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchProjectSprints(String projectId,
      {bool force = false}) async {
    if (_sprintsByProjectId.containsKey(projectId) && !force) return;

    try {
      _sprintsByProjectId[projectId] =
          await _apiService.listProjectSprints(projectId);
      notifyListeners();
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      notifyListeners();
    }
  }

  Future<CoquiLoopDetail?> loadLoopDetail(String id,
      {bool force = false}) async {
    if (_loadingDetailIds.contains(id)) return _detailsById[id];
    if (!force && _detailsById.containsKey(id)) return _detailsById[id];

    _loadingDetailIds.add(id);
    notifyListeners();

    try {
      final detail = await _apiService.getLoopDetail(id);
      _detailsById[id] = detail;
      _replaceLoop(detail.loop);
      _error = null;
      return detail;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _loadingDetailIds.remove(id);
      notifyListeners();
    }
  }

  Future<void> refreshLoopIterations(String loopId) async {
    try {
      _iterationsByLoopId[loopId] =
          await _apiService.listLoopIterations(loopId);
      notifyListeners();
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      notifyListeners();
    }
  }

  Future<CoquiLoopIterationDetail?> loadIterationDetail(
    String loopId,
    String iterationId, {
    bool force = false,
  }) async {
    if (!force && _iterationDetailsById.containsKey(iterationId)) {
      return _iterationDetailsById[iterationId];
    }

    try {
      final detail =
          await _apiService.getLoopIterationDetail(loopId, iterationId);
      _iterationDetailsById[iterationId] = detail;
      notifyListeners();
      return detail;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      notifyListeners();
      return null;
    }
  }

  Future<CoquiLoopDetail?> createLoop({
    required String definition,
    required String goal,
    String? projectId,
    String? sprintId,
    Map<String, String>? parameters,
    int? maxIterations,
  }) async {
    _isCreating = true;
    _error = null;
    notifyListeners();

    try {
      final detail = await _apiService.createLoop(
        definition: definition,
        goal: goal,
        projectId: projectId,
        sprintId: sprintId,
        parameters: parameters,
        maxIterations: maxIterations,
      );
      _detailsById[detail.loop.id] = detail;
      _replaceLoop(detail.loop);
      unawaited(refreshLoopIterations(detail.loop.id));
      unawaited(fetchLoops(status: _statusFilter, silent: true));
      return detail;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<CoquiLoop?> pauseLoop(String id) => _transitionLoop(
        id,
        (loopId) => _apiService.pauseLoop(loopId),
      );

  Future<CoquiLoop?> resumeLoop(String id) => _transitionLoop(
        id,
        (loopId) => _apiService.resumeLoop(loopId),
      );

  Future<CoquiLoop?> stopLoop(String id) => _transitionLoop(
        id,
        (loopId) => _apiService.stopLoop(loopId),
      );

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<CoquiLoop?> _transitionLoop(
    String id,
    Future<String> Function(String loopId) action,
  ) async {
    _mutatingIds.add(id);
    _error = null;
    notifyListeners();

    try {
      final status = await action(id);
      final existing = loopById(id);
      if (existing != null) {
        final updated = existing.copyWith(
          status: status,
          lastActivityAt: DateTime.now().toUtc(),
          completedAt: status == 'cancelled' ? DateTime.now().toUtc() : null,
        );
        _replaceLoop(updated);
        final detail = _detailsById[id];
        if (detail != null) {
          _detailsById[id] = CoquiLoopDetail(
            loop: updated,
            iteration: detail.iteration,
            stages: detail.stages,
          );
        }
      }
      unawaited(loadLoopDetail(id, force: true));
      unawaited(fetchLoops(status: _statusFilter, silent: true));
      return loopById(id);
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingIds.remove(id);
      notifyListeners();
    }
  }

  void _replaceLoop(CoquiLoop loop) {
    final index = _loops.indexWhere((item) => item.id == loop.id);
    if (index == -1) {
      _loops = [loop, ..._loops];
      return;
    }
    _loops[index] = loop;
  }
}
