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

  @override
  String toString() => message;
}
