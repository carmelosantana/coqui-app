/// Exception thrown when a Coqui API request fails.
///
/// Carries the structured error envelope from the API:
/// `{"error": "...", "code": "...", "details": {...}}`
class CoquiException implements Exception {
  final String message;
  final int? statusCode;

  /// Machine-readable error code from the API (e.g. `"rate_limited"`,
  /// `"agent_busy"`, `"session_not_found"`).
  final String? code;

  /// Optional structured details (e.g. `{"retry_after": 5}`).
  final Map<String, dynamic>? details;

  CoquiException(
    this.message, {
    this.statusCode,
    this.code,
    this.details,
  });

  /// Parse from the unified API error envelope.
  factory CoquiException.fromJson(
    Map<String, dynamic> json, {
    int? statusCode,
  }) {
    return CoquiException(
      json['error'] as String? ?? 'Unknown error',
      statusCode: statusCode,
      code: json['code'] as String?,
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  /// Wrap any exception into a user-friendly [CoquiException].
  ///
  /// If [error] is already a [CoquiException], it is returned as-is.
  /// Transport-level errors (socket failures, client exceptions) are
  /// mapped to a clear connection message. Everything else gets a
  /// generic fallback — raw exception text is never exposed.
  factory CoquiException.friendly(Object error) {
    if (error is CoquiException) return error;

    final text = error.toString();

    if (text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('XMLHttpRequest') ||
        text.contains('Connection refused') ||
        text.contains('Connection reset')) {
      return CoquiException(
        'Unable to connect to the server. Please ensure your Coqui API '
        'server is running and try again.',
        code: 'connection_failed',
      );
    }

    if (text.contains('TimeoutException') || text.contains('timed out')) {
      return CoquiException(
        'Connection timed out. The server may be unresponsive.',
        code: 'timeout',
      );
    }

    if (text.contains('401') || text.contains('Unauthorized')) {
      return CoquiException(
        'Authentication failed. Please check your API key and try again.',
        code: 'unauthorized',
        statusCode: 401,
      );
    }

    if (text.contains('403') || text.contains('Forbidden')) {
      return CoquiException(
        'Access denied. You do not have permission for this action.',
        code: 'forbidden',
        statusCode: 403,
      );
    }

    return CoquiException(
      'An unexpected error occurred. Please try again.',
      code: 'unknown',
    );
  }

  /// Seconds to wait before retrying (from rate limit response).
  int? get retryAfter {
    final value = details?['retry_after'];
    if (value is int) return value;
    if (value is double) return value.ceil();
    return null;
  }

  /// Whether this error indicates the agent is busy processing.
  bool get isAgentBusy => code == 'agent_busy';

  /// Whether this error indicates an authentication problem.
  bool get isUnauthorized => code == 'unauthorized';

  /// Whether this error indicates rate limiting.
  bool get isRateLimited => code == 'rate_limited';

  /// Whether this error indicates payload was too large.
  bool get isPayloadTooLarge => code == 'payload_too_large';

  /// Whether this error indicates a resource was not found.
  bool get isNotFound => code == 'not_found';

  /// Whether this error indicates the session was not found.
  bool get isSessionNotFound => code == 'session_not_found';

  /// Whether this error indicates the turn was not found.
  bool get isTurnNotFound => code == 'turn_not_found';

  /// Whether this error indicates the role was not found.
  bool get isRoleNotFound => code == 'role_not_found';

  /// Whether this error indicates a credential was not found.
  bool get isCredentialNotFound => code == 'credential_not_found';

  /// Whether this error indicates a validation error.
  bool get isValidationError => code == 'validation_error';

  /// Whether this error indicates a required field is missing.
  bool get isMissingField => code == 'missing_field';

  /// Whether this error indicates an invalid format.
  bool get isInvalidFormat => code == 'invalid_format';

  /// Whether this error indicates a resource conflict.
  bool get isConflict => code == 'conflict';

  /// Whether this error indicates the role is built-in and cannot be modified.
  bool get isRoleBuiltin => code == 'role_builtin';

  /// Whether this error indicates the role name is reserved.
  bool get isRoleReserved => code == 'role_reserved';

  /// Whether this error indicates forbidden access.
  bool get isForbidden => code == 'forbidden';

  /// Whether this error indicates an unsupported media type.
  bool get isUnsupportedMediaType => code == 'unsupported_media_type';

  /// Whether this error indicates an internal server error.
  bool get isInternalError => code == 'internal_error';

  /// Whether this error indicates a connection failure.
  bool get isConnectionFailed => code == 'connection_failed';

  /// Whether this error indicates a timeout.
  bool get isTimeout => code == 'timeout';

  @override
  String toString() => message;
}
