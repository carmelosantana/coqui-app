/// Platform-conditional barrel for OS service management.
///
/// Dispatches to the correct implementation based on the target platform.
/// Web and mobile platforms get the stub (no-op) implementation.
library;

export 'service_manager_stub.dart'
    if (dart.library.io) 'service_manager_native.dart';
