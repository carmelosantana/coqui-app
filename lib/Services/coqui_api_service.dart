import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:coqui_app/Models/coqui_child_run.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Models/coqui_session_file.dart';
import 'package:coqui_app/Models/coqui_task.dart';
import 'package:coqui_app/Models/coqui_task_event.dart';
import 'package:coqui_app/Models/coqui_turn.dart';
import 'package:coqui_app/Models/sse_event.dart';

/// HTTP client for the Coqui API server.
///
/// Handles all communication with a Coqui instance including
/// session management, prompt submission with SSE streaming,
/// role retrieval, and credential management.
class CoquiApiService {
  String _baseUrl;
  String _apiKey;
  String _apiVersion;

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;
  String get apiVersion => _apiVersion;

  CoquiApiService({
    String baseUrl = 'http://localhost:3300',
    String apiKey = '',
    String apiVersion = 'v1',
  })  : _baseUrl = baseUrl,
        _apiKey = apiKey,
        _apiVersion = apiVersion;

  /// Update the connection configuration.
  void configure({String? baseUrl, String? apiKey, String? apiVersion}) {
    if (baseUrl != null) _baseUrl = baseUrl;
    if (apiKey != null) _apiKey = apiKey;
    if (apiVersion != null) _apiVersion = apiVersion;
  }

  /// Construct a full API URL from a path.
  ///
  /// Paths are relative to the versioned API prefix (e.g. `/sessions`).
  /// The method prepends `/api/{version}` automatically.
  Uri _url(String path, [Map<String, String>? queryParams]) {
    final base = Uri.parse(_baseUrl);
    final segments = base.pathSegments.where((s) => s.isNotEmpty).toList();
    final versionedPath = '/api/$_apiVersion$path';
    final extra = versionedPath.split('/').where((s) => s.isNotEmpty).toList();
    return base.replace(
      pathSegments: [...segments, ...extra],
      queryParameters: queryParams,
    );
  }

  /// Standard headers for JSON requests with auth.
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_apiKey';
    }
    return headers;
  }

  /// Parse a JSON response body, throwing on errors.
  ///
  /// Handles non-JSON responses (proxy errors, empty bodies) gracefully
  /// and parses the unified error envelope `{"error": "...", "code": "..."}` .
  Map<String, dynamic> _parseResponse(http.Response response) {
    Map<String, dynamic> body;

    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      // Non-JSON response (proxy HTML pages, empty body, etc.)
      if (response.statusCode >= 400) {
        throw CoquiException(
          'Server error (${response.statusCode})',
          statusCode: response.statusCode,
          code: 'internal_error',
        );
      }
      throw CoquiException(
        'Invalid response from server',
        statusCode: response.statusCode,
        code: 'internal_error',
      );
    }

    if (response.statusCode >= 400) {
      throw CoquiException.fromJson(body, statusCode: response.statusCode);
    }

    return body;
  }

  // ── Helpers ─────────────────────────────────────────────────────────

  /// Read a streamed error response body and throw a [CoquiException].
  ///
  /// Attempts to parse the unified error envelope from the response.
  /// Falls back to a generic status-based message if parsing fails.
  Future<Never> _throwStreamedError(http.StreamedResponse response) async {
    final rawBody = await response.stream.bytesToString();

    try {
      final body = jsonDecode(rawBody) as Map<String, dynamic>;
      throw CoquiException.fromJson(body, statusCode: response.statusCode);
    } on CoquiException {
      rethrow;
    } catch (_) {
      throw CoquiException(
        'Server error (${response.statusCode})',
        statusCode: response.statusCode,
        code: 'internal_error',
      );
    }
  }

  // ── Health ──────────────────────────────────────────────────────────

  /// Check server health. Returns the health response or throws.
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response =
          await http.get(_url('/health')).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw CoquiException(
        'Health check failed',
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw CoquiException(
        'Connection timed out. The server may be unresponsive.',
        code: 'timeout',
      );
    } on http.ClientException catch (e) {
      throw CoquiException.friendly(e);
    } catch (e) {
      if (e is CoquiException) rethrow;
      throw CoquiException.friendly(e);
    }
  }

  // ── Sessions ────────────────────────────────────────────────────────

  /// List sessions, ordered by most recently updated.
  Future<List<CoquiSession>> listSessions({int limit = 50}) async {
    final response = await http.get(
      _url('/sessions', {'limit': limit.toString()}),
      headers: _headers,
    );
    final body = _parseResponse(response);

    final sessions = body['sessions'] as List? ?? [];
    return sessions
        .map((s) => CoquiSession.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Create a new session with the given role.
  Future<CoquiSession> createSession(
      {String modelRole = 'orchestrator', String? profile}) async {
    final payload = <String, dynamic>{'model_role': modelRole};
    if (profile != null && profile.isNotEmpty) {
      payload['profile'] = profile;
    }

    final response = await http.post(
      _url('/sessions'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final body = _parseResponse(response);
    return CoquiSession.fromJson(body);
  }

  /// Get a session by ID.
  Future<CoquiSession?> getSession(String id) async {
    final response = await http.get(
      _url('/sessions/$id'),
      headers: _headers,
    );

    if (response.statusCode == 404) return null;

    final body = _parseResponse(response);
    return CoquiSession.fromJson(body);
  }

  /// Delete a session and all associated data.
  Future<void> deleteSession(String id) async {
    final response = await http.delete(
      _url('/sessions/$id'),
      headers: _headers,
    );
    _parseResponse(response);
  }

  /// Update a session (e.g. title).
  Future<CoquiSession> updateSession(
    String id, {
    String? title,
    String? modelRole,
    String? profile,
    bool clearProfile = false,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (modelRole != null) body['model_role'] = modelRole;
    if (clearProfile) {
      body['profile'] = '';
    } else if (profile != null) {
      body['profile'] = profile;
    }

    final response = await http.patch(
      _url('/sessions/$id'),
      headers: _headers,
      body: jsonEncode(body),
    );
    final data = _parseResponse(response);
    return CoquiSession.fromJson(data);
  }

  // ── Messages ────────────────────────────────────────────────────────

  /// List all messages in a session.
  Future<List<CoquiMessage>> listMessages(String sessionId) async {
    final response = await http.get(
      _url('/sessions/$sessionId/messages'),
      headers: _headers,
    );
    final body = _parseResponse(response);

    final messages = body['messages'] as List? ?? [];
    return messages
        .map((m) => CoquiMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// Send a prompt and receive an SSE event stream.
  ///
  /// This is the core streaming endpoint. Events are yielded as they
  /// arrive, allowing the UI to render tool calls, iterations, and
  /// the final response in real-time.
  ///
  /// Pass [fileIds] to attach previously uploaded file IDs to this prompt.
  Stream<SseEvent> sendPrompt(
    String sessionId,
    String prompt, {
    List<String> fileIds = const [],
  }) async* {
    final request = http.Request(
      'POST',
      _url('/sessions/$sessionId/messages'),
    );
    request.headers.addAll(_headers);
    final body = <String, dynamic>{'prompt': prompt};
    if (fileIds.isNotEmpty) body['files'] = fileIds;
    request.body = jsonEncode(body);

    http.StreamedResponse response;
    try {
      response = await request.send();
    } on http.ClientException catch (e) {
      throw CoquiException.friendly(e);
    }

    // For non-200 responses, read the body and parse the error envelope
    if (response.statusCode != 200) {
      await _throwStreamedError(response);
    }

    // Parse the SSE stream
    String buffer = '';

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;

      // SSE events are separated by double newlines
      while (buffer.contains('\n\n')) {
        final index = buffer.indexOf('\n\n');
        final block = buffer.substring(0, index).trim();
        buffer = buffer.substring(index + 2);

        if (block.isEmpty) continue;

        final event = SseEvent.parse(block);
        if (event != null) {
          yield event;
        }
      }
    }

    // Process any remaining buffer
    if (buffer.trim().isNotEmpty) {
      final event = SseEvent.parse(buffer.trim());
      if (event != null) {
        yield event;
      }
    }
  }

  /// Send a prompt and wait for the complete response (blocking mode).
  Future<Map<String, dynamic>> sendPromptBlocking(
    String sessionId,
    String prompt,
  ) async {
    final response = await http.post(
      _url('/sessions/$sessionId/messages', {'stream': 'false'}),
      headers: _headers,
      body: jsonEncode({'prompt': prompt}),
    );
    return _parseResponse(response);
  }

  // ── File uploads ─────────────────────────────────────────────────────

  /// Upload files to a session using multipart/form-data.
  ///
  /// Returns the list of server-assigned file IDs which can then be passed
  /// to [sendPrompt] as [fileIds]. Each file is uploaded with the field
  /// name `files[]` as the server expects.
  Future<List<String>> uploadFiles(
    String sessionId,
    List<PlatformFile> files,
  ) async {
    final request = http.MultipartRequest(
      'POST',
      _url('/sessions/$sessionId/files'),
    );

    if (_apiKey.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_apiKey';
    }

    for (final file in files) {
      final contentType = _mediaTypeForFilename(file.name);
      if (!kIsWeb && file.path != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'files[]',
          file.path!,
          filename: file.name,
          contentType: contentType,
        ));
      } else if (file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'files[]',
          file.bytes!,
          filename: file.name,
          contentType: contentType,
        ));
      }
    }

    final streamedResponse = await request.send();

    if (streamedResponse.statusCode != 201) {
      await _throwStreamedError(streamedResponse);
    }

    final rawBody = await streamedResponse.stream.bytesToString();
    final body = jsonDecode(rawBody) as Map<String, dynamic>;
    final uploaded = body['files'] as List? ?? [];
    return uploaded
        .map((f) => (f as Map<String, dynamic>)['id'] as String)
        .toList();
  }

  /// List files previously uploaded for a session.
  Future<List<CoquiSessionFile>> listSessionFiles(String sessionId) async {
    final response = await http.get(
      _url('/sessions/$sessionId/files'),
      headers: _headers,
    );
    final body = _parseResponse(response);
    final files = body['files'] as List? ?? [];
    return files
        .map((f) => CoquiSessionFile.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  /// Delete a previously uploaded session file.
  Future<void> deleteSessionFile(String sessionId, String fileId) async {
    final response = await http.delete(
      _url('/sessions/$sessionId/files/$fileId'),
      headers: _headers,
    );
    _parseResponse(response);
  }

  /// Build a direct URL for a session file.
  Uri getSessionFileUrl(String sessionId, String fileId) {
    return _url('/sessions/$sessionId/files/$fileId');
  }

  /// List child agent runs recorded under a session.
  Future<List<CoquiChildRun>> listChildRuns(String sessionId) async {
    final response = await http.get(
      _url('/sessions/$sessionId/child-runs'),
      headers: _headers,
    );
    final body = _parseResponse(response);
    final runs = body['child_runs'] as List? ?? [];
    return runs
        .map((r) => CoquiChildRun.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Derive a [MediaType] from a filename's extension for multipart uploads.
  ///
  /// Maps the extensions accepted by the server's [FileUploadStorage] allowed
  /// list. Unknown extensions fall back to `application/octet-stream`, which
  /// the server will reject with a user-visible error on the chip.
  static MediaType _mediaTypeForFilename(String filename) {
    final dot = filename.lastIndexOf('.');
    final ext = dot >= 0 ? filename.substring(dot + 1).toLowerCase() : '';
    return switch (ext) {
      // Images
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'gif' => MediaType('image', 'gif'),
      'webp' => MediaType('image', 'webp'),
      // Plain text
      'txt' ||
      'log' ||
      'ini' ||
      'conf' ||
      'sh' ||
      'bash' ||
      'zsh' ||
      'fish' ||
      'env' =>
        MediaType('text', 'plain'),
      // Markdown
      'md' || 'markdown' => MediaType('text', 'markdown'),
      // CSV
      'csv' => MediaType('text', 'csv'),
      // HTML
      'html' || 'htm' => MediaType('text', 'html'),
      // XML
      'xml' => MediaType('text', 'xml'),
      // PHP
      'php' => MediaType('text', 'x-php'),
      // JavaScript
      'js' || 'mjs' => MediaType('text', 'javascript'),
      // JSON
      'json' => MediaType('application', 'json'),
      // PDF
      'pdf' => MediaType('application', 'pdf'),
      // YAML
      'yaml' || 'yml' => MediaType('application', 'x-yaml'),
      // Unknown — server will reject with a clear error message on the chip
      _ => MediaType('application', 'octet-stream'),
    };
  }

  // ── Turns ───────────────────────────────────────────────────────────

  /// List all turns in a session.
  Future<List<CoquiTurn>> listTurns(String sessionId) async {
    final response = await http.get(
      _url('/sessions/$sessionId/turns'),
      headers: _headers,
    );
    final body = _parseResponse(response);

    final turns = body['turns'] as List? ?? [];
    return turns
        .map((t) => CoquiTurn.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Get a specific turn with its messages.
  Future<Map<String, dynamic>> getTurn(
    String sessionId,
    String turnId,
  ) async {
    final response = await http.get(
      _url('/sessions/$sessionId/turns/$turnId'),
      headers: _headers,
    );
    return _parseResponse(response);
  }

  /// Get available roles with full metadata.
  Future<List<CoquiRole>> getRoles() async {
    final response = await http.get(
      _url('/config/roles'),
      headers: _headers,
    );
    final body = _parseResponse(response);

    final roles = body['roles'] as List? ?? [];
    return roles
        .map((r) => CoquiRole.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Get a single role with full details including instructions.
  Future<CoquiRole> getRole(String name) async {
    final response = await http.get(
      _url('/config/roles/$name'),
      headers: _headers,
    );
    final body = _parseResponse(response);
    return CoquiRole.fromJson(body);
  }

  /// List all available models from all providers.
  Future<List<Map<String, dynamic>>> listModels() async {
    final response = await http.get(
      _url('/config/models'),
      headers: _headers,
    );
    final body = _parseResponse(response);

    final models = body['models'] as List? ?? [];
    return models.cast<Map<String, dynamic>>();
  }

  // ── Credentials ────────────────────────────────────────────────────

  /// List stored credential keys (values are never exposed).
  ///
  /// Returns a list of maps with `key` and `is_set` fields.
  Future<List<Map<String, dynamic>>> listCredentials() async {
    final response = await http.get(
      _url('/credentials'),
      headers: _headers,
    );
    final body = _parseResponse(response);

    final creds = body['credentials'] as List? ?? [];
    return creds.cast<Map<String, dynamic>>();
  }

  /// Set a credential.
  Future<void> setCredential(String key, String value) async {
    final response = await http.post(
      _url('/credentials'),
      headers: _headers,
      body: jsonEncode({'key': key, 'value': value}),
    );
    _parseResponse(response);
  }

  /// Delete a credential.
  Future<void> deleteCredential(String key) async {
    final response = await http.delete(
      _url('/credentials/$key'),
      headers: _headers,
    );
    _parseResponse(response);
  }

  // ── Background Tasks ────────────────────────────────────────────────

  /// List background tasks, optionally filtered by status.
  Future<List<CoquiTask>> listTasks({
    String? status,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (status != null) params['status'] = status;

    final response = await http.get(
      _url('/tasks', params),
      headers: _headers,
    );
    final body = _parseResponse(response);

    final tasks = body['tasks'] as List? ?? [];
    return tasks
        .map((t) => CoquiTask.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Get detailed information about a specific task.
  Future<CoquiTask> getTask(String id) async {
    final response = await http.get(
      _url('/tasks/$id'),
      headers: _headers,
    );
    final body = _parseResponse(response);
    return CoquiTask.fromJson(body);
  }

  /// Create a new background task.
  Future<CoquiTask> createTask({
    required String prompt,
    String role = 'orchestrator',
    String? title,
    String? parentSessionId,
    String? profile,
    int maxIterations = 25,
  }) async {
    final payload = <String, dynamic>{
      'prompt': prompt,
      'role': role,
      'max_iterations': maxIterations,
    };
    if (title != null) payload['title'] = title;
    if (parentSessionId != null) payload['parent_session_id'] = parentSessionId;
    if (profile != null && profile.isNotEmpty) payload['profile'] = profile;

    final response = await http.post(
      _url('/tasks'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final body = _parseResponse(response);
    return CoquiTask.fromJson(body);
  }

  /// Stream task lifecycle and progress events via SSE.
  Stream<CoquiTaskEvent> streamTaskEvents(
    String taskId, {
    int? sinceId,
  }) async* {
    final params = <String, String>{};
    if (sinceId != null) {
      params['since_id'] = sinceId.toString();
    }

    final request = http.Request('GET', _url('/tasks/$taskId/events', params));
    request.headers['Accept'] = 'text/event-stream';
    if (_apiKey.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_apiKey';
    }

    http.StreamedResponse response;
    try {
      response = await request.send();
    } on http.ClientException catch (e) {
      throw CoquiException.friendly(e);
    }

    if (response.statusCode != 200) {
      await _throwStreamedError(response);
    }

    var buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;

      while (buffer.contains('\n\n')) {
        final index = buffer.indexOf('\n\n');
        final block = buffer.substring(0, index).trim();
        buffer = buffer.substring(index + 2);

        if (block.isEmpty) continue;
        yield CoquiTaskEvent.fromSseBlock(block);
      }
    }

    if (buffer.trim().isNotEmpty) {
      yield CoquiTaskEvent.fromSseBlock(buffer.trim());
    }
  }

  /// Cancel a running or pending task.
  Future<void> cancelTask(String id) async {
    final response = await http.post(
      _url('/tasks/$id/cancel'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{}),
    );
    _parseResponse(response);
  }

  /// Inject user input into a running task.
  Future<void> injectTaskInput(String id, String content) async {
    final response = await http.post(
      _url('/tasks/$id/input'),
      headers: _headers,
      body: jsonEncode({'content': content}),
    );
    _parseResponse(response);
  }
}
