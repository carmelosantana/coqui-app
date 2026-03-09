/// Platform detection that works on both native and web.
///
/// Uses conditional imports to avoid `dart:io` on web.
/// On native platforms, delegates to `dart:io` Platform.
/// On web, returns false for all native checks and true for [isWeb].
library;

export 'platform_info_stub.dart'
    if (dart.library.io) 'platform_info_native.dart'
    if (dart.library.js_interop) 'platform_info_web.dart';
