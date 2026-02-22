import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:coqui_app/Models/agent_activity_event.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Models/sse_event.dart';
import 'package:coqui_app/Models/uploaded_file.dart';
import 'package:coqui_app/Providers/instance_provider.dart';
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
  List<CoquiSession> get sessions => _sessions;

  int _currentSessionIndex = -1;
  int get selectedDestination => _currentSessionIndex + 1;

  CoquiSession? get currentSession =>
      _currentSessionIndex == -1 ? null : _sessions[_currentSessionIndex];

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

  // ── Agent activity state ───────────────────────────────────────────

  final List<AgentActivityEvent> _currentTurnActivity = [];
  List<AgentActivityEvent> get currentTurnActivity => _currentTurnActivity;

  int _currentIteration = 0;
  int get currentIteration => _currentIteration;

  /// Summary from the last completed turn.
  String? _lastTurnSummary;
  String? get lastTurnSummary => _lastTurnSummary;

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
    _currentSessionIndex = destination - 1;

    if (destination == 0) {
      _resetChat();
    } else {
      _loadCurrentSession();
    }

    notifyListeners();
  }

  void _resetChat() {
    _currentSessionIndex = -1;
    _messages.clear();
    _updateDisplayMessages();
    _currentTurnActivity.clear();
    _currentIteration = 0;
    _lastTurnSummary = null;
    _pendingFiles.clear();
    notifyListeners();
  }

  // ── Session management ────────────────────────────────────────────

  /// Load sessions from the server and sync to local cache.
  Future<void> refreshSessions() async {
    try {
      final serverSessions = await _apiService.listSessions(limit: 100);

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

      // Cache all sessions
      for (final session in serverSessions) {
        await _databaseService.upsertSession(session);
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
  Future<void> createNewSession(CoquiRole role) async {
    final session = await _apiService.createSession(modelRole: role.name);

    _sessions.insert(0, session);
    _currentSessionIndex = 0;

    await _databaseService.upsertSession(session);

    _messages.clear();
    _updateDisplayMessages();
    _currentTurnActivity.clear();

    notifyListeners();
  }

  /// Delete the current session.
  Future<void> deleteCurrentSession() async {
    final session = currentSession;
    if (session == null) return;

    _resetChat();
    _sessions.remove(session);

    try {
      await _apiService.deleteSession(session.id);
    } catch (_) {
      // Session may already be deleted server-side
    }

    await _databaseService.deleteSession(session.id);
  }

  // ── Message loading ───────────────────────────────────────────────

  Future<void> _loadCurrentSession() async {
    if (currentSession == null) return;

    try {
      // Fetch messages from server
      final serverMessages = await _apiService.listMessages(currentSession!.id);
      _messages = serverMessages;
      _updateDisplayMessages();

      // Cache locally
      await _databaseService.upsertMessages(
        serverMessages,
        sessionId: currentSession!.id,
      );
    } catch (_) {
      // Fall back to cached messages
      _messages = await _databaseService.getMessages(currentSession!.id);
      _updateDisplayMessages();
    }

    _currentTurnActivity.clear();
    _currentIteration = 0;
    _lastTurnSummary = null;
    _pendingFiles.clear();

    FocusManager.instance.primaryFocus?.unfocus();
    notifyListeners();
  }

  // ── Prompt submission ─────────────────────────────────────────────

  /// Maximum prompt size in bytes (matches server's MAX_PROMPT_BYTES).
  static const int _maxPromptBytes = 102400; // 100 KB

  Future<void> sendPrompt(String text) async {
    final session = currentSession;
    if (session == null) return;

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

    // Clear errors
    _sessionErrors.remove(session.id);

    // Move session to top
    _moveCurrentSessionToTop();

    // Set thinking state
    _activeStreams.add(session.id);
    _currentTurnActivity.clear();
    _currentIteration = 0;
    _lastTurnSummary = null;
    notifyListeners();

    try {
      await _processStream(session, prompt, fileIds, fileNames);
    } on CoquiException catch (e) {
      _sessionErrors[session.id] = e;
    } on SocketException catch (_) {
      _sessionErrors[session.id] = CoquiException(
        'Network connection lost. Check your server address or internet connection.',
      );
    } catch (e) {
      _sessionErrors[session.id] = CoquiException('Something went wrong: $e');
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

    await for (final event in stream) {
      // Check if stream was cancelled
      if (_cancelledStreams.contains(session.id)) {
        break;
      }

      switch (event.type) {
        case SseEventType.agentStart:
          _currentTurnActivity.add(AgentActivityEvent.fromSseEvent(event));
          break;

        case SseEventType.iteration:
          _currentIteration = event.iterationNumber;
          _currentTurnActivity.add(AgentActivityEvent.fromSseEvent(event));
          break;

        case SseEventType.toolCall:
          _currentTurnActivity.add(AgentActivityEvent.fromSseEvent(event));
          break;

        case SseEventType.toolResult:
          _currentTurnActivity.add(AgentActivityEvent.fromSseEvent(event));
          break;

        case SseEventType.childStart:
          _currentTurnActivity.add(AgentActivityEvent.fromSseEvent(event));
          break;

        case SseEventType.childEnd:
          _currentTurnActivity.add(AgentActivityEvent.fromSseEvent(event));
          break;

        case SseEventType.done:
          accumulatedContent = event.content;
          _streamingContent[session.id] = accumulatedContent;

          if (assistantMessage == null) {
            assistantMessage = CoquiMessage(
              id: 'stream_${DateTime.now().millisecondsSinceEpoch}',
              content: accumulatedContent,
              role: CoquiMessageRole.assistant,
            );
            _messages.add(assistantMessage);
          } else {
            // Update existing message content
            final index = _messages.indexOf(assistantMessage);
            if (index >= 0) {
              _messages[index] = CoquiMessage(
                id: assistantMessage.id,
                content: accumulatedContent,
                role: CoquiMessageRole.assistant,
                createdAt: assistantMessage.createdAt,
              );
              assistantMessage = _messages[index];
            }
          }
          _updateDisplayMessages();
          break;

        case SseEventType.error:
          _currentTurnActivity.add(AgentActivityEvent.fromSseEvent(event));
          _sessionErrors[session.id] = CoquiException(event.errorMessage);
          break;

        case SseEventType.complete:
          // Build turn summary
          final parts = <String>[];
          final iterations = event.data['iterations'] as int? ?? 0;
          final tools = event.toolsUsed;
          final childCount = event.data['child_agent_count'] as int? ?? 0;
          final tokens = event.totalTokens;
          final duration = event.durationMs;

          if (iterations > 0) {
            parts.add('$iterations iteration${iterations > 1 ? 's' : ''}');
          }
          if (tools.isNotEmpty) {
            parts.add('${tools.length} tool${tools.length > 1 ? 's' : ''}');
          }
          if (childCount > 0) {
            parts.add('$childCount child${childCount > 1 ? 'ren' : ''}');
          }
          if (tokens > 0) parts.add('$tokens tokens');
          if (duration > 0) {
            final secs = (duration / 1000).toStringAsFixed(1);
            parts.add('${secs}s');
          }
          _lastTurnSummary = parts.join(' · ');
          break;

        case SseEventType.title:
          final title = event.titleText;
          if (title.isNotEmpty) {
            session.title = title;
            await _databaseService.updateSessionTitle(session.id, title);
          }
          break;

        case SseEventType.unknown:
          break;
      }

      notifyListeners();
    }

    // After stream completes, re-fetch messages from server to get real IDs.
    // Preserve any local attachedFileNames by matching on user-message index
    // (positional) so duplicate-content messages don't share file names.
    try {
      final serverMessages = await _apiService.listMessages(session.id);

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

      await _databaseService.upsertMessages(_messages, sessionId: session.id);
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
    await _initializeStream(currentSession!, lastUserMessage.content, const [], const []);
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

  // ── Instance switching ────────────────────────────────────────────

  /// Track the last active instance ID to detect changes.
  String? _lastActiveInstanceId;

  /// Called by ChangeNotifierProxyProvider when InstanceProvider updates.
  /// Only triggers a refresh when the active instance actually changes.
  void listenToInstanceChanges(InstanceProvider instanceProvider) {
    final newId = instanceProvider.activeInstance?.id;
    if (newId != _lastActiveInstanceId) {
      _lastActiveInstanceId = newId;
      if (newId != null) {
        onInstanceChanged();
      }
    }
  }

  /// Called when the active instance changes.
  Future<void> onInstanceChanged() async {
    _resetChat();
    _sessions.clear();
    _sessionErrors.clear();
    notifyListeners();

    await refreshSessions();
  }

  // ── Session rename ────────────────────────────────────────────────

  /// Rename a session via the API and update local state.
  Future<void> renameSession(String sessionId, String newTitle) async {
    try {
      await _apiService.updateSession(sessionId, title: newTitle);

      // Update local state
      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index >= 0) {
        _sessions[index].title = newTitle;
      }

      await _databaseService.updateSessionTitle(sessionId, newTitle);
      notifyListeners();
    } on CoquiException catch (e) {
      _sessionErrors[sessionId] = e;
      notifyListeners();
    }
  }
}
