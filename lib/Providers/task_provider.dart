import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_task.dart';
import 'package:coqui_app/Models/coqui_task_event.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

/// State management for background tasks.
///
/// Streams task events for active tasks and falls back to manual refresh.
class TaskProvider extends ChangeNotifier {
  final CoquiApiService _apiService;

  List<CoquiTask> _tasks = [];
  final Map<String, List<CoquiTaskEvent>> _taskEvents = {};
  final Map<String, StreamSubscription<CoquiTaskEvent>> _taskStreams = {};
  final Map<String, int> _lastTaskEventIds = {};
  bool _isLoading = false;
  String? _error;
  bool _isCreating = false;

  TaskProvider({required CoquiApiService apiService})
      : _apiService = apiService;

  List<CoquiTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isCreating => _isCreating;
    List<CoquiTaskEvent> eventsForTask(String taskId) =>
      List.unmodifiable(_taskEvents[taskId] ?? const []);

  List<CoquiTask> get activeTasks =>
      _tasks.where((t) => t.isActive).toList();

  bool get hasActiveTasks => _tasks.any((t) => t.isActive);

  /// Fetch task list. Starts polling if any tasks are active.
  Future<void> fetchTasks({String? statusFilter}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tasks = await _apiService.listTasks(status: statusFilter);
      _reconcileTaskStreams();
    } catch (e) {
      _error = CoquiException.friendly(e).message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new background task.
  Future<CoquiTask?> createTask({
    required String prompt,
    String role = 'orchestrator',
    String? title,
    String? profile,
    int maxIterations = 25,
  }) async {
    _isCreating = true;
    _error = null;
    notifyListeners();

    try {
      final task = await _apiService.createTask(
        prompt: prompt,
        role: role,
        title: title,
        profile: profile,
        maxIterations: maxIterations,
      );
      // Prepend so the newest task appears first
      _tasks = [task, ..._tasks];
      _startTaskStream(task.id);
      notifyListeners();
      return task;
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      notifyListeners();
      return null;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  /// Cancel a task and refresh the task in the list.
  Future<void> cancelTask(String id) async {
    try {
      await _apiService.cancelTask(id);
      // Optimistically update status
      _tasks = _tasks.map((t) {
        if (t.id == id) return t.copyWith(status: 'cancelling');
        return t;
      }).toList();
      notifyListeners();
      unawaited(refreshTask(id));
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      notifyListeners();
    }
  }

  /// Send follow-up input to a running task.
  Future<void> injectInput(String id, String content) async {
    try {
      await _apiService.injectTaskInput(id, content);
    } catch (e) {
      _error = CoquiException.friendly(e).message;
      notifyListeners();
    }
  }

  /// Reload a single task from the server (used by detail view).
  Future<CoquiTask?> refreshTask(String id) async {
    try {
      final updated = await _apiService.getTask(id);
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index >= 0) {
        _tasks[index] = updated;
      } else {
        _tasks = [updated, ..._tasks];
      }
      if (updated.isActive) {
        _startTaskStream(id);
      } else {
        _stopTaskStream(id);
      }
      notifyListeners();
      return updated;
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> watchTask(String id) async {
    if ((_taskEvents[id]?.isNotEmpty ?? false) || _taskStreams.containsKey(id)) {
      return;
    }
    _startTaskStream(id);
  }

  // ── Streaming ────────────────────────────────────────────────────────

  void _reconcileTaskStreams() {
    final activeIds = activeTasks.map((task) => task.id).toSet();

    for (final taskId in activeIds) {
      _startTaskStream(taskId);
    }

    for (final taskId in _taskStreams.keys.toList()) {
      if (!activeIds.contains(taskId)) {
        _stopTaskStream(taskId);
      }
    }
  }

  void _startTaskStream(String taskId) {
    if (_taskStreams.containsKey(taskId)) return;

    final sinceId = _lastTaskEventIds[taskId];
    final stream = _apiService.streamTaskEvents(taskId, sinceId: sinceId);

    _taskStreams[taskId] = stream.listen(
      (event) {
        if (event.id != null) {
          _lastTaskEventIds[taskId] = event.id!;
        }

        if (!event.isConnected && !event.isDone) {
          final events = _taskEvents.putIfAbsent(taskId, () => []);
          final alreadySeen = event.id != null &&
              events.any((existing) => existing.id == event.id);
          if (!alreadySeen) {
            events.add(event);
          }
        }

        _applyTaskEvent(taskId, event);
      },
      onError: (_) {
        _taskStreams.remove(taskId);
      },
      onDone: () {
        _taskStreams.remove(taskId);
      },
      cancelOnError: false,
    );
  }

  void _applyTaskEvent(String taskId, CoquiTaskEvent event) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) {
      if (event.isTerminal || event.isDone) {
        unawaited(refreshTask(taskId));
      }
      return;
    }

    final current = _tasks[index];
    CoquiTask updated = current;

    switch (event.type) {
      case 'agent_start':
      case 'tool_start':
        updated = current.copyWith(status: 'running');
      case 'completed':
        updated = current.copyWith(
          status: 'completed',
          result: event.data['content'] as String? ?? current.result,
          completedAt: DateTime.now(),
        );
      case 'failed':
      case 'tool_error':
        updated = current.copyWith(
          status: 'failed',
          error: event.data['error'] as String? ??
              event.data['message'] as String? ??
              current.error,
          completedAt: DateTime.now(),
        );
      case 'cancel_requested':
        updated = current.copyWith(status: 'cancelling');
      case 'cancelled':
        updated = current.copyWith(
          status: 'cancelled',
          result: event.data['content'] as String? ?? current.result,
          error: event.data['message'] as String? ?? current.error,
          completedAt: DateTime.now(),
        );
      default:
        break;
    }

    _tasks[index] = updated;

    if (event.isTerminal || event.isDone) {
      _stopTaskStream(taskId);
      unawaited(refreshTask(taskId));
    }

    notifyListeners();
  }

  void _stopTaskStream(String taskId) {
    final subscription = _taskStreams.remove(taskId);
    subscription?.cancel();
  }

  @override
  void dispose() {
    for (final taskId in _taskStreams.keys.toList()) {
      _stopTaskStream(taskId);
    }
    super.dispose();
  }
}
