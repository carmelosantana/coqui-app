import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_task.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';

/// State management for background tasks.
///
/// Polls the server periodically when active tasks exist.
class TaskProvider extends ChangeNotifier {
  final CoquiApiService _apiService;

  List<CoquiTask> _tasks = [];
  bool _isLoading = false;
  String? _error;
  bool _isCreating = false;
  Timer? _pollTimer;

  TaskProvider({required CoquiApiService apiService})
      : _apiService = apiService;

  List<CoquiTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isCreating => _isCreating;

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
      _startOrStopPolling();
    } catch (e) {
      _error = CoquiException.friendly(e).message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Silently refresh without showing the loading spinner (used by poll timer).
  Future<void> _silentRefresh() async {
    try {
      _tasks = await _apiService.listTasks();
      _startOrStopPolling();
      notifyListeners();
    } catch (_) {
      // Ignore poll errors — next tick will retry
    }
  }

  /// Create a new background task.
  Future<CoquiTask?> createTask({
    required String prompt,
    String role = 'orchestrator',
    String? title,
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
        maxIterations: maxIterations,
      );
      // Prepend so the newest task appears first
      _tasks = [task, ..._tasks];
      _startOrStopPolling();
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
      // Refresh to get server truth shortly after
      await Future.delayed(const Duration(milliseconds: 500));
      await _silentRefresh();
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
      _tasks = _tasks.map((t) => t.id == id ? updated : t).toList();
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

  // ── Polling ──────────────────────────────────────────────────────────

  void _startOrStopPolling() {
    if (hasActiveTasks) {
      _ensurePolling();
    } else {
      _stopPolling();
    }
  }

  void _ensurePolling() {
    if (_pollTimer != null && _pollTimer!.isActive) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _silentRefresh();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
