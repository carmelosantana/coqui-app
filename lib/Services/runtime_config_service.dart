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

  final http.Client _client;
  final Duration _timeout;
  final bool _isWeb;
  final String Function() _originResolver;

  RuntimeConfigService({
    http.Client? client,
    Duration timeout = const Duration(seconds: 3),
    bool? isWeb,
    String Function()? originResolver,
  })  : _client = client ?? http.Client(),
        _timeout = timeout,
        _isWeb = isWeb ?? PlatformInfo.isWeb,
        _originResolver = originResolver ?? _pageOrigin;

  static String _pageOrigin() => Uri.base.origin;

  Future<RuntimeConfig> load() async {
    if (!_isWeb) return RuntimeConfig.notBundled;

    final String origin;
    try {
      origin = _originResolver();
    } catch (_) {
      return RuntimeConfig.notBundled;
    }

    try {
      final response =
          await _client.get(Uri.parse('$origin$configPath')).timeout(_timeout);

      if (response.statusCode != 200) return RuntimeConfig.notBundled;

      return RuntimeConfig.fromResponseBody(response.body, origin: origin);
    } catch (_) {
      return RuntimeConfig.notBundled;
    }
  }
}
