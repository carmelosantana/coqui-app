import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_project.dart';
import 'package:coqui_app/Models/coqui_sprint.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

class ProjectProvider extends ChangeNotifier {
  final CoquiApiService _apiService;

  List<CoquiProject> _projects = [];
  final Map<String, CoquiProject> _detailsById = {};
  final Map<String, List<CoquiSprint>> _sprintsByProjectId = {};
  final Map<String, CoquiSprint> _sprintDetailsById = {};
  final Set<String> _loadingProjectIds = {};
  final Set<String> _loadingSprintIds = {};
  final Set<String> _mutatingProjectIds = {};
  final Set<String> _mutatingSprintIds = {};

  bool _isLoading = false;
  String? _error;
  String? _projectStatusFilter;

  ProjectProvider({required CoquiApiService apiService})
      : _apiService = apiService;

  List<CoquiProject> get projects => _projects;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get projectStatusFilter => _projectStatusFilter;

  int get activeProjectsCount =>
      _projects.where((project) => project.isActive).length;

  int get archivedProjectsCount =>
      _projects.where((project) => project.isArchived).length;

  int get completedProjectsCount =>
      _projects.where((project) => project.isCompleted).length;

  CoquiProject? projectById(String idOrSlug) {
    return _detailsById[idOrSlug] ??
        _projects.cast<CoquiProject?>().firstWhere(
              (project) => project?.id == idOrSlug || project?.slug == idOrSlug,
              orElse: () => null,
            );
  }

  CoquiSprint? sprintById(String id) =>
      _sprintDetailsById[id] ??
      _sprintsByProjectId.values
          .expand((items) => items)
          .cast<CoquiSprint?>()
          .firstWhere((sprint) => sprint?.id == id, orElse: () => null);

  List<CoquiSprint> sprintsForProject(String projectId) =>
      List.unmodifiable(_sprintsByProjectId[projectId] ?? const []);

  bool isProjectLoading(String id) => _loadingProjectIds.contains(id);

  bool isSprintLoading(String id) => _loadingSprintIds.contains(id);

  bool isProjectMutating(String id) => _mutatingProjectIds.contains(id);

  bool isSprintMutating(String id) => _mutatingSprintIds.contains(id);

  Future<void> fetchProjects({
    String? status,
    bool silent = false,
  }) async {
    _projectStatusFilter = status;
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      _projects = await _apiService.listProjects(status: status);
      for (final project in _projects) {
        _detailsById[project.id] = project;
        _detailsById[project.slug] = project;
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

  Future<CoquiProject?> loadProjectDetail(
    String idOrSlug, {
    bool force = false,
  }) async {
    if (_loadingProjectIds.contains(idOrSlug)) {
      return projectById(idOrSlug);
    }
    if (!force && _detailsById.containsKey(idOrSlug)) {
      return _detailsById[idOrSlug];
    }

    _loadingProjectIds.add(idOrSlug);
    notifyListeners();

    try {
      final project = await _apiService.getProject(idOrSlug);
      _cacheProject(project);
      _error = null;
      return project;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _loadingProjectIds.remove(idOrSlug);
      notifyListeners();
    }
  }

  Future<List<CoquiSprint>> fetchProjectSprints(
    String projectIdOrSlug, {
    String? status,
    bool force = false,
  }) async {
    final project = projectById(projectIdOrSlug);
    final cacheKey = project?.id ?? projectIdOrSlug;
    if (!force && _sprintsByProjectId.containsKey(cacheKey)) {
      return sprintsForProject(cacheKey);
    }

    _loadingProjectIds.add(cacheKey);
    notifyListeners();

    try {
      final sprints = await _apiService.listProjectSprints(
        projectIdOrSlug,
        status: status,
      );
      _sprintsByProjectId[cacheKey] = sprints;
      for (final sprint in sprints) {
        _sprintDetailsById[sprint.id] = sprint;
      }
      _error = null;
      return sprints;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return sprintsForProject(cacheKey);
    } finally {
      _loadingProjectIds.remove(cacheKey);
      notifyListeners();
    }
  }

  Future<CoquiSprint?> loadSprintDetail(
    String id, {
    bool force = false,
  }) async {
    if (_loadingSprintIds.contains(id)) {
      return sprintById(id);
    }
    if (!force && _sprintDetailsById.containsKey(id)) {
      return _sprintDetailsById[id];
    }

    _loadingSprintIds.add(id);
    notifyListeners();

    try {
      final sprint = await _apiService.getSprint(id);
      _cacheSprint(sprint);
      _error = null;
      return sprint;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _loadingSprintIds.remove(id);
      notifyListeners();
    }
  }

  Future<CoquiProject?> createProject({
    required String title,
    required String slug,
    String? description,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final project = await _apiService.createProject(
        title: title,
        slug: slug,
        description: description,
      );
      _cacheProject(project, prepend: true);
      return project;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CoquiProject?> updateProject(
    String idOrSlug, {
    String? title,
    String? description,
    String? status,
  }) async {
    _mutatingProjectIds.add(idOrSlug);
    _error = null;
    notifyListeners();

    try {
      final project = await _apiService.updateProject(
        idOrSlug,
        title: title,
        description: description,
        status: status,
      );
      _cacheProject(project);
      return project;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingProjectIds.remove(idOrSlug);
      notifyListeners();
    }
  }

  Future<CoquiProject?> archiveProject(String idOrSlug) async {
    _mutatingProjectIds.add(idOrSlug);
    _error = null;
    notifyListeners();

    try {
      final project = await _apiService.archiveProject(idOrSlug);
      _cacheProject(project);
      return project;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingProjectIds.remove(idOrSlug);
      notifyListeners();
    }
  }

  Future<CoquiProject?> activateProject(String idOrSlug) async {
    _mutatingProjectIds.add(idOrSlug);
    _error = null;
    notifyListeners();

    try {
      final project = await _apiService.activateProject(idOrSlug);
      _cacheProject(project);
      return project;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingProjectIds.remove(idOrSlug);
      notifyListeners();
    }
  }

  Future<bool> deleteProject(String idOrSlug) async {
    _mutatingProjectIds.add(idOrSlug);
    _error = null;
    notifyListeners();

    try {
      final project = projectById(idOrSlug);
      await _apiService.deleteProject(idOrSlug);
      if (project != null) {
        _projects.removeWhere((item) => item.id == project.id);
        _detailsById.remove(project.id);
        _detailsById.remove(project.slug);
        _sprintsByProjectId.remove(project.id);
      } else {
        _projects.removeWhere(
            (item) => item.id == idOrSlug || item.slug == idOrSlug);
        _detailsById.remove(idOrSlug);
        _sprintsByProjectId.remove(idOrSlug);
      }
      return true;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return false;
    } finally {
      _mutatingProjectIds.remove(idOrSlug);
      notifyListeners();
    }
  }

  Future<CoquiSprint?> createSprint({
    required String projectIdOrSlug,
    required String title,
    String? acceptanceCriteria,
    String? lastSessionId,
    int maxReviewRounds = 3,
  }) async {
    _mutatingProjectIds.add(projectIdOrSlug);
    _error = null;
    notifyListeners();

    try {
      final sprint = await _apiService.createSprint(
        projectIdOrSlug: projectIdOrSlug,
        title: title,
        acceptanceCriteria: acceptanceCriteria,
        lastSessionId: lastSessionId,
        maxReviewRounds: maxReviewRounds,
      );
      _cacheSprint(sprint);
      await fetchProjectSprints(sprint.projectId, force: true);
      await loadProjectDetail(sprint.projectId, force: true);
      return sprint;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingProjectIds.remove(projectIdOrSlug);
      notifyListeners();
    }
  }

  Future<CoquiSprint?> updateSprint(
    String id, {
    String? title,
    String? acceptanceCriteria,
    String? lastSessionId,
    int? maxReviewRounds,
  }) async {
    _mutatingSprintIds.add(id);
    _error = null;
    notifyListeners();

    try {
      final sprint = await _apiService.updateSprint(
        id,
        title: title,
        acceptanceCriteria: acceptanceCriteria,
        lastSessionId: lastSessionId,
        maxReviewRounds: maxReviewRounds,
      );
      _cacheSprint(sprint);
      await fetchProjectSprints(sprint.projectId, force: true);
      await loadProjectDetail(sprint.projectId, force: true);
      return sprint;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingSprintIds.remove(id);
      notifyListeners();
    }
  }

  Future<bool> deleteSprint(String id) async {
    final sprint = sprintById(id);
    _mutatingSprintIds.add(id);
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteSprint(id);
      _sprintDetailsById.remove(id);
      if (sprint != null) {
        _sprintsByProjectId[sprint.projectId] =
            sprintsForProject(sprint.projectId)
                .where((item) => item.id != id)
                .toList();
        await loadProjectDetail(sprint.projectId, force: true);
      }
      return true;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return false;
    } finally {
      _mutatingSprintIds.remove(id);
      notifyListeners();
    }
  }

  Future<CoquiSprint?> startSprint(String id) =>
      _transitionSprint(id, (sprintId) => _apiService.startSprint(sprintId));

  Future<CoquiSprint?> submitSprintReview(String id) => _transitionSprint(
        id,
        (sprintId) => _apiService.submitSprintReview(sprintId),
      );

  Future<CoquiSprint?> completeSprint(String id) => _transitionSprint(
        id,
        (sprintId) => _apiService.completeSprint(sprintId),
      );

  Future<CoquiSprint?> rejectSprint(
    String id, {
    String? reviewerNotes,
  }) =>
      _transitionSprint(
        id,
        (sprintId) => _apiService.rejectSprint(
          sprintId,
          reviewerNotes: reviewerNotes,
        ),
      );

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<CoquiSprint?> _transitionSprint(
    String id,
    Future<CoquiSprint> Function(String id) action,
  ) async {
    _mutatingSprintIds.add(id);
    _error = null;
    notifyListeners();

    try {
      final sprint = await action(id);
      _cacheSprint(sprint);
      await fetchProjectSprints(sprint.projectId, force: true);
      await loadProjectDetail(sprint.projectId, force: true);
      return sprint;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingSprintIds.remove(id);
      notifyListeners();
    }
  }

  void _cacheProject(CoquiProject project, {bool prepend = false}) {
    _detailsById[project.id] = project;
    _detailsById[project.slug] = project;

    final index = _projects.indexWhere((item) => item.id == project.id);
    if (index >= 0) {
      _projects[index] = project;
    } else if (prepend) {
      _projects = [project, ..._projects];
    } else {
      _projects = [..._projects, project];
    }
  }

  void _cacheSprint(CoquiSprint sprint) {
    _sprintDetailsById[sprint.id] = sprint;
    final items = <CoquiSprint>[
      ...(_sprintsByProjectId[sprint.projectId] ?? const <CoquiSprint>[]),
    ];
    final index = items.indexWhere((item) => item.id == sprint.id);
    if (index >= 0) {
      items[index] = sprint;
    } else {
      items.insert(0, sprint);
    }
    _sprintsByProjectId[sprint.projectId] = items;
  }
}
