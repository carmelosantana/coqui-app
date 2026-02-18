import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Models/coqui_turn.dart';
import 'package:coqui_app/Models/sse_event.dart';

/// HTTP client for the Coqui API server.
///
/// Handles all communication with a Coqui instance including
/// session management, prompt submission with SSE streaming,
/// role/config retrieval, and credential management.
class CoquiApiService {
  String _baseUrl;
  String _apiKey;

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;

  CoquiApiService({
    String baseUrl = 'http://localhost:8080',
    String apiKey = '',
  })  : _baseUrl = baseUrl,
        _apiKey = apiKey;

  /// Update the connection configuration.
  void configure({String? baseUrl, String? apiKey}) {
    if (baseUrl != null) _baseUrl = baseUrl;
    if (apiKey != null) _apiKey = apiKey;
  }

  /// Construct a full API URL from a path.
  Uri _url(String path, [Map<String, String>? queryParams]) {
    final base = Uri.parse(_baseUrl);
    final segments = base.pathSegments.where((s) => s.isNotEmpty).toList();
    final extra = path.split('/').where((s) => s.isNotEmpty).toList();
    return base.replace(
      pathSegments: [...segments, ...extra],
      queryParameters: queryParams,
    );
  }

  /// Standard headers for JSON requests with auth.
  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_apiKey';
    }
    return headers;
  }

  /// Parse a JSON response body, throwing on errors.
  Map<String, dynamic> _parseResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      final error = body['error'] as String? ?? 'Unknown error';
      throw CoquiException(error, statusCode: response.statusCode);
    }

    return body;
  }

  // ── Health ──────────────────────────────────────────────────────────

  /// Check server health. Returns the health response or throws.
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await http
          .get(_url('/api/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw CoquiException(
        'Health check failed',
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      throw CoquiException('Connection timed out');
    } on http.ClientException catch (e) {
      throw CoquiException('Connection failed: ${e.message}');
    } catch (e) {
      if (e is CoquiException) rethrow;
      throw CoquiException('Connection failed: $e');
    }
  }

  // ── Sessions ────────────────────────────────────────────────────────

  /// List sessions, ordered by most recently updated.
  Future<List<CoquiSession>> listSessions({int limit = 50}) async {
    final response = await http.get(
      _url('/api/sessions', {'limit': limit.toString()}),
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
      {String modelRole = 'orchestrator'}) async {
    final response = await http.post(
      _url('/api/sessions'),
      headers: _headers,
      body: jsonEncode({'model_role': modelRole}),
    );
    final body = _parseResponse(response);
    return CoquiSession.fromJson(body);
  }

  /// Get a session by ID.
  Future<CoquiSession?> getSession(String id) async {
    final response = await http.get(
      _url('/api/sessions/$id'),
      headers: _headers,
    );

    if (response.statusCode == 404) return null;

    final body = _parseResponse(response);
    return CoquiSession.fromJson(body);
  }

  /// Delete a session and all associated data.
  Future<void> deleteSession(String id) async {
    final response = await http.delete(
      _url('/api/sessions/$id'),
      headers: _headers,
    );
    _parseResponse(response);
  }

  /// Update a session (e.g. title).
  Future<CoquiSession> updateSession(String id, {String? title}) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;

    final response = await http.patch(
      _url('/api/sessions/$id'),
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
      _url('/api/sessions/$sessionId/messages'),
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
  Stream<SseEvent> sendPrompt(String sessionId, String prompt) async* {
    final request = http.Request(
      'POST',
      _url('/api/sessions/$sessionId/messages'),
    );
    request.headers.addAll(_headers);
    request.body = jsonEncode({'prompt': prompt});

    http.StreamedResponse response;
    try {
      response = await request.send();
    } on http.ClientException catch (e) {
      throw CoquiException('Connection failed: ${e.message}');
    }

    if (response.statusCode == 404) {
      throw CoquiException('Session not found', statusCode: 404);
    } else if (response.statusCode == 409) {
      throw CoquiException(
        'Session already has an active agent run',
        statusCode: 409,
      );
    } else if (response.statusCode == 400) {
      throw CoquiException('Invalid prompt', statusCode: 400);
    } else if (response.statusCode == 401) {
      throw CoquiException('Authentication failed', statusCode: 401);
    } else if (response.statusCode != 200) {
      throw CoquiException(
        'Server error (${response.statusCode})',
        statusCode: response.statusCode,
      );
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
      _url('/api/sessions/$sessionId/messages', {'stream': 'false'}),
      headers: _headers,
      body: jsonEncode({'prompt': prompt}),
    );
    return _parseResponse(response);
  }

  // ── Turns ───────────────────────────────────────────────────────────

  /// List all turns in a session.
  Future<List<CoquiTurn>> listTurns(String sessionId) async {
    final response = await http.get(
      _url('/api/sessions/$sessionId/turns'),
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
      _url('/api/sessions/$sessionId/turns/$turnId'),
      headers: _headers,
    );
    return _parseResponse(response);
  }

  // ── Configuration ──────────────────────────────────────────────────

  /// Get the full server configuration.
  Future<Map<String, dynamic>> getConfig() async {
    final response = await http.get(
      _url('/api/config'),
      headers: _headers,
    );
    return _parseResponse(response);
  }

  /// Get available roles with full metadata.
  Future<List<CoquiRole>> getRoles() async {
    final response = await http.get(
      _url('/api/config/roles'),
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
      _url('/api/config/roles/$name'),
      headers: _headers,
    );
    final body = _parseResponse(response);
    return CoquiRole.fromJson(body);
  }

  /// Create a new custom role.
  Future<CoquiRole> createRole({
    required String name,
    required String instructions,
    String? displayName,
    String? description,
    String accessLevel = 'readonly',
    String? model,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'instructions': instructions,
      'access_level': accessLevel,
    };
    if (displayName != null) payload['display_name'] = displayName;
    if (description != null) payload['description'] = description;
    if (model != null) payload['model'] = model;

    final response = await http.post(
      _url('/api/config/roles'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final body = _parseResponse(response);
    return CoquiRole.fromJson(body);
  }

  /// Update an existing role.
  Future<CoquiRole> updateRole(
    String name, {
    String? displayName,
    String? description,
    String? accessLevel,
    String? model,
    String? instructions,
  }) async {
    final payload = <String, dynamic>{};
    if (displayName != null) payload['display_name'] = displayName;
    if (description != null) payload['description'] = description;
    if (accessLevel != null) payload['access_level'] = accessLevel;
    if (model != null) payload['model'] = model;
    if (instructions != null) payload['instructions'] = instructions;

    final response = await http.patch(
      _url('/api/config/roles/$name'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final body = _parseResponse(response);
    return CoquiRole.fromJson(body);
  }

  /// Delete a custom role.
  Future<void> deleteRole(String name) async {
    final response = await http.delete(
      _url('/api/config/roles/$name'),
      headers: _headers,
    );
    _parseResponse(response);
  }

  /// List all available models from all providers.
  Future<List<Map<String, dynamic>>> listModels() async {
    final response = await http.get(
      _url('/api/config/models'),
      headers: _headers,
    );
    final body = _parseResponse(response);

    final models = body['models'] as List? ?? [];
    return models.cast<Map<String, dynamic>>();
  }

  // ── Credentials ────────────────────────────────────────────────────

  /// List stored credential keys (values are never exposed).
  Future<List<String>> listCredentials() async {
    final response = await http.get(
      _url('/api/credentials'),
      headers: _headers,
    );
    final body = _parseResponse(response);

    final keys = body['credentials'] as List? ?? [];
    return keys.cast<String>();
  }

  /// Set a credential.
  Future<void> setCredential(String key, String value) async {
    final response = await http.post(
      _url('/api/credentials'),
      headers: _headers,
      body: jsonEncode({'key': key, 'value': value}),
    );
    _parseResponse(response);
  }

  /// Delete a credential.
  Future<void> deleteCredential(String key) async {
    final response = await http.delete(
      _url('/api/credentials/$key'),
      headers: _headers,
    );
    _parseResponse(response);
  }
}
