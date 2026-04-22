import 'package:flutter/foundation.dart';

import 'package:coqui_app/Models/coqui_artifact.dart';
import 'package:coqui_app/Models/coqui_artifact_version.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_todo.dart';
import 'package:coqui_app/Models/coqui_todo_stats.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

class WorkProvider extends ChangeNotifier {
  final CoquiApiService _apiService;

  final Map<String, List<CoquiTodo>> _todosBySessionId = {};
  final Map<String, CoquiTodoStats> _todoStatsBySessionId = {};
  final Map<String, List<CoquiArtifact>> _artifactsBySessionId = {};
  final Map<String, Map<String, CoquiArtifact>> _artifactDetailsBySessionId =
      {};
  final Map<String, List<CoquiArtifactVersion>> _artifactVersionsByArtifactId =
      {};
  final Set<String> _loadingTodoSessionIds = {};
  final Set<String> _loadingArtifactSessionIds = {};
  final Set<String> _loadingArtifactIds = {};
  final Set<String> _loadingArtifactVersionIds = {};
  final Set<String> _mutatingTodoIds = {};
  final Set<String> _mutatingArtifactIds = {};

  String? _error;

  WorkProvider({required CoquiApiService apiService})
      : _apiService = apiService;

  String? get error => _error;

  List<CoquiTodo> todosForSession(String sessionId) =>
      List.unmodifiable(_todosBySessionId[sessionId] ?? const []);

  CoquiTodoStats todoStatsForSession(String sessionId) =>
      _todoStatsBySessionId[sessionId] ?? const CoquiTodoStats.empty();

  List<CoquiArtifact> artifactsForSession(String sessionId) =>
      List.unmodifiable(_artifactsBySessionId[sessionId] ?? const []);

  CoquiArtifact? artifactById(String sessionId, String artifactId) {
    return _artifactDetailsBySessionId[sessionId]?[artifactId] ??
        _artifactsBySessionId[sessionId]
            ?.cast<CoquiArtifact?>()
            .firstWhere((item) => item?.id == artifactId, orElse: () => null);
  }

  List<CoquiArtifactVersion> versionsForArtifact(String artifactId) =>
      List.unmodifiable(_artifactVersionsByArtifactId[artifactId] ?? const []);

  bool isTodoSessionLoading(String sessionId) =>
      _loadingTodoSessionIds.contains(sessionId);

  bool isArtifactSessionLoading(String sessionId) =>
      _loadingArtifactSessionIds.contains(sessionId);

  bool isArtifactLoading(String artifactId) =>
      _loadingArtifactIds.contains(artifactId);

  bool isArtifactVersionsLoading(String artifactId) =>
      _loadingArtifactVersionIds.contains(artifactId);

  bool isTodoMutating(String todoId) => _mutatingTodoIds.contains(todoId);

  bool isArtifactMutating(String artifactId) =>
      _mutatingArtifactIds.contains(artifactId);

  Future<void> fetchTodos(String sessionId, {bool force = false}) async {
    if (!force && _todosBySessionId.containsKey(sessionId)) {
      return;
    }
    if (_loadingTodoSessionIds.contains(sessionId)) {
      return;
    }

    _loadingTodoSessionIds.add(sessionId);
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.listTodos(sessionId);
      _todosBySessionId[sessionId] = result.todos;
      _todoStatsBySessionId[sessionId] = result.stats;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
    } finally {
      _loadingTodoSessionIds.remove(sessionId);
      notifyListeners();
    }
  }

  Future<void> fetchArtifacts(String sessionId, {bool force = false}) async {
    if (!force && _artifactsBySessionId.containsKey(sessionId)) {
      return;
    }
    if (_loadingArtifactSessionIds.contains(sessionId)) {
      return;
    }

    _loadingArtifactSessionIds.add(sessionId);
    _error = null;
    notifyListeners();

    try {
      final artifacts = await _apiService.listArtifacts(sessionId);
      _artifactsBySessionId[sessionId] = artifacts;
      _artifactDetailsBySessionId[sessionId] = {
        for (final artifact in artifacts) artifact.id: artifact,
      };
    } catch (e) {
      _error = CoquiException.friendly(e).message;
    } finally {
      _loadingArtifactSessionIds.remove(sessionId);
      notifyListeners();
    }
  }

  Future<CoquiArtifact?> loadArtifactDetail(
    String sessionId,
    String artifactId, {
    bool force = false,
  }) async {
    if (!force) {
      final cached = artifactById(sessionId, artifactId);
      if (cached != null) {
        return cached;
      }
    }
    if (_loadingArtifactIds.contains(artifactId)) {
      return artifactById(sessionId, artifactId);
    }

    _loadingArtifactIds.add(artifactId);
    _error = null;
    notifyListeners();

    try {
      final artifact = await _apiService.getArtifact(sessionId, artifactId);
      _cacheArtifact(sessionId, artifact);
      return artifact;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _loadingArtifactIds.remove(artifactId);
      notifyListeners();
    }
  }

  Future<List<CoquiArtifactVersion>> fetchArtifactVersions(
    String sessionId,
    String artifactId, {
    bool force = false,
  }) async {
    if (!force && _artifactVersionsByArtifactId.containsKey(artifactId)) {
      return versionsForArtifact(artifactId);
    }
    if (_loadingArtifactVersionIds.contains(artifactId)) {
      return versionsForArtifact(artifactId);
    }

    _loadingArtifactVersionIds.add(artifactId);
    _error = null;
    notifyListeners();

    try {
      final versions =
          await _apiService.listArtifactVersions(sessionId, artifactId);
      _artifactVersionsByArtifactId[artifactId] = versions;
      return versions;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return versionsForArtifact(artifactId);
    } finally {
      _loadingArtifactVersionIds.remove(artifactId);
      notifyListeners();
    }
  }

  Future<CoquiTodo?> createTodo(
    String sessionId, {
    required String title,
    String priority = 'medium',
    String? notes,
    String? artifactId,
    String? parentId,
    String? sprintId,
    String? createdBy,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final todo = await _apiService.createTodo(
        sessionId,
        title: title,
        priority: priority,
        notes: notes,
        artifactId: artifactId,
        parentId: parentId,
        sprintId: sprintId,
        createdBy: createdBy,
      );
      await fetchTodos(sessionId, force: true);
      return todo;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      notifyListeners();
      return null;
    }
  }

  Future<CoquiTodo?> updateTodo(
    String sessionId,
    String todoId, {
    String? title,
    String? priority,
    String? notes,
    String? status,
    String? artifactId,
    String? parentId,
    String? sprintId,
    int? sortOrder,
    bool clearArtifact = false,
    bool clearParent = false,
    bool clearSprint = false,
  }) async {
    _mutatingTodoIds.add(todoId);
    _error = null;
    notifyListeners();

    try {
      final todo = await _apiService.updateTodo(
        sessionId,
        todoId,
        title: title,
        priority: priority,
        notes: notes,
        status: status,
        artifactId: artifactId,
        parentId: parentId,
        sprintId: sprintId,
        sortOrder: sortOrder,
        clearArtifact: clearArtifact,
        clearParent: clearParent,
        clearSprint: clearSprint,
      );
      await fetchTodos(sessionId, force: true);
      return todo;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingTodoIds.remove(todoId);
      notifyListeners();
    }
  }

  Future<bool> deleteTodo(String sessionId, String todoId) async {
    _mutatingTodoIds.add(todoId);
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteTodo(sessionId, todoId);
      await fetchTodos(sessionId, force: true);
      return true;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return false;
    } finally {
      _mutatingTodoIds.remove(todoId);
      notifyListeners();
    }
  }

  Future<CoquiTodo?> completeTodo(
    String sessionId,
    String todoId, {
    String? notes,
    String? completedBy,
  }) {
    return _transitionTodo(
      sessionId,
      todoId,
      () => _apiService.completeTodo(
        sessionId,
        todoId,
        notes: notes,
        completedBy: completedBy,
      ),
    );
  }

  Future<CoquiTodo?> reopenTodo(
    String sessionId,
    String todoId, {
    String? notes,
  }) {
    return _transitionTodo(
      sessionId,
      todoId,
      () => _apiService.reopenTodo(sessionId, todoId, notes: notes),
    );
  }

  Future<CoquiTodo?> cancelTodo(
    String sessionId,
    String todoId, {
    String? notes,
  }) {
    return _transitionTodo(
      sessionId,
      todoId,
      () => _apiService.cancelTodo(sessionId, todoId, notes: notes),
    );
  }

  Future<CoquiArtifact?> createArtifact(
    String sessionId, {
    required String title,
    required String content,
    String type = 'code',
    String stage = 'draft',
    String? language,
    String? filepath,
    String? projectId,
    String? sprintId,
    bool persistent = false,
    Map<String, dynamic>? metadata,
    List<String>? tags,
    String? summary,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final artifact = await _apiService.createArtifact(
        sessionId,
        title: title,
        content: content,
        type: type,
        stage: stage,
        language: language,
        filepath: filepath,
        projectId: projectId,
        sprintId: sprintId,
        persistent: persistent,
        metadata: metadata,
        tags: tags,
        summary: summary,
      );
      _cacheArtifact(sessionId, artifact);
      await fetchArtifacts(sessionId, force: true);
      return artifact;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      notifyListeners();
      return null;
    }
  }

  Future<CoquiArtifact?> updateArtifact(
    String sessionId,
    String artifactId, {
    String? title,
    String? content,
    String? changeSummary,
    String? stage,
    String? language,
    String? projectId,
    String? sprintId,
    bool? persistent,
    Map<String, dynamic>? metadata,
    List<String>? tags,
    String? summary,
    bool clearLanguage = false,
    bool clearProject = false,
    bool clearSprint = false,
    bool clearSummary = false,
  }) async {
    _mutatingArtifactIds.add(artifactId);
    _error = null;
    notifyListeners();

    try {
      final artifact = await _apiService.updateArtifact(
        sessionId,
        artifactId,
        title: title,
        content: content,
        changeSummary: changeSummary,
        stage: stage,
        language: language,
        projectId: projectId,
        sprintId: sprintId,
        persistent: persistent,
        metadata: metadata,
        tags: tags,
        summary: summary,
        clearLanguage: clearLanguage,
        clearProject: clearProject,
        clearSprint: clearSprint,
        clearSummary: clearSummary,
      );
      _cacheArtifact(sessionId, artifact);
      await fetchArtifacts(sessionId, force: true);
      return artifact;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingArtifactIds.remove(artifactId);
      notifyListeners();
    }
  }

  Future<bool> deleteArtifact(String sessionId, String artifactId) async {
    _mutatingArtifactIds.add(artifactId);
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteArtifact(sessionId, artifactId);
      _artifactVersionsByArtifactId.remove(artifactId);
      _artifactDetailsBySessionId[sessionId]?.remove(artifactId);
      await fetchArtifacts(sessionId, force: true);
      return true;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return false;
    } finally {
      _mutatingArtifactIds.remove(artifactId);
      notifyListeners();
    }
  }

  Future<CoquiArtifact?> createArtifactVersion(
    String sessionId,
    String artifactId, {
    required String content,
    String? changeSummary,
    String? title,
    String? stage,
  }) async {
    _mutatingArtifactIds.add(artifactId);
    _error = null;
    notifyListeners();

    try {
      final artifact = await _apiService.createArtifactVersion(
        sessionId,
        artifactId,
        content: content,
        changeSummary: changeSummary,
        title: title,
        stage: stage,
      );
      _cacheArtifact(sessionId, artifact);
      await fetchArtifactVersions(sessionId, artifactId, force: true);
      await fetchArtifacts(sessionId, force: true);
      return artifact;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingArtifactIds.remove(artifactId);
      notifyListeners();
    }
  }

  Future<CoquiArtifact?> restoreArtifactVersion(
    String sessionId,
    String artifactId,
    String versionId,
  ) async {
    _mutatingArtifactIds.add(artifactId);
    _error = null;
    notifyListeners();

    try {
      final artifact = await _apiService.restoreArtifactVersion(
        sessionId,
        artifactId,
        versionId,
      );
      _cacheArtifact(sessionId, artifact);
      await fetchArtifactVersions(sessionId, artifactId, force: true);
      await fetchArtifacts(sessionId, force: true);
      return artifact;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingArtifactIds.remove(artifactId);
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<CoquiTodo?> _transitionTodo(
    String sessionId,
    String todoId,
    Future<CoquiTodo> Function() action,
  ) async {
    _mutatingTodoIds.add(todoId);
    _error = null;
    notifyListeners();

    try {
      final todo = await action();
      await fetchTodos(sessionId, force: true);
      return todo;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      return null;
    } finally {
      _mutatingTodoIds.remove(todoId);
      notifyListeners();
    }
  }

  void _cacheArtifact(String sessionId, CoquiArtifact artifact) {
    _artifactDetailsBySessionId.putIfAbsent(sessionId, () => {})[artifact.id] =
        artifact;

    final items = [
      ...(_artifactsBySessionId[sessionId] ?? const <CoquiArtifact>[]),
    ];
    final index = items.indexWhere((item) => item.id == artifact.id);
    if (index >= 0) {
      items[index] = artifact;
    } else {
      items.insert(0, artifact);
    }
    _artifactsBySessionId[sessionId] = items;
  }
}
