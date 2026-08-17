import 'dart:convert';

/// Per-deployment runtime configuration, fetched from `<origin>/config.json`.
///
/// The hosted (Vercel) deployment serves no such file, so every parse failure
/// and every unexpected shape resolves to [notBundled] — the app's normal
/// manual-server behavior.
class RuntimeConfig {
  /// True only when the deployment ships a co-located Coqui server.
  final bool bundled;

  /// Absolute same-origin base for the co-located server, e.g.
  /// `http://host:8080`. Null when not bundled.
  final String? baseUrl;

  /// API version segment appended after `/api/` by the API service.
  final String apiVersion;

  const RuntimeConfig({
    required this.bundled,
    this.baseUrl,
    this.apiVersion = 'v1',
  });

  /// The safe default: behave exactly as the app did before bundling existed.
  static const RuntimeConfig notBundled = RuntimeConfig(bundled: false);

  /// Parse a `/config.json` response body.
  ///
  /// Deliberately strict: a hosted SPA rewrite answers `/config.json` with a
  /// 200 and `index.html`, so only a JSON object with a literal `true` for
  /// `bundled` is accepted.
  static RuntimeConfig fromResponseBody(String body, {required String origin}) {
    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return notBundled;
    }

    if (decoded is! Map) return notBundled;
    if (decoded['bundled'] != true) return notBundled;

    return RuntimeConfig(
      bundled: true,
      baseUrl: origin,
      apiVersion: apiVersionFromBase(decoded['apiBaseUrl']),
    );
  }

  /// Extract the version segment from an `/api/<version>` base path.
  ///
  /// Anything else — absent, malformed, or a different mount point — falls
  /// back to `v1`, the same-origin default.
  ///
  /// The segment itself must look like a version. An unvalidated segment is
  /// not merely cosmetic: `..` is normalized away by [Uri.replace], which
  /// would silently strip the `/api/<version>` prefix off every request and
  /// route it into the SPA catch-all instead.
  static String apiVersionFromBase(Object? apiBaseUrl) {
    if (apiBaseUrl is! String) return 'v1';

    final segments =
        apiBaseUrl.split('/').where((segment) => segment.isNotEmpty).toList();
    if (segments.length < 2 || segments.first != 'api') return 'v1';

    final version = segments[1];
    return RegExp(r'^v\d+$').hasMatch(version) ? version : 'v1';
  }
}
