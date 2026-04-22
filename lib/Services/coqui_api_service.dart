import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:coqui_app/Models/coqui_channel.dart';
import 'package:coqui_app/Models/coqui_channel_delivery.dart';
import 'package:coqui_app/Models/coqui_channel_driver.dart';
import 'package:coqui_app/Models/coqui_channel_event.dart';
import 'package:coqui_app/Models/coqui_channel_link.dart';
import 'package:coqui_app/Models/coqui_channel_stats.dart';
import 'package:coqui_app/Models/coqui_child_run.dart';
import 'package:coqui_app/Models/coqui_command_catalog.dart';
import 'package:coqui_app/Models/coqui_configured_model.dart';
import 'package:coqui_app/Models/coqui_backstory_inspection.dart';
import 'package:coqui_app/Models/coqui_exception.dart';
import 'package:coqui_app/Models/coqui_message.dart';
import 'package:coqui_app/Models/coqui_profile.dart';
import 'package:coqui_app/Models/coqui_project.dart';
import 'package:coqui_app/Models/coqui_prompt_inspection.dart';
import 'package:coqui_app/Models/coqui_role.dart';
import 'package:coqui_app/Models/coqui_schedule.dart';
import 'package:coqui_app/Models/coqui_schedule_stats.dart';
import 'package:coqui_app/Models/coqui_session.dart';
import 'package:coqui_app/Models/coqui_session_file.dart';
import 'package:coqui_app/Models/coqui_sprint.dart';
import 'package:coqui_app/Models/coqui_task.dart';
import 'package:coqui_app/Models/coqui_task_event.dart';
import 'package:coqui_app/Models/coqui_turn.dart';
import 'package:coqui_app/Models/coqui_loop.dart';
import 'package:coqui_app/Models/coqui_webhook.dart';
import 'package:coqui_app/Models/coqui_webhook_delivery.dart';
import 'package:coqui_app/Models/coqui_webhook_stats.dart';
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
  Future<List<CoquiSession>> listSessions({
    int limit = 50,
    String? status,
  }) async {
    final params = {'limit': limit.toString()};
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }

    final response = await http.get(
      _url('/sessions', params),
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
      {String modelRole = 'orchestrator',
      String? profile,
      bool confirmCloseActiveProfileSession = false}) async {
    final payload = <String, dynamic>{'model_role': modelRole};
    if (profile != null && profile.isNotEmpty) {
      payload['profile'] = profile;
    }
    if (confirmCloseActiveProfileSession) {
      payload['confirm_close_active_profile_session'] = true;
    }

    final response = await http.post(
      _url('/sessions'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final body = _parseResponse(response);
    return CoquiSession.fromJson(body);
  }

  /// Resolve the latest interactive session for a scope, or create one.
  Future<({CoquiSession session, bool created})> resolveSession({
    String modelRole = 'orchestrator',
    String? profile,
  }) async {
    final payload = <String, dynamic>{'model_role': modelRole};
    if (profile != null && profile.isNotEmpty) {
      payload['profile'] = profile;
    }

    final response = await http.post(
      _url('/sessions/resolve'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final body = _parseResponse(response);
    final created = body['created'] as bool? ?? false;
    final sessionId = body['id'] as String;
    final session = await getSession(sessionId) ?? CoquiSession.fromJson(body);
    return (session: session, created: created);
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

  /// Fetch the current session's active project label.
  ///
  /// Returns the project title when available, otherwise falls back to
  /// slug and then the raw active project ID.
  Future<String?> getSessionProjectLabel(String sessionId) async {
    final response = await http.get(
      _url('/sessions/$sessionId/project'),
      headers: _headers,
    );
    final body = _parseResponse(response);

    final project = body['project'] as Map<String, dynamic>?;
    final activeProjectId = body['active_project_id'] as String?;
    if (project == null) {
      return activeProjectId;
    }

    final title = project['title'] as String?;
    if (title != null && title.isNotEmpty) {
      return title;
    }

    final slug = project['slug'] as String?;
    if (slug != null && slug.isNotEmpty) {
      return slug;
    }

    return activeProjectId ?? project['id'] as String?;
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

  /// Get typed turn detail including messages and replayable event history.
  Future<CoquiTurnDetail> getTurnDetail(
    String sessionId,
    String turnId,
  ) async {
    final body = await getTurn(sessionId, turnId);
    return CoquiTurnDetail.fromJson(body);
  }

  /// List replayable turn events without fetching nested message payloads.
  Future<List<CoquiTurnEvent>> listTurnEvents(
    String sessionId,
    String turnId,
  ) async {
    final response = await http.get(
      _url('/sessions/$sessionId/turns/$turnId/events'),
      headers: _headers,
    );
    final body = _parseResponse(response);

    final events = body['events'] as List? ?? [];
    return events
        .map((event) => CoquiTurnEvent.fromJson(event as Map<String, dynamic>))
        .toList();
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

  /// Get available personality profiles with descriptions.
  Future<List<CoquiProfile>> getProfiles() async {
    final response = await http.get(
      _url('/config/profiles'),
      headers: _headers,
    );
    final body = _parseResponse(response);

    final defaultProfile = body['default_profile'] as String?;
    final profiles = body['profiles'] as List? ?? [];
    return profiles
        .map((profile) => CoquiProfile.fromJson(
              profile as Map<String, dynamic>,
              isDefault: (profile['name'] as String?) == defaultProfile,
            ))
        .toList();
  }

  Future<List<CoquiProject>> listProjects({
    String? status,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }

    final response = await http.get(
      _url('/projects', params),
      headers: _headers,
    );
    final body = _parseResponse(response);
    final projects = body['projects'] as List? ?? [];
    return projects
        .map((item) => CoquiProject.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<CoquiSprint>> listProjectSprints(
    String idOrSlug, {
    String? status,
  }) async {
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }

    final response = await http.get(
      _url('/projects/$idOrSlug/sprints', params.isEmpty ? null : params),
      headers: _headers,
    );
    final body = _parseResponse(response);
    final sprints = body['sprints'] as List? ?? [];
    return sprints
        .map((item) => CoquiSprint.fromJson(item as Map<String, dynamic>))
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
  Future<List<CoquiConfiguredModel>> listModels() async {
    final response = await http.get(
      _url('/config/models'),
      headers: _headers,
    );
    final body = _parseResponse(response);

    final models = body['models'] as List? ?? [];
    return models
        .map((model) =>
            CoquiConfiguredModel.fromJson(model as Map<String, dynamic>))
        .toList();
  }

  /// Get the fully rendered system prompt inspection payload.
  Future<CoquiPromptInspection> inspectPrompt({
    String? role,
    String? profile,
  }) async {
    final params = <String, String>{};
    if (role != null && role.isNotEmpty) {
      params['role'] = role;
    }
    if (profile != null && profile.isNotEmpty) {
      params['profile'] = profile;
    }

    final response = await http.get(
      _url('/server/prompt', params.isEmpty ? null : params),
      headers: _headers,
    );
    final body = _parseResponse(response);
    return CoquiPromptInspection.fromJson(body);
  }

  /// Get backstory inspection metadata for a profile.
  Future<CoquiBackstoryInspection> inspectBackstory({String? profile}) async {
    final params = <String, String>{};
    if (profile != null && profile.isNotEmpty) {
      params['profile'] = profile;
    }

    final response = await http.get(
      _url('/server/backstory', params.isEmpty ? null : params),
      headers: _headers,
    );
    final body = _parseResponse(response);
    return CoquiBackstoryInspection.fromJson(body);
  }

  /// Get prompt budget details for a role/profile scope.
  Future<Map<String, dynamic>> inspectBudget({
    String? role,
    String? profile,
  }) async {
    final params = <String, String>{};
    if (role != null && role.isNotEmpty) {
      params['role'] = role;
    }
    if (profile != null && profile.isNotEmpty) {
      params['profile'] = profile;
    }

    final response = await http.get(
      _url('/server/budget', params.isEmpty ? null : params),
      headers: _headers,
    );
    return _parseResponse(response);
  }

  /// Get runtime slash-command metadata equivalent to `/help`.
  Future<CoquiCommandCatalog> getCommandCatalog() async {
    final response = await http.get(
      _url('/server/commands'),
      headers: _headers,
    );
    final body = _parseResponse(response);
    return CoquiCommandCatalog.fromJson(body);
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

  // ── Channels ────────────────────────────────────────────────────────

  /// List configured channels with joined runtime health and dashboard stats.
  Future<
      ({
        List<CoquiChannel> channels,
        CoquiChannelStats stats,
        CoquiChannelStats manager,
      })> listChannels({
    bool? enabled,
    String? driver,
  }) async {
    final params = <String, String>{};
    if (enabled != null) {
      params['enabled'] = enabled.toString();
    }
    if (driver != null && driver.isNotEmpty) {
      params['driver'] = driver;
    }

    final response = await http.get(
      _url('/channels', params.isEmpty ? null : params),
      headers: _headers,
    );
    final body = _parseResponse(response);

    final channels = (body['channels'] as List? ?? [])
        .map(
            (channel) => CoquiChannel.fromJson(channel as Map<String, dynamic>))
        .toList();

    return (
      channels: channels,
      stats: body['stats'] is Map<String, dynamic>
          ? CoquiChannelStats.fromJson(body['stats'] as Map<String, dynamic>)
          : CoquiChannelStats.empty,
      manager: body['manager'] is Map<String, dynamic>
          ? CoquiChannelStats.fromJson(body['manager'] as Map<String, dynamic>)
          : CoquiChannelStats.empty,
    );
  }

  Future<List<CoquiChannelDriver>> listChannelDrivers() async {
    final response = await http.get(
      _url('/channels/drivers'),
      headers: _headers,
    );
    final body = _parseResponse(response);

    final drivers = body['drivers'] as List? ?? [];
    return drivers
        .map((driver) =>
            CoquiChannelDriver.fromJson(driver as Map<String, dynamic>))
        .toList();
  }

  Future<CoquiChannel> getChannel(String id) async {
    final response = await http.get(
      _url('/channels/$id'),
      headers: _headers,
    );
    final body = _parseResponse(response);
    return CoquiChannel.fromJson(body['channel'] as Map<String, dynamic>);
  }

  Future<CoquiChannel> createChannel({
    required String name,
    required String driver,
    bool enabled = true,
    String? displayName,
    String? defaultProfile,
    Map<String, dynamic>? settings,
    List<String>? allowedScopes,
    Map<String, dynamic>? security,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'driver': driver,
      'enabled': enabled,
    };
    if (displayName != null && displayName.isNotEmpty) {
      payload['displayName'] = displayName;
    }
    if (defaultProfile != null) {
      payload['defaultProfile'] = defaultProfile;
    }
    if (settings != null) {
      payload['settings'] = settings;
    }
    if (allowedScopes != null) {
      payload['allowedScopes'] = allowedScopes;
    }
    if (security != null) {
      payload['security'] = security;
    }

    final response = await http.post(
      _url('/channels'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final body = _parseResponse(response);
    return CoquiChannel.fromJson(body['channel'] as Map<String, dynamic>);
  }

  Future<CoquiChannel> updateChannel(
    String id, {
    String? driver,
    bool? enabled,
    String? displayName,
    String? defaultProfile,
    Map<String, dynamic>? settings,
    List<String>? allowedScopes,
    Map<String, dynamic>? security,
  }) async {
    final payload = <String, dynamic>{};
    if (driver != null && driver.isNotEmpty) {
      payload['driver'] = driver;
    }
    if (enabled != null) {
      payload['enabled'] = enabled;
    }
    if (displayName != null) {
      payload['displayName'] = displayName;
    }
    if (defaultProfile != null) {
      payload['defaultProfile'] = defaultProfile;
    }
    if (settings != null) {
      payload['settings'] = settings;
    }
    if (allowedScopes != null) {
      payload['allowedScopes'] = allowedScopes;
    }
    if (security != null) {
      payload['security'] = security;
    }

    final response = await http.patch(
      _url('/channels/$id'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final body = _parseResponse(response);
    return CoquiChannel.fromJson(body['channel'] as Map<String, dynamic>);
  }

  Future<void> deleteChannel(String id) async {
    final response = await http.delete(
      _url('/channels/$id'),
      headers: _headers,
    );
    _parseResponse(response);
  }

  Future<CoquiChannel> enableChannel(String id) async {
    final response = await http.post(
      _url('/channels/$id/enable'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{}),
    );
    final body = _parseResponse(response);
    return CoquiChannel.fromJson(body['channel'] as Map<String, dynamic>);
  }

  Future<CoquiChannel> disableChannel(String id) async {
    final response = await http.post(
      _url('/channels/$id/disable'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{}),
    );
    final body = _parseResponse(response);
    return CoquiChannel.fromJson(body['channel'] as Map<String, dynamic>);
  }

  Future<CoquiChannel> testChannel(String id) async {
    final response = await http.post(
      _url('/channels/$id/test'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{}),
    );
    final body = _parseResponse(response);
    return CoquiChannel.fromJson(body['channel'] as Map<String, dynamic>);
  }

  Future<({CoquiChannel channel, bool healthy, String workerStatus})>
      getChannelHealth(String id) async {
    final response = await http.get(
      _url('/channels/$id/health'),
      headers: _headers,
    );
    final body = _parseResponse(response);
    return (
      channel: CoquiChannel.fromJson(body['channel'] as Map<String, dynamic>),
      healthy: body['healthy'] as bool? ?? false,
      workerStatus: body['worker_status'] as String? ?? 'missing',
    );
  }

  Future<List<CoquiChannelLink>> listChannelLinks(
    String id, {
    int limit = 100,
  }) async {
    final response = await http.get(
      _url('/channels/$id/links', {'limit': limit.toString()}),
      headers: _headers,
    );
    final body = _parseResponse(response);
    final links = body['links'] as List? ?? [];
    return links
        .map((link) => CoquiChannelLink.fromJson(link as Map<String, dynamic>))
        .toList();
  }

  Future<CoquiChannelLink> createChannelLink(
    String id, {
    required String remoteUserKey,
    required String profile,
    String? remoteScopeKey,
    String trustLevel = 'linked',
    Map<String, dynamic>? metadata,
  }) async {
    final payload = <String, dynamic>{
      'remote_user_key': remoteUserKey,
      'profile': profile,
      'trust_level': trustLevel,
    };
    if (remoteScopeKey != null && remoteScopeKey.isNotEmpty) {
      payload['remote_scope_key'] = remoteScopeKey;
    }
    if (metadata != null) {
      payload['metadata'] = metadata;
    }

    final response = await http.post(
      _url('/channels/$id/links'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final body = _parseResponse(response);
    return CoquiChannelLink.fromJson(body['link'] as Map<String, dynamic>);
  }

  Future<void> deleteChannelLink(String id, String linkId) async {
    final response = await http.delete(
      _url('/channels/$id/links/$linkId'),
      headers: _headers,
    );
    _parseResponse(response);
  }

  Future<List<CoquiChannelEvent>> listChannelEvents(
    String id, {
    int limit = 50,
  }) async {
    final response = await http.get(
      _url('/channels/$id/events', {'limit': limit.toString()}),
      headers: _headers,
    );
    final body = _parseResponse(response);
    final events = body['events'] as List? ?? [];
    return events
        .map((event) =>
            CoquiChannelEvent.fromJson(event as Map<String, dynamic>))
        .toList();
  }

  Future<List<CoquiChannelDelivery>> listChannelDeliveries(
    String id, {
    int limit = 50,
  }) async {
    final response = await http.get(
      _url('/channels/$id/deliveries', {'limit': limit.toString()}),
      headers: _headers,
    );
    final body = _parseResponse(response);
    final deliveries = body['deliveries'] as List? ?? [];
    return deliveries
        .map((delivery) =>
            CoquiChannelDelivery.fromJson(delivery as Map<String, dynamic>))
        .toList();
  }

  // ── Schedules ──────────────────────────────────────────────────────

  Future<({List<CoquiSchedule> schedules, CoquiScheduleStats stats})>
      listSchedules({
    bool? enabled,
  }) async {
    final params = <String, String>{};
    if (enabled != null) {
      params['enabled'] = enabled ? '1' : '0';
    }

    final response = await http.get(
      _url('/schedules', params.isEmpty ? null : params),
      headers: _headers,
    );
    final body = _parseResponse(response);
    final schedules = (body['schedules'] as List? ?? [])
        .map((item) => CoquiSchedule.fromJson(item as Map<String, dynamic>))
        .toList();

    return (
      schedules: schedules,
      stats: body['stats'] is Map<String, dynamic>
          ? CoquiScheduleStats.fromJson(body['stats'] as Map<String, dynamic>)
          : CoquiScheduleStats.empty,
    );
  }

  Future<CoquiSchedule> getSchedule(String id) async {
    final response = await http.get(
      _url('/schedules/$id'),
      headers: _headers,
    );
    final body = _parseResponse(response);
    return CoquiSchedule.fromJson(body);
  }

  Future<CoquiSchedule> createSchedule({
    required String name,
    required String scheduleExpression,
    required String prompt,
    String role = 'orchestrator',
    String timezone = 'UTC',
    int maxIterations = 48,
    int maxFailures = 3,
    String? description,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'schedule_expression': scheduleExpression,
      'prompt': prompt,
      'role': role,
      'timezone': timezone,
      'max_iterations': maxIterations,
      'max_failures': maxFailures,
    };
    if (description != null && description.isNotEmpty) {
      payload['description'] = description;
    }

    final response = await http.post(
      _url('/schedules'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final body = _parseResponse(response);
    return CoquiSchedule.fromJson(body['schedule'] as Map<String, dynamic>);
  }

  Future<CoquiSchedule> updateSchedule(
    String id, {
    String? name,
    String? description,
    String? scheduleExpression,
    String? prompt,
    String? role,
    String? timezone,
    int? maxIterations,
    int? maxFailures,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (description != null) payload['description'] = description;
    if (scheduleExpression != null) {
      payload['schedule_expression'] = scheduleExpression;
    }
    if (prompt != null) payload['prompt'] = prompt;
    if (role != null) payload['role'] = role;
    if (timezone != null) payload['timezone'] = timezone;
    if (maxIterations != null) payload['max_iterations'] = maxIterations;
    if (maxFailures != null) payload['max_failures'] = maxFailures;

    final response = await http.patch(
      _url('/schedules/$id'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final body = _parseResponse(response);
    return CoquiSchedule.fromJson(body['schedule'] as Map<String, dynamic>);
  }

  Future<void> deleteSchedule(String id) async {
    final response = await http.delete(
      _url('/schedules/$id'),
      headers: _headers,
    );
    _parseResponse(response);
  }

  Future<CoquiSchedule> enableSchedule(String id) async {
    final response = await http.post(
      _url('/schedules/$id/enable'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{}),
    );
    final body = _parseResponse(response);
    return CoquiSchedule.fromJson(body['schedule'] as Map<String, dynamic>);
  }

  Future<CoquiSchedule> disableSchedule(String id) async {
    final response = await http.post(
      _url('/schedules/$id/disable'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{}),
    );
    final body = _parseResponse(response);
    return CoquiSchedule.fromJson(body['schedule'] as Map<String, dynamic>);
  }

  Future<CoquiSchedule> triggerSchedule(String id) async {
    final response = await http.post(
      _url('/schedules/$id/trigger'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{}),
    );
    final body = _parseResponse(response);
    return CoquiSchedule.fromJson(body['schedule'] as Map<String, dynamic>);
  }

  // ── Loops ──────────────────────────────────────────────────────────

  Future<({List<CoquiLoop> loops, int activeCount})> listLoops({
    String? status,
  }) async {
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }

    final response = await http.get(
      _url('/loops', params.isEmpty ? null : params),
      headers: _headers,
    );
    final body = _parseResponse(response);
    final loops = (body['loops'] as List? ?? [])
        .map((item) => CoquiLoop.fromJson(item as Map<String, dynamic>))
        .toList();

    return (
      loops: loops,
      activeCount: _coerceInt(body['active']),
    );
  }

  Future<List<CoquiLoopDefinition>> listLoopDefinitions() async {
    final response = await http.get(
      _url('/loops/definitions'),
      headers: _headers,
    );
    final body = _parseResponse(response);
    final definitions = body['definitions'] as List? ?? [];
    return definitions
        .map(
          (item) => CoquiLoopDefinition.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<CoquiLoopDetail> createLoop({
    required String definition,
    required String goal,
    String? sessionId,
    String? projectId,
    String? projectSlug,
    String? sprintId,
    Map<String, String>? parameters,
    int? maxIterations,
  }) async {
    final payload = <String, dynamic>{
      'definition': definition,
      'goal': goal,
    };
    if (sessionId != null && sessionId.isNotEmpty) {
      payload['session_id'] = sessionId;
    }
    if (projectId != null && projectId.isNotEmpty) {
      payload['project_id'] = projectId;
    }
    if (projectSlug != null && projectSlug.isNotEmpty) {
      payload['project_slug'] = projectSlug;
    }
    if (sprintId != null && sprintId.isNotEmpty) {
      payload['sprint_id'] = sprintId;
    }
    if (parameters != null && parameters.isNotEmpty) {
      payload['parameters'] = parameters;
    }
    if (maxIterations != null) {
      payload['max_iterations'] = maxIterations;
    }

    final response = await http.post(
      _url('/loops'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final body = _parseResponse(response);
    return CoquiLoopDetail(
      loop: CoquiLoop.fromJson(body['loop'] as Map<String, dynamic>),
      iteration: body['iteration'] is Map<String, dynamic>
          ? CoquiLoopIteration.fromJson(
              body['iteration'] as Map<String, dynamic>)
          : null,
      stages: (body['stages'] as List? ?? [])
          .map((item) => CoquiLoopStage.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<CoquiLoopDetail> getLoopDetail(String id) async {
    final response = await http.get(
      _url('/loops/$id'),
      headers: _headers,
    );
    final body = _parseResponse(response);
    return CoquiLoopDetail(
      loop: CoquiLoop.fromJson(body['loop'] as Map<String, dynamic>),
      iteration: body['iteration'] is Map<String, dynamic>
          ? CoquiLoopIteration.fromJson(
              body['iteration'] as Map<String, dynamic>)
          : null,
      stages: (body['stages'] as List? ?? [])
          .map((item) => CoquiLoopStage.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<String> pauseLoop(String id) async {
    final response = await http.post(
      _url('/loops/$id/pause'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{}),
    );
    final body = _parseResponse(response);
    return body['status'] as String? ?? 'paused';
  }

  Future<String> resumeLoop(String id) async {
    final response = await http.post(
      _url('/loops/$id/resume'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{}),
    );
    final body = _parseResponse(response);
    return body['status'] as String? ?? 'running';
  }

  Future<String> stopLoop(String id) async {
    final response = await http.post(
      _url('/loops/$id/stop'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{}),
    );
    final body = _parseResponse(response);
    return body['status'] as String? ?? 'cancelled';
  }

  Future<List<CoquiLoopIteration>> listLoopIterations(String id) async {
    final response = await http.get(
      _url('/loops/$id/iterations'),
      headers: _headers,
    );
    final body = _parseResponse(response);
    final iterations = body['iterations'] as List? ?? [];
    return iterations
        .map(
          (item) => CoquiLoopIteration.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<CoquiLoopIterationDetail> getLoopIterationDetail(
    String loopId,
    String iterationId,
  ) async {
    final response = await http.get(
      _url('/loops/$loopId/iterations/$iterationId'),
      headers: _headers,
    );
    final body = _parseResponse(response);
    return CoquiLoopIterationDetail(
      iteration: CoquiLoopIteration.fromJson(
          body['iteration'] as Map<String, dynamic>),
      stages: (body['stages'] as List? ?? [])
          .map((item) => CoquiLoopStage.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  // ── Webhooks ───────────────────────────────────────────────────────

  Future<({List<CoquiWebhook> webhooks, CoquiWebhookStats stats})>
      listWebhooks({
    bool? enabled,
    int limit = 100,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (enabled != null) {
      params['enabled'] = enabled.toString();
    }

    final response = await http.get(
      _url('/webhooks', params),
      headers: _headers,
    );
    final body = _parseResponse(response);
    final webhooks = (body['webhooks'] as List? ?? [])
        .map((item) => CoquiWebhook.fromJson(item as Map<String, dynamic>))
        .toList();

    return (
      webhooks: webhooks,
      stats: body['stats'] is Map<String, dynamic>
          ? CoquiWebhookStats.fromJson(body['stats'] as Map<String, dynamic>)
          : CoquiWebhookStats.empty,
    );
  }

  Future<CoquiWebhook> getWebhook(String id) async {
    final response = await http.get(
      _url('/webhooks/$id'),
      headers: _headers,
    );
    final body = _parseResponse(response);
    return CoquiWebhook.fromJson(body['webhook'] as Map<String, dynamic>);
  }

  Future<CoquiWebhook> createWebhook({
    required String name,
    required String promptTemplate,
    String source = 'generic',
    String role = 'orchestrator',
    String? profile,
    int maxIterations = 48,
    String? description,
    String? eventFilter,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'prompt_template': promptTemplate,
      'source': source,
      'role': role,
      'max_iterations': maxIterations,
    };
    if (profile != null && profile.isNotEmpty) payload['profile'] = profile;
    if (description != null && description.isNotEmpty) {
      payload['description'] = description;
    }
    if (eventFilter != null && eventFilter.isNotEmpty) {
      payload['event_filter'] = eventFilter;
    }

    final response = await http.post(
      _url('/webhooks'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final body = _parseResponse(response);
    return CoquiWebhook.fromJson(body['webhook'] as Map<String, dynamic>);
  }

  Future<CoquiWebhook> updateWebhook(
    String id, {
    String? name,
    String? description,
    String? source,
    String? promptTemplate,
    String? role,
    String? profile,
    bool clearProfile = false,
    int? maxIterations,
    bool? enabled,
    String? eventFilter,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (description != null) payload['description'] = description;
    if (source != null && source.isNotEmpty) payload['source'] = source;
    if (promptTemplate != null) payload['prompt_template'] = promptTemplate;
    if (role != null && role.isNotEmpty) payload['role'] = role;
    if (clearProfile) {
      payload['profile'] = '';
    } else if (profile != null) {
      payload['profile'] = profile;
    }
    if (maxIterations != null) payload['max_iterations'] = maxIterations;
    if (enabled != null) payload['enabled'] = enabled;
    if (eventFilter != null) payload['event_filter'] = eventFilter;

    final response = await http.put(
      _url('/webhooks/$id'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    final body = _parseResponse(response);
    return CoquiWebhook.fromJson(body['webhook'] as Map<String, dynamic>);
  }

  Future<void> deleteWebhook(String id) async {
    final response = await http.delete(
      _url('/webhooks/$id'),
      headers: _headers,
    );
    _parseResponse(response);
  }

  Future<String> rotateWebhookSecret(String id) async {
    final response = await http.post(
      _url('/webhooks/$id/rotate'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{}),
    );
    final body = _parseResponse(response);
    return body['secret'] as String? ?? '';
  }

  Future<List<CoquiWebhookDelivery>> listWebhookDeliveries(
    String id, {
    int limit = 50,
  }) async {
    final response = await http.get(
      _url('/webhooks/$id/deliveries', {'limit': limit.toString()}),
      headers: _headers,
    );
    final body = _parseResponse(response);
    final deliveries = body['deliveries'] as List? ?? [];
    return deliveries
        .map((item) =>
            CoquiWebhookDelivery.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Uri getWebhookIncomingUrl(String name) {
    return _url('/webhooks/incoming/$name');
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

int _coerceInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
