import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:coqui_app/Models/agent_activity_event.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Models/coqui_turn.dart';
import 'package:coqui_app/Models/sse_event.dart';
import 'package:coqui_app/Models/uploaded_file.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
import 'package:coqui_app/Services/analytics_service.dart';
import 'package:coqui_app/Services/coqui_api_service.dart';
import 'package:coqui_app/Services/database_service.dart';

/// Central state manager for chat interactions with the Coqui API.
///
/// Manages sessions, messages, SSE streaming, and real-time agent activity.
class ChatProvider extends ChangeNotifier {
  final CoquiApiService _apiService;
  final DatabaseService _databaseService;

  // ── Session state ───────────────────────────────────────────────────

  List<CoquiSession> _sessions = [];
  List<CoquiSession> get sessions =>
      _sessions.where((session) => !session.isArchived).toList();

  List<CoquiSession> get archivedSessions =>
      _sessions.where((session) => session.isArchived).toList();

  List<CoquiSession> get _navigableSessions => [
        ...sessions,
        ...archivedSessions,
      ];

  int _currentSessionIndex = -1;
  int get selectedDestination {
    final session = currentSession;
    if (session == null) return 0;

    final visibleIndex = _navigableSessions
        .indexWhere((candidate) => candidate.id == session.id);
    return visibleIndex == -1 ? 0 : visibleIndex + 1;
  }

  CoquiSession? get currentSession =>
      _currentSessionIndex < 0 || _currentSessionIndex >= _sessions.length
          ? null
          : _sessions[_currentSessionIndex];

  bool get isCurrentSessionReadOnly => currentSession?.isReadOnly ?? false;

  final Map<String, String?> _sessionProjectLabels = {};

  String? get currentSessionProjectLabel =>
      currentSession == null ? null : _sessionProjectLabels[currentSession!.id];

  String? projectLabelForSession(String sessionId) =>
      _sessionProjectLabels[sessionId];

  // ── Message state ───────────────────────────────────────────────────

  List<CoquiMessage> _messages = [];
  List<CoquiMessage> get messages => _messages;

  /// Displayable messages (excludes tool messages). Cached to avoid
  /// recomputing on every widget build.
  List<CoquiMessage> _displayMessages = [];
  List<CoquiMessage> get displayMessages => _displayMessages;

  /// Rebuild the cached [displayMessages] list. Must be called after every
  /// mutation of [_messages].
  void _updateDisplayMessages() {
    _displayMessages = _messages.where((m) => m.isDisplayable).toList();
  }

  // ── Streaming state ────────────────────────────────────────────────

  final Set<String> _activeStreams = {};

  bool get isCurrentSessionStreaming =>
      _activeStreams.contains(currentSession?.id);

  bool get isCurrentSessionThinking =>
      currentSession != null &&
      _activeStreams.contains(currentSession?.id) &&
      _streamingContent[currentSession?.id] == null;

  /// Content being accumulated from SSE 'done' event.
  final Map<String, String> _streamingContent = {};

  /// Whether a stream was cancelled by the user.
  final Set<String> _cancelledStreams = {};

  // ── Agent activity state (per-session) ────────────────────────────

  final Map<String, List<AgentActivityEvent>> _sessionActivity = {};
  final Map<String, int> _sessionIteration = {};
  final Map<String, String?> _sessionSummary = {};
  final Map<String, CoquiTurn?> _sessionLastTurn = {};
  final Map<String, String?> _sessionTurnProcessIds = {};

  List<AgentActivityEvent> get currentTurnActivity =>
      _sessionActivity[currentSession?.id] ?? const [];

  int get currentIteration => _sessionIteration[currentSession?.id] ?? 0;

  /// Summary from the last completed turn.
  String? get lastTurnSummary => _sessionSummary[currentSession?.id];

  /// Full typed turn payload from the most recent completed turn.
  CoquiTurn? get lastCompletedTurn => _sessionLastTurn[currentSession?.id];

  // ── Error state ────────────────────────────────────────────────────

  final Map<String, CoquiException> _sessionErrors = {};

  CoquiException? get currentSessionError => _sessionErrors[currentSession?.id];

  // ── File attachment state ──────────────────────────────────────────

  final List<UploadedFile> _pendingFiles = [];

  /// Files selected by the user that are pending or ready to attach to the
  /// next prompt. Each file transitions from [UploadedFileStatus.uploading]
  /// to [UploadedFileStatus.uploaded] (or [UploadedFileStatus.error]) once
  /// the server upload completes.
  List<UploadedFile> get pendingFiles => List.unmodifiable(_pendingFiles);

  // ── Constructor ────────────────────────────────────────────────────

  ChatProvider({
    required CoquiApiService apiService,
    required DatabaseService databaseService,
  })  : _apiService = apiService,
        _databaseService = databaseService {
    _initialize();
  }

  Future<void> _initialize() async {
    await _databaseService.open('coqui_app.db');
    // Load cached sessions
    _sessions = await _databaseService.getSessions();
    notifyListeners();
  }

  // ── Navigation ────────────────────────────────────────────────────

  void destinationSelected(int destination) {
    if (destination == 0) {
      _resetChat();
      return;
    }

    final visibleIndex = destination - 1;
    if (visibleIndex < 0 || visibleIndex >= _navigableSessions.length) {
      _resetChat();
      return;
    }

    final sessionId = _navigableSessions[visibleIndex].id;
    openSession(sessionId);
  }

  void openSession(String sessionId) {
    _currentSessionIndex =
        _sessions.indexWhere((session) => session.id == sessionId);
    if (_currentSessionIndex == -1) {
      _resetChat();
      return;
    }

    // Clear previous session data immediately to prevent ghosting/stacking
    // while the new session loads.
    _messages = [];
    _updateDisplayMessages();
    _pendingFiles.clear();

    _loadCurrentSession();
    notifyListeners();
  }

  void _resetChat() {
    _currentSessionIndex = -1;
    _messages.clear();
    _updateDisplayMessages();
    _pendingFiles.clear();
    notifyListeners();
  }

  // ── Session management ────────────────────────────────────────────

  /// Load sessions from the server and sync to local cache.
  Future<void> refreshSessions() async {
    try {
      final selectedSessionId = currentSession?.id;
      final serverSessions =
          await _apiService.listSessions(limit: 100, status: 'all');

      // Prefer server-provided titles; fall back to cached title for
      // older sessions created before server-side title generation.
      for (final session in serverSessions) {
        if (session.title == null || session.title!.isEmpty) {
          final cached = await _databaseService.getSession(session.id);
          if (cached?.title != null) {
            session.title = cached!.title;
          }
        }
      }

      _sessions = serverSessions;
      _retainProjectLabelsForCurrentSessions();

      if (selectedSessionId != null) {
        _currentSessionIndex = _sessions.indexWhere(
          (session) => session.id == selectedSessionId,
        );
      }

      // Cache all sessions
      for (final session in serverSessions) {
        await _databaseService.upsertSession(session);
      }

      for (final session in serverSessions) {
        if (session.activeProjectId?.isNotEmpty == true) {
          unawaited(_refreshProjectLabelForSession(session));
        }
      }

      notifyListeners();
    } on CoquiException catch (e) {
      _sessionErrors['global'] = e;
      notifyListeners();
    } catch (_) {
      // Fall back to cached sessions
    }
  }

  /// Create a new session with the given role.
  Future<void> createNewSession(
    CoquiRole role, {
    String? profile,
    bool confirmCloseActiveProfileSession = false,
  }) async {
    final session = await _apiService.createSession(
      modelRole: role.name,
      profile: profile,
      confirmCloseActiveProfileSession: confirmCloseActiveProfileSession,
    );

    _sessions.insert(0, session);
    _currentSessionIndex = 0;

    await _databaseService.upsertSession(session);

    _messages.clear();
    _updateDisplayMessages();

    unawaited(_refreshProjectLabelForSession(session));

    AnalyticsService.trackEvent('session_created', {
      'role': role.name,
      if (profile != null && profile.isNotEmpty) 'profile': profile,
      if (confirmCloseActiveProfileSession) 'replaced_existing_profile': true,
    });

    notifyListeners();
  }

  /// Resolve or create the latest interactive session for the given scope.
  Future<void> resolveSessionScope(CoquiRole role, {String? profile}) async {
    final resolved = await _apiService.resolveSession(
      modelRole: role.name,
      profile: profile,
    );

    final session = resolved.session;
    _upsertSessionAtTop(session);
    _currentSessionIndex = 0;

    await _databaseService.upsertSession(session);

    _messages.clear();
    _updateDisplayMessages();
    unawaited(_refreshProjectLabelForSession(session));
    notifyListeners();

    await _loadCurrentSession();

    AnalyticsService.trackEvent('session_resolved', {
      'role': role.name,
      'created': resolved.created,
      if (profile != null && profile.isNotEmpty) 'profile': profile,
    });
  }

  /// Delete the current session.
  Future<void> deleteCurrentSession() async {
    final session = currentSession;
    if (session == null) return;

    final sessionId = session.id;
    _resetChat();
    _sessions.remove(session);
    _sessionProjectLabels.remove(sessionId);

    // Clean up per-session activity state
    _sessionActivity.remove(sessionId);
    _sessionIteration.remove(sessionId);
    _sessionSummary.remove(sessionId);
    _sessionLastTurn.remove(sessionId);
    _sessionTurnProcessIds.remove(sessionId);

    try {
      await _apiService.deleteSession(sessionId);
    } catch (_) {
      // Session may already be deleted server-side
    }

    await _databaseService.deleteSession(sessionId);
  }

  // ── Message loading ───────────────────────────────────────────────

  Future<void> _loadCurrentSession() async {
    final session = currentSession;
    if (session == null) return;

    unawaited(_refreshProjectLabelForSession(session));

    // Clear unread indicator
    _markSessionAsRead(session.id);
    // Clear any sticky error badge once user opens the session
    _sessionErrors.remove(session.id);

    // Load from cache FIRST for instant navigation
    _messages = await _databaseService.getMessages(session.id);
    _updateDisplayMessages();
    notifyListeners();

    final sessionIsStreaming = _activeStreams.contains(session.id);

    // Skip server sync while the session is actively streaming —
    // the stream handler manages _messages in real time.
    if (!sessionIsStreaming) {
      try {
        // Then sync with server in background
        final serverMessages = await _apiService.listMessages(session.id);

        // Only update if still on the same session
        if (currentSession?.id == session.id) {
          _messages = serverMessages;
          _updateDisplayMessages();

          // Cache locally
          await _databaseService.deleteMessages(session.id);
          await _databaseService.upsertMessages(
            serverMessages,
            sessionId: session.id,
          );
        }
      } catch (_) {
        // Already showed cached messages, so just fail silently
      }
    }

    _pendingFiles.clear();

    // Do not forcibly unfocus the input; preserve user typing across loads
    notifyListeners();
  }

  // ── Unread state ──────────────────────────────────────────────────

  final Set<String> _unreadSessions = {};

  bool hasUnreadMessages(String sessionId) =>
      _unreadSessions.contains(sessionId);

  void _markSessionAsRead(String sessionId) {
    if (_unreadSessions.contains(sessionId)) {
      _unreadSessions.remove(sessionId);
      notifyListeners();
    }
  }

  // Expose per-session streaming/thinking/error state for UI badges
  bool isSessionStreaming(String sessionId) =>
      _activeStreams.contains(sessionId);

  bool isSessionThinking(String sessionId) =>
      _activeStreams.contains(sessionId) &&
      _streamingContent[sessionId] == null;

  bool hasSessionError(String sessionId) =>
      _sessionErrors.containsKey(sessionId);

  // ── Prompt submission ─────────────────────────────────────────────

  /// Maximum prompt size in bytes (matches server's MAX_PROMPT_BYTES).
  static const int _maxPromptBytes = 102400; // 100 KB

  Future<void> sendPrompt(String text) async {
    final session = currentSession;
    if (session == null) return;

    if (session.isReadOnly) {
      _sessionErrors[session.id] = CoquiException(
        session.isArchived
            ? 'This conversation is archived and cannot be modified.'
            : 'This conversation is closed and cannot be modified.',
        code: 'session_closed',
        statusCode: 409,
        details: {
          'session_id': session.id,
          'status': session.status,
          'closure_reason': session.closureReason,
        },
      );
      notifyListeners();
      return;
    }

    AnalyticsService.trackEvent('message_sent');

    // Clear unread status for the active session
    _markSessionAsRead(session.id);

    // Client-side prompt length guard
    if (utf8.encode(text).length > _maxPromptBytes) {
      _sessionErrors[session.id] = CoquiException(
        'Message is too long. Maximum size is 100 KB.',
        code: 'payload_too_large',
        statusCode: 413,
      );
      notifyListeners();
      return;
    }

    // Collect IDs and names of successfully uploaded files, then clear the
    // pending list before starting the stream so the UI resets immediately.
    final uploadedFiles = _pendingFiles
        .where((f) =>
            f.status == UploadedFileStatus.uploaded && f.serverId != null)
        .toList();
    final fileIds = uploadedFiles.map((f) => f.serverId!).toList();
    final fileNames = uploadedFiles.map((f) => f.name).toList();
    _pendingFiles.clear();

    // Add optimistic user message, carrying the file names so the bubble
    // can render chips even after server messages replace this instance.
    final userMessage = CoquiMessage(
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      content: text,
      role: CoquiMessageRole.user,
      attachedFileNames: fileNames,
    );
    _messages.add(userMessage);
    _updateDisplayMessages();
    notifyListeners();

    // Cache the optimistic message immediately so it persists when switching sessions
    await _databaseService.upsertMessage(userMessage, sessionId: session.id);

    // Set a provisional title from the first user message while the server
    // generates a proper one via LLM. Overwritten when a 'title' SSE event arrives.
    if ((session.title == null || session.title!.isEmpty) &&
        _messages.where((m) => m.role == CoquiMessageRole.user).length <= 1) {
      final trimmed = text.trim();
      final provisional = trimmed.length > 50
          ? '${trimmed.substring(0, 47).trimRight()}…'
          : trimmed;
      session.title = provisional;
      await _databaseService.updateSessionTitle(session.id, provisional);
      notifyListeners();
    }

    // Start streaming
    await _initializeStream(session, text, fileIds, fileNames);
  }

  Future<void> _initializeStream(
    CoquiSession session,
    String prompt,
    List<String> fileIds,
    List<String> fileNames,
  ) async {
    // Cancel any existing stream for this session
    _cancelStream(session.id);

    // Clear the cancel flag so the NEW stream is not poisoned by the
    // cancellation of the previous one.
    _cancelledStreams.remove(session.id);

    // Clear errors
    _sessionErrors.remove(session.id);

    // Move session to top
    _moveCurrentSessionToTop();

    // Set thinking state
    _activeStreams.add(session.id);
    _sessionActivity[session.id] = [];
    _sessionIteration[session.id] = 0;
    _sessionSummary[session.id] = null;
    _sessionLastTurn[session.id] = null;
    _sessionTurnProcessIds[session.id] = null;
    notifyListeners();

    try {
      await _processStream(session, prompt, fileIds, fileNames);
    } on CoquiException catch (e) {
      _sessionErrors[session.id] = e;
    } catch (e) {
      _sessionErrors[session.id] = CoquiException.friendly(e);
    } finally {
      _activeStreams.remove(session.id);
      _streamingContent.remove(session.id);
      _cancelledStreams.remove(session.id);
      notifyListeners();
    }
  }

  Future<void> _processStream(
    CoquiSession session,
    String prompt,
    List<String> fileIds,
    List<String> fileNames,
  ) async {
    final stream = _apiService.sendPrompt(session.id, prompt, fileIds: fileIds);

    String accumulatedContent = '';
    CoquiMessage? assistantMessage;
    bool gotContent = false;

    // Throttle notifyListeners during rapid text_delta events to avoid
    // excessive widget rebuilds. Accumulate deltas and flush at ~50ms.
    bool hasPendingNotify = false;
    Timer? throttleTimer;

    void scheduleNotify() {
      if (hasPendingNotify) return;
      hasPendingNotify = true;
      throttleTimer?.cancel();
      throttleTimer = Timer(const Duration(milliseconds: 50), () {
        hasPendingNotify = false;
        notifyListeners();
      });
    }

    /// Helper to add an activity event (handles nullable return from fromSseEvent).
    void addActivity(SseEvent event) {
      final activity = AgentActivityEvent.fromSseEvent(event);
      if (activity != null) {
        _sessionActivity.putIfAbsent(session.id, () => []).add(activity);
      }
    }

    /// Helper to create or update the streaming assistant message.
    void upsertStreamingMessage() {
      if (assistantMessage == null) {
        assistantMessage = CoquiMessage(
          id: 'stream_${DateTime.now().millisecondsSinceEpoch}',
          content: accumulatedContent,
          role: CoquiMessageRole.assistant,
        );
        _messages.add(assistantMessage!);
      } else {
        final index = _messages.indexOf(assistantMessage!);
        final updated = CoquiMessage(
          id: assistantMessage!.id,
          content: accumulatedContent,
          role: CoquiMessageRole.assistant,
          createdAt: assistantMessage!.createdAt,
        );
        if (index >= 0) {
          _messages[index] = updated;
        } else {
          // The _messages list was replaced (e.g. user navigated away and
          // back). Re-add the streaming message so it stays visible.
          _messages.add(updated);
        }
        assistantMessage = updated;
      }
      _updateDisplayMessages();
    }

    try {
      await for (final event in stream) {
        // Check if stream was cancelled
        if (_cancelledStreams.contains(session.id)) {
          break;
        }

        final isViewing = currentSession?.id == session.id;
        bool stateChanged = false;

        switch (event.type) {
          case SseEventType.agentStart:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.iteration:
            _sessionIteration[session.id] = event.iterationNumber;
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.toolCall:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.toolResult:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.childStart:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.childEnd:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.batchStart:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.batchEnd:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.reviewStart:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.reviewEnd:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.textDelta:
            // Incremental text streaming — append delta to the running content
            // and update the assistant message bubble in real time.
            final delta = event.textDeltaContent;
            if (delta.isNotEmpty) {
              accumulatedContent += delta;
              _streamingContent[session.id] = accumulatedContent;
              gotContent = true;

              if (isViewing) {
                upsertStreamingMessage();
                // Use throttled notify to avoid excessive rebuilds
                scheduleNotify();
              }
            }
            // Don't set stateChanged — throttled notify handles it
            break;

          case SseEventType.reasoning:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.done:
            // Final authoritative content from the server — replace whatever
            // was accumulated from text deltas.
            accumulatedContent = event.content;
            _streamingContent[session.id] = accumulatedContent;
            gotContent = accumulatedContent.trim().isNotEmpty;

            if (isViewing) {
              upsertStreamingMessage();
              stateChanged = true;
            } else {
              // Mark as unread if we're not viewing this session
              if (!_unreadSessions.contains(session.id)) {
                _unreadSessions.add(session.id);
                stateChanged = true;
              }
            }
            break;

          case SseEventType.error:
            if (isViewing) {
              addActivity(event);
            }
            _sessionErrors[session.id] = CoquiException(event.errorMessage);
            stateChanged = true;
            break;

          case SseEventType.complete:
            final iterations = event.data['iterations'] as int? ?? 0;
            final tools = event.toolsUsed;
            final childCount = event.data['child_agent_count'] as int? ?? 0;
            final tokens = event.totalTokens;
            final duration = event.durationMs;
            final completeContent =
                (event.data['content'] as String?) ?? accumulatedContent;
            final completeError = event.data['error'];
            final timestamp = DateTime.now().toIso8601String();
            final turn = CoquiTurn.fromJson({
              'id': '',
              'session_id': session.id,
              'turn_number': 0,
              'user_prompt': prompt,
              'response_text': completeContent,
              'content': completeContent,
              'model': session.model,
              'prompt_tokens': event.data['prompt_tokens'] as int? ?? 0,
              'completion_tokens': event.data['completion_tokens'] as int? ?? 0,
              'total_tokens': tokens,
              'iterations': iterations,
              'duration_ms': duration,
              'tools_used': tools,
              'child_agent_count': childCount,
              'turn_process_id': _sessionTurnProcessIds[session.id],
              'restart_requested':
                  event.data['restart_requested'] as bool? ?? false,
              'iteration_limit_reached':
                  event.data['iteration_limit_reached'] as bool? ?? false,
              'budget_exhausted':
                  event.data['budget_exhausted'] as bool? ?? false,
              'context_usage': event.data['context_usage'],
              'file_edits': event.data['file_edits'],
              'review_feedback': event.data['review_feedback'],
              'review_approved': event.data['review_approved'],
              'background_tasks': event.data['background_tasks'],
              'error': completeError,
              'created_at': timestamp,
              'completed_at': timestamp,
            });
            _sessionLastTurn[session.id] = turn;
            _sessionSummary[session.id] = turn.summary;
            if (isViewing) {
              stateChanged = true;
            } else {
              // For background sessions: mark as unread or error appropriately
              if (completeError != null) {
                _sessionErrors[session.id] = CoquiException(
                  completeError.toString(),
                );
                stateChanged = true;
              } else {
                final hasAnyContent =
                    gotContent || completeContent.trim().isNotEmpty;
                if (hasAnyContent) {
                  _unreadSessions.add(session.id);
                  stateChanged = true;
                } else {
                  // Stream ended without any content and no error reported — treat as error
                  _sessionErrors[session.id] =
                      CoquiException('No response received from server');
                  stateChanged = true;
                }
              }
            }
            break;

          case SseEventType.title:
            final title = event.titleText;
            if (title.isNotEmpty) {
              session.title = title;
              await _databaseService.updateSessionTitle(session.id, title);
            }
            break;

          case SseEventType.warning:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.budgetWarning:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.summary:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.memoryExtraction:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.notification:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.loopStart:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.loopIterationStart:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.loopStageStart:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.loopStageEnd:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.loopIterationEnd:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.loopComplete:
            addActivity(event);
            if (isViewing) stateChanged = true;
            break;

          case SseEventType.connected:
            _sessionTurnProcessIds[session.id] = event.turnProcessId;
            break;

          case SseEventType.unknown:
            break;
        }
        if (stateChanged) {
          notifyListeners();
        }
      }
    } finally {
      // Always clean up the throttle timer
      throttleTimer?.cancel();
      // Flush any pending throttled notify
      if (hasPendingNotify) {
        hasPendingNotify = false;
        notifyListeners();
      }
    }

    // Skip post-stream work if the user cancelled — server auto-cancels
    // the turn process when the HTTP connection closes.
    if (_cancelledStreams.contains(session.id)) return;

    // After stream completes, re-fetch messages from server to get real IDs.
    // Preserve any local attachedFileNames by matching on user-message index
    // (positional) so duplicate-content messages don't share file names.
    try {
      final serverMessages = await _apiService.listMessages(session.id);

      if (currentSession?.id == session.id) {
        // Build a positional lookup: Nth user message → its file names.
        final Map<int, List<String>> fileNamesByIndex = {};
        int userIdx = 0;
        for (final m in _messages) {
          if (m.role == CoquiMessageRole.user) {
            if (m.attachedFileNames.isNotEmpty) {
              fileNamesByIndex[userIdx] = m.attachedFileNames;
            }
            userIdx++;
          }
        }

        // Re-attach file names to the corresponding Nth user message from
        // the server response.
        userIdx = 0;
        _messages = serverMessages.map((m) {
          if (m.role == CoquiMessageRole.user) {
            final names = fileNamesByIndex[userIdx];
            userIdx++;
            if (names != null && names.isNotEmpty) {
              return CoquiMessage(
                id: m.id,
                content: m.content,
                role: m.role,
                toolCalls: m.toolCalls,
                toolCallId: m.toolCallId,
                createdAt: m.createdAt,
                attachedFileNames: names,
              );
            }
          }
          return m;
        }).toList();
        _updateDisplayMessages();
      }

      // Clean out any stale pending_*/stream_* messages before caching
      // the authoritative server response.
      await _databaseService.deleteMessages(session.id);
      await _databaseService.upsertMessages(serverMessages,
          sessionId: session.id);
    } catch (_) {
      // Keep the streaming messages if re-fetch fails
    }

    // Title polling fallback: if we never received a title event during
    // streaming, check the server after a short delay to allow the
    // TitleGenerator to finish its async LLM call.
    if (session.title == null || session.title!.isEmpty) {
      // First check immediately — title may already be generated
      await _pollForTitle(session);

      // If still missing, try once more after a delay
      if (session.title == null || session.title!.isEmpty) {
        await Future.delayed(const Duration(seconds: 3));
        await _pollForTitle(session);
      }
    }

    notifyListeners();
  }

  /// Poll the server for a session title and update local state if found.
  Future<void> _pollForTitle(CoquiSession session) async {
    try {
      final refreshed = await _apiService.getSession(session.id);
      if (refreshed != null &&
          refreshed.title != null &&
          refreshed.title!.isNotEmpty) {
        session.title = refreshed.title;
        await _databaseService.updateSessionTitle(session.id, refreshed.title!);
        notifyListeners();
      }
    } catch (_) {
      // Best-effort title polling — don't interrupt the flow
    }
  }

  /// Retry the last prompt.
  Future<void> retryLastPrompt() async {
    if (_messages.isEmpty || currentSession == null) return;

    // Find the last user message
    CoquiMessage? lastUserMessage;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == CoquiMessageRole.user) {
        lastUserMessage = _messages[i];
        break;
      }
    }

    if (lastUserMessage == null) return;

    // Clear errors
    _sessionErrors.remove(currentSession!.id);

    // Re-send the prompt
    await _initializeStream(
        currentSession!, lastUserMessage.content, const [], const []);
  }

  /// Cancel the current streaming operation.
  void cancelCurrentStreaming() {
    if (currentSession != null) {
      _cancelStream(currentSession!.id);
      notifyListeners();
    }
  }

  void _cancelStream(String sessionId) {
    _cancelledStreams.add(sessionId);
    _activeStreams.remove(sessionId);
    _streamingContent.remove(sessionId);
  }

  // ── Session navigation helpers ────────────────────────────────────

  void _moveCurrentSessionToTop() {
    if (_currentSessionIndex <= 0) return;

    final session = _sessions.removeAt(_currentSessionIndex);
    _sessions.insert(0, session);
    _currentSessionIndex = 0;
  }

  Future<void> _refreshProjectLabelForSession(CoquiSession session) async {
    final activeProjectId = session.activeProjectId;
    if (activeProjectId == null || activeProjectId.isEmpty) {
      final removed = _sessionProjectLabels.remove(session.id);
      if (removed != null && currentSession?.id == session.id) {
        notifyListeners();
      }
      return;
    }

    String? label;
    try {
      label = await _apiService.getSessionProjectLabel(session.id);
    } catch (_) {
      label = activeProjectId;
    }

    final resolvedLabel =
        label != null && label.isNotEmpty ? label : activeProjectId;

    if (_sessionProjectLabels[session.id] == resolvedLabel) {
      return;
    }

    _sessionProjectLabels[session.id] = resolvedLabel;
    notifyListeners();
  }

  void _retainProjectLabelsForCurrentSessions() {
    final currentIds = _sessions.map((session) => session.id).toSet();
    _sessionProjectLabels.removeWhere(
      (sessionId, _) => !currentIds.contains(sessionId),
    );
  }

  CoquiSession? latestActiveSessionForProfile(
    String? profile, {
    String? excludingSessionId,
  }) {
    if (profile == null || profile.isEmpty) return null;

    for (final session in _sessions) {
      if (session.profile == profile &&
          !session.isClosed &&
          session.id != excludingSessionId) {
        return session;
      }
    }

    return null;
  }

  // ── File attachments ──────────────────────────────────────────────

  /// Pick and upload files, showing upload progress via [pendingFiles].
  ///
  /// Each file is uploaded independently in parallel. The [pendingFiles]
  /// list is updated as each upload completes so the UI can display
  /// per-file status in real-time.
  Future<void> attachFiles(List<PlatformFile> files) async {
    final session = currentSession;
    if (session == null || files.isEmpty) return;

    // Add all files to the pending list immediately with uploading status.
    final newFiles = files
        .map((f) => UploadedFile(
              name: f.name,
              size: f.size,
            ))
        .toList();

    _pendingFiles.addAll(newFiles);
    notifyListeners();

    // Upload files in parallel, updating individual statuses as they finish.
    await Future.wait(
      List.generate(files.length, (i) async {
        final platformFile = files[i];
        final localId = newFiles[i].localId;
        try {
          final ids = await _apiService.uploadFiles(
            session.id,
            [platformFile],
          );
          _updatePendingFile(
            localId,
            serverId: ids.isNotEmpty ? ids.first : null,
            status: UploadedFileStatus.uploaded,
          );
        } catch (_) {
          _updatePendingFile(localId, status: UploadedFileStatus.error);
        }
      }),
    );
  }

  /// Remove a pending file by its [localId] before it is sent.
  void removeAttachment(String localId) {
    _pendingFiles.removeWhere((f) => f.localId == localId);
    notifyListeners();
  }

  void _updatePendingFile(
    String localId, {
    String? serverId,
    required UploadedFileStatus status,
  }) {
    final index = _pendingFiles.indexWhere((f) => f.localId == localId);
    if (index >= 0) {
      _pendingFiles[index] = _pendingFiles[index].copyWith(
        serverId: serverId,
        status: status,
      );
      notifyListeners();
    }
  }

  // ── Roles ─────────────────────────────────────────────────────────

  /// Fetch available roles from the server.
  Future<List<CoquiRole>> fetchAvailableRoles() async {
    return await _apiService.getRoles();
  }

  /// Fetch available profiles from the server.
  Future<List<CoquiProfile>> fetchAvailableProfiles() async {
    return await _apiService.getProfiles();
  }

  // ── Instance switching ────────────────────────────────────────────

  /// Track the last active instance ID to detect changes.
  String? _lastActiveInstanceId;
  bool? _lastActiveInstanceOnline;

  /// Called by ChangeNotifierProxyProvider when InstanceProvider updates.
  /// Only triggers a refresh when the active instance actually changes.
  void listenToInstanceChanges(InstanceProvider instanceProvider) {
    bool changedId = false;

    final newId = instanceProvider.activeInstance?.id;
    if (newId != _lastActiveInstanceId) {
      _lastActiveInstanceId = newId;
      changedId = true;
    }

    final newOnline = instanceProvider.isOnline;
    bool justCameOnline =
        newOnline == true && _lastActiveInstanceOnline != true;
    _lastActiveInstanceOnline = newOnline;

    if (changedId && newId != null) {
      onInstanceChanged();
    } else if (justCameOnline) {
      // If we didn't just change the instance ID, but the current instance came online,
      // fetch sessions to populate the UI.
      refreshSessions();
    }
  }

  /// Called when the active instance changes.
  Future<void> onInstanceChanged() async {
    _resetChat();
    _sessions.clear();
    _sessionProjectLabels.clear();
    _sessionErrors.clear();
    _sessionActivity.clear();
    _sessionIteration.clear();
    _sessionSummary.clear();
    _sessionLastTurn.clear();
    _sessionTurnProcessIds.clear();
    notifyListeners();

    await refreshSessions();
  }

  // ── Session rename ────────────────────────────────────────────────

  /// Rename a session via the API and update local state.
  Future<void> renameSession(String sessionId, String newTitle) async {
    try {
      final updated =
          await _apiService.updateSession(sessionId, title: newTitle);
      final renamed = updated.copyWith(title: newTitle);
      _replaceSession(renamed);
      await _databaseService.upsertSession(renamed);
      notifyListeners();
    } on CoquiException catch (e) {
      _sessionErrors[sessionId] = e;
      notifyListeners();
    }
  }

  Future<void> updateSessionRole(String sessionId, String roleName) async {
    try {
      final updated = await _apiService.updateSession(
        sessionId,
        modelRole: roleName,
      );
      _replaceSession(updated);
      await _databaseService.upsertSession(updated);
      unawaited(_refreshProjectLabelForSession(updated));
      notifyListeners();
    } on CoquiException catch (e) {
      _sessionErrors[sessionId] = e;
      notifyListeners();
    }
  }

  Future<void> updateSessionProfile(String sessionId, String? profile) async {
    try {
      final updated = await _apiService.updateSession(
        sessionId,
        profile: profile,
        clearProfile: profile == null || profile.isEmpty,
      );
      _replaceSession(updated);
      await _databaseService.upsertSession(updated);
      unawaited(_refreshProjectLabelForSession(updated));
      notifyListeners();
    } on CoquiException catch (e) {
      _sessionErrors[sessionId] = e;
      notifyListeners();
    }
  }

  void _replaceSession(CoquiSession updatedSession) {
    final index =
        _sessions.indexWhere((session) => session.id == updatedSession.id);
    if (index >= 0) {
      _sessions[index] = updatedSession;
    }
  }

  void _upsertSessionAtTop(CoquiSession session) {
    _sessions.removeWhere((existing) => existing.id == session.id);
    _sessions.insert(0, session);
  }
}
