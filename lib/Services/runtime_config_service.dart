import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:coqui_app/Models/runtime_config.dart';
import 'package:coqui_app/Platform/platform_info.dart';

/// Loads the per-deployment [RuntimeConfig] at app boot.
///
/// Web only: native builds never fetch. Every failure mode — non-web, 404,
/// SPA HTML fallback, malformed JSON, transport error, timeout — resolves to
/// [RuntimeConfig.notBundled], which is byte-for-byte the app's pre-existing
/// behavior.
class RuntimeConfigService {
  static const String configPath = '/config.json';

  http.Client? _client;
  final Duration _timeout;
  final bool _isWeb;
  final String Function() _originResolver;

  RuntimeConfigService({
    http.Client? client,
    Duration timeout = const Duration(seconds: 3),
    bool? isWeb,
    String Function()? originResolver,
  })  : _client = client,
        _timeout = timeout,
        _isWeb = isWeb ?? PlatformInfo.isWeb,
        _originResolver = originResolver ?? _pageOrigin;

  /// The injected client, or one created on first use. [load] short-circuits
  /// on native builds before touching this, so they allocate nothing.
  http.Client get _http => _client ??= http.Client();

  static String _pageOrigin() => Uri.base.origin;

  Future<RuntimeConfig> load() async {
    if (!_isWeb) return RuntimeConfig.notBundled;

    final String origin;
    try {
      // Deliberately bare: a non-http origin makes `Uri.base.origin` throw a
      // StateError, which is an Error, not an Exception.
      origin = _originResolver();
    } catch (_) {
      return RuntimeConfig.notBundled;
    }

    try {
      final response =
          await _http.get(Uri.parse('$origin$configPath')).timeout(_timeout);

      if (response.statusCode != 200) return RuntimeConfig.notBundled;

      return RuntimeConfig.fromResponseBody(response.body, origin: origin);
    } on Exception catch (_) {
      // Covers every spec'd failure mode (ClientException, TimeoutException,
      // FormatException) while letting a genuine programming Error surface
      // instead of masquerading as "not bundled".
      return RuntimeConfig.notBundled;
    }
  }
}
