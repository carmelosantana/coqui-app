import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:coqui_app/Models/agent_activity_event.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Models/sse_event.dart';
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

  /// Displayable messages (excludes tool messages).
  List<CoquiMessage> get displayMessages =>
      _messages.where((m) => m.isDisplayable).toList();

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
    _currentTurnActivity.clear();
    _currentIteration = 0;
    _lastTurnSummary = null;
    notifyListeners();
  }

  // ── Session management ────────────────────────────────────────────

  /// Load sessions from the server and sync to local cache.
  Future<void> refreshSessions() async {
    try {
      final serverSessions = await _apiService.listSessions(limit: 100);

      // Preserve local titles
      for (final session in serverSessions) {
        final cached = await _databaseService.getSession(session.id);
        if (cached?.title != null) {
          session.title = cached!.title;
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

      // Cache locally
      await _databaseService.upsertMessages(
        serverMessages,
        sessionId: currentSession!.id,
      );
    } catch (_) {
      // Fall back to cached messages
      _messages = await _databaseService.getMessages(currentSession!.id);
    }

    _currentTurnActivity.clear();
    _currentIteration = 0;
    _lastTurnSummary = null;

    FocusManager.instance.primaryFocus?.unfocus();
    notifyListeners();
  }

  // ── Prompt submission ─────────────────────────────────────────────

  Future<void> sendPrompt(String text) async {
    final session = currentSession;
    if (session == null) return;

    // Add optimistic user message
    final userMessage = CoquiMessage(
      id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      content: text,
      role: CoquiMessageRole.user,
    );
    _messages.add(userMessage);
    notifyListeners();

    // Generate title from first prompt if needed
    if (session.title == null || session.title!.isEmpty) {
      session.title = CoquiSession.generateTitle(text);
      await _databaseService.updateSessionTitle(session.id, session.title!);
      notifyListeners();
    }

    // Start streaming
    await _initializeStream(session, text);
  }

  Future<void> _initializeStream(CoquiSession session, String prompt) async {
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
      await _processStream(session, prompt);
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

  Future<void> _processStream(CoquiSession session, String prompt) async {
    final stream = _apiService.sendPrompt(session.id, prompt);

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

          if (iterations > 0)
            parts.add('$iterations iteration${iterations > 1 ? 's' : ''}');
          if (tools.isNotEmpty)
            parts.add('${tools.length} tool${tools.length > 1 ? 's' : ''}');
          if (childCount > 0)
            parts.add('$childCount child${childCount > 1 ? 'ren' : ''}');
          if (tokens > 0) parts.add('$tokens tokens');
          if (duration > 0) {
            final secs = (duration / 1000).toStringAsFixed(1);
            parts.add('${secs}s');
          }
          _lastTurnSummary = parts.join(' · ');
          break;

        case SseEventType.unknown:
          break;
      }

      notifyListeners();
    }

    // After stream completes, re-fetch messages from server to get real IDs
    try {
      final serverMessages = await _apiService.listMessages(session.id);
      _messages = serverMessages;
      await _databaseService.upsertMessages(serverMessages,
          sessionId: session.id);
    } catch (_) {
      // Keep the streaming messages if re-fetch fails
    }

    notifyListeners();
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
    await _initializeStream(currentSession!, lastUserMessage.content);
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

  // ── Roles ─────────────────────────────────────────────────────────

  /// Fetch available roles from the server.
  Future<List<CoquiRole>> fetchAvailableRoles() async {
    return await _apiService.getRoles();
  }

  // ── Instance switching ────────────────────────────────────────────

  /// Called when the active instance changes.
  Future<void> onInstanceChanged() async {
    _resetChat();
    _sessions.clear();
    _sessionErrors.clear();
    notifyListeners();

    await refreshSessions();
  }
}
