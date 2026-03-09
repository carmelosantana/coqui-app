/// Analytics service with platform-conditional implementation.
///
/// On web, delegates to Umami via JS interop.
/// On native platforms, all calls are silent no-ops.
library;

export 'analytics_service_stub.dart'
    if (dart.library.js_interop) 'analytics_service_web.dart';
