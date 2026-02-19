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

  @override
  String toString() => message;
}
